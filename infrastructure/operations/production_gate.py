"""Fail-closed authorization for public production releases.

A signed operator decision is evidence of review, NOT a grant of commercial model
rights. The mounted model's own provenance must independently permit production.
This module does not change weights, licenses, model metadata, or approvals.
"""

import hashlib
import hmac
import json
import os
import re
import tomllib
from datetime import UTC, datetime, timedelta
from pathlib import Path
from urllib.parse import urlsplit

REQUIRED_REVIEWS = frozenset({
    "modelRights", "independentFieldValidation", "torchSecurityAdvisories",
    "privacyAndRetention", "hostedTLSAndSecrets", "connectedEndToEnd",
    "physicalDeviceAcceptance", "backupRestoreDrill", "incidentResponse",
})
KNOWN_TORCH_ADVISORIES = frozenset({"PYSEC-2025-194", "PYSEC-2026-139"})
HEX_SHA256 = re.compile(r"[a-f0-9]{64}\Z")
EVIDENCE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._:/#-]{11,199}\Z")


def _json(path: Path, *, max_size: int = 16384) -> dict:
    if not path.is_file() or path.is_symlink() or path.stat().st_size > max_size:
        raise ValueError("Missing, unsafe or oversized release gate input")
    value = json.loads(path.read_bytes())
    if not isinstance(value, dict):
        raise ValueError("Release gate JSON must be an object")
    return value


def _canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()


def _stamp(value: str) -> datetime:
    if not isinstance(value, str):
        raise ValueError("Approval time must include UTC timezone")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValueError("Invalid approval date") from exc
    if parsed.tzinfo is None or parsed.utcoffset() != timedelta(0):
        raise ValueError("Approval time must be UTC")
    return parsed.astimezone(UTC)


def _key(path: Path) -> bytes:
    if not path.is_absolute() or not path.is_file() or path.is_symlink():
        raise ValueError("Signing key must be a separate absolute regular file")
    if os.name != "nt" and path.stat().st_mode & 0o077:
        raise ValueError("Signing key has insecure filesystem permissions")
    if path.stat().st_size > 4096:
        raise ValueError("Signing key is oversized")
    key = path.read_bytes()
    if len(key) < 32:
        raise ValueError("Signing key requires at least 32 random bytes")
    return key


def _model_rights(model: dict) -> None:
    rights = model.get("research_policy")
    if not isinstance(rights, dict):
        raise ValueError("Model rights provenance is absent")
    if (rights.get("commercial_clearance") is not True or
            model.get("production_model_promoted") is not True or
            "non-commercial" in str(rights.get("permitted_use", "")).lower()):
        raise ValueError("Mounted model is restricted to research; no public production serving")
    if not isinstance(rights.get("permitted_use"), str) or not rights["permitted_use"].strip():
        raise ValueError("Model use rights are not specified")


def _privacy_policy(policy: dict) -> None:
    retention = policy.get("retention")
    mandatory = {"expiredSessionsDays", "operationalEventsDays", "farmerScansDays",
                 "anonymousScansDays", "backupDays", "minimumBackupsToKeep"}
    if (policy.get("erasureEnabled") is not True or
            not isinstance(policy.get("approvalReference"), str) or
            not policy["approvalReference"].strip() or
            not isinstance(retention, dict) or set(retention) != mandatory or
            any(type(value) is not int or not 1 <= value <= (100 if key == "minimumBackupsToKeep" else 36500)
                for key, value in retention.items())):
        raise ValueError("Public production needs an approved, active privacy/retention policy")


def _pinned_torch(root: Path) -> str:
    project = tomllib.loads((root / "ai-service/pyproject.toml").read_text(encoding="utf-8"))
    versions = [value.split("==", 1)[1] for value in project["project"]["dependencies"]
                if re.fullmatch(r"torch==[0-9]+(?:\.[0-9]+){2}", value)]
    if len(versions) != 1:
        raise ValueError("Torch must be pinned to one unambiguous exact version")
    return versions[0]


