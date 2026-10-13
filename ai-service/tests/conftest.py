"""Isolate foundation tests from the developer's private service environment."""

from collections.abc import Iterator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.config.settings import Settings
from app.main import create_app


@pytest.fixture(autouse=True)
def isolated_settings_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in (
        "ENVIRONMENT",
        "HOST",
        "PORT",
        "LOG_LEVEL",
        "AI_SERVICE_TOKEN",
        "INFERENCE_ENABLED",
        "MODEL_PATH",
        "MODEL_METADATA_PATH",
        "MODEL_METADATA_SHA256",
        "MODEL_VERSION",
        "PREPROCESSING_VERSION",
        "INFERENCE_THREADS",
        "INFERENCE_MAX_CONCURRENCY",
        "INFERENCE_UPLOAD_TIMEOUT_SECONDS",
        "CONFIDENCE_POLICY_PATH",
        "CONFIDENCE_POLICY_SHA256",
        "RAG_ENABLED",
        "DATABASE_URL",
        "GEMINI_API_KEY",
        "EMBEDDING_MODEL",
        "EMBEDDING_VERSION",
        "EMBEDDING_DIMENSIONS",
        "EMBEDDING_TIMEOUT_SECONDS",
        "RAG_CHUNK_CHARS",
        "RAG_CHUNK_OVERLAP",
        "RAG_MAX_CONCURRENCY",
        "GENERATION_ENABLED",
        "GEMINI_MODEL",
        "GENERATION_TIMEOUT_SECONDS",
        "GENERATION_MAX_CONCURRENCY",
        "GENERATION_CONTEXT_CHARS",
        "GENERATION_MAX_CHUNKS",
        "GENERATION_CORPUS_PATH",
        "GENERATION_REVIEW_PATH",
    ):
        monkeypatch.delenv(name, raising=False)


@pytest.fixture
def application() -> FastAPI:
    return create_app(Settings(_env_file=None, environment="test", inference_enabled=False))


@pytest.fixture
def client(application: FastAPI) -> Iterator[TestClient]:
    with TestClient(application) as test_client:
        yield test_client
