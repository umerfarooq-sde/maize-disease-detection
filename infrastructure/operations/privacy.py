"""Explicitly approved, audit-preserving account erasure and retention tools.

Default policy is disabled. Run with a dedicated operator identity, never the
public Node/AI identity. Cloud assets are deleted only after atomic detachment.
"""

import hashlib
import json
import re
import time
import urllib.parse
import urllib.request
from datetime import UTC, datetime, timedelta
from pathlib import Path
from uuid import UUID, uuid4

from database import connect
from psycopg import sql
from psycopg.types.json import Jsonb

ASSET = re.compile(
    r"^maizedoctor/(scans|profiles)/[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$"
)
RETENTION = frozenset(
    {
        "expiredSessionsDays",
        "operationalEventsDays",
        "farmerScansDays",
        "anonymousScansDays",
        "backupDays",
        "minimumBackupsToKeep",
    }
)


def read_policy(path: Path, *, enabled=False) -> tuple[dict, str]:
    raw = path.read_bytes()
    if len(raw) > 8192:
        raise ValueError("Privacy policy exceeds limit")
    policy = json.loads(raw)
    if not isinstance(policy, dict) or set(policy) != {
        "version",
        "approvalReference",
        "erasureEnabled",
        "retention",
    }:
        raise ValueError("Invalid policy contract")
    if not isinstance(policy["version"], str) or not re.fullmatch(
        r"[A-Za-z0-9._-]{1,80}", policy["version"]
    ):
        raise ValueError("Invalid policy version")
    if type(policy["erasureEnabled"]) is not bool or not isinstance(
        policy["approvalReference"], str
    ):
        raise ValueError("Invalid policy approval")
    retention = policy["retention"]
    if not isinstance(retention, dict) or set(retention) != RETENTION:
        raise ValueError("Invalid retention scopes")
    for value in retention.values():
        if value is not None and (type(value) is not int or not 1 <= value <= 36500):
            raise ValueError("Retention must be explicitly approved whole days or null")
    if retention["minimumBackupsToKeep"] is not None and retention["minimumBackupsToKeep"] > 100:
        raise ValueError("Reference backup retention supports at most 100 protected archives")
    if (retention["backupDays"] is None) != (retention["minimumBackupsToKeep"] is None):
        raise ValueError("Backup age and minimum retained count must be approved together")
    if (
        policy["erasureEnabled"] or any(value is not None for value in retention.values())
    ) and not policy["approvalReference"].strip():
        raise ValueError("Human policy approval reference is required")
    if enabled and not policy["erasureEnabled"]:
        raise ValueError("Account erasure remains disabled by policy")
    canonical = json.dumps(policy, sort_keys=True, separators=(",", ":")).encode()
    return policy, hashlib.sha256(canonical).hexdigest()


def identifier(value: str) -> str:
    return str(UUID(value))


def review(url: str, request_id: str, reviewer_id: str, path: Path) -> dict:
    _, fingerprint = read_policy(path, enabled=True)
    with connect(url) as connection:
        actor = connection.execute(
            "SELECT id FROM users WHERE id=%s AND role='ADMIN' AND status='ACTIVE' FOR SHARE",
            (identifier(reviewer_id),),
        ).fetchone()
        row = connection.execute(
            "SELECT user_id,status,policy_hash FROM privacy_requests WHERE id=%s FOR UPDATE",
            (identifier(request_id),),
        ).fetchone()
        if not actor or not row or not row[0]:
            raise ValueError("Active Admin and existing account request required")
        if row[1] == "APPROVED" and row[2] == fingerprint:
            return {"status": "APPROVED", "idempotent": True}
        if row[1] != "REQUESTED":
            raise ValueError("Request version conflict")
        target = connection.execute(
            "SELECT id FROM users WHERE id=%s AND role='FARMER' FOR UPDATE", (row[0],)
        ).fetchone()
        if not target:
            raise ValueError("Only Farmer account erasure is supported")
        connection.execute("UPDATE users SET status='SUSPENDED' WHERE id=%s", (row[0],))
        connection.execute(
            "UPDATE auth_sessions SET revoked_at=COALESCE(revoked_at,now()) WHERE user_id=%s",
            (row[0],),
        )
        connection.execute(
            (
                "UPDATE privacy_requests SET status='APPROVED',reviewer_id=%s"
                ",policy_hash=%s,frozen_at=now() WHERE id=%s"
            ),
            (reviewer_id, fingerprint, request_id),
        )
        connection.execute(
            (
                "INSERT INTO audit_logs(actor_id,action,entity_type,entity_id"
                ",changes) VALUES (%s,'UPDATE','privacy_request',%s,%s)"
            ),
            (
                reviewer_id,
                request_id,
                Jsonb({"status": "APPROVED", "policyHash": fingerprint}),
            ),
        )
    return {"status": "APPROVED", "policyHash": fingerprint, "erased": False}


