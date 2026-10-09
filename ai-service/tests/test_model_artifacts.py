"""Startup rejects untrusted bytes and incompatible metadata before readiness."""

import hashlib
from pathlib import Path
from typing import cast

import pytest
import torch
from pydantic import JsonValue
from torch import Tensor

from app.model_management.artifacts import CLASS_NAMES, ModelStartupError, load_model
from tests.model_fixtures import (
    ModelFixture,
    read_json,
    refresh_checkpoint_pins,
    section,
    write_json,
    write_model_fixture,
)


@pytest.fixture
def artifacts(tmp_path: Path) -> ModelFixture:
    return write_model_fixture(tmp_path)


def test_valid_startup_returns_frozen_cpu_eval_model(artifacts: ModelFixture) -> None:
    loaded = artifacts.load()
    assert loaded.model.training is False
    assert all(parameter.device.type == "cpu" for parameter in loaded.model.parameters())
    assert all(not parameter.requires_grad for parameter in loaded.model.parameters())
    assert loaded.class_names == CLASS_NAMES
    assert loaded.config.segmentation.mode == "disabled"
    assert loaded.calibration_temperature == 1.0
    assert loaded.confidence_threshold is None
    assert loaded.validation_predictions_sha256 == (
        "b2c7ac706fce189e591e58349e0fd43516946af72219e32cd5b5a3247c7c7f1c"
    )
    with torch.inference_mode():
        assert loaded.model(torch.zeros(1, 3, 224, 224)).shape == (1, 4)


@pytest.mark.parametrize("kind", ["metadata", "checkpoint", "calibration"])
def test_missing_deployment_file_is_safe_failure(artifacts: ModelFixture, kind: str) -> None:
    expected_hash = artifacts.metadata_sha256
    paths = {
        "metadata": artifacts.metadata_path,
        "checkpoint": artifacts.checkpoint_path,
        "calibration": artifacts.metadata_path.parent / "calibration/calibration-config.json",
    }
    paths[kind].unlink()
    with pytest.raises(ModelStartupError) as caught:
        load_model(
            checkpoint_path=artifacts.checkpoint_path,
            metadata_path=artifacts.metadata_path,
            metadata_sha256=expected_hash,
            model_version=artifacts.model_version,
            preprocessing_version=artifacts.preprocessing_version,
            threads=2,
        )
    assert caught.value.code == f"MODEL_{kind.upper()}_MISSING"
    assert str(artifacts.metadata_path.parent) not in str(caught.value)


def test_metadata_digest_is_required(artifacts: ModelFixture) -> None:
    with pytest.raises(ModelStartupError, match="MODEL_METADATA_HASH_MISMATCH"):
        load_model(
            checkpoint_path=artifacts.checkpoint_path,
            metadata_path=artifacts.metadata_path,
            metadata_sha256="0" * 64,
            model_version=artifacts.model_version,
            preprocessing_version=artifacts.preprocessing_version,
            threads=2,
        )


@pytest.mark.parametrize("kind", ["metadata", "checkpoint", "calibration"])
def test_corrupt_deployment_bytes_fail(artifacts: ModelFixture, kind: str) -> None:
    paths = {
        "metadata": artifacts.metadata_path,
        "checkpoint": artifacts.checkpoint_path,
        "calibration": artifacts.metadata_path.parent / "calibration/calibration-config.json",
    }
    paths[kind].write_bytes(b"corrupt model content")
    with pytest.raises(ModelStartupError):
        artifacts.load()


@pytest.mark.parametrize(
    ("parent", "name", "value"),
    [
        ("", "model_version", "unknown-model"),
        ("", "architecture", "different-network"),
        ("", "classes", []),
        ("", "class_to_index", {"Common_Rust": 1}),
        ("", "production_model_promoted", True),
        ("", "verdict", "UNFIT"),
        ("input", "shape", [1, 3, 256, 256]),
        ("input", "color_space", "BGR"),
        ("input", "layout", "NHWC"),
        ("input", "dtype", "float16"),
        ("input", "resize", "stretch"),
        ("preprocessing", "version", "2.0.0"),
        ("preprocessing", "semantic_sha256", "0" * 64),
        ("calibration", "temperature", 1.2),
        ("calibration", "operational_threshold", 0.95),
        ("training", "selected_epoch", 9),
    ],
)
def test_incompatible_critical_metadata(
    artifacts: ModelFixture, parent: str, name: str, value: JsonValue
) -> None:
    payload = read_json(artifacts.metadata_path)
    target = section(payload, parent) if parent else payload
    target[name] = value
    write_json(artifacts.metadata_path, payload)
    with pytest.raises(ModelStartupError):
        artifacts.load()


@pytest.mark.parametrize("name", ["model_version", "classes", "input", "preprocessing"])
def test_critical_fields_are_required(artifacts: ModelFixture, name: str) -> None:
    payload = read_json(artifacts.metadata_path)
    del payload[name]
    write_json(artifacts.metadata_path, payload)
    with pytest.raises(ModelStartupError):
        artifacts.load()


