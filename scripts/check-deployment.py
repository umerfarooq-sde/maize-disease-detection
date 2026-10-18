"""Executable deployment contract checks; never claims a hosted runtime from syntax."""

import argparse
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def compose_command():
    if shutil.which("docker"):
        return ["docker", "compose"]
    standalone = ROOT / ".cache/tools/docker-compose.exe"
    if standalone.is_file():
        return [str(standalone)]
    raise RuntimeError("Docker Compose is required for deployment configuration checks")


def static_checks(docker_tools=False):
    runtime = ROOT / "infrastructure/runtime"
    with tempfile.TemporaryDirectory(prefix="maizedoctor-contract-") as temporary:
        directory = Path(temporary)
        for file in (
            "node.json",
            "ai.json",
            "migration.json",
            "backup.json",
            "privacy.json",
            "operator.json",
            "curator.json",
        ):
            (directory / file).write_text("{}")
        for file in (
            "operations-token",
            "grafana-password",
            "backup-key",
            "postgres-password",
            "redis.conf",
            "component-password",
        ):
            (directory / file).write_text("synthetic-configuration-contract-only")
        environment = os.environ.copy()
        environment.update(
            {
                "STACK_NAME": "maizedoctor-contract",
                "API_HOST": "api.localhost",
                "PUBLIC_HTTPS_ORIGIN": "https://api.localhost:8443",
                "CORS_ORIGINS": "https://api.localhost:8443",
                "SECRETS_DIRECTORY": directory.as_posix(),
                "MODEL_DIRECTORY": directory.as_posix(),
                "CLOUDINARY_CLOUD_NAME": "synthetic",
                "EMBEDDING_MODEL": "synthetic",
                "EMBEDDING_VERSION": "synthetic",
                "GEMINI_MODEL": "synthetic",
            }
        )
        command = compose_command() + ["--env-file", str(directory / "empty.env")]
        (directory / "empty.env").write_text("")
        for files in (
            [runtime / "compose.yaml"],
            [runtime / "compose.yaml", runtime / "compose.local.yaml"],
            [runtime / "compose.yaml", runtime / "compose.staging.yaml"],
            [runtime / "compose.yaml", runtime / "compose.production.yaml"],
            [runtime / "compose.yaml", runtime / "compose.ci-monitoring.yaml"],
        ):
            result = subprocess.run(
                command
                + [item for file in files for item in ("-f", str(file))]
                + ["config", "--format", "json"],
                env=environment,
                capture_output=True,
                timeout=30,
            )
            if result.returncode:
                raise RuntimeError(
                    "Compose contract could not be rendered; check public configuration"
                )
            config = json.loads(result.stdout)
            services = config["services"]
            assert {
                "grants",
                "register-model",
                "api",
                "ai",
                "redis",
                "edge",
                "cleanup",
                "backups",
                "privacy",
                "prometheus",
                "alertmanager",
                "alerts",
                "grafana",
                "alloy",
                "loki",
            } <= services.keys()
            for name, service in services.items():
                if name != "edge":
                    assert not service.get("ports"), f"{name} must not publish a host port"
                assert not any(
                    "docker.sock" in str(volume) for volume in service.get("volumes", [])
                )
            assert services["cleanup"]["environment"]["OPERATIONS_PORT"] == "9010"
            if files[-1].name == "compose.production.yaml":
                assert services["api"]["deploy"]["replicas"] == 2
            if files[-1].name == "compose.ci-monitoring.yaml":
                assert services["api"]["environment"]["NODE_ENV"] == "test"
                assert "grafana_password" in {
                    entry["source"] for entry in services["alerts"]["secrets"]
                }
            assert services["ai"]["environment"]["CONFIDENCE_POLICY_PATH"] == ""
            assert services["ai"]["environment"]["CONFIDENCE_POLICY_SHA256"] == ""
            assert config["networks"]["service"]["internal"]
            assert config["networks"]["data"]["internal"]
            assert config["networks"]["monitoring"]["internal"]
        if docker_tools:
            token = directory / "operations-token"
            for tool, arguments, mounts in [
                (
                    "prom/prometheus:v3.15.0",
                    ["promtool", "check", "rules", "/config/alerts.yml"],
                    [],
                ),
                (
                    "prom/prometheus:v3.15.0",
                    ["promtool", "check", "config", "/etc/prometheus/prometheus.yml"],
                    [
                        "-v",
                        str(runtime / "monitoring") + ":/etc/prometheus:ro",
                        "-v",
                        str(token) + ":/run/secrets/operations_token:ro",
                    ],
                ),
                (
                    "prom/alertmanager:v0.34.1",
                    ["amtool", "check-config", "/config/alertmanager.yml"],
                    ["-v", str(token) + ":/run/secrets/operations_token:ro"],
                ),
                (
                    "grafana/alloy:v1.20.1",
                    ["/bin/alloy", "validate", "/config/config.alloy"],
                    [],
                ),
            ]:
                entrypoint, *args = arguments
                subprocess.run(
                    [
                        "docker",
                        "run",
                        "--rm",
                        "--network",
                        "none",
                        "--entrypoint",
                        entrypoint,
                        "-v",
                        str(runtime / "monitoring") + ":/config:ro",
                        *mounts,
                        tool,
                        *args,
                    ],
                    check=True,
                    timeout=120,
                )
    print(
        "PASS: base/local Compose contracts, private topology and lifecycle configuration."
        + (
            " Operational tools also validated their configurations."
            if docker_tools
            else " Container runtime is NOT verified by this check."
        )
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--static", action="store_true", required=True)
    parser.add_argument("--docker-tools", action="store_true")
    args = parser.parse_args()
    static_checks(args.docker_tools)