def preview(url: str, request_id: str, path: Path) -> dict:
    policy, fingerprint = read_policy(path)
    with connect(url) as connection:
        connection.execute("SET TRANSACTION READ ONLY")
        row = connection.execute(
            "SELECT user_id,status,frozen_at,policy_hash FROM privacy_requests WHERE id=%s",
            (identifier(request_id),),
        ).fetchone()
        if not row:
            raise ValueError("Request not found")
        counts = {}
        for table in (
            "scans",
            "ai_queries",
            "history",
            "notifications",
            "auth_sessions",
        ):
            counts[table] = connection.execute(
                sql.SQL("SELECT count(*) FROM {} WHERE user_id=%s").format(sql.Identifier(table)),
                (row[0],),
            ).fetchone()[0]
    return {
        "status": row[1],
        "counts": counts,
        "policyHash": fingerprint,
        "approvedPolicyMatches": row[3] == fingerprint,
        "erasureEnabled": policy["erasureEnabled"],
        "dryRun": True,
    }


def detach(url: str, request_id: str, path: Path) -> dict:
    _, fingerprint = read_policy(path, enabled=True)
    with connect(url) as connection:
        connection.execute("SET LOCAL statement_timeout='10000'")
        connection.execute("SET LOCAL lock_timeout='2000'")
        row = connection.execute(
            (
                "SELECT user_id,status,policy_hash,frozen_at FROM privacy_req"
                "uests WHERE id=%s FOR UPDATE"
            ),
            (identifier(request_id),),
        ).fetchone()
        if not row or row[2] != fingerprint:
            raise ValueError("Approved policy/request does not match")
        if row[1] in ("ASSET_CLEANUP", "COMPLETED"):
            return {"status": row[1], "idempotent": True}
        if (
            row[1] != "APPROVED"
            or not row[0]
            or row[3] > datetime.now(UTC) - timedelta(seconds=180)
        ):
            raise ValueError(
                "Account must remain frozen beyond the maximum in-flight admission lease"
            )
        user = row[0]
        target = connection.execute(
            "SELECT id FROM users WHERE id=%s AND role='FARMER' AND status='SUSPENDED' FOR UPDATE",
            (user,),
        ).fetchone()
        if not target:
            raise ValueError("Account was reactivated or changed; repeat review required")
        scans = connection.execute(
            "SELECT id,status,cloudinary_public_id FROM scans WHERE user_id=%s FOR UPDATE",
            (user,),
        ).fetchall()
        if any(item[1] in ("PENDING", "PROCESSING") for item in scans):
            raise ValueError("Inference must finish or stale recovery must resolve it first")
        profile = connection.execute(
            (
                "SELECT avatar_public_id,avatar_pending_public_id,avatar_clea"
                "nup_public_ids FROM farmer_profiles WHERE user_id=%s FOR UPD"
                "ATE"
            ),
            (user,),
        ).fetchone()
        if profile and profile[1]:
            raise ValueError("Uncertain profile upload must be recovered first")
        ids = [item[0] for item in scans]
        unresolved = (
            connection.execute(
                (
                    "SELECT 1 FROM scan_uploads WHERE scan_id=ANY(%s) AND state N"
                    "OT IN ('COMPLETED','FAILED') LIMIT 1"
                ),
                (ids,),
            ).fetchone()
            if ids
            else None
        )
        if unresolved:
            raise ValueError("Uncertain scan upload must be recovered first")
        assets = {item[2] for item in scans}
        if profile:
            assets.update([profile[0]] if profile[0] else [])
            assets.update(profile[2])
        if any(not ASSET.fullmatch(value) for value in assets) or len(assets) > 10000:
            raise ValueError("Asset ownership manifest is invalid or exceeds bounded batch")
        for asset in assets:
            if connection.execute(
                (
                    "SELECT 1 FROM scans WHERE cloudinary_public_id=%s AND user_i"
                    "d IS DISTINCT FROM %s UNION ALL SELECT 1 FROM farmer_profile"
                    "s WHERE (avatar_public_id=%s OR avatar_pending_public_id=%s)"
                    " AND user_id<>%s LIMIT 1"
                ),
                (asset, user, asset, asset, user),
            ).fetchone():
                raise ValueError("Asset ownership conflict; nothing erased")
        # Store the exact manifest in the SAME transaction as association removal.
        connection.execute(
            "UPDATE privacy_requests SET assets=%s,status='ASSET_CLEANUP' WHERE id=%s",
            (Jsonb(sorted(assets)), request_id),
        )
        connection.execute("DELETE FROM history WHERE user_id=%s", (user,))
        connection.execute("DELETE FROM notifications WHERE user_id=%s", (user,))
        connection.execute(
            (
                "DELETE FROM ai_responses WHERE query_id IN (SELECT id FROM a"
                "i_queries WHERE user_id=%s)"
            ),
            (user,),
        )
        connection.execute("DELETE FROM ai_queries WHERE user_id=%s", (user,))
        if ids:
            connection.execute("DELETE FROM scan_uploads WHERE scan_id=ANY(%s)", (ids,))
            connection.execute("DELETE FROM scan_predictions WHERE scan_id=ANY(%s)", (ids,))
        connection.execute("DELETE FROM scans WHERE user_id=%s", (user,))
        connection.execute("DELETE FROM users WHERE id=%s", (user,))
        connection.execute(
            (
                "INSERT INTO audit_logs(action,entity_type,entity_id,changes)"
                " VALUES ('DELETE','privacy_request',%s,%s)"
            ),
            (
                request_id,
                Jsonb(
                    {
                        "status": "ASSET_CLEANUP",
                        "policyHash": fingerprint,
                        "assetCount": len(assets),
                        "retainedAudit": True,
                    }
                ),
            ),
        )
    return {"status": "ASSET_CLEANUP", "assetCount": len(assets)}