@pytest.mark.parametrize("name", ["max_bytes", "interpolation", "normalization", "segmentation"])
def test_shared_configuration_never_fills_missing_defaults(
    artifacts: ModelFixture, name: str
) -> None:
    payload = read_json(artifacts.metadata_path)
    config = section(section(payload, "preprocessing"), "configuration")
    del config[name]
    write_json(artifacts.metadata_path, payload)
    with pytest.raises(ModelStartupError, match="MODEL_PREPROCESSING_INCOMPATIBLE"):
        artifacts.load()


@pytest.mark.parametrize("name", ["mean", "std"])
def test_normalization_incompatibility_fails(artifacts: ModelFixture, name: str) -> None:
    payload = read_json(artifacts.metadata_path)
    normalization = section(section(payload, "input"), "normalization")
    normalization[name] = [0.1, 0.2, 0.3]
    write_json(artifacts.metadata_path, payload)
    with pytest.raises(ModelStartupError):
        artifacts.load()


def test_runtime_dependency_mismatch_fails(artifacts: ModelFixture) -> None:
    payload = read_json(artifacts.metadata_path)
    distributions = cast(
        list[dict[str, JsonValue]], section(payload, "environment")["distributions"]
    )
    for distribution in distributions:
        if distribution["name"] == "maizedoctor-preprocessing":
            distribution["version"] = "9.9.9"
    write_json(artifacts.metadata_path, payload)
    with pytest.raises(ModelStartupError, match="MODEL_RUNTIME_INCOMPATIBLE"):
        artifacts.load()


@pytest.mark.parametrize(
    "mutation", ["classes", "epoch", "preprocessing", "nonfinite", "shape", "dtype"]
)
def test_checksummed_but_incompatible_checkpoint_fails(
    artifacts: ModelFixture, mutation: str
) -> None:
    payload = cast(
        dict[str, object],
        torch.load(artifacts.checkpoint_path, map_location="cpu", weights_only=True),
    )
    if mutation == "classes":
        payload["class_names"] = list(reversed(CLASS_NAMES))
    elif mutation == "epoch":
        payload["epoch"] = 9
    elif mutation == "preprocessing":
        payload["preprocessing_hash"] = "0" * 64
    else:
        state = cast(dict[str, Tensor], payload["state_dict"])
        if mutation == "nonfinite":
            state["classifier.3.bias"][0] = float("nan")
        elif mutation == "dtype":
            state["classifier.3.bias"] = state["classifier.3.bias"].to(torch.float64)
        else:
            state["classifier.3.bias"] = torch.zeros(5)
    torch.save(payload, artifacts.checkpoint_path)
    refresh_checkpoint_pins(artifacts)
    with pytest.raises(ModelStartupError):
        artifacts.load()


def test_safe_failure_for_non_checkpoint_bytes_with_valid_checksum(artifacts: ModelFixture) -> None:
    artifacts.checkpoint_path.write_bytes(b"this is not a torch checkpoint")
    refresh_checkpoint_pins(artifacts)
    with pytest.raises(ModelStartupError):
        artifacts.load()


def test_finite_weights_producing_nonfinite_outputs_fail(artifacts: ModelFixture) -> None:
    payload = cast(
        dict[str, object],
        torch.load(artifacts.checkpoint_path, map_location="cpu", weights_only=True),
    )
    state = cast(dict[str, Tensor], payload["state_dict"])
    state["features.0.0.weight"].fill_(torch.finfo(torch.float32).max)
    state["features.0.1.bias"].fill_(torch.finfo(torch.float32).max)
    torch.save(payload, artifacts.checkpoint_path)
    refresh_checkpoint_pins(artifacts)
    with pytest.raises(ModelStartupError, match="MODEL_OUTPUT_INVALID"):
        artifacts.load()


@pytest.mark.parametrize("name", ["checkpoint_sha256", "preprocessing_hash", "class_names"])
def test_calibration_metadata_binds_selected_model(artifacts: ModelFixture, name: str) -> None:
    sidecar_path = artifacts.metadata_path.parent / "calibration/calibration-config.json"
    sidecar = read_json(sidecar_path)
    sidecar[name] = [] if name == "class_names" else "0" * 64
    write_json(sidecar_path, sidecar)
    metadata = read_json(artifacts.metadata_path)
    reference = section(section(metadata, "calibration"), "configuration")
    reference["sha256"] = hashlib.sha256(sidecar_path.read_bytes()).hexdigest()
    reference["size_bytes"] = sidecar_path.stat().st_size
    write_json(artifacts.metadata_path, metadata)
    with pytest.raises(ModelStartupError, match="MODEL_CALIBRATION_INCOMPATIBLE"):
        artifacts.load()


def test_metadata_size_is_bounded(artifacts: ModelFixture) -> None:
    artifacts.metadata_path.write_bytes(b"x" * (512 * 1024 + 1))
    with pytest.raises(ModelStartupError, match="MODEL_METADATA_INVALID"):
        artifacts.load()


@pytest.mark.parametrize("threads", [0, 9, True])
def test_thread_limit_is_enforced(artifacts: ModelFixture, threads: int) -> None:
    with pytest.raises(ModelStartupError, match="MODEL_CONFIGURATION_INVALID"):
        load_model(
            checkpoint_path=artifacts.checkpoint_path,
            metadata_path=artifacts.metadata_path,
            metadata_sha256=artifacts.metadata_sha256,
            model_version=artifacts.model_version,
            preprocessing_version=artifacts.preprocessing_version,
            threads=threads,
        )
