"""Authenticated encrypted backup; restore is permitted only in a new owned DB."""

import hashlib
import json
import os
import re
import tarfile
import tempfile
import time
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit
from uuid import uuid4

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from database import connect, owned_database, run_pg, snapshot, snapshot_in
from psycopg import IsolationLevel, sql

MAGIC = b"MDBACKUP1"
CHECKPOINT = "e95a2e83262637fc1a08b919e6003bddb2fe70664b9c51418f059b7c8287dc66"
METADATA = "a831116fe1ff8b915543991412f4ab6b334736e8eaca376fab8db3b57e5b263d"


def key_bytes(path: Path) -> bytes:
    key = path.read_bytes()
    if len(key) != 32:
        raise ValueError("Backup key must contain exactly 32 random bytes")
    return key


def encrypt(source: Path, target: Path, key: bytes) -> None:
    nonce = os.urandom(12)
    encryptor = Cipher(algorithms.AES(key), modes.GCM(nonce)).encryptor()
    header = MAGIC + nonce
    encryptor.authenticate_additional_data(header)
    with source.open("rb") as incoming, target.open("xb") as outgoing:
        os.chmod(target, 0o600)
        outgoing.write(header)
        while chunk := incoming.read(1024 * 1024):
            outgoing.write(encryptor.update(chunk))
        outgoing.write(encryptor.finalize())
        outgoing.write(encryptor.tag)
        outgoing.flush()
        os.fsync(outgoing.fileno())


def decrypt(source: Path, target: Path, key: bytes) -> None:
    length = source.stat().st_size
    with source.open("rb") as incoming:
        header = incoming.read(len(MAGIC) + 12)
        if not header.startswith(MAGIC) or length < len(header) + 16:
            raise ValueError("Invalid backup envelope")
        incoming.seek(-16, 2)
        tag = incoming.read(16)
        incoming.seek(len(header))
        decoder = Cipher(algorithms.AES(key), modes.GCM(header[len(MAGIC) :], tag)).decryptor()
        decoder.authenticate_additional_data(header)
        remaining = length - len(header) - 16
        try:
            with target.open("xb") as outgoing:
                os.chmod(target, 0o600)
                while remaining:
                    chunk = incoming.read(min(1024 * 1024, remaining))
                    if not chunk:
                        raise ValueError("Truncated backup")
                    remaining -= len(chunk)
                    outgoing.write(decoder.update(chunk))
                outgoing.write(decoder.finalize())
        except BaseException:
            target.unlink(missing_ok=True)  # Newly-created owned temporary output only.
            raise


def verify_artifacts(directory: Path) -> dict:
    paths = {"epoch-008.pt": CHECKPOINT, "model-artifact.json": METADATA}
    for name, expected in paths.items():
        if hashlib.sha256((directory / name).read_bytes()).hexdigest() != expected:
            raise ValueError("Approved model integrity mismatch")
    metadata = json.loads((directory / "model-artifact.json").read_text(encoding="utf-8"))
    sidecar = directory / "calibration/calibration-config.json"
    if (
        hashlib.sha256(sidecar.read_bytes()).hexdigest()
        != metadata["calibration"]["configuration"]["sha256"]
    ):
        raise ValueError("Approved calibration sidecar mismatch")
    return {
        **paths,
        "calibration/calibration-config.json": hashlib.sha256(sidecar.read_bytes()).hexdigest(),
    }


def create_backup(url: str, directory: Path, key_file: Path, artifacts: Path) -> dict:
    directory.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    hashes = verify_artifacts(artifacts)
    name = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime()) + "-" + uuid4().hex + ".mdb"
    target = directory / name
    with tempfile.TemporaryDirectory(prefix="maizedoctor-backup-") as temporary:
        work = Path(temporary)
        dump = work / "database.dump"
        with connect(url) as consistent:
            consistent.isolation_level = IsolationLevel.REPEATABLE_READ
            consistent.read_only = True
            exported = consistent.execute("SELECT pg_export_snapshot()").fetchone()[0]
            if not re.fullmatch(r"[0-9A-Fa-f-]{1,80}", exported):
                raise ValueError("Unexpected snapshot identity")
            before = snapshot_in(consistent)
            run_pg(
                url=url,
                name="pg_dump",
                arguments=[
                    "--format=custom",
                    "--no-owner",
                    "--no-privileges",
                    "--schema=public",
                    "--snapshot",
                    exported,
                    "--file",
                    str(dump),
                ],
            )
        if dump.stat().st_size > 256 * 1024 * 1024:
            raise ValueError(
                "Reference backup capacity exceeded; increase reviewed recovery capacity"
            )
        manifest = {
            "format": 1,
            "database": before,
            "dumpSha256": hashlib.sha256(dump.read_bytes()).hexdigest(),
            "artifacts": hashes,
        }
        (work / "manifest.json").write_text(json.dumps(manifest, sort_keys=True), encoding="utf-8")
        archive = work / "backup.tar"

        def strip_host_identity(info):
            info.uid = info.gid = info.mtime = 0
            info.uname = info.gname = ""
            return info

        with tarfile.open(archive, "w") as bundle:
            for source, name in [
                (dump, "database.dump"),
                (work / "manifest.json", "manifest.json"),
            ]:
                bundle.add(source, arcname=name, filter=strip_host_identity)
            for name in hashes:
                bundle.add(
                    artifacts / name,
                    arcname="artifacts/" + name,
                    filter=strip_host_identity,
                )
        pending = target.with_suffix(".partial")
        try:
            encrypt(archive, pending, key_bytes(key_file))
            os.replace(pending, target)
        finally:
            pending.unlink(missing_ok=True)
    return {
        "status": "PASS",
        "backup": target.name,
        "bytes": target.stat().st_size,
        "encryptedSha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "seconds": round(time.monotonic() - started, 3),
        "retentionDeletionEnabled": False,
    }