def destroy_asset(public_id: str, provider: dict) -> None:
    if not ASSET.fullmatch(public_id) or not re.fullmatch(
        r"[A-Za-z0-9_-]{1,100}", provider.get("cloudName", "")
    ):
        raise ValueError("Invalid provider asset scope")
    values = {
        "public_id": public_id,
        "timestamp": str(int(time.time())),
        "type": "authenticated",
    }
    signing = "&".join(f"{key}={values[key]}" for key in sorted(values)) + provider["apiSecret"]
    values.update(
        {
            "signature": hashlib.sha256(signing.encode()).hexdigest(),
            "api_key": provider["apiKey"],
        }
    )
    request = urllib.request.Request(
        "https://api.cloudinary.com/v1_1/" + provider["cloudName"] + "/image/destroy",
        data=urllib.parse.urlencode(values).encode(),
        method="POST",
    )
    # Default verified TLS; no arbitrary URL fetch and no retries with new identity.
    with urllib.request.urlopen(request, timeout=15) as response:
        result = json.loads(response.read(8193))
    if result.get("result") not in ("ok", "not found"):
        raise ValueError("Provider deletion was not acknowledged")


def cleanup(url: str, request_id: str, path: Path, destroy) -> dict:
    _, fingerprint = read_policy(path, enabled=True)
    # Serialize deletion with the request row. This operator path is bounded to
    # ten assets per invocation; uncertain acknowledgements leave the same ID.
    with connect(url) as connection:
        connection.execute("SET LOCAL lock_timeout='2000'")
        row = connection.execute(
            "SELECT status,policy_hash,assets FROM privacy_requests WHERE id=%s FOR UPDATE",
            (identifier(request_id),),
        ).fetchone()
        if not row or row[1] != fingerprint:
            raise ValueError("Approved policy/request does not match")
        if row[0] == "COMPLETED":
            return {"status": "COMPLETED", "idempotent": True}
        if row[0] != "ASSET_CLEANUP" or not isinstance(row[2], list):
            raise ValueError("Account has not been detached")
        pending = list(row[2])
        for asset in pending[:10]:
            if not ASSET.fullmatch(asset):
                raise ValueError("Invalid asset journal")
            current = connection.execute(
                (
                    "SELECT 1 FROM scans WHERE cloudinary_public_id=%s UNION ALL "
                    "SELECT 1 FROM farmer_profiles WHERE avatar_public_id=%s OR a"
                    "vatar_pending_public_id=%s LIMIT 1"
                ),
                (asset, asset, asset),
            ).fetchone()
            if current:
                raise ValueError("Current asset cannot be removed")
            destroy(asset)
            pending.remove(asset)
        connection.execute(
            (
                "UPDATE privacy_requests SET assets=%s,status=%s,completed_at"
                "=CASE WHEN %s THEN now() ELSE NULL END WHERE id=%s"
            ),
            (
                Jsonb(pending),
                "ASSET_CLEANUP" if pending else "COMPLETED",
                not pending,
                request_id,
            ),
        )
    return {
        "status": "ASSET_CLEANUP" if pending else "COMPLETED",
        "remainingAssets": len(pending),
    }


