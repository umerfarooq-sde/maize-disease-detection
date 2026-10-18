"""Private, bounded alert journal and serialized encrypted-backup scheduler.

The journal is an operator inbox, not an external notification integration.
No automatic backup deletion: retention requires a separately approved policy.
"""

import argparse
import hmac
import json
import logging
import logging.handlers
import re
import shutil
import signal
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

from backup import create_backup
from backup_retention import expire_backups
from database import connect, secret

LABELS = frozenset({"alertname", "job", "severity"})


def sanitize_alerts(body: bytes) -> list[dict]:
    if len(body) > 65536:
        raise ValueError("Alert envelope exceeds limit")
    payload = json.loads(body)
    alerts = payload.get("alerts") if isinstance(payload, dict) else None
    if not isinstance(alerts, list) or len(alerts) > 50:
        raise ValueError("Invalid alert count")
    result = []
    for alert in alerts:
        if not isinstance(alert, dict) or alert.get("status") not in {
            "firing",
            "resolved",
        }:
            raise ValueError("Invalid alert status")
        labels = alert.get("labels", {})
        if not isinstance(labels, dict):
            raise ValueError("Invalid alert labels")
        retained = {
            key: value
            for key, value in labels.items()
            if key in LABELS
            and isinstance(value, str)
            and re.fullmatch(r"[A-Za-z0-9_:.-]{1,100}", value)
        }
        result.append(
            {
                "event": "operational_alert",
                "status": alert["status"],
                "labels": retained,
                "observedAt": round(time.time()),
            }
        )
    return result


class State:
    def __init__(self, mode: str, token: str):
        self.mode, self.token = mode, token
        self.lock = threading.Lock()
        self.stopping = threading.Event()
        self.success = self.failure = self.alerts = 0
        self.retention_failures = 0
        self.last_success = None
        self.running = False
        self.inventory = {}
        self.inventory_at = 0
        self.disk_directory = None

    def metrics(self) -> str:
        with self.lock:
            rows = [
                f'maizedoctor_backup_runs_total{{outcome="success"}} {self.success}',
                f'maizedoctor_backup_runs_total{{outcome="failure"}} {self.failure}',
                f"maizedoctor_backup_running {int(self.running)}",
                f"maizedoctor_backup_retention_failures_total {self.retention_failures}",
                f"maizedoctor_alerts_received_total {self.alerts}",
            ]
            if self.mode != "backup":
                rows = [f"maizedoctor_alerts_received_total {self.alerts}"]
            if self.last_success is not None:
                rows.append(f"maizedoctor_backup_last_success_seconds {self.last_success}")
            if self.disk_directory:
                try:
                    usage = shutil.disk_usage(self.disk_directory)
                except OSError:
                    rows.append("maizedoctor_operational_storage_observation_available 0")
                else:
                    rows.append("maizedoctor_operational_storage_observation_available 1")
                    for label, value in (("available", usage.free), ("total", usage.total)):
                        rows.append(
                            "maizedoctor_operational_storage_bytes"
                            f'{{state="{label}",mode="{self.mode}"}} {value}'
                        )
            if time.monotonic() - self.inventory_at < 120:
                for service, values in self.inventory.items():
                    for field, value in values.items():
                        rows.append(f'maizedoctor_container_{field}{{service="{service}"}} {value}')
        return "\n".join(rows) + "\n"


def backup_once(
    state: State,
    url: str,
    output: Path,
    key: Path,
    artifacts: Path,
    policy: Path | None = None,
) -> bool:
    # A PostgreSQL session lock coordinates independent replicas. No runtime
    # table writes or DDL: backup identity remains read-only on application data.
    with connect(url, autocommit=True) as lease:
        acquired = lease.execute(
            "SELECT pg_try_advisory_lock(hashtextextended('maizedoctor-backup-v1',0))"
        ).fetchone()[0]
        if not acquired:
            return False
        try:
            with state.lock:
                state.running = True
            create_backup(url, output, key, artifacts)
            with state.lock:
                state.success += 1
                state.last_success = time.time()
            if policy:
                try:
                    expire_backups(output, policy, execute=True)
                except Exception:
                    with state.lock:
                        state.retention_failures += 1
                    print(json.dumps({"event": "backup_retention_blocked"}), flush=True)
            return True
        finally:
            with state.lock:
                state.running = False
            lease.execute("SELECT pg_advisory_unlock(hashtextextended('maizedoctor-backup-v1',0))")


