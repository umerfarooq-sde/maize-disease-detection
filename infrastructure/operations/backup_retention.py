"""Policy-gated archive expiration with recent, verified restore evidence fence."""

import hashlib
import json
import re
from datetime import UTC, datetime, timedelta
from pathlib import Path
from uuid import uuid4

from privacy import read_policy

NAME = re.compile(r"^(\d{8}T\d{6}Z)-[a-f0-9]{32}\.mdb$")


def record_restore(archive: Path, proof: dict) -> dict:
    if (
        proof.get("status") != "PASS"
        or proof.get("isolatedRestore") is not True
        or proof.get("modelArtifactsVerified") is not True
        or not NAME.fullmatch(archive.name)
    ):
        raise ValueError("Successful isolated recovery evidence is required")
    receipt = {
        "format": 1,
        "status": "PASS",
        "encryptedSha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
        "restoredAt": datetime.now(UTC).isoformat(),
        "migrations": proof["migrations"],
        "tables": proof["tables"],
    }
    path = archive.with_name(archive.name + ".restore-" + uuid4().hex + ".json")
    with path.open("x", encoding="utf-8") as output:
        output.write(json.dumps(receipt, sort_keys=True) + "\n")
    path.chmod(0o600)
    return receipt


def expire_backups(directory: Path, policy_path: Path, *, execute=False) -> dict:
    policy, fingerprint = read_policy(policy_path)
    days = policy["retention"]["backupDays"]
    if days is None:
        return {"status": "DISABLED", "removed": 0, "dryRun": not execute}
    if not directory.is_dir():
        raise ValueError("Backup archive directory is unavailable")
    files = []
    for path in directory.glob("*.mdb"):
        match = NAME.fullmatch(path.name)
        if not match or path.is_symlink() or path.resolve().parent != directory.resolve():
            raise ValueError("Unexpected archive ownership; no expiration performed")
        date = datetime.strptime(match[1], "%Y%m%dT%H%M%SZ").replace(tzinfo=UTC)
        files.append((date, path))
        if len(files) > 10000:
            raise ValueError("Archive inventory exceeds reviewed capacity")
    files.sort(key=lambda item: item[1].name, reverse=True)
    protected = files[: policy["retention"]["minimumBackupsToKeep"]]
    cutoff = datetime.now(UTC) - timedelta(days=days)
    candidates = [path for date, path in files[len(protected) :] if date < cutoff]
    # Retain at least one archive with a completed real restore receipt. A
    # merely encrypted/completed backup is not a proven recovery point.
    known = None
    for _, path in protected:
        receipts = sorted(directory.glob(path.name + ".restore-*.json"))
        if receipts:
            receipt = receipts[-1]
            if receipt.is_symlink() or receipt.stat().st_size > 16384:
                raise ValueError("Invalid recovery receipt")
            value = json.loads(receipt.read_text())
            if value.get("status") == "PASS":
                known = path, value
                break
    if candidates and (
        known is None
        or hashlib.sha256(known[0].read_bytes()).hexdigest() != known[1].get("encryptedSha256")
    ):
        raise ValueError("No protected, integrity-matched restored backup; expiration is blocked")
    if execute:
        for path in candidates:
            # Exact own archive files only. No recursive deletion, raw data,
            # model files, or audit/restore receipts are removed.
            path.unlink()
    return {
        "status": "PASS",
        "policyHash": fingerprint,
        "eligible": len(candidates),
        "protected": len(protected),
        "removed": len(candidates) if execute else 0,
        "dryRun": not execute,
    }
