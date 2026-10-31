"""Isolated tests: no database, network, model execution or live secrets."""

import hashlib
import hmac
import json
import os
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
from production_gate import REQUIRED_REVIEWS, _canonical, validate_production_gate


def fixture(tmp_path):
    root = tmp_path / "source"
    (root / "ai-service").mkdir(parents=True)
    (root / "ai-service/pyproject.toml").write_text('[project]\ndependencies = ["torch==2.10.0"]\n')
    models = tmp_path / "artifacts"
    models.mkdir()
    policy = tmp_path / "private-policy.json"
    model = {
        "production_model_promoted": True,
        "research_policy": {"commercial_clearance": True, "permitted_use": "licensed public use"},
    }
    (models / "model-artifact.json").write_text(json.dumps(model))
    policy_value = {
        "version": "approved-v1", "approvalReference": "PRIVACY-2026-REVIEW-123",
        "erasureEnabled": True,
        "retention": {key: value for key, value in [
            ("expiredSessionsDays", 30), ("operationalEventsDays", 90),
            ("farmerScansDays", 180), ("anonymousScansDays", 30),
            ("backupDays", 90), ("minimumBackupsToKeep", 2),
        ]},
    }
    policy.write_text(json.dumps(policy_value))
    values = {"PRIVACY_POLICY_FILE": str(policy), "MODEL_DIRECTORY": str(models),
              "PUBLIC_HTTPS_ORIGIN": "https://api.example.com"}
    release = {"commit": "a" * 40, "images": {"AI_IMAGE": "b" * 64},
               "expandOnlyCompatible": True}
    now = datetime(2026, 10, 31, tzinfo=UTC)
    payload = {
        "version": 1, "status": "APPROVED", "environment": "production",
        "issuedAt": (now - timedelta(hours=1)).isoformat(),
        "expiresAt": (now + timedelta(days=7)).isoformat(),
        "releaseSha256": hashlib.sha256(_canonical(release)).hexdigest(),
        "modelMetadataSha256": hashlib.sha256((models / "model-artifact.json").read_bytes()).hexdigest(),
        "privacyPolicySha256": hashlib.sha256(_canonical(policy_value)).hexdigest(),
        "publicOrigin": values["PUBLIC_HTTPS_ORIGIN"], "torchVersion": "2.10.0",
        "reviewedAdvisories": ["PYSEC-2025-194", "PYSEC-2026-139"],
        "controls": {key: {"status": "PASS", "evidence": "https://review.example.org/2026/" + key}
                     for key in REQUIRED_REVIEWS},
    }
    key = tmp_path / "private-hmac-key"
    key.write_bytes(os.urandom(32))
    key.chmod(0o600)
    approval = tmp_path / "private-approval.json"

    def sign():
        signed = {"payload": payload, "signature": hmac.new(key.read_bytes(), _canonical(payload), hashlib.sha256).hexdigest()}
        approval.write_text(json.dumps(signed))
        return approval

    return root, values, release, model, policy_value, payload, key, sign, now


def test_signed_binding_requires_scope_and_complete_evidence(tmp_path):
    root, values, release, model, policy, payload, key, sign, now = fixture(tmp_path)
    assert validate_production_gate(root, values, release, sign(), key, now=now)["signedProductionGate"]
    payload["controls"]["modelRights"]["evidence"] = "todo"
    with pytest.raises(ValueError, match="evidence"):
        validate_production_gate(root, values, release, sign(), key, now=now)
    payload["controls"]["modelRights"]["evidence"] = "https://review.example.org/model-rights"
    payload["reviewedAdvisories"] = ["PYSEC-2025-194"]
    with pytest.raises(ValueError, match="advisories"):
        validate_production_gate(root, values, release, sign(), key, now=now)


def test_research_model_cannot_be_overridden_by_signed_review(tmp_path):
    root, values, release, model, policy, payload, key, sign, now = fixture(tmp_path)
    model["research_policy"]["commercial_clearance"] = False
    model["research_policy"]["permitted_use"] = "non-commercial research only"
    model["production_model_promoted"] = False
    (Path(values["MODEL_DIRECTORY"]) / "model-artifact.json").write_text(json.dumps(model))
    payload["modelMetadataSha256"] = hashlib.sha256(
        (Path(values["MODEL_DIRECTORY"]) / "model-artifact.json").read_bytes()
    ).hexdigest()
    with pytest.raises(ValueError, match="restricted to research"):
        validate_production_gate(root, values, release, sign(), key, now=now)


def test_rejects_expired_tampered_and_mismatched_scopes(tmp_path):
    root, values, release, model, policy, payload, key, sign, now = fixture(tmp_path)
    payload["expiresAt"] = (now - timedelta(seconds=1)).isoformat()
    with pytest.raises(ValueError, match="expired"):
        validate_production_gate(root, values, release, sign(), key, now=now)
    payload["expiresAt"] = (now + timedelta(days=1)).isoformat()
    sign()
    signed = json.loads((tmp_path / "private-approval.json").read_text())
    signed["payload"]["status"] = "APPROVED2"
    (tmp_path / "private-approval.json").write_text(json.dumps(signed))
    with pytest.raises(ValueError, match="signature"):
        validate_production_gate(root, values, release, tmp_path / "private-approval.json", key, now=now)
    payload["releaseSha256"] = "c" * 64
    with pytest.raises(ValueError, match="release identity"):
        validate_production_gate(root, values, release, sign(), key, now=now)


def test_default_privacy_policy_and_missing_approval_fail_closed(tmp_path):
    root, values, release, model, policy, payload, key, sign, now = fixture(tmp_path)
    with pytest.raises(ValueError, match="signed operator"):
        validate_production_gate(root, values, release, None, None, now=now)
    policy["erasureEnabled"] = False
    Path(values["PRIVACY_POLICY_FILE"]).write_text(json.dumps(policy))
    with pytest.raises(ValueError, match="privacy/retention"):
        validate_production_gate(root, values, release, sign(), key, now=now)


def test_key_protection_and_policy_binding(tmp_path):
    root, values, release, model, policy, payload, key, sign, now = fixture(tmp_path)
    if os.name != "nt":
        key.chmod(0o644)
        with pytest.raises(ValueError, match="permissions"):
            validate_production_gate(root, values, release, sign(), key, now=now)
        key.chmod(0o600)
    policy["retention"]["farmerScansDays"] = 31
    Path(values["PRIVACY_POLICY_FILE"]).write_text(json.dumps(policy))
    with pytest.raises(ValueError, match="privacy policy differs"):
        validate_production_gate(root, values, release, sign(), key, now=now)


def test_model_and_torch_digest_binding(tmp_path):
    root, values, release, model, policy, payload, key, sign, now = fixture(tmp_path)
    (root / "ai-service/pyproject.toml").write_text('[project]\ndependencies = ["torch==2.11.0"]\n')
    with pytest.raises(ValueError, match="Torch review"):
        validate_production_gate(root, values, release, sign(), key, now=now)
    (root / "ai-service/pyproject.toml").write_text('[project]\ndependencies = ["torch==2.10.0"]\n')
    model["research_policy"]["permitted_use"] = "different cleared license"
    (Path(values["MODEL_DIRECTORY"]) / "model-artifact.json").write_text(json.dumps(model))
    with pytest.raises(ValueError, match="model artifact provenance"):
        validate_production_gate(root, values, release, sign(), key, now=now)
