"""Opt-in real SQL erasure fixtures, only in explicitly owned local databases."""

import json
import os
from pathlib import Path
from urllib.parse import urlsplit
from uuid import uuid4

import pytest
from database import connect
from privacy import cleanup, detach, expire, preview, review

URL = os.environ.get("TEST_PRIVACY_DATABASE_URL", "")
RUNTIME = os.environ.get("TEST_PRIVACY_RUNTIME_URL", URL)
pytestmark = pytest.mark.skipif(
    not URL,
    reason="Requires owned local TEST_PRIVACY_DATABASE_URL; never runs on configured user database",
)


def test_real_account_erasure_preserves_other_users_and_audit_and_recovers_provider_failure(
    tmp_path,
):
    parsed = urlsplit(URL)
    assert parsed.hostname in ("localhost", "127.0.0.1") and parsed.path.startswith("/phase25_")
    farmer, other, admin, request_id, scan_id = [uuid4() for _ in range(5)]
    avatar, image = [
        "maizedoctor/" + purpose + "/" + str(uuid4()) for purpose in ("profiles", "scans")
    ]
    policy = tmp_path / "policy.json"
    policy.write_text(
        json.dumps(
            {
                "version": "synthetic-test-v1",
                "approvalReference": "SYNTHETIC ISOLATED FIXTURE ONLY",
                "erasureEnabled": True,
                "retention": {
                    "expiredSessionsDays": None,
                    "operationalEventsDays": None,
                    "farmerScansDays": None,
                    "anonymousScansDays": None,
                    "backupDays": None,
                    "minimumBackupsToKeep": None,
                },
            }
        )
    )
    try:
        with connect(URL) as c:
            for user_id, role in (
                (farmer, "FARMER"),
                (other, "FARMER"),
                (admin, "ADMIN"),
            ):
                c.execute(
                    (
                        "INSERT INTO users(id,email,password_hash,role) VALUES (%s,%s"
                        ",'synthetic-never-login',%s::\"UserRole\")"
                    ),
                    (user_id, "phase25-" + str(user_id) + "@example.invalid", role),
                )
            c.execute(
                (
                    "INSERT INTO farmer_profiles(user_id,display_name,avatar_url,"
                    "avatar_public_id) VALUES (%s,%s,%s,%s)"
                ),
                (farmer, "Synthetic", "https://example.invalid/private", avatar),
            )
            c.execute(
                (
                    "INSERT INTO scans(id,user_id,image_url,cloudinary_public_id,"
                    "image_mime_type,image_bytes,status,error_code,finished_at) V"
                    "ALUES (%s,%s,%s,%s,'image/png',100,'FAILED','INFERENCE_UNAVA"
                    "ILABLE',now())"
                ),
                (scan_id, farmer, "https://example.invalid/private", image),
            )
            c.execute(
                "INSERT INTO privacy_requests(id,user_id) VALUES (%s,%s)",
                (request_id, farmer),
            )
            c.execute(
                (
                    "INSERT INTO audit_logs(actor_id,action,entity_type,entity_id"
                    ",changes) VALUES (%s,'CREATE','privacy_request',%s,'{}')"
                ),
                (farmer, request_id),
            )
        assert preview(RUNTIME, str(request_id), policy)["counts"]["scans"] == 1
        with pytest.raises(ValueError, match="Active Admin"):
            review(RUNTIME, str(request_id), str(other), policy)
        assert review(RUNTIME, str(request_id), str(admin), policy)["status"] == "APPROVED"
        assert review(RUNTIME, str(request_id), str(admin), policy)["idempotent"]
        with pytest.raises(ValueError, match="frozen"):
            detach(RUNTIME, str(request_id), policy)
        # Advance ONLY the owned synthetic fixture to exercise the quiescence fence.
        with connect(URL) as c:
            c.execute(
                "UPDATE privacy_requests SET frozen_at=now()-interval '181 seconds' WHERE id=%s",
                (request_id,),
            )
        assert detach(RUNTIME, str(request_id), policy)["assetCount"] == 2
        assert detach(RUNTIME, str(request_id), policy)["idempotent"]

        def unavailable(_asset):
            raise TimeoutError("synthetic uncertain acknowledgement")

        with pytest.raises(TimeoutError):
            cleanup(RUNTIME, str(request_id), policy, unavailable)
        with connect(URL) as c:
            assert c.execute(
                "SELECT assets FROM privacy_requests WHERE id=%s", (request_id,)
            ).fetchone()[0] == sorted([avatar, image])
            assert c.execute("SELECT 1 FROM users WHERE id=%s", (farmer,)).fetchone() is None
            assert c.execute("SELECT 1 FROM users WHERE id=%s", (other,)).fetchone() == (1,)
            assert c.execute(
                "SELECT actor_id FROM audit_logs WHERE entity_id=%s AND action='CREATE'",
                (request_id,),
            ).fetchone() == (None,)
        removed = []
        assert cleanup(RUNTIME, str(request_id), policy, removed.append)["status"] == "COMPLETED"
        assert sorted(removed) == sorted([avatar, image])
        assert cleanup(RUNTIME, str(request_id), policy, unavailable)["idempotent"]
        changed = json.loads(policy.read_text())
        changed["version"] = "synthetic-test-v2"
        policy.write_text(json.dumps(changed))
        with pytest.raises(ValueError, match="match"):
            detach(RUNTIME, str(request_id), policy)
    finally:
        # Explicit UUIDs created by this test only; no broad user/asset removal.
        with connect(URL) as c:
            c.execute("DELETE FROM privacy_requests WHERE id=%s", (request_id,))
            c.execute("DELETE FROM scans WHERE id=%s", (scan_id,))
            c.execute("DELETE FROM users WHERE id=ANY(%s)", ([farmer, other, admin],))
            c.execute("DELETE FROM audit_logs WHERE entity_id=%s", (request_id,))


