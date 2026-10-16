"""Provider telemetry is bounded metadata and cannot replace operation outcomes."""

import pytest

from app.utils.errors import AppError, ErrorCode
from app.utils.operations import CURRENT, OperationsRecorder, provider_operation


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