def validate_production_gate(root: Path, values: dict, release: dict,
                             approval_file: Path | None, approval_key_file: Path | None,
                             *, now: datetime | None = None) -> dict:
    """Verify before any production rollout side effects; no approvals invented."""
    if approval_file is None or approval_key_file is None:
        raise ValueError("Production release needs external signed operator authorization")
    root = root.resolve()
    approval_file, approval_key_file = Path(approval_file), Path(approval_key_file)
    if not approval_file.is_absolute() or approval_file.is_relative_to(root) or approval_key_file.is_relative_to(root):
        raise ValueError("Approvals/keys must remain outside the source checkout")
    if (not values.get("PRIVACY_POLICY_FILE") or
            not Path(values["PRIVACY_POLICY_FILE"]).is_absolute() or
            Path(values["PRIVACY_POLICY_FILE"]).is_relative_to(root)):
        raise ValueError("Production requires an explicit external absolute privacy policy mount")
    model_path = Path(values["MODEL_DIRECTORY"]) / "model-artifact.json"
    policy_path = Path(values["PRIVACY_POLICY_FILE"])
    if model_path.is_symlink() or policy_path.is_symlink():
        raise ValueError("Model metadata and privacy policy must be regular non-symlink files")
    model = _json(model_path, max_size=512 * 1024)
    policy = _json(policy_path)
    _model_rights(model)  # Cannot be bypassed by a signed attestation.
    _privacy_policy(policy)
    signed = _json(approval_file)
    if set(signed) != {"payload", "signature"} or not isinstance(signed["payload"], dict):
        raise ValueError("Malformed operator approval envelope")
    sig = signed["signature"]
    if not isinstance(sig, str) or not HEX_SHA256.fullmatch(sig):
        raise ValueError("Invalid approval signature encoding")
    digest = hmac.new(_key(approval_key_file), _canonical(signed["payload"]), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(digest, sig):
        raise ValueError("Operator authorization signature is invalid")
    p = signed["payload"]
    expected = {"version", "status", "issuedAt", "expiresAt", "environment",
                "releaseSha256", "modelMetadataSha256", "privacyPolicySha256",
                "publicOrigin", "torchVersion", "reviewedAdvisories", "controls"}
    if set(p) != expected or p["version"] != 1 or p["status"] != "APPROVED" or p["environment"] != "production":
        raise ValueError("Operator approval contract is incomplete")
    issued, expires = _stamp(p["issuedAt"]), _stamp(p["expiresAt"])
    clock = now or datetime.now(UTC)
    if not (issued <= clock < expires and expires <= issued + timedelta(days=30)):
        raise ValueError("Operator authorization has expired, is premature or too long-lived")
    if p["releaseSha256"] != hashlib.sha256(_canonical(release)).hexdigest():
        raise ValueError("Approved release identity differs")
    if p["modelMetadataSha256"] != hashlib.sha256(model_path.read_bytes()).hexdigest():
        raise ValueError("Approved model artifact provenance differs")
    if p["privacyPolicySha256"] != hashlib.sha256(_canonical(policy)).hexdigest():
        raise ValueError("Approved privacy policy differs")
    if (p["publicOrigin"] != values["PUBLIC_HTTPS_ORIGIN"] or
            urlsplit(p["publicOrigin"]).scheme != "https"):
        raise ValueError("Approved public origin differs")
    if p["torchVersion"] != _pinned_torch(root):
        raise ValueError("Pinned runtime differs from approved Torch review")
    if (not isinstance(p["reviewedAdvisories"], list) or
            not all(isinstance(a, str) for a in p["reviewedAdvisories"]) or
            not KNOWN_TORCH_ADVISORIES.issubset(set(p["reviewedAdvisories"]))):
        raise ValueError("Known Torch advisories lack explicit security disposition")
    controls = p["controls"]
    if not isinstance(controls, dict) or set(controls) != REQUIRED_REVIEWS:
        raise ValueError("Mandatory release evidence is missing")
    for name, item in controls.items():
        if (not isinstance(item, dict) or set(item) != {"status", "evidence"} or
                item.get("status") != "PASS" or not isinstance(item.get("evidence"), str) or
                not EVIDENCE.fullmatch(item["evidence"]) or
                item["evidence"].lower().startswith(("todo", "placeholder", "synthetic", "example"))):
            raise ValueError("Release control lacks explicit reviewed evidence: " + name)
    return {
        "status": "PASS",
        "signedProductionGate": True,
        "modelRightsFromArtifact": True,
        "policyApproved": True,
        "runtimeAdvisoriesReviewed": sorted(KNOWN_TORCH_ADVISORIES),
        "authorizationExpiresAt": p["expiresAt"],
        "evidenceNotIndependentlyReplayed": True,
    }
