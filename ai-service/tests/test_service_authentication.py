"""Future internal router protection, without adding production operations."""

import pytest
from fastapi import Depends
from fastapi.testclient import TestClient
from pydantic import SecretStr

from app.api.security import require_service_authentication
from app.config.settings import Settings
from app.main import create_app

TEST_TOKEN = "test_only_" + "T" * 55


def internal_client(token: str) -> TestClient:
    application = create_app(
        Settings(
            _env_file=None,
            environment="test",
            inference_enabled=False,
            ai_service_token=SecretStr(token),
        )
    )

    @application.get("/test/internal", dependencies=[Depends(require_service_authentication)])
    def internal_operation() -> dict[str, bool]:
        return {"accepted": True}

    return TestClient(application)


@pytest.mark.parametrize(
    "authorization",
    [None, "Basic invalid", "Bearer wrong-test-token", "Bearer " + "W" * 257],
)
def test_configured_service_rejects_missing_invalid_or_oversized_credentials(
    authorization: str | None,
) -> None:
    headers = {"Authorization": authorization} if authorization is not None else {}
    with internal_client(TEST_TOKEN) as test_client:
        response = test_client.get("/test/internal", headers=headers)
    assert response.status_code == 401
    assert response.headers["WWW-Authenticate"] == "Bearer"
    assert response.json()["success"] is False
    assert response.json()["error"]["code"] == "AUTHENTICATION_ERROR"
    assert response.json()["meta"]["requestId"] == response.headers["X-Request-Id"]
    assert TEST_TOKEN not in response.text
    if authorization:
        assert authorization not in response.text


def test_correct_service_token_allows_internal_operation() -> None:
    with internal_client(TEST_TOKEN) as test_client:
        response = test_client.get(
            "/test/internal", headers={"Authorization": f"Bearer {TEST_TOKEN}"}
        )
        health = test_client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"accepted": True}
    assert health.status_code == 200
    assert TEST_TOKEN not in response.text + health.text


@pytest.mark.parametrize("authorization", [None, f"Bearer {TEST_TOKEN}"])
def test_unconfigured_future_operations_fail_closed_but_health_is_available(
    authorization: str | None,
) -> None:
    headers = {"Authorization": authorization} if authorization is not None else {}
    with internal_client("") as test_client:
        response = test_client.get("/test/internal", headers=headers)
        health = test_client.get("/health")
    assert response.status_code == 503
    assert response.json()["error"]["code"] == "SERVICE_UNAVAILABLE"
    assert "WWW-Authenticate" not in response.headers
    assert health.status_code == 200
