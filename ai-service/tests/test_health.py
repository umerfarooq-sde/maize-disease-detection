"""Exercise the real factory and lifecycle without loading an AI artifact."""

import json
import logging
import subprocess
import sys
from pathlib import Path
from uuid import UUID

from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import SecretStr

from app import SERVICE_NAME, SERVICE_VERSION
from app.config.settings import Settings
from app.main import create_app
from app.utils.logging import LOGGER_NAME


def test_health_reports_running_foundation_without_provider_details(client: TestClient) -> None:
    response = client.get("/health")
    assert response.status_code == 200
    payload = response.json()
    assert set(payload) == {"success", "data", "meta"}
    assert payload["success"] is True
    assert set(payload["data"]) == {
        "service",
        "version",
        "status",
        "uptimeSeconds",
        "capabilities",
        "model",
    }
    assert payload["data"]["service"] == SERVICE_NAME
    assert payload["data"]["version"] == SERVICE_VERSION
    assert payload["data"]["status"] == "ok"
    assert payload["data"]["uptimeSeconds"] >= 0
    assert payload["data"]["capabilities"] == {
        "preprocessing": "not_implemented",
        "inference": "not_implemented",
        "rag": "not_implemented",
        "generation": "not_implemented",
    }
    assert payload["data"]["model"] == {"status": "not_loaded", "version": None}
    assert payload["meta"] == {"requestId": response.headers["X-Request-Id"]}
    assert UUID(payload["meta"]["requestId"]).version == 4
    assert response.headers["Cache-Control"] == "no-store"
    assert response.headers["X-Content-Type-Options"] == "nosniff"


def test_request_ids_are_generated_per_request_and_do_not_trust_client_input(
    client: TestClient,
) -> None:
    incoming = "untrusted-request-id"
    first = client.get("/health", headers={"X-Request-Id": incoming})
    second = client.get("/health", headers={"X-Request-Id": incoming})
    first_id = first.json()["meta"]["requestId"]
    second_id = second.json()["meta"]["requestId"]
    assert first_id != second_id
    assert incoming not in {first_id, second_id}
    assert UUID(first_id).version == UUID(second_id).version == 4


def test_lifespan_controls_health_and_stops_cleanly(application: FastAPI) -> None:
    assert application.state.running is False
    assert application.state.started_at is None
    with TestClient(application) as test_client:
        assert application.state.running is True
        assert application.state.started_at is not None
        assert test_client.get("/health").json()["data"]["status"] == "ok"
    assert application.state.running is False


def test_health_without_startup_is_not_ready(application: FastAPI) -> None:
    # Deliberately omit the context manager: the ASGI lifespan has not run.
    test_client = TestClient(application)
    try:
        response = test_client.get("/health")
    finally:
        test_client.close()
    assert response.status_code == 503
    assert response.json()["data"]["status"] == "starting"
    assert response.json()["data"]["uptimeSeconds"] == 0
    assert response.json()["data"]["model"]["status"] == "not_loaded"


def test_factory_keeps_settings_and_logging_local_and_health_does_not_leak_token() -> None:
    token = "test_only_" + "T" * 55
    settings = Settings(_env_file=None, environment="test", ai_service_token=SecretStr(token))
    root_handlers = tuple(logging.getLogger().handlers)
    service_handlers = tuple(logging.getLogger(LOGGER_NAME).handlers)
    application = create_app(settings)
    assert application.state.settings is settings
    assert tuple(logging.getLogger().handlers) == root_handlers
    assert tuple(logging.getLogger(LOGGER_NAME).handlers) == service_handlers
    with TestClient(application) as test_client:
        response = test_client.get("/health")
    assert token not in response.text
    assert "AI_SERVICE_TOKEN" not in response.text
    assert "host" not in response.json()["data"]


def test_import_and_factory_do_not_load_heavy_models_or_providers() -> None:
    source = """
import json
import sys
from app.config.settings import Settings
from app.main import create_app
application = create_app(Settings(_env_file=None, environment="test"))
heavy_modules = ("torch", "torchvision", "cv2", "numpy", "google.genai", "psycopg")
print(json.dumps({
    "running": application.state.running,
    "imported": [name for name in heavy_modules if name in sys.modules],
}))
"""
    result = subprocess.run(
        [sys.executable, "-c", source],
        cwd=Path(__file__).resolve().parents[1],
        capture_output=True,
        text=True,
        check=True,
        timeout=30,
    )
    assert json.loads(result.stdout) == {"running": False, "imported": []}


def test_no_browser_cors_or_future_business_endpoints(client: TestClient) -> None:
    headers = {"Origin": "https://mobile-browser.invalid"}
    health = client.get("/health", headers=headers)
    assert "Access-Control-Allow-Origin" not in health.headers
    preflight = client.options(
        "/health", headers={**headers, "Access-Control-Request-Method": "GET"}
    )
    assert preflight.status_code == 405
    assert "Access-Control-Allow-Origin" not in preflight.headers
    for route in ("/api/v1/predict", "/api/v1/rag", "/api/v1/generate", "/health/"):
        assert client.get(route).status_code == 404


def test_production_disables_interactive_docs_but_keeps_health() -> None:
    settings = Settings(
        _env_file=None,
        environment="production",
        ai_service_token=SecretStr("test_only_" + "T" * 55),
    )
    application = create_app(settings)
    assert application.debug is False
    with TestClient(application) as test_client:
        assert test_client.get("/health").status_code == 200
        assert test_client.get("/docs").status_code == 404
        assert test_client.get("/openapi.json").status_code == 404


def test_development_openapi_describes_health_without_private_config(client: TestClient) -> None:
    response = client.get("/openapi.json")
    assert response.status_code == 200
    assert set(response.json()["paths"]) == {"/health"}
    contracts = response.json()["paths"]["/health"]["get"]["responses"]
    for status in ("422", "500"):
        assert contracts[status]["content"]["application/json"]["schema"] == {
            "$ref": "#/components/schemas/ErrorResponse"
        }
    assert "AI_SERVICE_TOKEN" not in response.text
    assert "GEMINI_API_KEY" not in response.text
