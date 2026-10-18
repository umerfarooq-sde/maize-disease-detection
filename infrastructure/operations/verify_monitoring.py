"""Real isolated Docker monitoring pipeline, without model/provider claims.

Host mode is restricted to disposable Linux GitHub CI. Probe mode runs inside
the private alerts container; secrets are read from files, never argv/logs.
No source environments, databases, model artifacts or provider accounts are used.
"""

import base64
import json
import os
import secrets
import subprocess
import sys
import tempfile
import time
from datetime import UTC, datetime, timedelta
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


def probe() -> None:
    token = Path("/run/secrets/operations_token").read_text().strip()
    password = Path("/run/secrets/grafana_password").read_text().strip()

    def request(url, headers=None, data=None, method=None):
        body = None if data is None else json.dumps(data).encode()
        options = dict(headers or {})
        if body is not None:
            options["Content-Type"] = "application/json"
        with urlopen(Request(url, body, options, method=method), timeout=5) as response:
            return response.read()

    def wait(name, check, seconds=90):
        until = time.monotonic() + seconds
        while True:
            try:
                if check():
                    print(json.dumps({"check": name, "status": "PASS"}), flush=True)
                    return
            except (URLError, TimeoutError, OSError, ValueError, KeyError):
                pass
            if time.monotonic() >= until:
                raise RuntimeError("Monitoring component deadline: " + name)
            time.sleep(2)

    node_headers = {"X-Operations-Token": token}
    ops_headers = {"Authorization": "Bearer " + token}
    wait(
        "real-node-database-redis-readiness",
        lambda: json.loads(request("http://api:3000/internal/ready", node_headers))["ready"],
    )
    for endpoint in ("http://api:3000/internal/metrics", "http://alerts:9030/internal/metrics"):
        try:
            request(endpoint)
        except HTTPError as error:
            assert error.code == 404
        else:
            raise AssertionError("Private monitoring endpoint admitted guest")
    request("http://api:3000/api/v1/health")

    def prom(query):
        result = json.loads(
            request("http://prometheus:9090/api/v1/query?" + urlencode({"query": query}))
        )
        assert result["status"] == "success"
        return result["data"]["result"]

    wait(
        "prometheus-real-node-scrape",
        lambda: any(float(row["value"][1]) == 1 for row in prom('up{job="node"}')),
    )
    wait(
        "prometheus-real-alert-inbox-scrape",
        lambda: any(float(row["value"][1]) == 1 for row in prom('up{job="alerts"}')),
    )
    wait(
        "real-http-counter",
        lambda: any(float(row["value"][1]) > 0 for row in prom("maizedoctor_http_requests_total")),
    )
    # Absent model/workers must remain unavailable, never fabricated success.
    assert all(float(row["value"][1]) == 0 for row in prom('up{job="ai"}'))

    def logs():
        query = urlencode({"query": '{service="node"}', "limit": "20"})
        result = json.loads(request("http://loki:3100/loki/api/v1/query_range?" + query))
        return any(row["values"] for row in result["data"]["result"])

    wait("actual-node-file-alloy-loki-ingestion", logs, 120)
    grafana_headers = {
        "Authorization": "Basic " + base64.b64encode(("admin:" + password).encode()).decode()
    }
    wait(
        "grafana-provisioned-dashboard",
        lambda: bool(
            json.loads(request("http://grafana:3000/api/search?type=dash-db", grafana_headers))
        ),
    )
    try:
        request("http://grafana:3000/api/search?type=dash-db")
    except HTTPError as error:
        assert error.code == 401
    else:
        raise AssertionError("Anonymous Grafana dashboard access enabled")

    now = datetime.now(UTC)
    request(
        "http://alertmanager:9093/api/v2/alerts",
        data=[
            {
                "labels": {
                    "alertname": "Phase25ComponentProbe",
                    "job": "component",
                    "severity": "info",
                },
                "startsAt": now.isoformat(),
                "endsAt": (now + timedelta(minutes=5)).isoformat(),
            }
        ],
        method="POST",
    )

    def delivered():
        # Inspect the real journal, not only a counter that another alert could increment.
        for path in Path("/inbox").glob("*.jsonl*"):
            for line in path.read_text().splitlines():
                event = json.loads(line)
                if event.get("labels", {}).get("alertname") == "Phase25ComponentProbe":
                    return True
        return False

    wait("alertmanager-authenticated-private-journal-delivery", delivered)
    assert b"maizedoctor_alerts_received_total" in request(
        "http://alerts:9030/internal/metrics", ops_headers
    )


