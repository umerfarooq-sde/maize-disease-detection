"""Provider telemetry is bounded metadata and cannot replace operation outcomes."""

from threading import Event
from time import perf_counter

import pytest

from app.utils.errors import AppError, ErrorCode
from app.utils.operations import CURRENT, OperationsRecorder, provider_operation


def test_capacity_is_bounded_and_owned_shutdown_drains_without_payload_leaks(caplog) -> None:
    entered, release = Event(), Event()
    rows: list[dict[str, object]] = []

    def blocked_sink(event: dict[str, object]) -> None:
        entered.set()
        assert release.wait(5), "Fixture must release the owned worker"
        rows.append(event)

    recorder = OperationsRecorder(blocked_sink)
    try:
        recorder.record("INFERENCE", perf_counter(), None, "AI_SERVICE")
        assert entered.wait(2)
        for _ in range(132):
            recorder.record("INFERENCE", perf_counter(), None, "AI_SERVICE")
        assert recorder.events.qsize() == 128
        assert recorder.dropped == 4
        assert "ai_telemetry_capacity_exceeded" in caplog.text
    finally:
        release.set()
        recorder.close()
    assert not recorder.worker.is_alive()
    assert recorder.events.unfinished_tasks == 0
    assert len(rows) == 129
    assert len({row["id"] for row in rows}) == 129


def test_storage_loss_does_not_change_inference_and_later_event_recovers(caplog) -> None:
    from PIL import Image
    from test_inference import encode, loaded_model

    from app.inference.service import InferenceService

    rows: list[dict[str, object]] = []
    attempts = 0

    def intermittent_sink(event: dict[str, object]) -> None:
        nonlocal attempts
        attempts += 1
        if attempts == 1:
            raise RuntimeError("private-storage-marker")
        rows.append(event)

    recorder = OperationsRecorder(intermittent_sink)
    token = CURRENT.set(recorder)
    try:
        service = InferenceService(loaded_model())
        image = encode(Image.new("RGB", (48, 80), (112, 140, 30)))
        first = service.predict(image, mime_type="image/png")
        second = service.predict(image, mime_type="image/png")
        assert first.predicted_class == second.predicted_class == "Healthy"
        assert first.confidence == second.confidence
    finally:
        CURRENT.reset(token)
        recorder.close()
    assert attempts == 2 and recorder.dropped == 1
    assert len(rows) == 1 and rows[0]["operation"] == "INFERENCE"
    assert rows[0]["outcome"] == "SUCCESS"
    assert "ai_telemetry_storage_failed" in caplog.text
    assert "private-storage-marker" not in caplog.text


def test_shutdown_deadline_is_reported_and_released_worker_can_finish(caplog) -> None:
    entered, release = Event(), Event()
    rows: list[dict[str, object]] = []

    def stalled_sink(event: dict[str, object]) -> None:
        entered.set()
        assert release.wait(8)
        rows.append(event)

    recorder = OperationsRecorder(stalled_sink)
    try:
        recorder.record("INFERENCE", perf_counter(), None, "AI_SERVICE")
        assert entered.wait(2)
        started = perf_counter()
        recorder.close()
        assert 2.8 <= perf_counter() - started < 5
        assert recorder.worker.is_alive()
        assert "ai_telemetry_shutdown_incomplete" in caplog.text
    finally:
        release.set()
        recorder.worker.join(2)
    assert not recorder.worker.is_alive()
    assert len(rows) == 1 and recorder.events.unfinished_tasks == 0


def test_provider_events_have_no_private_context_and_keep_failure_category() -> None:
    rows: list[dict[str, object]] = []
    recorder = OperationsRecorder(rows.append)
    token = CURRENT.set(recorder)
    try:
        with provider_operation("EMBEDDING"):
            pass
        with pytest.raises(AppError), provider_operation("GEMINI"):
            raise AppError(ErrorCode.GENERATION_TIMEOUT)
    finally:
        CURRENT.reset(token)
        recorder.close()
    assert len(rows) == 2
    assert rows[1]["category"] == "TIMEOUT"
    assert rows[1]["outcome"] == "FAILED"
    assert set(rows[0]) == {
        "id",
        "scope",
        "operation",
        "outcome",
        "durationMs",
        "category",
        "occurredAt",
    }


def test_storage_failure_is_contained_and_reported() -> None:
    def unavailable(_event: dict[str, object]) -> None:
        raise RuntimeError("private provider details")

    recorder = OperationsRecorder(unavailable)
    token = CURRENT.set(recorder)
    try:
        with provider_operation("GEMINI"):
            pass
    finally:
        CURRENT.reset(token)
        recorder.close()
    assert recorder.dropped == 1
