"""Configuration boundaries, deterministic dotenv loading and safe failures."""

import traceback
from pathlib import Path

import pytest
from pydantic import SecretStr, ValidationError

from app.config.settings import SERVICE_ROOT, ConfigurationError, Settings, load_settings

TEST_TOKEN = "test_only_" + "T" * 55


def test_executable_reports_actionable_safe_policy_error(monkeypatch: pytest.MonkeyPatch) -> None:
    import json
    import logging
    from types import SimpleNamespace

    from app import server
    from app.utils.logging import JsonFormatter

    class Capture:
        def error(self, message: str, *, extra: dict[str, object]) -> None:
            record = logging.LogRecord("test", logging.ERROR, "", 0, message, (), None)
            for key, value in extra.items():
                setattr(record, key, value)
            payload = json.loads(JsonFormatter().format(record))
            assert "configure both" in payload["configuration_hint"]
            assert "CONFIDENCE_POLICY_SHA256" in payload["configuration_hint"]

    def invalid() -> Settings:
        raise ConfigurationError(
            "CONFIDENCE_POLICY_INVALID: configure both CONFIDENCE_POLICY_PATH and "
            "CONFIDENCE_POLICY_SHA256, or leave both empty."
        )

    monkeypatch.setattr(server, "load_settings", invalid)
    monkeypatch.setattr(server, "configure_logging", lambda _level: None)
    monkeypatch.setattr(server, "logging", SimpleNamespace(getLogger=lambda _name: Capture()))
    with pytest.raises(SystemExit) as result:
        server.main()
    assert result.value.code == 1


@pytest.mark.parametrize("path,digest", [("", "a" * 64), ("policy.json", "")])
def test_policy_preflight_explains_one_sided_dotenv_without_values(
    tmp_path: Path, path: str, digest: str
) -> None:
    env = tmp_path / "service.env"
    env.write_text(f"CONFIDENCE_POLICY_PATH={path}\nCONFIDENCE_POLICY_SHA256={digest}\n")
    with pytest.raises(ConfigurationError, match="configure both") as failure:
        load_settings(env)
    assert "Windows PowerShell" in str(failure.value)
    assert "a" * 64 not in str(failure.value)


@pytest.mark.parametrize("path,digest", [("", ""), ("policy.json", "a" * 64)])
def test_policy_preflight_accepts_paired_optional_states(
    tmp_path: Path, path: str, digest: str
) -> None:
    env = tmp_path / "service.env"
    env.write_text(f"CONFIDENCE_POLICY_PATH={path}\nCONFIDENCE_POLICY_SHA256={digest}\n")
    assert bool(load_settings(env).confidence_policy_path) == bool(path)


def test_local_defaults_need_no_database_model_or_generation_credentials() -> None:
    settings = load_settings(env_file=None)
    assert settings.environment == "development"
    assert settings.host == "127.0.0.1"
    assert settings.port == 8000
    assert settings.log_level == "INFO"
    assert settings.ai_service_token.get_secret_value() == ""
    assert settings.inference_enabled is True
    assert settings.model_path is None
    assert Settings.model_config["env_file"] == SERVICE_ROOT / ".env"
    assert Path(Settings.model_config["env_file"]).is_absolute()


