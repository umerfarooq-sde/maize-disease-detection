import io
import json
import zipfile

import pytest
import release


def approved():
    return {
        "commit": "a" * 40,
        "images": {
            key: "ghcr.io/fixture/image@sha256:" + "b" * 64
            for key in ("NODE_IMAGE", "AI_IMAGE", "MIGRATION_IMAGE", "OPERATIONS_IMAGE")
        },
        "expandOnlyCompatible": True,
    }


def test_manifest_rejects_mutable_or_unreviewed_releases():
    assert release.validate_manifest(approved()) == approved()
    for invalid in (
        None,
        {},
        {**approved(), "expandOnlyCompatible": False},
        {**approved(), "images": {"NODE_IMAGE": "image:latest"}},
    ):
        with pytest.raises(ValueError):
            release.validate_manifest(invalid)


def test_host_lock_is_exclusive_and_released_on_failure(tmp_path):
    with pytest.raises(RuntimeError), release.deployment_lock(tmp_path):
        with pytest.raises(ValueError), release.deployment_lock(tmp_path):
            pass
        raise RuntimeError("controlled interrupted command")
    assert not (tmp_path / "deployment.lock").exists()


def archive(name):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as output:
        output.writestr(name, "retained configuration")
    return buffer.getvalue()


def test_configuration_bundle_is_reused_on_rollback(tmp_path, monkeypatch):
    monkeypatch.setattr(
        release, "run", lambda *_args, **_kwargs: archive("infrastructure/runtime/compose.yaml")
    )
    bundle = release.source_bundle(tmp_path / "checkout", tmp_path, approved())
    assert (bundle / "infrastructure/runtime/compose.yaml").read_text() == "retained configuration"
    monkeypatch.setattr(release, "run", lambda *_a, **_k: pytest.fail("Rollback re-read checkout"))
    assert (
        release.source_bundle(tmp_path / "new-checkout", tmp_path, approved(), rollback=True)
        == bundle
    )
    (bundle / "release.json").write_text(json.dumps({**approved(), "commit": "c" * 40}))
    with pytest.raises(ValueError):
        release.source_bundle(tmp_path, tmp_path, approved(), rollback=True)


def test_bundle_rejects_traversal_and_missing_rollback(tmp_path, monkeypatch):
    with pytest.raises(ValueError):
        release.source_bundle(tmp_path, tmp_path, approved(), rollback=True)
    monkeypatch.setattr(release, "run", lambda *_a, **_k: archive("../../escape"))
    with pytest.raises(ValueError):
        release.source_bundle(tmp_path, tmp_path, approved())
    assert not (tmp_path.parent / "escape").exists()


def test_real_git_bundle_excludes_untracked_operator_secrets(tmp_path):
    import subprocess

    root, state = tmp_path / "checkout", tmp_path / "state"
    runtime = root / "infrastructure/runtime"
    runtime.mkdir(parents=True)
    (root / "backend/knowledge").mkdir(parents=True)
    (runtime / "compose.yaml").write_text("services: {}\n")
    (root / "backend/knowledge/review.json").write_text("{}")
    for arguments in (
        ["init"],
        ["add", "infrastructure/runtime/compose.yaml", "backend/knowledge/review.json"],
        [
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "commit",
            "-m",
            "fixture",
        ],
    ):
        subprocess.run(["git", "-C", str(root), *arguments], check=True, capture_output=True)
    identity = (
        subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"]).decode().strip()
    )
    (runtime / "private-secret.json").write_text("private-test-marker")
    bundle = release.source_bundle(root, state, {**approved(), "commit": identity})
    assert not (bundle / "infrastructure/runtime/private-secret.json").exists()
    assert (bundle / "infrastructure/runtime/compose.yaml").is_file()


def test_rollout_jobs_are_explicit_and_rollback_never_runs_migrations(tmp_path, monkeypatch):
    current = approved()
    older = {**approved(), "commit": "c" * 40}
    (tmp_path / "previous-release.json").write_text(json.dumps(older))
    environment = tmp_path / "environment.env"
    environment.write_text("STACK_NAME=fixture\n")
    calls = []

    def command(arguments, **_kwargs):
        calls.append(arguments)
        if arguments[0] == "git":
            return current["commit"].encode()
        if "config" in arguments:
            return json.dumps(
                {
                    "services": {
                        key: {}
                        for key in (
                            "api",
                            "ai",
                            "edge",
                            "migrate",
                            "grants",
                            "register-model",
                            "curate",
                        )
                    }
                }
            ).encode()
        return b""

    monkeypatch.setattr(release, "run", command)
    monkeypatch.setattr(release, "source_bundle", lambda *_a, **_k: tmp_path / "bundle")
    monkeypatch.setattr(release, "smoke", lambda _origin: None)
    monkeypatch.setattr(release, "create_backup", lambda *_a, **_k: None)
    monkeypatch.setattr(release, "secret", lambda _path: {"DATABASE_URL": "synthetic-not-used"})
    values = {
        "SECRETS_DIRECTORY": str(tmp_path / "secrets"),
        "MODEL_DIRECTORY": str(tmp_path / "model"),
        "PUBLIC_HTTPS_ORIGIN": "https://fixture.example.invalid",
    }
    result = release.rollout(
        tmp_path, environment, values, current, tmp_path, "staging", allow_migrations=True
    )
    assert result["status"] == "PASS"
    jobs = [c[-1] for c in calls if "run" in c]
    assert jobs == ["migrate", "grants", "register-model", "curate"]
    calls.clear()
    result = release.rollout(
        tmp_path, environment, values, current, tmp_path, "staging", rollback=True
    )
    assert result["commit"] == older["commit"]
    assert not any("run" in c for c in calls)
    up = next(c for c in calls if "up" in c)
    assert "--no-deps" in up and up[-3:] == ["ai", "api", "edge"]
