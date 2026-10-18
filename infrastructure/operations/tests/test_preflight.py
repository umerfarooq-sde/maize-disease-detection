import json
import secrets
from pathlib import Path

import preflight
import pytest


def configuration(tmp_path):
    directory = tmp_path / "secrets"
    directory.mkdir()
    model = tmp_path / "model"
    model.mkdir()
    node = {
        key: secrets.token_urlsafe(32)
        for key in ("JWT_SECRET", "JWT_REFRESH_SECRET", "AI_SERVICE_TOKEN", "OPERATIONS_TOKEN")
    }
    node.update(
        {
            "REDIS_URL": "redis://:synthetic@redis:6379",
            "CLOUDINARY_API_KEY": "synthetic",
            "CLOUDINARY_API_SECRET": "synthetic",
        }
    )
    for name, role in [
        ("node", "md_node"),
        ("ai", "md_ai"),
        ("migration", "md_migrator"),
        ("backup", "md_backup"),
        ("privacy", "md_privacy"),
        ("curator", "md_curator"),
    ]:
        value = {
            "DATABASE_URL": f"postgresql://{role}:synthetic@db.example.invalid/application?sslmode=verify-full"
        }
        if name == "node":
            value.update(node)
        if name in ("ai", "curator"):
            value.update({k: node[k] for k in ("AI_SERVICE_TOKEN", "OPERATIONS_TOKEN")})
            value["GEMINI_API_KEY"] = "synthetic"
        (directory / (name + ".json")).write_text(json.dumps(value))
    (directory / "operations-token").write_text(node["OPERATIONS_TOKEN"])
    (directory / "backup-key").write_bytes(bytes(range(32)))
    policy = Path(__file__).resolve().parents[2] / "runtime/privacy-policy.example.json"
    values = {
        "STACK_NAME": "synthetic",
        "API_HOST": "api.example.com",
        "PUBLIC_HTTPS_ORIGIN": "https://api.example.com",
        "CORS_ORIGINS": "https://portal.example.com",
        "SECRETS_DIRECTORY": directory.as_posix(),
        "MODEL_DIRECTORY": model.as_posix(),
        "PRIVACY_POLICY_FILE": policy.as_posix(),
        "CLOUDINARY_CLOUD_NAME": "synthetic",
        "EMBEDDING_MODEL": "synthetic",
        "EMBEDDING_VERSION": "synthetic",
        "GEMINI_MODEL": "synthetic",
    }
    file = tmp_path / "deployment.env"
    file.write_text("".join(key + "=" + value + "\n" for key, value in values.items()))
    return file, directory


def test_six_purpose_identities_and_default_policy(tmp_path, monkeypatch):
    file, directory = configuration(tmp_path)
    monkeypatch.setattr(preflight, "verify_artifacts", lambda _path: {"synthetic": "test-only"})
    result = preflight.preflight(file)
    assert result["status"] == "PASS" and result["hostedTLSVerified"] is False
    assert result["policyErasureEnabled"] is False
    privacy = json.loads((directory / "privacy.json").read_text())
    privacy["DATABASE_URL"] = privacy["DATABASE_URL"].replace("md_privacy", "md_node")
    (directory / "privacy.json").write_text(json.dumps(privacy))
    with pytest.raises(ValueError, match="identity"):
        preflight.preflight(file)


def test_relative_and_overlapping_secret_mounts_are_rejected(tmp_path, monkeypatch):
    file, directory = configuration(tmp_path)
    monkeypatch.setattr(preflight, "verify_artifacts", lambda _path: {})
    text = file.read_text()
    file.write_text(
        text.replace(
            "MODEL_DIRECTORY=" + str(tmp_path / "model").replace("\\", "/"),
            "MODEL_DIRECTORY=" + directory.as_posix(),
        )
    )
    with pytest.raises(ValueError, match="separate"):
        preflight.preflight(file)