def restore_drill(source_url: str, backup: Path, key_file: Path) -> dict:
    started = time.monotonic()
    database = "phase25_restore_" + uuid4().hex
    owned_database(database)
    parsed = urlsplit(source_url)
    restored_url = urlunsplit(parsed._replace(path="/" + database))
    created = False
    try:
        with tempfile.TemporaryDirectory(prefix="maizedoctor-restore-") as temporary:
            work = Path(temporary)
            decrypt(
                backup, work / "backup.tar", key_bytes(key_file)
            )  # Authenticate BEFORE any DB creation.
            allowed = {
                "database.dump",
                "manifest.json",
                "artifacts/epoch-008.pt",
                "artifacts/model-artifact.json",
                "artifacts/calibration/calibration-config.json",
            }
            with tarfile.open(work / "backup.tar") as bundle:
                members = bundle.getmembers()
                if (
                    len(members) != len(allowed)
                    or {m.name for m in members} != allowed
                    or any(not m.isfile() or m.size > 256 * 1024 * 1024 for m in members)
                ):
                    raise ValueError("Invalid bounded backup contents")
                bundle.extractall(work, filter="data")
            manifest = json.loads((work / "manifest.json").read_text(encoding="utf-8"))
            if (
                hashlib.sha256((work / "database.dump").read_bytes()).hexdigest()
                != manifest["dumpSha256"]
            ):
                raise ValueError("Dump integrity mismatch")
            verify_artifacts(work / "artifacts")
            with connect(source_url, autocommit=True) as admin:
                if admin.execute(
                    "SELECT 1 FROM pg_database WHERE datname=%s", (database,)
                ).fetchone():
                    raise ValueError("Owned restore database unexpectedly exists")
                admin.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(database)))
                created = True
            # Schema-filtered pg_dump omits extension dependencies. Install the
            # recorded extension in the fresh target, preserve its public schema,
            # and restore all application objects without replaying public CREATE.
            vector_version = manifest["database"]["pgvector"][0]
            if not re.fullmatch(r"\d+\.\d+\.\d+", vector_version):
                raise ValueError("Unrecognized extension version")
            with connect(restored_url) as target:
                target.execute(
                    sql.SQL("CREATE EXTENSION vector WITH SCHEMA public VERSION {}").format(
                        sql.Literal(vector_version)
                    )
                )
            listing = run_pg(
                "pg_restore", restored_url, ["--list", str(work / "database.dump")]
            ).decode("utf-8")
            lines = [
                line
                for line in listing.splitlines()
                if not re.match(r"^\d+; \d+ \d+ SCHEMA - public ", line)
            ]
            (work / "restore.list").write_text("\n".join(lines) + "\n", encoding="utf-8")
            # A safe database name selects execution mode; connection credentials
            # remain in libpq environment, never a command-line connection URL.
            run_pg(
                "pg_restore",
                restored_url,
                [
                    "--dbname",
                    database,
                    "--clean",
                    "--if-exists",
                    "--no-owner",
                    "--no-privileges",
                    "--exit-on-error",
                    "--single-transaction",
                    "--use-list",
                    str(work / "restore.list"),
                    str(work / "database.dump"),
                ],
            )
            actual = snapshot(restored_url)
            if json.loads(json.dumps(actual)) != manifest["database"]:
                raise ValueError("Restored database verification differs")
            return {
                "status": "PASS",
                "isolatedRestore": True,
                "tables": len(actual["counts"]),
                "migrations": len(actual["migrations"]),
                "modelArtifactsVerified": True,
                "foreignKeys": len(actual["foreignKeys"]),
                "seconds": round(time.monotonic() - started, 3),
            }
    finally:
        if created:
            owned_database(database)
            with connect(source_url, autocommit=True) as admin:
                admin.execute(
                    sql.SQL("DROP DATABASE {} WITH (FORCE)").format(sql.Identifier(database))
                )
