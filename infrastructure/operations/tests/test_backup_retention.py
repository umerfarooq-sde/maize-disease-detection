import json
from pathlib import Path

import pytest
from backup_retention import expire_backups, record_restore


def policy(tmp_path, **changes):
    example = Path(__file__).resolve().parents[2] / "runtime/privacy-policy.example.json"
    value = json.loads(example.read_text())
    value["retention"].update(changes)
    value["approvalReference"] = "SYNTHETIC FIXTURE ONLY"
    target = tmp_path / "policy.json"
    target.write_text(json.dumps(value))
    return target


def test_backup_expiration_is_disabled_without_policy_and_refuses_missing_restore_evidence(
    tmp_path,
):
    assert expire_backups(tmp_path / "missing", policy(tmp_path))["status"] == "DISABLED"
    old = tmp_path / ("20200101T000000Z-" + "a" * 32 + ".mdb")
    new = tmp_path / ("20260101T000000Z-" + "b" * 32 + ".mdb")
    old.write_bytes(b"synthetic-old")
    new.write_bytes(b"synthetic-new")
    path = policy(tmp_path, backupDays=1, minimumBackupsToKeep=1)
    with pytest.raises(ValueError, match="restored"):
        expire_backups(tmp_path, path, execute=True)
    assert old.exists() and new.exists()
    # Synthetic receipt tests the fence only. This is not live restore evidence.
    record_restore(
        new,
        {
            "status": "PASS",
            "isolatedRestore": True,
            "modelArtifactsVerified": True,
            "tables": 1,
            "migrations": 1,
        },
    )
    result = expire_backups(tmp_path, path)
    assert result["eligible"] == 1 and result["removed"] == 0
    assert old.exists()
    assert expire_backups(tmp_path, path, execute=True)["removed"] == 1
    assert new.exists() and not old.exists()
    assert list(tmp_path.glob("*.restore-*.json"))


def test_modified_recovery_archive_or_unknown_file_blocks_retention(tmp_path):
    old = tmp_path / ("20200101T000000Z-" + "a" * 32 + ".mdb")
    new = tmp_path / ("20260101T000000Z-" + "b" * 32 + ".mdb")
    old.write_bytes(b"synthetic-old")
    new.write_bytes(b"synthetic-new")
    record_restore(
        new,
        {
            "status": "PASS",
            "isolatedRestore": True,
            "modelArtifactsVerified": True,
            "tables": 1,
            "migrations": 1,
        },
    )
    new.write_bytes(b"synthetic-changed")
    path = policy(tmp_path, backupDays=1, minimumBackupsToKeep=1)
    with pytest.raises(ValueError, match="integrity"):
        expire_backups(tmp_path, path, execute=True)
    assert old.exists()
    (tmp_path / "not-project-owned.mdb").write_bytes(b"unrelated")
    with pytest.raises(ValueError, match="ownership"):
        expire_backups(tmp_path, path, execute=True)