def host() -> None:
    if sys.platform != "linux" or os.environ.get("GITHUB_ACTIONS") != "true":
        raise ValueError("Only disposable Linux GitHub CI is authorized by this component test")
    root = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(
        prefix="md-monitoring-", dir=os.environ["RUNNER_TEMP"]
    ) as temporary:
        directory = Path(temporary)
        os.chmod(directory, 0o700)
        namespace = "mdmonitor-" + secrets.token_hex(6)
        token, password, redis_password = (secrets.token_urlsafe(32) for _ in range(3))

        def write(name, value):
            target = directory / name
            target.write_text(json.dumps(value) if isinstance(value, dict) else value)
            target.chmod(0o444)

        database = f"postgresql://postgres:{password}@component-db:5432/monitoring_ci"
        write("component-password", password)
        write("operations-token", token)
        write("grafana-password", secrets.token_urlsafe(32))
        write("migration.json", {"DIRECT_DATABASE_URL": database})
        write(
            "node.json",
            {
                "DATABASE_URL": database,
                "JWT_SECRET": secrets.token_urlsafe(32),
                "JWT_REFRESH_SECRET": secrets.token_urlsafe(32),
                "OPERATIONS_TOKEN": token,
                "REDIS_URL": f"redis://quota:{redis_password}@redis:6379",
            },
        )
        # Same ACL and bounds as the prepared runtime, without importing optional
        # host dependencies or reading any developer/provider configuration.
        from preparation import redis_configuration

        write("redis.conf", redis_configuration(namespace, redis_password))
        for name in ("ai.json", "backup.json", "privacy.json", "curator.json"):
            write(name, {})
        write("backup-key", secrets.token_urlsafe(32))
        env = {
            **os.environ,
            "STACK_NAME": namespace,
            "SECRETS_DIRECTORY": str(directory),
            "MODEL_DIRECTORY": str(directory),
            "CORS_ORIGINS": "https://verification.example.invalid",
            "CLOUDINARY_CLOUD_NAME": "unused-component-fixture",
            "API_HOST": "verification.example.invalid",
            "PUBLIC_HTTPS_ORIGIN": "https://verification.example.invalid",
            "EMBEDDING_MODEL": "",
            "EMBEDDING_VERSION": "",
            "NODE_IMAGE": "maizedoctor-node:ci",
            "MIGRATION_IMAGE": "maizedoctor-migration:ci",
            "OPERATIONS_IMAGE": "maizedoctor-operations:ci",
        }
        compose = [
            "docker",
            "compose",
            "--project-name",
            namespace,
            "-f",
            str(root / "infrastructure/runtime/compose.yaml"),
            "-f",
            str(root / "infrastructure/runtime/compose.ci-monitoring.yaml"),
        ]

        def run(*args, source=None, timeout=240):
            result = subprocess.run(
                [*compose, *args],
                env=env,
                cwd=root,
                input=source,
                capture_output=True,
                text=True,
                timeout=timeout,
            )
            if result.returncode:
                for line in result.stdout.splitlines():
                    try:
                        event = json.loads(line)
                    except ValueError:
                        continue
                    if set(event) == {"check", "status"}:
                        print(json.dumps(event), flush=True)
                # Docker/config errors can contain environment values. Keep only
                # the command stage; private fixture secrets never enter CI logs.
                raise RuntimeError("Monitoring Docker stage failed: " + args[0])
            return result.stdout

        try:
            run("config", "--quiet")
            run("up", "-d", "--no-deps", "--wait", "--wait-timeout", "90", "component-db", "redis")
            run("run", "--rm", "--no-deps", "migrate")
            run(
                "up",
                "-d",
                "--no-deps",
                "api",
                "alerts",
                "prometheus",
                "loki",
                "alloy",
                "grafana",
                "alertmanager",
            )
            result = run(
                "exec",
                "-T",
                "alerts",
                "/opt/operations/bin/python",
                "-",
                "--probe",
                source=Path(__file__).read_text(),
                timeout=420,
            )
            print(result, end="", flush=True)
        finally:
            # Newly generated owned project only, never source/production volumes.
            run("down", "--volumes", "--timeout", "25", timeout=90)
            print(
                json.dumps({"check": "owned-monitoring-project-cleanup", "status": "PASS"}),
                flush=True,
            )


if __name__ == "__main__":
    if sys.argv[1:] == ["--probe"]:
        try:
            probe()
        except Exception as error:
            print(
                json.dumps({"check": "monitoring-probe-" + type(error).__name__, "status": "FAIL"}),
                flush=True,
            )
            raise SystemExit(1) from None
    elif not sys.argv[1:]:
        host()
    else:
        raise ValueError("Unknown monitoring verification mode")