def test_real_scan_expiration_dry_run_queues_assets_and_preserves_inflight_scans(
    tmp_path,
):
    parsed = urlsplit(URL)
    assert parsed.hostname in ("localhost", "127.0.0.1") and parsed.path.startswith("/phase25_")
    farmer, own, anonymous, inflight, original_upload, legacy_upload = [uuid4() for _ in range(6)]
    ids = [own, anonymous, inflight]
    example = Path(__file__).resolve().parents[2] / "runtime/privacy-policy.example.json"
    policy = json.loads(example.read_text())
    policy["version"] = "synthetic-scan-expiration-v1"
    policy["approvalReference"] = "SYNTHETIC LOCAL FIXTURES ONLY"
    policy["retention"].update({"farmerScansDays": 1, "anonymousScansDays": 1})
    file = tmp_path / "retention.json"
    file.write_text(json.dumps(policy))
    try:
        with connect(URL) as c:
            c.execute(
                (
                    "INSERT INTO users(id,email,password_hash) VALUES "
                    "(%s,%s,'synthetic-never-login')"
                ),
                (farmer, ("phase25-") + str(farmer) + ("@example.invalid")),
            )
            for scan_id, user_id, asset_id, status in [
                (own, farmer, original_upload, ("FAILED")),
                (anonymous, None, legacy_upload, ("FAILED")),
                (inflight, farmer, uuid4(), ("PROCESSING")),
            ]:
                c.execute(
                    (
                        "INSERT INTO "
                        "scans(id,user_id,image_url,cloudinary_public_id,image_mime_type,image_bytes,status,created_at,finished_at,error_code)"
                        " VALUES "
                        "(%s,%s,'https://example.invalid/private',%s,'image/png',100,%s::\"ScanStatus\",now()-interval"
                        " '10 days',CASE WHEN %s='FAILED' THEN now() ELSE NULL END,CASE "
                        "WHEN %s='FAILED' THEN 'INFERENCE_UNAVAILABLE' ELSE NULL END)"
                    ),
                    (
                        scan_id,
                        user_id,
                        ("maizedoctor/scans/") + str(asset_id),
                        status,
                        status,
                        status,
                    ),
                )
            c.execute(
                (
                    "INSERT INTO "
                    "scan_uploads(id,public_id,request_key_hash,image_hash,state,scan_id)"
                    " VALUES (%s,%s,%s,%s,'COMPLETED',%s)"
                ),
                (
                    original_upload,
                    ("maizedoctor/scans/") + str(original_upload),
                    ("a") * 64,
                    ("b") * 64,
                    own,
                ),
            )
        assert expire(RUNTIME, file)["dryRun"]
        with connect(URL) as c:
            assert c.execute("SELECT count(*) FROM scans WHERE id=ANY(%s)", (ids,)).fetchone() == (
                3,
            )
        result = expire(RUNTIME, file, execute=True)
        assert result["scopes"]["farmerScansDays"]["removed"] == 1
        assert result["scopes"]["anonymousScansDays"]["removed"] == 1
        with connect(URL) as c:
            assert c.execute(("SELECT id FROM scans WHERE id=ANY(%s)"), (ids,)).fetchall() == [
                (inflight,)
            ]
            journals = c.execute(
                ("SELECT id,state,scan_id FROM scan_uploads WHERE id=ANY(%s)"),
                ([original_upload, legacy_upload],),
            ).fetchall()
            assert len(journals) == 2 and all(
                row[1:] == ("CLEANUP_PENDING", None) for row in journals
            )
            assert c.execute(
                ("SELECT status::text FROM users WHERE id=%s"), (farmer,)
            ).fetchone() == (("ACTIVE"),)
        repeat = expire(RUNTIME, file, execute=True)
        assert repeat["scopes"]["farmerScansDays"]["removed"] == 0
        assert repeat["scopes"]["anonymousScansDays"]["removed"] == 0
    finally:
        with connect(URL) as c:
            c.execute(
                ("DELETE FROM scan_uploads WHERE id=ANY(%s)"),
                ([original_upload, legacy_upload],),
            )
            c.execute("DELETE FROM scans WHERE id=ANY(%s)", (ids,))
            c.execute("DELETE FROM users WHERE id=%s", (farmer,))
            c.execute("DELETE FROM audit_logs WHERE entity_id=ANY(%s)", (ids,))
