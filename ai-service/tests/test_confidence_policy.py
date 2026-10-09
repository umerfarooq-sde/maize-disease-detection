"""Operational cutoffs require pinned validation provenance, never a default guess."""

import hashlib
import json
from dataclasses import replace
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.model_management.artifacts import ModelStartupError
from app.model_management.confidence import load_confidence_policy
from tests.model_fixtures import ModelFixture, write_model_fixture
from tests.test_prediction_api import HEADERS, image_bytes, settings_for


@pytest.fixture(scope="module")
def policy_model(tmp_path_factory: pytest.TempPathFactory) -> ModelFixture:
    return write_model_fixture(tmp_path_factory.mktemp("confidence-policy"), class_index=2)


def policy_file(path: Path, fixture: ModelFixture, **changes: object) -> tuple[Path, str]:
    loaded = fixture.load()
    payload = {
        "schema_version": 1,
        "decision_status": "approved_for_research",
        "selected_using": "validation",
        "model_version": loaded.model_version,
        "checkpoint_sha256": loaded.checkpoint_sha256,
        "validation_predictions_sha256": loaded.validation_predictions_sha256,
        "threshold": 0.99,
        "rationale": "Synthetic unit-test policy; this does not approve a real deployment cutoff.",
        **changes,
    }
    path.write_text(json.dumps(payload), encoding="utf-8")
    return path, hashlib.sha256(path.read_bytes()).hexdigest()


@pytest.mark.parametrize(
    ("name", "value"),
    [
        ("selected_using", "test"),
        ("decision_status", "experimental"),
        ("model_version", "different-model"),
        ("checkpoint_sha256", "0" * 64),
        ("validation_predictions_sha256", "0" * 64),
        ("threshold", 0),
        ("threshold", 1),
        ("threshold", float("nan")),
        ("rationale", ""),
    ],
)
def test_unapproved_or_incompatible_policy_fails_safely(
    tmp_path: Path, policy_model: ModelFixture, name: str, value: object
) -> None:
    path, digest = policy_file(tmp_path / "policy.json", policy_model, **{name: value})
    with pytest.raises(ModelStartupError, match="CONFIDENCE_POLICY_INVALID"):
        load_confidence_policy(path, digest, policy_model.load())


def test_policy_bytes_must_match_configured_digest(
    tmp_path: Path, policy_model: ModelFixture
) -> None:
    path, digest = policy_file(tmp_path / "policy.json", policy_model)
    path.write_bytes(b"private invalid policy content")
    with pytest.raises(ModelStartupError) as failure:
        load_confidence_policy(path, digest, policy_model.load())
    assert "private" not in str(failure.value)
    assert str(path) not in str(failure.value)


@pytest.mark.parametrize("missing", ["path", "digest"])
def test_partial_policy_configuration_fails_startup(
    tmp_path: Path, policy_model: ModelFixture, missing: str
) -> None:
    path, digest = policy_file(tmp_path / "policy.json", policy_model)
    settings = settings_for(
        policy_model,
        confidence_policy_path=path if missing != "path" else None,
        confidence_policy_sha256=digest if missing != "digest" else "",
    )
    with (
        pytest.raises(ModelStartupError, match="CONFIDENCE_POLICY_INVALID"),
        TestClient(create_app(settings)),
    ):
        pass


def test_explicit_synthetic_validation_policy_controls_api_status(
    tmp_path: Path, policy_model: ModelFixture
) -> None:
    path, digest = policy_file(tmp_path / "policy.json", policy_model)
    settings = settings_for(
        policy_model, confidence_policy_path=path, confidence_policy_sha256=digest
    )
    loaded = policy_model.load()
    original_state = {key: tensor.clone() for key, tensor in loaded.model.state_dict().items()}
    with TestClient(create_app(settings, model_loader=lambda **_kwargs: loaded)) as client:
        health = client.get("/api/v1/model-health", headers=HEADERS)
        assert health.json()["data"]["confidenceThreshold"] == 0.99
        assert health.json()["data"]["confidencePolicy"] == "VALIDATION_BASED"
        response = client.post(
            "/api/v1/predict",
            content=image_bytes(),
            headers={**HEADERS, "Content-Type": "image/jpeg"},
        )
    assert response.status_code == 200
    assert response.json()["data"]["predictionStatus"] == "CONFIDENT"
    assert response.json()["data"]["confidenceThreshold"] == 0.99
    assert loaded.confidence_threshold is None
    assert loaded.calibration_temperature == 1
    assert all(
        tensor.equal(original_state[key]) for key, tensor in loaded.model.state_dict().items()
    )

    # A uniform synthetic classifier demonstrates below-threshold handling via HTTP.
    import torch
    from torch import nn

    class UniformModel(nn.Module):
        def forward(self, tensor: torch.Tensor) -> torch.Tensor:
            return torch.zeros((1, 4))

    uniform = replace(loaded, model=UniformModel().eval())
    with TestClient(create_app(settings, model_loader=lambda **_kwargs: uniform)) as client:
        response = client.post(
            "/api/v1/predict",
            content=image_bytes(),
            headers={**HEADERS, "Content-Type": "image/jpeg"},
        )
    assert response.json()["data"]["predictionStatus"] == "LOW_CONFIDENCE"
    assert response.json()["data"]["uncertaintyReason"] == "BELOW_VALIDATION_THRESHOLD"