def expire(url: str, path: Path, *, execute=False) -> dict:
    policy, fingerprint = read_policy(path)
    results = {}
    with connect(url) as connection:
        if not execute:
            connection.execute("SET TRANSACTION READ ONLY")
        for key, table, column in [
            ("expiredSessionsDays", "auth_sessions", "expires_at"),
            ("operationalEventsDays", "ai_operations", "occurred_at"),
        ]:
            days = policy["retention"][key]
            if days is None:
                results[key] = {"status": "DISABLED"}
                continue
            cutoff = datetime.now(UTC) - timedelta(days=days)
            count = connection.execute(
                sql.SQL("SELECT count(*) FROM {} WHERE {}<%s").format(
                    sql.Identifier(table), sql.Identifier(column)
                ),
                (cutoff,),
            ).fetchone()[0]
            if execute:
                # Bounded batch and SKIP LOCKED make independent invocations safe.
                removed = connection.execute(
                    sql.SQL(
                        "DELETE FROM {} WHERE id IN (SELECT id FROM {} WHERE {}<%s OR"
                        "DER BY {} LIMIT 1000 FOR UPDATE SKIP LOCKED)"
                    ).format(
                        sql.Identifier(table),
                        sql.Identifier(table),
                        sql.Identifier(column),
                        sql.Identifier(column),
                    ),
                    (cutoff,),
                ).rowcount
                results[key] = {"eligible": count, "removed": removed}
                if removed:
                    connection.execute(
                        "INSERT INTO audit_logs(action,entity_type,entity_id,changes) "
                        "VALUES ('DELETE','privacy_retention_run',%s,%s)",
                        (
                            uuid4(),
                            Jsonb(
                                {
                                    "policyHash": fingerprint,
                                    "scope": key,
                                    "removed": removed,
                                }
                            ),
                        ),
                    )
            else:
                results[key] = {"eligible": count}
    results.update(expire_scans(url, policy, fingerprint, execute=execute))
    return {"policyHash": fingerprint, "dryRun": not execute, "scopes": results}


