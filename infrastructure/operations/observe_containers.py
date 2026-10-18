"""Host-side read-only Docker observations; no socket is mounted in applications."""

import argparse
import json
import re
import subprocess
import urllib.request
from pathlib import Path


def run(args):
    result = subprocess.run(["docker", *args], capture_output=True, timeout=15, check=True)
    if len(result.stdout) > 65536:
        raise ValueError("Excessive engine output")
    return result.stdout.decode().strip()


def collect(namespace):
    if not re.fullmatch(r"[a-z][a-z0-9_-]{0,39}", namespace):
        raise ValueError("Invalid stack namespace")
    ids = run(
        ["ps", "-aq", "--filter", "label=com.docker.compose.project=" + namespace]
    ).splitlines()
    if len(ids) > 24:
        raise ValueError("Unexpected container count")
    result = {}
    for identity in ids:
        if not re.fullmatch(r"[a-f0-9]{12,64}", identity):
            raise ValueError("Unexpected engine identity")
        # Never read .Config.Env or full inspection output.
        row = json.loads(
            run(
                [
                    "inspect",
                    "--format",
                    (
                        '{"service":{{json (index .Config.Labels "com.docker.compose.'
                        'service")}},"running":{{.State.Running}},"restarts":{{.Resta'
                        'rtCount}},"health":{{if .State.Health}}{{json .State.Health.'
                        "Status}}{{else}}null{{end}}}"
                    ),
                    identity,
                ]
            )
        )
        if row["service"] in {
            "migrate",
            "initialize",
            "grants",
            "curate",
            "certificates",
            "register-model",
        }:
            continue
        values = {"running": int(row["running"]), "restarts": row["restarts"]}
        if row["health"] is not None:
            values["healthy"] = int(row["health"] == "healthy")
        if row["running"]:
            stats = json.loads(run(["stats", "--no-stream", "--format", "{{json .}}", identity]))
            values["cpu_percent"] = float(stats["CPUPerc"].rstrip("%"))
            amount = stats["MemUsage"].split("/")[0].strip()
            match = re.fullmatch(r"([0-9.]+)(B|kB|KB|KiB|MB|MiB|GB|GiB)", amount)
            if match:
                scales = {
                    "B": 1,
                    "kB": 1000,
                    "KB": 1000,
                    "KiB": 1024,
                    "MB": 10**6,
                    "MiB": 1024**2,
                    "GB": 10**9,
                    "GiB": 1024**3,
                }
                values["memory_bytes"] = float(match[1]) * scales[match[2]]
        existing = result.get(row["service"])
        if existing is None:
            result[row["service"]] = values
        else:
            # Never overwrite a failed replica with a later healthy one.
            existing["running"] = min(existing["running"], values["running"])
            for field in ("restarts", "cpu_percent", "memory_bytes"):
                if field in values:
                    existing[field] = existing.get(field, 0) + values[field]
            if "healthy" in values:
                existing["healthy"] = min(existing.get("healthy", 1), values["healthy"])
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--namespace", required=True)
    parser.add_argument("--token", type=Path, required=True)
    parser.add_argument("--url", required=True)
    args = parser.parse_args()
    request = urllib.request.Request(
        args.url.rstrip("/") + "/inventory",
        data=json.dumps(collect(args.namespace)).encode(),
        headers={"Authorization": "Bearer " + args.token.read_text().strip()},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=5) as response:
        assert response.status == 202
