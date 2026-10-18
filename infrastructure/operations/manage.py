"""Operator commands print bounded metadata only; never raw dependency errors."""

import argparse
import json
import sys
from pathlib import Path

from backup import create_backup, restore_drill, verify_artifacts
from backup_retention import expire_backups, record_restore
from database import pg_environment, secret, snapshot
from preflight import preflight
from preparation import prepare_local
from privacy import cleanup, destroy_asset, detach, expire, preview, review
from roles import audit, provision, provisioning_statements


def main() -> dict:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=[
            "prepare-local",
            "preflight",
            "backup",
            "restore-drill",
            "verify-model",
            "snapshot",
            "provision-local",
            "grant-local",
            "grant-runtime",
            "export-role-sql",
            "export-grants-sql",
            "audit-role",
            "privacy-preview",
            "privacy-approve",
            "privacy-erase",
            "privacy-cleanup",
            "retention",
            "backup-retention",
        ],
    )
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--environment-file", type=Path)
    parser.add_argument("--local", action="store_true")
    parser.add_argument("--secrets", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--artifacts", type=Path)
    parser.add_argument("--key", type=Path)
    parser.add_argument("--backup", type=Path)
    parser.add_argument("--identity")
    parser.add_argument("--policy", type=Path)
    parser.add_argument("--request-id")
    parser.add_argument("--reviewer-id")
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    if args.command == "prepare-local":
        return prepare_local(args.root)
    if args.command == "preflight":
        return preflight(args.environment_file, local=args.local)
    if args.command == "verify-model":
        return {"status": "PASS", "hashes": verify_artifacts(args.artifacts)}
    if args.command == "backup-retention":
        return expire_backups(args.output, args.policy, execute=args.execute)
    values = secret(args.secrets)
    url = values.get("DIRECT_DATABASE_URL") or values.get("DATABASE_URL")
    if not url:
        raise ValueError("Database secret is required")
    if args.command in {"export-role-sql", "export-grants-sql"}:
        if args.output is None or args.output.parent.resolve() != args.secrets.parent.resolve():
            raise ValueError("Write administrator SQL only into the private secret directory")
        statements = provisioning_statements(
            pg_environment(url)["PGDATABASE"],
            values.get("roles", {}),
            grants_only=args.command == "export-grants-sql",
        )
        import os

        descriptor = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as output:
            output.write("\\set ON_ERROR_STOP on\n")
            output.write(
                "BEGIN;\n" + ";\n".join(item.as_string() for item in statements) + ";\nCOMMIT;\n"
            )
        return {"status": "PASS", "sqlWrittenPrivately": True, "databaseChanged": False}
    if args.command == "grant-runtime":
        if not args.execute:
            raise ValueError("Explicit approved runtime-grant application is required")
        return provision(url, {}, grants_only=True, allow_managed=True)
    if args.command == "privacy-preview":
        return preview(url, args.request_id, args.policy)
    if args.command == "retention":
        return expire(url, args.policy, execute=args.execute)
    if args.command.startswith("privacy-"):
        if not args.execute:
            return preview(url, args.request_id, args.policy)
        if args.command == "privacy-approve":
            return review(url, args.request_id, args.reviewer_id, args.policy)
        if args.command == "privacy-erase":
            return detach(url, args.request_id, args.policy)
        return cleanup(
            url,
            args.request_id,
            args.policy,
            lambda asset: destroy_asset(asset, values["provider"]),
        )
    if args.command == "backup":
        return create_backup(url, args.output, args.key, args.artifacts)
    if args.command == "restore-drill":
        result = restore_drill(url, args.backup, args.key)
        record_restore(args.backup, result)
        return result
    if args.command == "snapshot":
        return {"status": "PASS", **snapshot(url)}
    if args.command in {"provision-local", "grant-local"}:
        if not args.local:
            raise ValueError("Explicit --local disposable-reference authorization is required")
        return provision(url, values["roles"], grants_only=args.command == "grant-local")
    return audit(url, args.identity)


if __name__ == "__main__":
    try:
        print(json.dumps(main(), sort_keys=True))
    except Exception as error:
        print(
            json.dumps(
                {
                    "status": "FAIL",
                    "category": type(error).__name__,
                    ("hint"): (
                        "Check required tools, mounted configuration, privileges and "
                        "isolated target. No secrets/dependency messages are printed."
                    ),
                }
            )
        )
        sys.exit(1)
