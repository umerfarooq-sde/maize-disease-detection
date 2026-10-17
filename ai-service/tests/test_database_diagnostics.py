"""Failure stages are actionable without serializing connection details."""

import json
import logging

import psycopg
import pytest
from pydantic import SecretStr

from app.config.settings import Settings
from app.rag.repository import KnowledgeRepository, database_failure_kind
from app.utils.errors import AppError
from app.utils.logging import LOGGER_NAME, REQUEST_ID, JsonFormatter


@pytest.mark.parametrize(
    ("message", "expected"),
    [
        ("connection timeout expired password=private-marker", "CONNECTION_TIMEOUT"),
        ("SSL certificate error postgresql://private-marker", "TLS_FAILURE"),
        ("could not translate host private-marker", "DNS_FAILURE"),
        ("connection refused private-marker", "CONNECTION_FAILURE"),
    ],
)
def test_failure_classifier_never_returns_dependency_text(message, expected):
    assert database_failure_kind(psycopg.OperationalError(message)) == expected


@pytest.mark.parametrize("stage", ["CONNECT", "TRANSACTION_SETUP", "QUERY", "COMMIT"])
def test_database_error_stage_and_correlation_are_safe(monkeypatch, caplog, stage):
    error = psycopg.OperationalError("timeout expired password=private-marker")

    class Connection:
        def __enter__(self):
            return self

        def __exit__(self, kind, value, trace):
            if stage == "COMMIT":
                raise error

        def execute(self, *args):
            if stage == "TRANSACTION_SETUP":
                raise error

    def connect(*args, **kwargs):
        if stage == "CONNECT":
            raise error
        return Connection()

    monkeypatch.setattr("app.rag.repository.psycopg.connect", connect)
    settings = Settings(_env_file=None, inference_enabled=False).model_copy(
        update={"database_url": SecretStr("postgresql://localhost/fixture")}
    )
    repository = KnowledgeRepository(settings, "fixture")
    token = REQUEST_ID.set("aaf75661-2740-4a18-bc40-56f9d1f3d89e")
    try:
        with (
            caplog.at_level(logging.ERROR, logger=LOGGER_NAME),
            pytest.raises(AppError),
            repository.connection(),
        ):
            if stage == "QUERY":
                raise error
    finally:
        REQUEST_ID.reset(token)
    entries = [json.loads(JsonFormatter().format(row)) for row in caplog.records]
    entry = entries[-1]
    assert entry["database_stage"] == stage
    assert entry["database_failure_kind"] == "CONNECTION_TIMEOUT"
    assert entry["request_id"] == "aaf75661-2740-4a18-bc40-56f9d1f3d89e"
    assert entry["duration_ms"] >= 0
    assert "private-marker" not in json.dumps(entries)
    assert "password" not in caplog.text
