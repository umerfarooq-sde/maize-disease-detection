"""Phase 23 live verification in a disposable schema, with explicit per-check results.

Copies only existing sourced knowledge and model registry metadata. Uses generated
accounts/images, owned Cloudinary assets and actual configured services. Never
reads a source dataset or trains/promotes/re-evaluates the approved classifier.
"""

import argparse
import json
import os
import re
import secrets
import shutil
import socket
import subprocess
import sys
import threading
import time
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "ai-service"))
os.chdir(ROOT / "ai-service")

import psycopg  # noqa: E402
import uvicorn  # noqa: E402
from dotenv import dotenv_values  # noqa: E402
from psycopg import sql  # noqa: E402
from pydantic import SecretStr  # noqa: E402

# isort: split
# These imports depend on the explicit service path above, regardless of cwd.
from app.config.settings import load_settings  # noqa: E402
from app.main import create_app  # noqa: E402
from app.rag.repository import KnowledgeRepository  # noqa: E402
from app.rag.service import retrieval_identity  # noqa: E402

NODE = [
    "node",
    "--env-file=backend/.env",
    "--import",
    (ROOT / "backend/node_modules/tsx/dist/loader.mjs").as_uri(),
    "--import",
    (ROOT / "scripts/e2e-database-context.mjs").as_uri(),
]
TASKS = {
    "database": (
        NODE
        + [
            "--test",
            "backend/tests/database.integration.test.ts",
            "backend/tests/auth.database.integration.ts",
            "backend/tests/scans.database.integration.ts",
            "backend/tests/scans.inference.integration.ts",
            "backend/tests/scans/history.database.integration.ts",
            "backend/tests/fertilizer.database.integration.ts",
        ],
        ROOT,
        900,
    ),
    "migrations": (NODE + ["backend/tests/migration-replay.ts"], ROOT, 180),
    "rag-database": (
        [
            str(ROOT / "ai-service/.venv/Scripts/python.exe"),
            "-m",
            "pytest",
            "tests/test_rag_database.py",
            "-q",
        ],
        ROOT / "ai-service",
        240,
    ),
    "knowledge": (
        NODE + ["--test", "backend/tests/knowledge.live.integration.ts"],
        ROOT,
        240,
    ),
    "generation": (
        NODE + ["--test", "backend/tests/generation.live.integration.ts"],
        ROOT,
        360,
    ),
    "upload-api": (
        NODE
        + [
            "--test",
            "backend/tests/scans.live.integration.ts",
            "backend/tests/scans.inference.live.integration.ts",
        ],
        ROOT,
        360,
    ),
    "guest-upload": (NODE + ["scripts/check-scan-upload.mjs"], ROOT, 240),
    "guest-inference": (
        NODE + ["scripts/check-scan-upload.mjs", "--inference"],
        ROOT,
        240,
    ),
    "farmer-scan": (
        NODE + ["scripts/check-scan-upload.mjs", "--inference", "--farmer"],
        ROOT,
        240,
    ),
    "assistant": (NODE + ["scripts/check-assistant.mjs"], ROOT, 360),
    "fertilizer": (NODE + ["scripts/check-fertilizer.mjs"], ROOT, 360),
    "yield": (NODE + ["scripts/check-yield.mjs"], ROOT, 360),
    "farmer-analytics": (NODE + ["scripts/check-analytics.mjs"], ROOT, 360),
    "admin-analytics": (NODE + ["scripts/check-analytics.mjs", "--admin"], ROOT, 360),
    "management": (
        [
            str(ROOT / "ai-service/.venv/Scripts/python.exe"),
            "scripts/check-admin-management.py",
        ],
        ROOT,
        960,
    ),
    "model-health": (
        [
            str(ROOT / "ai-service/.venv/Scripts/python.exe"),
            "scripts/check-model-health.py",
        ],
        ROOT,
        300,
    ),
    # Check the baseline catalogue before the Admin journey publishes an extra
    # immutable document version in this same owned schema.
    "farmer-remediation": (NODE + ["scripts/check-farmer-remediation.mjs"], ROOT, 420),
    "original-requirements": (NODE + ["scripts/check-requirements.mjs"], ROOT, 600),
    "journey": (NODE + ["scripts/check-e2e.mjs"], ROOT, 600),
    "predeployment-remediation": (
        NODE + ["scripts/check-predeployment-remediation.mjs"],
        ROOT,
        600,
    ),
}
TABLES = (
    "users",
    "farmer_profiles",
    "diseases",
    "disease_images",
    "disease_sources",
    "scans",
    "scan_predictions",
    "knowledge_documents",
    "knowledge_chunks",
    "fertilizers",
    "fertilizer_rules",
    "calculator_configs",
    "model_versions",
    "model_metrics",
    "ai_queries",
    "ai_responses",
    "audit_logs",
    "notifications",
    "history",
    "auth_sessions",
    "scan_uploads",
    "ai_operations",
    "privacy_requests",
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", nargs="+", choices=list(TASKS))
    args = parser.parse_args()
    settings = load_settings()
    assert settings.inference_enabled and settings.rag_enabled and settings.generation_enabled
    # Session search_path is intentionally used by this schema-isolation harness.
    # Transaction-pooled connections do not retain session settings. Reuse the
    # existing operator-supplied direct database configuration; never guess hosts.
    direct = os.environ.get("DIRECT_DATABASE_URL") or dotenv_values(ROOT / "backend/.env").get(
        "DIRECT_DATABASE_URL"
    )
    if direct:
        assert urlsplit(direct).path == urlsplit(settings.database_url.get_secret_value()).path
        settings = settings.model_copy(update={"database_url": SecretStr(direct)})
    if "-pooler" in (urlsplit(settings.database_url.get_secret_value()).hostname or ""):
        raise RuntimeError("Configure the existing DIRECT_DATABASE_URL for schema-isolated tests")
    repository = KnowledgeRepository(settings, retrieval_identity(settings))
    stamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid4().hex[:8]
    output = ROOT / ".cache/phase23" / stamp
    output.mkdir(parents=True)
    schema = "phase23_" + uuid4().hex
    assert re.fullmatch(r"phase23_[a-f0-9]{32}", schema)
    results = []
    proof = {
        "run": stamp,
        "schema": schema,
        "checks": results,
        "schemaRemoved": False,
        "productionCountsUnchanged": False,
        "modelPromotion": False,
        "rawDatasetAccess": False,
        "realModelTrainingOrFinalTestRerun": False,
    }
    server = thread = listener = application = owned_recorder = None
    created = False

    def save_proof():
        (output / "results.json").write_text(json.dumps(proof, indent=2) + "\n")

    def inventory(connection):
        return {
            table: connection.execute(
                sql.SQL("SELECT count(*) FROM {}.{}").format(
                    sql.Identifier(repository.schema), sql.Identifier(table)
                )
            ).fetchone()[0]
            for table in TABLES
        }

    def copy_table(connection, table, condition=None):
        # Each replayed schema owns distinct PostgreSQL enum types. Cast enum
        # values explicitly rather than copying source-schema enum OIDs.
        columns = connection.execute(
            "SELECT a.attname,t.typname,t.typtype FROM pg_attribute a "
            "JOIN pg_class c ON c.oid=a.attrelid "
            "JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_type t ON t.oid=a.atttypid "
            "WHERE n.nspname=%s AND c.relname=%s AND a.attnum>0 AND NOT a.attisdropped "
            "ORDER BY a.attnum",
            (repository.schema, table),
        ).fetchall()
        expressions = [
            sql.SQL("s.{}::text::{}.{}").format(
                sql.Identifier(column),
                sql.Identifier(schema),
                sql.Identifier(type_name),
            )
            if kind == "e"
            else sql.SQL("s.{}").format(sql.Identifier(column))
            for column, type_name, kind in columns
        ]
        connection.execute(
            sql.SQL("INSERT INTO {}.{} SELECT {} FROM {}.{} s WHERE {}").format(
                sql.Identifier(schema),
                sql.Identifier(table),
                sql.SQL(",").join(expressions),
                sql.Identifier(repository.schema),
                sql.Identifier(table),
                condition if condition is not None else sql.SQL("true"),
            )
        )

    with psycopg.connect(
        repository.connection_url, connect_timeout=10, autocommit=True
    ) as connection:
        before = inventory(connection)
        proof["productionCountsBefore"] = before
        save_proof()
        try:
            with connection.transaction():
                connection.execute(sql.SQL("CREATE SCHEMA {}").format(sql.Identifier(schema)))
                created = True
                connection.execute(
                    "SELECT set_config('search_path',%s,true)", (schema + ",public",)
                )
                for path in sorted((ROOT / "backend/prisma/migrations").glob("*/migration.sql")):
                    migration = re.sub(r"(?m)^BEGIN;\s*$|^COMMIT;\s*$", "", path.read_text())
                    connection.execute(migration, prepare=False)
                # Copy no accounts, scans, private requests, recommendations or audit records.
                for table in (
                    "diseases",
                    "disease_sources",
                    "model_versions",
                    "model_metrics",
                ):
                    copy_table(connection, table)
                copy_table(
                    connection,
                    "knowledge_documents",
                    sql.SQL("s.created_by_id IS NULL"),
                )
                copy_table(
                    connection,
                    "knowledge_chunks",
                    sql.SQL("s.document_id IN (SELECT id FROM {}.knowledge_documents)").format(
                        sql.Identifier(schema)
                    ),
                )
            # A long live suite must not rely on an idle control connection
            # remaining open while external providers and Flutter run.
            connection.close()
            parsed = urlsplit(settings.database_url.get_secret_value())
            query = dict(parse_qsl(parsed.query))
            query["schema"] = schema
            isolated_url = urlunsplit(parsed._replace(query=urlencode(query)))
            token = secrets.token_urlsafe(48)
            isolated = settings.model_copy(
                update={
                    "database_url": SecretStr(isolated_url),
                    "environment": "test",
                    "ai_service_token": SecretStr(token),
                }
            )
            listener = socket.socket()
            listener.bind(("127.0.0.1", 0))
            listener.listen()
            application = create_app(isolated)
            server = uvicorn.Server(
                uvicorn.Config(
                    application,
                    log_config=None,
                    log_level="error",
                    access_log=False,
                )
            )
            thread = threading.Thread(target=lambda: server.run(sockets=[listener]), daemon=True)
            thread.start()
            deadline = time.monotonic() + 60
            while not server.started and thread.is_alive() and time.monotonic() < deadline:
                time.sleep(0.1)
            if not server.started:
                raise RuntimeError("Private complete AI service did not start")
            owned_recorder = getattr(application.state, "operational_recorder", None)
            flutter = shutil.which("flutter")
            if flutter is None:
                raise RuntimeError("Flutter is required")
            cache = Path(flutter).resolve().parent / "cache"
            environment = {
                **os.environ,
                "DATABASE_URL": isolated_url,
                "DIRECT_DATABASE_URL": isolated_url,
                "AI_SERVICE_URL": f"http://127.0.0.1:{listener.getsockname()[1]}",
                "AI_SERVICE_TOKEN": token,
                "AI_MODEL_VERSION": settings.model_version,
                "AI_PREPROCESSING_VERSION": settings.preprocessing_version,
                "PHASE23_SCHEMA": schema,
                "PHASE23_OUTPUT": str(output),
                "PHASE23_DART": str(
                    cache / "dart-sdk/bin" / ("dart.exe" if os.name == "nt" else "dart")
                ),
                "PHASE23_FLUTTER_TOOLS": str(cache / "flutter_tools.snapshot"),
                "RUN_RAG_DATABASE_TESTS": "1",
                "RUN_LIVE_KNOWLEDGE": "1",
                "RUN_LIVE_GENERATION": "1",
                "RUN_LIVE_SCAN_UPLOAD": "true",
                "RUN_LIVE_SCAN_INFERENCE": "true",
            }
            selected = {
                "schema-preflight": (
                    NODE + ["scripts/check-e2e.mjs", "--preflight"],
                    ROOT,
                    60,
                ),
                **{name: TASKS[name] for name in args.only or TASKS},
            }
            for name, (command, cwd, timeout) in selected.items():
                started = time.monotonic()
                with (output / (name + ".log")).open("w", encoding="utf-8") as log:
                    try:
                        process = subprocess.Popen(
                            command,
                            cwd=cwd,
                            env=environment,
                            stdout=log,
                            stderr=subprocess.STDOUT,
                        )
                        try:
                            process.wait(timeout=timeout)
                        except subprocess.TimeoutExpired:
                            # Terminate only this owned command tree, including
                            # Flutter children, before examining cleanup evidence.
                            if os.name == "nt":
                                subprocess.run(
                                    ["taskkill", "/PID", str(process.pid), "/T", "/F"],
                                    stdout=subprocess.DEVNULL,
                                    stderr=subprocess.DEVNULL,
                                    check=False,
                                )
                            else:
                                process.kill()
                            process.wait(timeout=15)
                            raise
                        result = {
                            "check": name,
                            "status": "PASS" if process.returncode == 0 else "FAIL",
                            "exitCode": process.returncode,
                        }
                    except subprocess.TimeoutExpired:
                        result = {"check": name, "status": "TIMEOUT"}
                result["seconds"] = round(time.monotonic() - started, 2)
                captured = (output / (name + ".log")).read_text(encoding="utf-8", errors="replace")
                skipped = sum(int(count) for count in re.findall(r"\bskipped\s+(\d+)", captured))
                skipped += sum(int(count) for count in re.findall(r"\b(\d+) skipped\b", captured))
                result["skipped"] = skipped
                if result["status"] == "PASS" and (skipped or "All tests skipped" in captured):
                    result["status"] = "PARTIAL_SKIPPED"
                results.append(result)
                save_proof()
                print(f"{result['status']}: {name} ({result['seconds']} s)", flush=True)
                if name == "schema-preflight" and result["status"] != "PASS":
                    break
        except Exception as error:
            proof["setupOrCleanupErrorType"] = type(error).__name__
            print("FAIL: live harness setup/cleanup; private details omitted.", flush=True)
        finally:
            # Capture before lifespan clears the reference. A best-effort service
            # close is not proof that a writer can no longer touch this fixture.
            recorder = (
                owned_recorder
                if owned_recorder is not None
                else getattr(application.state, "operational_recorder", None)
                if application is not None
                else None
            )
            if server is not None:
                server.should_exit = True
            if thread is not None:
                thread.join(timeout=10)
            proof["aiServerStopped"] = thread is None or not thread.is_alive()
            proof["aiTelemetryStopped"] = recorder is None or recorder.wait_stopped(30)
            if recorder is not None:
                proof["aiTelemetryDropped"] = recorder.dropped
                proof["aiTelemetryPending"] = recorder.events.unfinished_tasks
            resources_stopped = proof["aiServerStopped"] and proof["aiTelemetryStopped"]
            if not resources_stopped:
                print("FAIL: owned AI resources still active; fixture schema retained.", flush=True)
            if listener is not None:
                listener.close()
            cloud_clean = True
            journey = output / "journey-proof.json"
            requirements = output / "requirements-proof.json"
            if any(row["check"] == "predeployment-remediation" for row in results):
                try:
                    media_proof = json.loads((output / "phase246-proof.json").read_text())
                    cloud_clean = bool(media_proof.get("cloudCleanupComplete", False))
                except (OSError, ValueError):
                    cloud_clean = False
                    proof["remediationCleanupProofInvalid"] = True
            if any(row["check"] == "original-requirements" for row in results):
                if not requirements.exists():
                    cloud_clean = False
                else:
                    try:
                        cloud_clean = cloud_clean and bool(
                            json.loads(requirements.read_text()).get("cloudCleanupComplete", False)
                        )
                    except (OSError, ValueError):
                        cloud_clean = False
                        proof["requirementsCleanupProofInvalid"] = True
            if any(row["check"] == "journey" for row in results) and not journey.exists():
                cloud_clean = False
            if any(row["status"] == "TIMEOUT" for row in results):
                cloud_clean = False
            asset_checks = {
                "upload-api",
                "guest-upload",
                "guest-inference",
                "farmer-scan",
                "journey",
                "original-requirements",
            }
            if any(row["check"] in asset_checks and row["status"] != "PASS" for row in results):
                cloud_clean = False
            if journey.exists():
                try:
                    cloud_clean = cloud_clean and json.loads(journey.read_text()).get(
                        "cloudCleanupComplete", False
                    )
                except (OSError, ValueError):
                    cloud_clean = False
                    proof["journeyCleanupProofInvalid"] = True
            proof["cloudCleanupComplete"] = cloud_clean
            try:
                with psycopg.connect(
                    repository.connection_url, connect_timeout=10, autocommit=True
                ) as cleanup_connection:
                    if created and cloud_clean and resources_stopped:
                        assert re.fullmatch(r"phase23_[a-f0-9]{32}", schema)
                        cleanup_connection.execute(
                            sql.SQL("DROP SCHEMA IF EXISTS {} CASCADE").format(
                                sql.Identifier(schema)
                            )
                        )
                        proof["schemaRemoved"] = True
                    proof["productionCountsUnchanged"] = inventory(cleanup_connection) == before
            except Exception as error:
                proof["cleanupErrorType"] = type(error).__name__
                print(
                    "FAIL: cleanup verification; owned schema retained if present.",
                    flush=True,
                )
            proof["passed"] = (
                bool(results)
                and all(r["status"] == "PASS" for r in results)
                and proof["schemaRemoved"]
                and proof["productionCountsUnchanged"]
                and resources_stopped
                and "setupOrCleanupErrorType" not in proof
                and "cleanupErrorType" not in proof
            )
            save_proof()
            print(f"Report: .cache/phase23/{stamp}/results.json", flush=True)
    return 0 if proof["passed"] else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        print(
            "Phase 23 verification could not run; private configuration is not printed.",
            file=sys.stderr,
        )
        raise SystemExit(1) from None
