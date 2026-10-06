"""Isolate foundation tests from the developer's private service environment."""

from collections.abc import Iterator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.config.settings import Settings
from app.main import create_app


@pytest.fixture(autouse=True)
def isolated_settings_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in ("ENVIRONMENT", "HOST", "PORT", "LOG_LEVEL", "AI_SERVICE_TOKEN"):
        monkeypatch.delenv(name, raising=False)


@pytest.fixture
def application() -> FastAPI:
    return create_app(Settings(_env_file=None, environment="test"))


@pytest.fixture
def client(application: FastAPI) -> Iterator[TestClient]:
    with TestClient(application) as test_client:
        yield test_client
