"""Protected real-stack probes. Never substitutes static validation for runtime.

Read-only domain operations; the synthetic operational alert is explicitly labeled.
No farmer registration, provider image mutation, retention or migration is invoked.
"""

import argparse
import json
from pathlib import Path

from database import secret
from dotenv import dotenv_values
from preflight import preflight
from release import run, smoke, validate_manifest
from roles import audit


def verify(environment_file: Path, state: Path, environment: str):
    preflight(environment_file)
    values = dotenv_values(environment_file)
    release = validate_manifest(json.loads((state / "active-release.json").read_text()))
    bundle = state / "bundles" / release["commit"]
    if validate_manifest(json.loads((bundle / "release.json").read_text())) != release:
        raise ValueError("Active configuration/image provenance differs")
    compose = [
        "docker",
        "compose",
        "--env-file",
        str(state / "selected-release.env"),
        "-f",
        str(bundle / "infrastructure/runtime/compose.yaml"),
        "-f",
        str(bundle / ("infrastructure/runtime/compose." + environment + ".yaml")),
    ]
    details = json.loads(run(compose + ["config", "--format", "json"], timeout=30))
    for name, config in details["services"].items():
        if name != "edge" and config.get("ports"):
            raise ValueError("Unexpected externally published private service")
    run(compose + ["exec", "-T", "api", "node", "dist/cli/readiness.js"], timeout=25)
    run(
        compose + ["exec", "-T", "ai", "/app/ai-service/.venv/bin/python", "-m", "app.healthcheck"],
        timeout=25,
    )
    # The probe executes inside a private operational container; no host port or
    # secret values in argv. It checks real scrape targets, private denial, and
    # a labeled alert receiver event. Empty metrics are not accepted as healthy.
    program = """
import json, urllib.request, urllib.error
from pathlib import Path
token=Path('/run/secrets/operations_token').read_text()
def get(url, headers=None):
    with urllib.request.urlopen(urllib.request.Request(url,headers=headers or {}),timeout=20) as r:
        return r.read(262144)
targets=json.loads(get('http://prometheus:9090/api/v1/targets'))['data']['activeTargets']
required={'node','ai','cleanup','backups','alerts'}
assert required <= {t['labels']['job'] for t in targets if t['health']=='up'}
for url in ('http://api:3000/internal/metrics','http://ai:8000/internal/metrics'):
    try: get(url)
    except urllib.error.HTTPError as error: assert error.code==404
    else: raise AssertionError('Private metrics accepted missing credentials')
headers={'Authorization':'Bearer '+token}
metrics=get('http://backups:9031/internal/metrics',headers).decode()
assert 'maizedoctor_backup_last_success_seconds ' in metrics
assert get('http://loki:3100/ready').strip() == b'ready'
get('http://grafana:3000/api/health')
request=urllib.request.Request('http://alerts:9030/events',data=json.dumps({'alerts':[
 {'status':'resolved','labels':{'alertname':'InfrastructureSmoke','job':'controlled_probe'}}
]}).encode(),headers=headers)
with urllib.request.urlopen(request,timeout=10) as r: assert r.status==202
print(json.dumps({'scrapes':len(required),'privateAuth':'PASS','backupObserved':True,'alertReceiver':'PASS'}))
"""
    # Use stdin, not a shell, to preserve the program and prevent interpolation.
    import subprocess

    process = subprocess.run(
        compose + ["exec", "-T", "alerts", "/opt/operations/bin/python", "-"],
        input=program.encode(),
        capture_output=True,
        timeout=120,
    )
    if process.returncode:
        raise RuntimeError("Connected monitoring/authentication probe failed")
    smoke(values["PUBLIC_HTTPS_ORIGIN"])
    directory = Path(values["SECRETS_DIRECTORY"])
    audits = [
        audit(secret(directory / (name + ".json"))["DATABASE_URL"], role)
        for name, role in [
            ("node", "md_node"),
            ("ai", "md_ai"),
            ("backup", "md_backup"),
            ("privacy", "md_privacy"),
        ]
    ]
    return {
        "status": "PASS",
        "commit": release["commit"],
        "runtimeAudits": audits,
        "connectedMonitoring": json.loads(process.stdout),
        "publicReleaseApproval": False,
        "notCovered": [
            "physical device",
            "signed APK",
            "private provider failure injection",
            "full farmer domain E2E (separate check-e2e.py evidence required)",
        ],
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--environment-file", type=Path, required=True)
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--environment", choices=["staging", "production"], required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(verify(args.environment_file, args.state, args.environment)))
    except Exception:
        print(
            json.dumps(
                {
                    "status": "FAIL",
                    "category": "CONNECTED_STACK_PROBE",
                    "secretValuesPrinted": False,
                }
            )
        )
        raise SystemExit(1) from None
