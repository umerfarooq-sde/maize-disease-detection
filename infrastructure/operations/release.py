"""Protected-host rollout with preflight, backup, explicit migration gate and rollback.

No SSH credential transport or public deployment from untrusted PRs. Run only on
an operator-owned deployment host, via the protected manual workflow.
"""

import argparse
import io
import json
import os
import re
import subprocess
import sys
import urllib.request
import zipfile
from contextlib import contextmanager
from pathlib import Path

from backup import create_backup
from database import secret
from preflight import preflight


def run(command, *, timeout=600):
    completed = subprocess.run(command, capture_output=True, timeout=timeout)
    if completed.returncode:
        # Captured output may contain deployment paths or dependency errors; only
        # persist a static result. Operators inspect private host logs separately.
        raise RuntimeError("Deployment command failed: " + command[0])
    return completed.stdout


def smoke(origin):
    if not origin.startswith("https://"):
        raise ValueError("A verified HTTPS public origin is required")
    # No insecure CA override. Local TLS uses an explicitly installed local root.
    with urllib.request.urlopen(origin.rstrip("/") + "/api/v1/health", timeout=20) as response:
        payload = json.loads(response.read(16384))
        if response.status != 200 or payload.get("success") is not True:
            raise RuntimeError("Public API health failed")


def validate_manifest(release):
    if (
        not isinstance(release, dict)
        or set(release) != {"commit", "images", "expandOnlyCompatible"}
        or not isinstance(release["commit"], str)
        or not re.fullmatch("[a-f0-9]{40}", release["commit"])
    ):
        raise ValueError("Invalid immutable release manifest")
    if release["expandOnlyCompatible"] is not True:
        raise ValueError("Operator compatibility review is required before migration/rollback")
    required = {"NODE_IMAGE", "AI_IMAGE", "MIGRATION_IMAGE", "OPERATIONS_IMAGE"}
    if (
        not isinstance(release["images"], dict)
        or set(release["images"]) != required
        or any(
            not isinstance(value, str)
            or not re.fullmatch(r"[A-Za-z0-9./:_-]+@sha256:[a-f0-9]{64}", value)
            for value in release["images"].values()
        )
    ):
        raise ValueError("All application images require reviewed immutable digest references")
    return release


def atomic_json(path, value):
    pending = path.with_suffix(".pending")
    with pending.open("w", encoding="utf-8") as output:
        json.dump(value, output, indent=2)
        output.write("\n")
        output.flush()
        os.fsync(output.fileno())
    pending.chmod(0o600)
    pending.replace(path)


@contextmanager
def deployment_lock(state):
    """No stale-lock takeover: an operator must reconcile an interrupted rollout."""
    lock = state / "deployment.lock"
    try:
        descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError:
        raise ValueError(
            "Deployment already active or interrupted; reconcile the host lock"
        ) from None
    try:
        with os.fdopen(descriptor, "w") as output:
            output.write(str(os.getpid()) + "\n")
        yield
    finally:
        lock.unlink()


def source_bundle(root, state, release, *, rollback=False):
    """Only committed runtime/curation files; never copy ignored local secrets."""
    bundle = state / "bundles" / release["commit"]
    marker = bundle / "release.json"
    if marker.is_file():
        if json.loads(marker.read_text()) != release:
            raise ValueError("Existing commit bundle has a different image identity")
        return bundle
    if rollback:
        raise ValueError("Rollback requires the retained immutable configuration bundle")
    content = run(
        [
            "git",
            "-C",
            str(root),
            "archive",
            "--format=zip",
            release["commit"],
            "infrastructure/runtime",
            "backend/knowledge",
        ],
        timeout=30,
    )
    if len(content) > 32 * 1024 * 1024:
        raise ValueError("Deployment configuration archive exceeds its bound")
    pending = state / "bundles" / (release["commit"] + ".pending")
    pending.mkdir(parents=True, mode=0o700)
    with zipfile.ZipFile(io.BytesIO(content)) as archive:
        if sum(item.file_size for item in archive.infolist()) > 64 * 1024 * 1024:
            raise ValueError("Expanded deployment configuration exceeds its bound")
        for item in archive.infolist():
            name = Path(item.filename)
            target = (pending / name).resolve()
            if (
                name.is_absolute()
                or not target.is_relative_to(pending.resolve())
                or not (
                    item.filename.startswith(("infrastructure/runtime/", "backend/knowledge/"))
                    or item.is_dir()
                    and item.filename in {"infrastructure/", "backend/"}
                )
                or (item.external_attr >> 16) & 0o170000 == 0o120000
            ):
                raise ValueError("Unsafe deployment archive entry")
            if item.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(archive.read(item))
    atomic_json(pending / "release.json", release)
    pending.rename(bundle)
    return bundle


