"""Least-privilege integration gate for a NEW, EMPTY, local CI PostgreSQL cluster.

Refuses configured user databases and existing MAIZEDOCTOR role identities. No
reset/drop/role-rotation path exists. CI discards its dedicated service afterward.
"""

import argparse
import json
import os
import secrets
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import quote, urlsplit, urlunsplit

from database import connect, pg_environment, secret
from roles import ROLES, audit, provision


def verify(root: Path, admin_url: str, approved: bool):
    env = pg_environment(admin_url)
    if (
        not approved
        or env["PGHOST"] not in {"postgres", "localhost", "127.0.0.1"}
        or env["PGDATABASE"] != "phase25_ci"
    ):
        raise ValueError("Explicit approval of the dedicated local phase25_ci cluster is required")
    with connect(admin_url) as admin:
        if admin.execute("SELECT 1 FROM pg_tables WHERE schemaname='public' LIMIT 1").fetchone():
            raise ValueError("CI database is not empty; no reset is performed")
        if admin.execute(
            "SELECT 1 FROM pg_roles WHERE rolname=ANY(%s) LIMIT 1", (list(ROLES),)
        ).fetchone():
            raise ValueError(
                "Application identities already exist; never rotate an existing cluster"
            )
    passwords = {role: secrets.token_urlsafe(32) for role in ROLES}
    provision(admin_url, passwords)
    parsed = urlsplit(admin_url)

    def url(role):
        return urlunsplit(
            parsed._replace(
                netloc=role
                + ":"
                + quote(passwords[role], safe="")
                + "@"
                + parsed.netloc.split("@")[-1]
            )
        )

    with tempfile.TemporaryDirectory(prefix="maizedoctor-privilege-") as temporary:
        work = Path(temporary)
        config = work / "migration.json"
        config.write_text(json.dumps({"DIRECT_DATABASE_URL": url("md_migrator")}))
        config.chmod(0o600)
        environment = os.environ.copy()
        for key in ("DATABASE_URL", "DIRECT_DATABASE_URL"):
            environment.pop(key, None)
        environment["MAIZEDOCTOR_SECRETS_FILE"] = str(config)
        # Environment URL, never a credential in argv or printed SQL output.
        migrate = subprocess.run(
            ["node", "node_modules/prisma/build/index.js", "migrate", "deploy"],
            cwd=root / "backend",
            env=environment,
            capture_output=True,
            timeout=180,
        )
        if migrate.returncode:
            raise RuntimeError("Disposable migration failed")
        # This pass proves the schema-owner job can grant its reviewed objects,
        # without running future deployment grants as a superuser.
        provision(url("md_migrator"), {}, grants_only=True, allow_managed=True)
        audits = [
            audit(url(role), role) for role in ("md_node", "md_ai", "md_backup", "md_privacy")
        ]
        with connect(url("md_ai")) as indexer:
            assert (
                indexer.execute(
                    "SELECT id FROM knowledge_documents WHERE false FOR UPDATE"
                ).fetchall()
                == []
            )
            assert not indexer.execute(
                "SELECT has_column_privilege(current_user,'knowledge_documents','content','UPDATE')"
            ).fetchone()[0]
        metadata = (
            root
            / "ml-training/reports/mobilenet-v3-small-20261009-v2-01-fitness/model-artifact.json"
        )
        approved = json.loads(metadata.read_text())
        environment.update(
            {
                "NODE_ENV": "production",
                "AI_MODEL_VERSION": approved["model_version"],
                "AI_PREPROCESSING_VERSION": approved["preprocessing"]["version"],
            }
        )
        registration = subprocess.run(
            [
                "node",
                "--import",
                "tsx",
                "src/cli/register-model.ts",
                "--metadata",
                str(metadata),
                "--sha256",
                "a831116fe1ff8b915543991412f4ab6b334736e8eaca376fab8db3b57e5b263d",
            ],
            cwd=root / "backend",
            env=environment,
            capture_output=True,
            timeout=60,
        )
        if registration.returncode:
            raise RuntimeError("Controlled approved-model registration failed")
        with connect(url("md_node")) as reader:
            assert reader.execute(
                "SELECT status::text FROM model_versions WHERE version=%s",
                (approved["model_version"],),
            ).fetchone() == ("VALIDATED",)
        environment.pop("MAIZEDOCTOR_SECRETS_FILE", None)
        environment["TEST_PRIVACY_DATABASE_URL"] = admin_url
        environment["TEST_PRIVACY_RUNTIME_URL"] = url("md_privacy")
        environment["TEST_OPERATIONAL_ADMIN_URL"] = admin_url
        environment["TEST_PRIVACY_NODE_DATABASE_URL"] = url("md_node")
        node = subprocess.run(
            [
                "node",
                "--import",
                "tsx",
                "--test",
                "tests/privacy.database.integration.ts",
            ],
            cwd=root / "backend",
            env=environment,
            capture_output=True,
            timeout=120,
        )
        if node.returncode:
            raise RuntimeError("Least-privilege Node request regression failed")
        sql = subprocess.run(
            [
                str(
                    root
                    / "ai-service/.venv"
                    / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
                ),
                "-m",
                "pytest",
                "infrastructure/operations/tests/test_privacy_database.py",
                "-q",
            ],
            cwd=root,
            env=environment,
            capture_output=True,
            timeout=300,
        )
        if sql.returncode:
            raise RuntimeError("Least-privilege SQL privacy/retention regression failed")
    return {
        "status": "PASS",
        "runtimeAudits": audits,
        "migrations": 15,
        "nodePrivacy": "PASS",
        "privacySQL": "PASS",
        "cluster": "dedicated empty CI cluster only",
        "resetPerformed": False,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--secrets", type=Path, required=True)
    parser.add_argument("--disposable-cluster-approved", action="store_true")
    args = parser.parse_args()
    try:
        print(
            json.dumps(
                verify(
                    args.root,
                    secret(args.secrets)["DATABASE_URL"],
                    args.disposable_cluster_approved,
                )
            )
        )
    except Exception:
        print(
            json.dumps(
                {
                    "status": "FAIL",
                    "category": "DISPOSABLE_PRIVILEGE_GATE",
                    "secretValuesPrinted": False,
                }
            )
        )
        raise SystemExit(1) from None
