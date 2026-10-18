"""Deployment secrets, private monitoring and bounded address-attempt regressions."""

import json
from concurrent.futures import ThreadPoolExecutor
from threading import Event, Lock
from time import monotonic

import psycopg
import pytest
from fastapi.testclient import TestClient

from app.config.settings import ConfigurationError, Settings, load_settings
from app.main import create_app
from app.rag.connectivity import DatabaseConnector


def test_runtime_secret_file_is_allowlisted_and_conflicts_fail_without_values(
    tmp_path, monkeypatch
):
    path = tmp_path / "secrets.json"
    path.write_text(json.dumps({"AI_SERVICE_TOKEN": "a" * 43}), encoding="utf-8")
    monkeypatch.setenv("MAIZEDOCTOR_SECRETS_FILE", str(path))
    monkeypatch.setenv("INFERENCE_ENABLED", "false")
    assert load_settings(env_file=None).ai_service_token.get_secret_value() == "a" * 43
    monkeypatch.setenv("AI_SERVICE_TOKEN", "b" * 43)
    with pytest.raises(ConfigurationError) as error:
        load_settings(env_file=None)
    assert "b" * 43 not in str(error.value)
    monkeypatch.delenv("AI_SERVICE_TOKEN")
    path.write_text(json.dumps({"PYTHONPATH": "private-marker"}), encoding="utf-8")
    with pytest.raises(ConfigurationError):
        load_settings(env_file=None)


def test_metrics_require_existing_service_auth_and_never_export_the_token():
    token = "c" * 43
    app = create_app(Settings(_env_file=None, inference_enabled=False, operations_token=token))
    with TestClient(app) as client:
        assert client.get("/internal/metrics").status_code == 401
        response = client.get("/internal/metrics", headers={"Authorization": "Bearer " + token})
        assert response.status_code == 200
        assert "maizedoctor_ai_model_ready 0" in response.text
        assert token not in response.text


def test_address_attempts_share_one_budget_and_preserve_tls_hostname(monkeypatch):
    clock = [0.0]
    attempts = []
    monkeypatch.setattr("app.rag.connectivity.monotonic", lambda: clock[0])
    monkeypatch.setattr(
        "app.rag.connectivity.resolve_addresses",
        lambda *args: [f"127.0.0.{index}" for index in (1, 2, 3)],
    )

    def timeout(url, **kwargs):
        assert "server.fixture.invalid" in url and "sslmode=verify-full" in url
        attempts.append(kwargs["connect_timeout"])
        clock[0] += kwargs["connect_timeout"]
        raise psycopg.errors.ConnectionTimeout("controlled timeout")

    monkeypatch.setattr("app.rag.connectivity.psycopg.connect", timeout)
    connector = DatabaseConnector()
    try:
        with pytest.raises(psycopg.OperationalError, match="deadline"):
            connector.connect("postgresql://server.fixture.invalid/fixture?sslmode=verify-full")
        assert attempts == [5, 3]
        assert clock[0] == 8
    finally:
        connector.close()


def test_slow_dns_has_no_unbounded_waiting_queue_and_closed_resolver_rejects(monkeypatch):
    release = Event()
    entered = Event()
    lock = Lock()
    arrivals = [0]

    def delayed(*args, **kwargs):
        with lock:
            arrivals[0] += 1
            if arrivals[0] == 2:
                entered.set()
        assert release.wait(5)
        return []

    monkeypatch.setattr("app.rag.connectivity.resolve_addresses", delayed)
    connector = DatabaseConnector()

    def request():
        with pytest.raises(psycopg.OperationalError):
            connector.connect("postgresql://server.fixture.invalid/fixture")

    try:
        with ThreadPoolExecutor(max_workers=2) as callers:
            futures = [callers.submit(request) for _ in range(2)]
            try:
                assert entered.wait(2)
                started = monotonic()
                request()  # Two active DNS calls; no third waiting task is allocated.
                assert monotonic() - started < 0.5
            finally:
                release.set()
            for future in futures:
                future.result()
    finally:
        release.set()
        connector.close()
    request()


def test_resolver_child_timeout_is_killed_and_joined(monkeypatch):
    import subprocess

    from app.rag.connectivity import resolve_addresses

    children = []
    original = subprocess.Popen

    def spawn(*args, **kwargs):
        child = original(*args, **kwargs)
        children.append(child)
        return child

    monkeypatch.setattr("app.rag.connectivity.subprocess.Popen", spawn)
    monkeypatch.setattr("app.rag.connectivity.DNS_PROGRAM", "import time; time.sleep(20)")
    with pytest.raises(psycopg.OperationalError, match="DNS"):
        resolve_addresses("localhost", "5432", 0.1)
    assert len(children) == 1 and children[0].poll() is not None


def test_resolver_subprocess_never_inherits_provider_credentials(monkeypatch):
    from app.rag.connectivity import resolve_addresses

    monkeypatch.setenv("GEMINI_API_KEY", "private-marker")
    monkeypatch.setattr(
        "app.rag.connectivity.DNS_PROGRAM",
        "import os,json; print(json.dumps("
        '["127.0.0.1"] if "GEMINI_API_KEY" not in os.environ else []))',
    )
    assert resolve_addresses("localhost", "5432", 2) == ["127.0.0.1"]


def test_stdlib_resolver_bypasses_windows_venv_launcher(monkeypatch, tmp_path):
    import sys

    from app.rag.connectivity import resolve_addresses

    # A launcher process can outlive its direct parent on Windows. The base
    # interpreter must run the actual stdlib resolver task, without that layer.
    monkeypatch.setattr(sys, "executable", str(tmp_path / "unused-launcher.exe"))
    monkeypatch.setattr("app.rag.connectivity.DNS_PROGRAM", 'print("[\\"127.0.0.1\\"]")')
    assert resolve_addresses("localhost", "5432", 2) == ["127.0.0.1"]