def handler(state: State, journal: logging.Logger):
    class Handler(BaseHTTPRequestHandler):
        timeout = 5

        def log_message(self, *_args):
            pass

        def authorized(self):
            value = self.headers.get("Authorization", "")
            return hmac.compare_digest(value.encode(), ("Bearer " + state.token).encode())

        def do_GET(self):
            if not self.authorized():
                self.send_error(404)
                return
            if self.path == "/internal/metrics":
                body = state.metrics().encode()
                self.send_response(200)
                self.send_header("Content-Type", "text/plain; version=0.0.4")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            elif self.path == "/internal/ready":
                self.send_response(200 if not state.stopping.is_set() else 503)
                self.end_headers()
            else:
                self.send_error(404)

        def do_POST(self):
            if (
                not self.authorized()
                or self.path not in ("/events", "/inventory")
                or state.mode != "alerts"
            ):
                self.send_error(404)
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if not 0 < length <= 65536:
                    raise ValueError("Invalid size")
                body = self.rfile.read(length)
                if self.path == "/inventory":
                    values = json.loads(body)
                    allowed_services = {
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
                        "alloy",
                        "grafana",
                        "loki",
                        "postgres",
                    }
                    fields = {
                        "running",
                        "healthy",
                        "restarts",
                        "cpu_percent",
                        "memory_bytes",
                    }
                    if not isinstance(values, dict) or not set(values) <= allowed_services:
                        raise ValueError("Invalid inventory")
                    for item in values.values():
                        if (
                            not isinstance(item, dict)
                            or not set(item) <= fields
                            or any(
                                type(value) not in (int, float) or not 0 <= value <= 2**50
                                for value in item.values()
                            )
                        ):
                            raise ValueError("Invalid bounded inventory observations")
                    with state.lock:
                        state.inventory, state.inventory_at = values, time.monotonic()
                    self.send_response(202)
                    self.end_headers()
                    return
                records = sanitize_alerts(body)
                for record in records:
                    journal.warning(json.dumps(record, separators=(",", ":")))
                with state.lock:
                    state.alerts += len(records)
            except (ValueError, OSError):
                self.send_error(400)
                return
            self.send_response(202)
            self.end_headers()

    return Handler


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["alerts", "backup"])
    parser.add_argument("--secrets", type=Path)
    parser.add_argument("--token", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("/backups"))
    parser.add_argument("--key", type=Path, default=Path("/run/secrets/backup_key"))
    parser.add_argument("--artifacts", type=Path, default=Path("/artifacts"))
    parser.add_argument("--policy", type=Path, default=Path("/policy.json"))
    parser.add_argument("--interval", type=int, default=86400)
    args = parser.parse_args()
    if not 3600 <= args.interval <= 604800:
        raise ValueError("Backup interval must be between one hour and seven days")
    token = args.token.read_text().strip()
    if len(token) < 43:
        raise ValueError("Private operational token required")
    state = State(args.mode, token)
    state.disk_directory = args.output
    journal = logging.getLogger("operator-inbox")
    journal.setLevel(logging.WARNING)
    if args.mode == "alerts":
        args.output.mkdir(parents=True, exist_ok=True)
        journal.addHandler(
            logging.handlers.RotatingFileHandler(
                args.output / "alerts.jsonl", maxBytes=1048576, backupCount=4
            )
        )

    def work():
        url = secret(args.secrets)["DATABASE_URL"]
        while not state.stopping.is_set():
            try:
                backup_once(state, url, args.output, args.key, args.artifacts, args.policy)
            except Exception:
                with state.lock:
                    state.failure += 1
                print(json.dumps({"event": "scheduled_backup_failed"}), flush=True)
            state.stopping.wait(args.interval)

    worker = (
        threading.Thread(target=work, name="encrypted-backup") if args.mode == "backup" else None
    )
    if worker:
        worker.start()
    server = HTTPServer(
        ("0.0.0.0", 9030 if args.mode == "alerts" else 9031), handler(state, journal)
    )
    server.timeout = 0.5
    for signum in (signal.SIGINT, signal.SIGTERM):
        signal.signal(signum, lambda *_: state.stopping.set())
    try:
        while not state.stopping.is_set():
            server.handle_request()
    finally:
        server.server_close()
        if worker:
            worker.join(timeout=650)  # pg_dump itself has a bounded 300s deadline.
        logging.shutdown()


if __name__ == "__main__":
    main()