def deploy(
    root: Path,
    environment_file: Path,
    manifest: Path,
    *,
    state: Path,
    deployment_environment: str,
    allow_migrations=False,
    rollback=False,
):
    from dotenv import dotenv_values

    values = dotenv_values(environment_file)
    preflight(environment_file)
    release = validate_manifest(json.loads(manifest.read_text()))
    if deployment_environment not in {"staging", "production"} or not state.is_absolute():
        raise ValueError("Explicit environment and absolute external deployment state are required")
    state, root = state.resolve(), root.resolve()
    for protected in (
        root,
        Path(values["SECRETS_DIRECTORY"]).resolve(),
        Path(values["MODEL_DIRECTORY"]).resolve(),
    ):
        if state.is_relative_to(protected) or protected.is_relative_to(state):
            raise ValueError("Deployment state must be separate from checkout, secrets and models")
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    with deployment_lock(state):
        return rollout(
            root,
            environment_file.resolve(),
            values,
            release,
            state,
            deployment_environment,
            allow_migrations=allow_migrations,
            rollback=rollback,
        )


def rollout(
    root,
    environment_file,
    values,
    release,
    state,
    deployment_environment,
    *,
    allow_migrations=False,
    rollback=False,
):
    active, previous = state / "active-release.json", state / "previous-release.json"
    if rollback:
        if not previous.is_file():
            raise ValueError("No retained compatible release exists for rollback")
        release = validate_manifest(json.loads(previous.read_text()))
    elif not allow_migrations:
        raise ValueError("Explicit protected migration approval is required; no rollout performed")
    if (
        run(["git", "-C", str(root), "rev-parse", "HEAD"]).decode().strip() != release["commit"]
        and not rollback
    ):
        raise ValueError("Checkout and approved image/source provenance do not match")
    bundle = source_bundle(root, state, release, rollback=rollback)
    public = state / "selected-release.env"
    public.write_text(
        environment_file.read_text()
        + "\n"
        + "".join(key + "=" + value + "\n" for key, value in release["images"].items())
    )
    public.chmod(0o600)
    compose = [
        "docker",
        "compose",
        "--env-file",
        str(public),
        "-f",
        str(bundle / "infrastructure/runtime/compose.yaml"),
        "-f",
        str(bundle / ("infrastructure/runtime/compose." + deployment_environment + ".yaml")),
    ]
    configuration = json.loads(run(compose + ["config", "--format", "json"], timeout=30))
    run(compose + ["pull"], timeout=900)
    if not rollback:
        directory = Path(values["SECRETS_DIRECTORY"])
        create_backup(
            secret(directory / "backup.json")["DATABASE_URL"],
            state / "pre-release-backups",
            directory / "backup-key",
            Path(values["MODEL_DIRECTORY"]),
        )
        run(compose + ["run", "--rm", "--no-deps", "migrate"], timeout=300)
        run(compose + ["run", "--rm", "--no-deps", "grants"], timeout=60)
        run(compose + ["run", "--rm", "--no-deps", "register-model"], timeout=60)
        run(compose + ["run", "--rm", "--no-deps", "curate"], timeout=900)
        # This grant pass uses the schema owner to grant existing identities
        # access to reviewed new objects. Role creation/credentials/capabilities
        # are never changed by deployment automation.
    if active.exists() and not rollback:
        atomic_json(previous, validate_manifest(json.loads(active.read_text())))
    try:
        # Includes graceful backup shutdown (660s) and cold model/curation startup.
        runtime = sorted(
            set(configuration["services"]) - {"migrate", "grants", "register-model", "curate"}
        )
        # Rollback must not rerun old migrations or re-ingest an older corpus.
        run(
            compose
            + ["up", "-d", "--no-deps", "--no-build", "--wait", "--wait-timeout", "1200", *runtime],
            timeout=3300,
        )
        run(compose + ["exec", "-T", "api", "node", "dist/cli/readiness.js"], timeout=25)
        smoke(values["PUBLIC_HTTPS_ORIGIN"])
    except Exception:
        # Migration DDL is NEVER reversed automatically. Recovery is a separately
        # reviewed compatible-image rollback or an isolated restore drill.
        raise RuntimeError(
            "Rollout/smoke failed; preserve evidence and invoke explicit compatible rollback"
        ) from None
    atomic_json(active, release)
    return {
        "status": "PASS",
        "commit": release["commit"],
        "rollback": rollback,
        "publicReleaseApproval": False,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--environment-file", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument(
        "--deployment-environment", choices=["staging", "production"], required=True
    )
    parser.add_argument("--allow-migrations", action="store_true")
    parser.add_argument("--rollback", action="store_true")
    args = parser.parse_args()
    try:
        print(
            json.dumps(
                deploy(
                    args.root,
                    args.environment_file,
                    args.manifest,
                    state=args.state,
                    deployment_environment=args.deployment_environment,
                    allow_migrations=args.allow_migrations,
                    rollback=args.rollback,
                )
            )
        )
    except Exception:
        print(
            json.dumps(
                {
                    "status": "FAIL",
                    "category": "RELEASE_GATE_OR_ROLLOUT_FAILED",
                    "publicReleaseApproval": False,
                }
            )
        )
        sys.exit(1)
