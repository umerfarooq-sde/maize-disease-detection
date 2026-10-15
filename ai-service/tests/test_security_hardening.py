"""Adversarial internal admission, redaction and production configuration checks."""

import pytest
from fastapi import Depends, Request
from fastapi.testclient import TestClient
from pydantic import BaseModel, SecretStr, ValidationError

from app.api.json_body import read_json_body
from app.api.security import require_service_authentication
from app.config.settings import Settings
from app.main import create_app
from app.rag.repository import KnowledgeRepository
from app.utils.errors import AppError

TOKEN = "synthetic_" + "S" * 50


class Payload(BaseModel):
    question: str


def client() -> TestClient:
    application = create_app(
        Settings(_env_file=None, inference_enabled=False, ai_service_token=SecretStr(TOKEN))
    )

    @application.post("/test/security", dependencies=[Depends(require_service_authentication)])
    async def route(request: Request) -> dict[str, bool]:
        await read_json_body(request, Payload, max_bytes=64)
        return {"accepted": True}

    return TestClient(application)


@pytest.mark.parametrize(
    "headers",
    [
        [("Content-Type", "application/json"), ("Content-Type", "text/plain")],
        [
            ("Content-Type", "application/json"),
            ("Content-Encoding", "identity"),
            ("Content-Encoding", "gzip"),
        ],
    ],
)
def test_ambiguous_internal_headers_fail_closed(headers: list[tuple[str, str]]) -> None:
    with client() as api:
        response = api.post(
            "/test/security",
            headers=[*headers, ("Authorization", f"Bearer {TOKEN}")],
            content=b'{"question":"fixture"}',
        )
    assert response.status_code == 422
    assert TOKEN not in response.text


def test_authentication_precedes_body_and_oversized_or_malformed_json_is_redacted() -> None:
    with client() as api:
        assert api.post("/test/security", content=b"x" * 1024).status_code == 401
        for body, expected in [(b"x" * 65, 413), (b'{"PRIVATE_SECRET":', 422)]:
            response = api.post(
                "/test/security",
                headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"},
                content=body,
            )
            assert response.status_code == expected
            assert "PRIVATE_SECRET" not in response.text
            assert TOKEN not in response.text


@pytest.mark.parametrize(
    "url",
    [
        "postgresql://db.example.invalid/fixture?sslmode=disable",
        "postgresql://localhost/fixture?host=remote.example.invalid&sslmode=disable",
    ],
)
def test_production_retrieval_refuses_remote_unverified_database_connection(url: str) -> None:
    with pytest.raises(ValidationError):
        Settings(
            _env_file=None,
            environment="production",
            rag_enabled=True,
            inference_enabled=False,
            ai_service_token=SecretStr(TOKEN),
            database_url=SecretStr(url),
            gemini_api_key=SecretStr("synthetic-provider-key"),
            embedding_model="fixture-embedding",
            embedding_version="fixture-v1",
        )


@pytest.mark.parametrize("unsafe", [None, "privileged", "owns_objects", "can_create", "missing"])
def test_production_database_role_is_checked_before_any_application_query(monkeypatch, unsafe):
    permissions = {"privileged": False, "owns_objects": False, "can_create": False}
    if unsafe in permissions:
        permissions[unsafe] = True
    calls = []

    class FakeConnection:
        def __enter__(self):
            return self

        def __exit__(self, *args):
            pass

        def execute(self, query, parameters=None):
            calls.append(query)
            return self

        def fetchone(self):
            return None if unsafe == "missing" else permissions

    monkeypatch.setattr(
        "app.rag.repository.psycopg.connect", lambda *args, **kwargs: FakeConnection()
    )
    settings = Settings(_env_file=None, inference_enabled=False).model_copy(
        update={
            "environment": "production",
            "database_url": SecretStr("postgresql://localhost/fixture"),
        }
    )
    repository = KnowledgeRepository(settings, "fixture")
    if unsafe is None:
        with repository.connection():
            pass
        assert len(calls) == 2
        assert "set_config" in calls[1]
    else:
        with pytest.raises(AppError), repository.connection():
            pytest.fail("Unsafe database role admitted")
        assert len(calls) == 1
    assert "pg_catalog" in calls[0]
