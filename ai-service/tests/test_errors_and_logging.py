"""Validate real middleware/error contracts using routes confined to test apps."""

import json
import logging
from typing import Annotated
from uuid import UUID

import httpx
import pytest
from fastapi import FastAPI, Path, Query
from fastapi.testclient import TestClient
from pydantic import BaseModel, ConfigDict, Field
from starlette.exceptions import HTTPException

from app.utils.errors import AppError, ErrorCode
from app.utils.logging import LOGGER_NAME, JsonFormatter


class TestBody(BaseModel):
    __test__ = False
    model_config = ConfigDict(extra="forbid")
    quantity: int = Field(ge=1)


class LogBody(BaseModel):
    message: str


def install_validation_route(application: FastAPI) -> None:
    @application.post("/test/items/{item_id}")
    def typed_request(
        item_id: Annotated[int, Path(ge=1)],
        payload: TestBody,
        limit: Annotated[int, Query(ge=1)],
    ) -> dict[str, int]:
        return {"item": item_id, "quantity": payload.quantity, "limit": limit}


def assert_safe_error(response: httpx.Response, expected_status: int, expected_code: str) -> None:
    assert response.status_code == expected_status
    payload = response.json()
    assert set(payload) == {"success", "error", "meta"}
    assert payload["success"] is False
    assert set(payload["error"]) == {"code", "message", "issues"}
    assert payload["error"]["code"] == expected_code
    assert payload["meta"] == {"requestId": response.headers["X-Request-Id"]}
    assert UUID(payload["meta"]["requestId"]).version == 4
    assert response.headers["Cache-Control"] == "no-store"
    assert response.headers["X-Content-Type-Options"] == "nosniff"
    assert "traceback" not in response.text.lower()


def test_health_rejects_unknown_query_without_echoing_names_or_values(client: TestClient) -> None:
    response = client.get("/health", params={"private_field_marker": "private_value_marker"})
    assert_safe_error(response, 422, "VALIDATION_ERROR")
    assert response.json()["error"]["issues"] == [{"source": "query", "code": "extra_forbidden"}]
    assert "private_field_marker" not in response.text
    assert "private_value_marker" not in response.text


def test_typed_body_path_and_query_support_success_and_safe_validation(
    application: FastAPI,
) -> None:
    install_validation_route(application)
    with TestClient(application) as test_client:
        success = test_client.post("/test/items/7?limit=2", json={"quantity": 3})
        assert success.status_code == 200
        assert success.json() == {"item": 7, "quantity": 3, "limit": 2}
        failure = test_client.post(
            "/test/items/path_private_marker?limit=query_private_marker",
            json={"quantity": "body_private_marker", "private_field_marker": "private_value"},
        )
    assert_safe_error(failure, 422, "VALIDATION_ERROR")
    assert {issue["source"] for issue in failure.json()["error"]["issues"]} == {
        "path",
        "query",
        "body",
    }
    assert all(set(issue) == {"source", "code"} for issue in failure.json()["error"]["issues"])
    for marker in (
        "path_private_marker",
        "query_private_marker",
        "body_private_marker",
        "private_field_marker",
        "private_value",
    ):
        assert marker not in failure.text


def test_malformed_json_is_handled_and_validation_issues_are_bounded(application: FastAPI) -> None:
    install_validation_route(application)
    with TestClient(application) as test_client:
        malformed = test_client.post(
            "/test/items/1?limit=1",
            content=b'{"private_body_marker":',
            headers={"Content-Type": "application/json"},
        )
        excessive = test_client.post(
            "/test/items/1?limit=1",
            json={"quantity": 1, **{f"secret_{number}": "private" for number in range(30)}},
        )
    assert_safe_error(malformed, 422, "VALIDATION_ERROR")
    assert "private_body_marker" not in malformed.text
    assert_safe_error(excessive, 422, "VALIDATION_ERROR")
    assert len(excessive.json()["error"]["issues"]) == 20
    assert "secret_" not in excessive.text


def test_not_found_method_not_allowed_and_http_details_are_sanitized(application: FastAPI) -> None:
    @application.get("/test/forbidden")
    def forbidden() -> None:
        raise HTTPException(
            403, detail="private_error_detail", headers={"X-Secret": "private_header"}
        )

    with TestClient(application) as test_client:
        missing = test_client.get("/missing/private_path_marker")
        wrong_method = test_client.post("/health")
        denied = test_client.get("/test/forbidden")
    assert_safe_error(missing, 404, "NOT_FOUND")
    assert "private_path_marker" not in missing.text
    assert_safe_error(wrong_method, 405, "METHOD_NOT_ALLOWED")
    assert "GET" in wrong_method.headers["Allow"].split(", ")
    assert_safe_error(denied, 403, "AUTHORIZATION_ERROR")
    assert "private_error_detail" not in denied.text
    assert "X-Secret" not in denied.headers


