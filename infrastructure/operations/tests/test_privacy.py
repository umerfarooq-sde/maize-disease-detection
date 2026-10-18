import json

import pytest
from privacy import cleanup, detach, read_policy, review
from privacy_worker import cycle


def policy_file(tmp_path, **changes):
    policy = {
        "version": "synthetic-policy-v1",
        "approvalReference": "",
        "erasureEnabled": False,
        "retention": {
            "expiredSessionsDays": None,
            "operationalEventsDays": None,
            "farmerScansDays": None,
            "anonymousScansDays": None,
            "backupDays": None,
            "minimumBackupsToKeep": None,
        },
    }
    policy.update(changes)
    path = tmp_path / "policy.json"
    path.write_text(json.dumps(policy))
    return path


def test_default_policy_never_connects_or_deletes(tmp_path, monkeypatch):
    import privacy

    def forbidden(*_a, **_kw):
        raise AssertionError("Disabled policy cannot access database/provider")

    monkeypatch.setattr(privacy, "connect", forbidden)
    path = policy_file(tmp_path)
    assert cycle("private fixture", path, forbidden) == {
        "status": "DISABLED",
        "deleted": False,
    }
    for function in (review, detach, cleanup):
        args = ["private fixture", "not-a-real-request"]
        if function is review:
            args.append("not-a-real-admin")
        args.append(path)
        if function is cleanup:
            args.append(forbidden)
        with pytest.raises(ValueError, match="disabled"):
            function(*args)


def test_policy_is_strict_versioned_and_approval_gated(tmp_path):
    path = policy_file(tmp_path)
    _, fingerprint = read_policy(path)
    path.write_text(json.dumps(json.loads(path.read_text()), indent=4))
    assert read_policy(path)[1] == fingerprint
    with pytest.raises(ValueError, match="approval"):
        read_policy(policy_file(tmp_path, erasureEnabled=True))
    for days in (-1, 0, True, 0.5, "30"):
        with pytest.raises(ValueError):
            read_policy(
                policy_file(
                    tmp_path,
                    retention={
                        "expiredSessionsDays": days,
                        "operationalEventsDays": None,
                        "farmerScansDays": None,
                        "anonymousScansDays": None,
                        "backupDays": None,
                        "minimumBackupsToKeep": None,
                    },
                )
            )
    changed = policy_file(tmp_path, erasureEnabled=True, approvalReference="SYNTHETIC TEST ONLY")
    assert read_policy(changed, enabled=True)[1] != fingerprint
