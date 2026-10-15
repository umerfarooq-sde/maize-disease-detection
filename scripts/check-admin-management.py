"""Live Phase 21 contract in a generated disposable schema; never edits production content."""

import json
import os
import re
import secrets
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "ai-service"))
os.chdir(ROOT / "ai-service")

import psycopg  # noqa: E402
import uvicorn  # noqa: E402
from psycopg import sql  # noqa: E402
from pydantic import SecretStr  # noqa: E402

from app.config.settings import load_settings  # noqa: E402
from app.main import create_app  # noqa: E402
from app.rag.repository import KnowledgeRepository  # noqa: E402
from app.rag.service import retrieval_identity  # noqa: E402


def main() -> None:
    settings = load_settings()
    root_repository = KnowledgeRepository(settings, retrieval_identity(settings))
    schema = "phase21_" + uuid4().hex
    assert re.fullmatch(r"phase21_[a-f0-9]{32}", schema)
    tables = [
        "users",
        "diseases",
        "disease_sources",
        "knowledge_documents",
        "knowledge_chunks",
        "fertilizers",
        "fertilizer_rules",
        "calculator_configs",
        "audit_logs",
        "model_versions",
    ]

    def inventory(connection):
        return [
            connection.execute(
                sql.SQL("SELECT count(*) FROM {}.{}").format(
                    sql.Identifier(root_repository.schema), sql.Identifier(table)
                )
            ).fetchone()[0]
            for table in tables
        ]

    created = False
    server = None
    thread = None
    listener = None
    with psycopg.connect(root_repository.connection_url, autocommit=True) as connection:
        before = inventory(connection)
        try:
            with connection.transaction():
                connection.execute(sql.SQL("CREATE SCHEMA {}").format(sql.Identifier(schema)))
                created = True
                connection.execute(
                    "SELECT set_config('search_path',%s,true)", (schema + ",public",)
                )
                for path in sorted((ROOT / "backend/prisma/migrations").glob("*/migration.sql")):
                    migration = re.sub(
                        r"(?m)^BEGIN;\s*$|^COMMIT;\s*$", "", path.read_text(encoding="utf-8")
                    )
                    connection.execute(migration, prepare=False)
                corpus = json.loads(
                    (ROOT / "backend/knowledge/maize-extension-20261012-v1.json").read_text(
                        encoding="utf-8"
                    )
                )
                for disease in corpus["diseases"]:
                    connection.execute(
                        "INSERT INTO diseases(slug,name,description,scientific_name,status) "
                        "VALUES (%s,%s,%s,%s,'ACTIVE')",
                        (
                            disease["slug"],
                            disease["name"],
                            disease["description"],
                            disease.get("scientificName"),
                        ),
                    )
            parsed = urlsplit(settings.database_url.get_secret_value())
            query = dict(parse_qsl(parsed.query))
            query["schema"] = schema
            isolated_url = urlunsplit(parsed._replace(query=urlencode(query)))
            token = secrets.token_urlsafe(48)
            isolated = settings.model_copy(
                update={
                    "database_url": SecretStr(isolated_url),
                    "inference_enabled": False,
                    "rag_enabled": True,
                    "generation_enabled": True,
                    "environment": "test",
                    "ai_service_token": SecretStr(token),
                }
            )
            listener = socket.socket()
            listener.bind(("127.0.0.1", 0))
            listener.listen()
            port = listener.getsockname()[1]
            server = uvicorn.Server(
                uvicorn.Config(
                    create_app(isolated), log_config=None, log_level="error", access_log=False
                )
            )
            thread = threading.Thread(target=lambda: server.run(sockets=[listener]), daemon=True)
            thread.start()
            deadline = time.monotonic() + 45
            while not server.started and thread.is_alive() and time.monotonic() < deadline:
                time.sleep(0.1)
            if not server.started:
                raise RuntimeError("Isolated AI startup did not become ready")
            result = subprocess.run(
                ["node", "--env-file=backend/.env", "scripts/check-admin-management.mjs"],
                cwd=ROOT,
                env={
                    **os.environ,
                    "DATABASE_URL": isolated_url,
                    "AI_SERVICE_URL": f"http://127.0.0.1:{port}",
                    "AI_SERVICE_TOKEN": token,
                    "PHASE21_SCHEMA": schema,
                },
                check=False,
                timeout=900,
            )
            if result.returncode:
                raise RuntimeError("Admin management contract failed; see safe stage output")
        finally:
            if server is not None:
                server.should_exit = True
            if thread is not None:
                thread.join(timeout=10)
            if listener is not None:
                listener.close()
            if created:
                # The only destructive operation targets this generated, verified schema.
                assert re.fullmatch(r"phase21_[a-f0-9]{32}", schema)
                connection.execute(
                    sql.SQL("DROP SCHEMA IF EXISTS {} CASCADE").format(sql.Identifier(schema))
                )
            assert inventory(connection) == before, "Production table counts changed"
            print(
                "PASS: isolated schema removed; production account/knowledge/"
                "calculator/model counts unchanged."
            )


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print(
            "Phase 21 live contract failed; private configuration is not printed.", file=sys.stderr
        )
        raise SystemExit(1) from None