def test_process_environment_overrides_explicit_service_env_file(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env_file = tmp_path / "service.env"
    env_file.write_text(
        "ENVIRONMENT=test\nPORT=8123\nHOST=127.0.0.1\nUNUSED_KEY=private_unused\n", encoding="utf-8"
    )
    monkeypatch.setenv("PORT", "8456")
    settings = load_settings(env_file=env_file)
    assert settings.port == 8456
    assert settings.environment == "test"
    assert "private_unused" not in repr(settings)


def test_dotenv_location_is_independent_of_working_directory(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    source_directory = tmp_path / "service"
    source_directory.mkdir()
    env_file = source_directory / ".env"
    env_file.write_text("PORT=8123\nENVIRONMENT=test\n", encoding="utf-8")
    hostile_directory = tmp_path / "other"
    hostile_directory.mkdir()
    (hostile_directory / ".env").write_text("PORT=invalid_cwd_marker\n", encoding="utf-8")
    monkeypatch.chdir(hostile_directory)
    assert load_settings(env_file=env_file).port == 8123
    assert load_settings(env_file=None).port == 8000


@pytest.mark.parametrize("host", ["127.0.0.1", "::1", "localhost"])
def test_loopback_development_can_start_without_service_token(host: str) -> None:
    assert Settings(_env_file=None, host=host).host == host


@pytest.mark.parametrize(
    ("environment", "host"),
    [
        ("production", "127.0.0.1"),
        ("development", "0.0.0.0"),
        ("test", "::"),
        ("development", "192.168.1.20"),
    ],
)
def test_production_and_non_loopback_binding_require_token(environment: str, host: str) -> None:
    with pytest.raises(ValidationError):
        Settings(_env_file=None, environment=environment, host=host)
    settings = Settings(
        _env_file=None, environment=environment, host=host, ai_service_token=SecretStr(TEST_TOKEN)
    )
    assert settings.host == host
    assert settings.ai_service_token.get_secret_value() == TEST_TOKEN
    assert TEST_TOKEN not in repr(settings)


@pytest.mark.parametrize(
    ("variable", "value"),
    [
        ("ENVIRONMENT", "private_invalid_environment"),
        ("HOST", "https://private_invalid_host"),
        ("PORT", "private_invalid_port"),
        ("PORT", "0"),
        ("PORT", "65536"),
        ("LOG_LEVEL", "private_invalid_level"),
        ("AI_SERVICE_TOKEN", "private_short_token"),
        ("AI_SERVICE_TOKEN", "private token with spaces " + "T" * 50),
        ("MODEL_METADATA_SHA256", "private-invalid-hash"),
        ("INFERENCE_THREADS", "0"),
        ("INFERENCE_MAX_CONCURRENCY", "5"),
        ("INFERENCE_UPLOAD_TIMEOUT_SECONDS", "nan"),
    ],
)
def test_invalid_environment_fails_startup_without_echoing_rejected_values(
    monkeypatch: pytest.MonkeyPatch, variable: str, value: str
) -> None:
    monkeypatch.setenv(variable, value)
    with pytest.raises(ConfigurationError) as caught:
        load_settings(env_file=None)
    safe_traceback = "".join(traceback.format_exception(caught.value))
    assert "Invalid AI service configuration" in safe_traceback
    if "private" in value:
        assert value not in safe_traceback
    assert caught.value.__cause__ is None
    assert caught.value.__suppress_context__ is True


def test_invalid_env_file_encoding_is_reported_as_safe_configuration_error(tmp_path: Path) -> None:
    env_file = tmp_path / ".env"
    env_file.write_bytes(b"AI_SERVICE_TOKEN=private_file_secret\xff")
    with pytest.raises(ConfigurationError) as caught:
        load_settings(env_file=env_file)
    assert "private_file_secret" not in str(caught.value)
    assert str(env_file) not in str(caught.value)


def test_settings_are_immutable_and_do_not_re_read_process_environment(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    settings = load_settings(env_file=None)
    monkeypatch.setenv("PORT", "8123")
    assert settings.port == 8000
    assert load_settings(env_file=None).port == 8123
    with pytest.raises(ValidationError):
        settings.port = 8123


def test_artifact_paths_resolve_against_service_root_not_cwd(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.chdir(tmp_path)
    monkeypatch.setenv("MODEL_PATH", "models/version.pt")
    assert load_settings(env_file=None).model_path == (SERVICE_ROOT / "models/version.pt").resolve()
    monkeypatch.setenv("MODEL_PATH", "")
    assert load_settings(env_file=None).model_path is None