@pytest.mark.parametrize(
    ("code", "status"),
    [
        (ErrorCode.CONFLICT, 409),
        (ErrorCode.RATE_LIMITED, 429),
        (ErrorCode.SERVICE_UNAVAILABLE, 503),
    ],
)
def test_application_errors_use_one_safe_envelope(
    application: FastAPI, code: ErrorCode, status: int
) -> None:
    @application.get("/test/error")
    def error() -> None:
        raise AppError(code)

    with TestClient(application) as test_client:
        response = test_client.get("/test/error")
    assert_safe_error(response, status, code.value)


def test_request_logs_use_templates_and_allowlisted_json_fields_only(
    application: FastAPI, caplog: pytest.LogCaptureFixture
) -> None:
    @application.post("/test/log/{name}")
    def logged_request(name: str, payload: LogBody, lookup: str = "") -> dict[str, bool]:
        return {"accepted": bool(name and payload.message and lookup)}

    with caplog.at_level(logging.INFO, logger=LOGGER_NAME), TestClient(application) as test_client:
        response = test_client.post(
            "/test/log/private_path_marker?lookup=private_query_marker",
            json={"message": "private_body_marker"},
            headers={"Authorization": "Bearer private_auth_marker"},
        )
        missing = test_client.get("/missing/private_unmatched_marker?token=private_token_marker")
    records = [
        record for record in caplog.records if getattr(record, "event", None) == "request_completed"
    ]
    entries = [json.loads(JsonFormatter().format(record)) for record in records]
    assert len(entries) == 2
    first = entries[0]
    assert first["route"] == "/test/log/{name}"
    assert first["method"] == "POST"
    assert first["status_code"] == response.status_code == 200
    assert first["request_id"] == response.headers["X-Request-Id"]
    assert isinstance(first["duration_ms"], (int, float)) and first["duration_ms"] >= 0
    assert set(first) == {
        "timestamp",
        "level",
        "service",
        "event",
        "request_id",
        "method",
        "route",
        "status_code",
        "duration_ms",
    }
    assert entries[1]["route"] == "unmatched"
    assert entries[1]["status_code"] == missing.status_code == 404
    assert entries[1]["request_id"] == missing.headers["X-Request-Id"]
    encoded = json.dumps(entries)
    for marker in (
        "private_path_marker",
        "private_query_marker",
        "private_body_marker",
        "private_auth_marker",
        "private_unmatched_marker",
        "private_token_marker",
    ):
        assert marker not in encoded


def test_unexpected_exceptions_are_safe_for_responses_and_logs(
    application: FastAPI, caplog: pytest.LogCaptureFixture
) -> None:
    @application.get("/test/failure/{name}")
    def fail(name: str) -> None:
        raise RuntimeError(f"private_exception_marker: {name}")

    with caplog.at_level(logging.INFO, logger=LOGGER_NAME), TestClient(application) as test_client:
        response = test_client.get(
            "/test/failure/private_path_marker?password=private_query_marker"
        )
    assert_safe_error(response, 500, "INTERNAL_ERROR")
    assert response.json()["error"]["message"] == "An internal error occurred."
    assert response.json()["error"]["issues"] == []
    records = [record for record in caplog.records if record.name == LOGGER_NAME]
    entries = [json.loads(JsonFormatter().format(record)) for record in records]
    failed = [entry for entry in entries if entry["event"] == "request_failed"]
    completed = [entry for entry in entries if entry["event"] == "request_completed"]
    assert len(failed) == len(completed) == 1
    assert failed[0]["error_code"] == "INTERNAL_ERROR"
    assert failed[0]["request_id"] == completed[0]["request_id"] == response.headers["X-Request-Id"]
    assert completed[0]["route"] == "/test/failure/{name}"
    assert completed[0]["status_code"] == 500
    encoded = response.text + json.dumps(entries)
    for marker in ("private_exception_marker", "private_path_marker", "private_query_marker"):
        assert marker not in encoded


def test_json_formatter_does_not_serialize_arbitrary_messages_or_exception_text() -> None:
    record = logging.LogRecord(
        LOGGER_NAME, logging.ERROR, "private_path", 1, "private_message", (), None
    )
    record.private_secret = "private_secret_marker"
    record.exc_text = "private_exception_marker"
    record.event = "request_failed"
    record.error_code = "INTERNAL_ERROR"
    entry = json.loads(JsonFormatter().format(record))
    assert entry["event"] == "request_failed"
    assert entry["error_code"] == "INTERNAL_ERROR"
    assert "private_" not in json.dumps(entry)