def expire_scans(url: str, policy: dict, fingerprint: str, *, execute=False) -> dict:
    results = {}
    for scope, anonymous in (("farmerScansDays", False), ("anonymousScansDays", True)):
        days = policy["retention"][scope]
        if days is None:
            results[scope] = {"status": "DISABLED"}
            continue
        cutoff = datetime.now(UTC) - timedelta(days=days)
        with connect(url) as connection:
            if not execute:
                connection.execute("SET TRANSACTION READ ONLY")
            connection.execute("SET LOCAL statement_timeout='10000'")
            connection.execute("SET LOCAL lock_timeout='2000'")
            clause = "user_id IS NULL" if anonymous else "user_id IS NOT NULL"
            # The interpolated fragment is chosen above, never from input text.
            condition = sql.SQL(
                "status IN ('COMPLETED','FAILED') AND created_at<%s AND "
            ) + sql.SQL(clause)
            count = connection.execute(
                sql.SQL("SELECT count(*) FROM scans WHERE ") + condition, (cutoff,)
            ).fetchone()[0]
            removed = 0
            if execute:
                rows = connection.execute(
                    sql.SQL("SELECT id,cloudinary_public_id FROM scans WHERE ")
                    + condition
                    + sql.SQL(" ORDER BY created_at LIMIT 20 FOR UPDATE SKIP LOCKED"),
                    (cutoff,),
                ).fetchall()
                for scan_id, asset in rows:
                    if not ASSET.fullmatch(asset) or not asset.startswith("maizedoctor/scans/"):
                        raise ValueError("Invalid scan asset; retention leaves it untouched")
                    existing = connection.execute(
                        "SELECT id,state,scan_id FROM scan_uploads WHERE public_id=%s FOR UPDATE",
                        (asset,),
                    ).fetchone()
                    if existing and (existing[1] != "COMPLETED" or existing[2] != scan_id):
                        raise ValueError("Uncertain upload association; retain record")
                    if existing:
                        connection.execute(
                            (
                                "UPDATE scan_uploads SET scan_id=NULL,state='CLEANUP_PENDING' "
                                "WHERE id=%s"
                            ),
                            (existing[0],),
                        )
                    else:
                        # Existing cleanup owns eventual provider deletion. Preserve
                        # its required asset/UUID identity even for legacy scans.
                        digest = hashlib.sha256(("retention:" + str(scan_id)).encode()).hexdigest()
                        connection.execute(
                            (
                                "INSERT INTO "
                                "scan_uploads(id,public_id,request_key_hash,image_hash,state) "
                                "VALUES (%s,%s,%s,%s,'CLEANUP_PENDING')"
                            ),
                            (UUID(asset.rsplit("/", 1)[1]), asset, digest, digest),
                        )
                    connection.execute(
                        (
                            "DELETE FROM history WHERE scan_id=%s OR ai_query_id IN (SELECT id"
                            " FROM ai_queries WHERE scan_id=%s)"
                        ),
                        (scan_id, scan_id),
                    )
                    connection.execute("DELETE FROM notifications WHERE scan_id=%s", (scan_id,))
                    connection.execute(
                        (
                            "DELETE FROM ai_responses WHERE query_id IN (SELECT id FROM "
                            "ai_queries WHERE scan_id=%s)"
                        ),
                        (scan_id,),
                    )
                    connection.execute("DELETE FROM ai_queries WHERE scan_id=%s", (scan_id,))
                    connection.execute("DELETE FROM scan_predictions WHERE scan_id=%s", (scan_id,))
                    connection.execute("DELETE FROM scans WHERE id=%s", (scan_id,))
                    connection.execute(
                        (
                            "INSERT INTO audit_logs(action,entity_type,entity_id,changes) "
                            "VALUES ('DELETE','privacy_scan_retention',%s,%s)"
                        ),
                        (
                            scan_id,
                            Jsonb({"policyHash": fingerprint, "assetCleanup": "QUEUED"}),
                        ),
                    )
                    removed += 1
            results[scope] = {
                "eligible": count,
                **({"removed": removed, "assetCleanup": "DURABLE_QUEUE"} if execute else {}),
            }
    return results
