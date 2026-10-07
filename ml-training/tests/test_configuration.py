"""Dataset configuration is deterministic, portable, and independent of cwd."""

import os
from pathlib import Path

import pytest

import configuration
from configuration import DatasetConfigurationError, load_dataset_path


def test_missing_configuration(tmp_path: Path) -> None:
    with pytest.raises(DatasetConfigurationError, match="must be configured"):
        load_dataset_path(environment={}, dotenv_path=tmp_path / "missing.env")


@pytest.mark.parametrize("value", ["", " ", "\t\n"])
def test_blank_configuration(value: str, tmp_path: Path) -> None:
    with pytest.raises(DatasetConfigurationError, match="must be configured"):
        load_dataset_path(environment={"DATASET_PATH": value}, dotenv_path=tmp_path / ".env")


@pytest.mark.parametrize("value", ["dataset", "./dataset", "../dataset"])
def test_relative_path_is_rejected(value: str) -> None:
    with pytest.raises(DatasetConfigurationError, match="absolute directory"):
        load_dataset_path(environment={"DATASET_PATH": value})


def test_missing_directory_is_rejected(tmp_path: Path) -> None:
    with pytest.raises(DatasetConfigurationError, match="existing directory"):
        load_dataset_path(environment={"DATASET_PATH": str(tmp_path / "missing")})


def test_regular_file_is_rejected(tmp_path: Path) -> None:
    file = tmp_path / "image.png"
    file.write_bytes(b"not a dataset directory")
    with pytest.raises(DatasetConfigurationError, match="existing directory"):
        load_dataset_path(environment={"DATASET_PATH": str(file)})


def test_unicode_and_spaces_in_absolute_directory(tmp_path: Path) -> None:
    dataset = tmp_path / "maize leaves \u062d\u0642\u0644"
    dataset.mkdir()
    assert load_dataset_path(environment={"DATASET_PATH": str(dataset)}) == dataset.resolve()


def test_environment_takes_precedence_without_reading_dotenv(tmp_path: Path) -> None:
    dataset = tmp_path / "selected dataset"
    dataset.mkdir()
    invalid_dotenv = tmp_path / ".env"
    invalid_dotenv.write_bytes(b"\xff\xfeinvalid UTF-8")
    assert (
        load_dataset_path(environment={"DATASET_PATH": str(dataset)}, dotenv_path=invalid_dotenv)
        == dataset.resolve()
    )


def test_blank_environment_does_not_fall_back_to_dotenv(tmp_path: Path) -> None:
    dotenv = tmp_path / ".env"
    dotenv.write_text(f"DATASET_PATH='{tmp_path.as_posix()}'\n", encoding="utf-8")
    with pytest.raises(DatasetConfigurationError, match="must be configured"):
        load_dataset_path(environment={"DATASET_PATH": ""}, dotenv_path=dotenv)


def test_dotenv_default_is_independent_of_cwd(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    project = tmp_path / "training project"
    project.mkdir()
    dataset = tmp_path / "raw leaves"
    dataset.mkdir()
    (project / ".env").write_text(f"DATASET_PATH='{dataset.as_posix()}'\n", encoding="utf-8")
    caller_directory = tmp_path / "another directory"
    caller_directory.mkdir()
    monkeypatch.setattr(configuration, "_TRAINING_ROOT", project)
    monkeypatch.chdir(caller_directory)

    assert load_dataset_path(environment={}) == dataset.resolve()


def test_loader_does_not_mutate_environment(tmp_path: Path) -> None:
    dotenv = tmp_path / ".env"
    dotenv.write_text(
        f"DATASET_PATH='{tmp_path.as_posix()}'\nUNRELATED_SETTING=must_not_be_loaded\n",
        encoding="utf-8",
    )
    before = dict(os.environ)
    assert load_dataset_path(environment={}, dotenv_path=dotenv) == tmp_path.resolve()
    assert dict(os.environ) == before


def test_empty_dotenv_key_is_rejected(tmp_path: Path) -> None:
    dotenv = tmp_path / ".env"
    dotenv.write_text("DATASET_PATH\n", encoding="utf-8")
    with pytest.raises(DatasetConfigurationError, match="must be configured"):
        load_dataset_path(environment={}, dotenv_path=dotenv)


def test_dotenv_interpolation_is_disabled(tmp_path: Path) -> None:
    dotenv = tmp_path / ".env"
    dotenv.write_text("DATASET_PATH=${UNRELATED_SETTING}\n", encoding="utf-8")
    with pytest.raises(DatasetConfigurationError, match="absolute directory"):
        load_dataset_path(environment={"UNRELATED_SETTING": str(tmp_path)}, dotenv_path=dotenv)


def test_invalid_dotenv_encoding_has_safe_error(tmp_path: Path) -> None:
    dotenv = tmp_path / ".env"
    dotenv.write_bytes(b"DATASET_PATH=\xff")
    with pytest.raises(DatasetConfigurationError, match="configuration file cannot be read"):
        load_dataset_path(environment={}, dotenv_path=dotenv)


def test_default_reads_process_environment(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATASET_PATH", str(tmp_path))
    before = dict(os.environ)
    assert load_dataset_path(dotenv_path=tmp_path / "missing.env") == tmp_path.resolve()
    assert dict(os.environ) == before


def test_invalid_path_has_safe_error(tmp_path: Path) -> None:
    with pytest.raises(DatasetConfigurationError, match="existing directory|cannot be inspected"):
        load_dataset_path(environment={"DATASET_PATH": str(tmp_path / "invalid\0")})
