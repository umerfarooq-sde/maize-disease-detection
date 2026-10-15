"""Offline evidence is a projection, never a new final-test evaluation."""

import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.main import create_app
from app.model_management.artifacts import ModelStartupError
from app.model_management.dashboard import Evaluation, RuntimeStatistics, development_snapshot
from tests.model_fixtures import write_model_fixture
from tests.test_prediction_api import HEADERS, image_bytes, settings_for

REPORT = Path(__file__).resolve().parents[2] / (
    "ml-training/reports/mobilenet-v3-small-20261009-v2-01-fitness/model-artifact.json"
)


def test_pinned_saved_metrics_preserve_values_and_omit_private_artifact_fields() -> None:
    snapshot = development_snapshot(REPORT.read_bytes())
    source = json.loads(REPORT.read_bytes())["metrics"]["final_test"]["raw_classification"]
    assert snapshot.evaluation.sample_count == 624
    assert snapshot.evaluation.accuracy == source["accuracy"]
    assert snapshot.evaluation.confusion_matrix == source["confusion_matrix"]
    assert snapshot.trainedAt is None
    public = snapshot.model_dump_json()
    for private in (".cache", "checkpoint", "environment", "hyperparameters", "dependencies"):
        assert private not in public


@pytest.mark.parametrize("change", ["negative", "count", "label", "accuracy", "nan"])
def test_corrupt_evaluation_fails_closed(change: str) -> None:
    data = json.loads(REPORT.read_bytes())["metrics"]["final_test"]["raw_classification"]
    if change == "negative":
        data["confusion_matrix"][0][0] = -1
    elif change == "count":
        data["sample_count"] += 1
    elif change == "label":
        data["per_class"][0]["label"] = "Invented"
    elif change == "accuracy":
        data["accuracy"] = 0.5
    else:
        data["macro_f1"] = float("nan")
    with pytest.raises(ValidationError):
        Evaluation.model_validate(data)


def test_thread_safe_bounded_counters_and_empty_denominators() -> None:
    statistics = RuntimeStatistics()
    empty = statistics.snapshot()
    assert empty.lowConfidenceRate is empty.meanLatencyMs is None

    def run(i: int) -> None:
        started = statistics.begin()
        statistics.finish(started, "Healthy" if i % 2 else None, True)

    with ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(run, range(100)))
    result = statistics.snapshot()
    assert result.requests == 100
    assert result.successes == result.failures == result.lowConfidence == 50
    assert result.inFlight == 0
    assert sum(result.predictionDistribution.values()) == 50
    assert result.lowConfidenceRate == 1
    assert result.meanLatencyMs is not None and result.meanLatencyMs >= 0


def test_protected_dashboard_tracks_success_admission_failure_and_resets(tmp_path: Path) -> None:
    fixture = write_model_fixture(tmp_path)
    app = create_app(settings_for(fixture))
    with TestClient(app) as client:
        assert client.get("/api/v1/model-dashboard").status_code == 401
        assert (
            client.get("/api/v1/model-dashboard?unexpected=1", headers=HEADERS).status_code == 422
        )
        first = client.get("/api/v1/model-dashboard", headers=HEADERS).json()["data"]
        assert first["ready"] is True
        assert first["runtime"]["requests"] == 0
        assert first["development"]["evaluation"]["sample_count"] == 624
        assert client.post("/api/v1/predict", headers=HEADERS, content=b"bad").status_code == 415
        assert (
            client.post(
                "/api/v1/predict",
                headers={**HEADERS, "Content-Type": "image/png"},
                content=image_bytes("PNG"),
            ).status_code
            == 200
        )
        current = client.get("/api/v1/model-dashboard", headers=HEADERS).json()["data"]
        assert current["development"] == first["development"]
        assert current["runtime"]["requests"] == 2
        assert current["runtime"]["successes"] == current["runtime"]["failures"] == 1
        assert current["runtime"]["lowConfidenceRate"] == 1
    with TestClient(app) as client:
        assert (
            client.get("/api/v1/model-dashboard", headers=HEADERS).json()["data"]["runtime"][
                "requests"
            ]
            == 0
        )


def test_disabled_inference_reports_not_loaded_without_fake_evaluation(tmp_path: Path) -> None:
    app = create_app(settings_for(write_model_fixture(tmp_path), inference_enabled=False))
    with TestClient(app) as client:
        response = client.get("/api/v1/model-dashboard", headers=HEADERS)
        assert response.status_code == 200
        data = response.json()["data"]
        assert data["ready"] is False
        assert data["modelVersion"] is data["development"] is None


def test_corrupt_saved_evaluation_stops_model_startup(tmp_path: Path) -> None:
    fixture = write_model_fixture(tmp_path)
    metadata = json.loads(fixture.metadata_path.read_bytes())
    metadata["metrics"]["final_test"]["raw_classification"]["sample_count"] = 999
    fixture.metadata_path.write_text(json.dumps(metadata), encoding="utf-8")
    with pytest.raises(ModelStartupError, match="MODEL_ARTIFACT_INVALID"):
        fixture.load()
