import os

import backup
import pytest
from cryptography.exceptions import InvalidTag
from database import owned_database, pg_environment, snapshot_in


def test_authenticated_backup_roundtrip_and_tampering_rejection(tmp_path):
    source = tmp_path / "source"
    encrypted = tmp_path / "encrypted"
    restored = tmp_path / "restored"
    source.write_bytes(os.urandom(2 * 1024 * 1024 + 17))
    key = os.urandom(32)
    backup.encrypt(source, encrypted, key)
    backup.decrypt(encrypted, restored, key)
    assert source.read_bytes() == restored.read_bytes()
    data = bytearray(encrypted.read_bytes())
    data[len(data) // 2] ^= 1
    tampered = tmp_path / "tampered"
    tampered.write_bytes(data)
    output = tmp_path / "invalid-output"
    with pytest.raises(InvalidTag):
        backup.decrypt(tampered, output, key)
    assert not output.exists()


def test_wrong_key_and_invalid_envelope_never_create_a_restore_database(tmp_path, monkeypatch):
    source = tmp_path / "source"
    source.write_bytes(b"synthetic backup")
    encrypted = tmp_path / "encrypted"
    backup.encrypt(source, encrypted, os.urandom(32))
    key = tmp_path / "key"
    key.write_bytes(os.urandom(32))

    def forbidden(*args, **kwargs):
        raise AssertionError("No DB connection before authentication")

    monkeypatch.setattr(backup, "connect", forbidden)
    with pytest.raises(InvalidTag):
        backup.restore_drill("postgresql://localhost/fixture", encrypted, key)
    encrypted.write_bytes(b"invalid")
    with pytest.raises(ValueError):
        backup.restore_drill("postgresql://localhost/fixture", encrypted, key)


def test_restore_refuses_existing_or_unowned_database_names():
    for name in ("public", "maizedoctor", "phase25_restore_unsafe", "../database"):
        with pytest.raises(ValueError):
            owned_database(name)
    owned_database("phase25_restore_" + "a" * 32)


def test_connection_settings_preserve_tls_and_channel_binding_without_endpoint_overrides():
    env = pg_environment(
        "postgresql://test:private-fixture@db.example.invalid/data?ss"
        "lmode=require&channel_binding=require"
    )
    assert env["PGSSLMODE"] == "verify-full"
    assert env["PGCHANNELBINDING"] == "require"
    assert env["PGPASSWORD"] == "private-fixture"
    for query in ("sslmode=disable", "sslmode=verify-full&host=another.invalid"):
        with pytest.raises(ValueError):
            pg_environment("postgresql://db.example.invalid/data?" + query)


def test_model_recovery_rejects_unapproved_content(tmp_path):
    (tmp_path / "epoch-008.pt").write_bytes(b"synthetic not a model")
    with pytest.raises(ValueError, match="integrity"):
        backup.verify_artifacts(tmp_path)


def test_pre_release_snapshot_supports_a_fresh_vector_database():
    class EmptyConnection:
        def execute(self, query):
            if "_prisma_migrations" in query or "model_versions" in query:
                raise AssertionError("Fresh database has no application tables yet")
            self.vector = "pg_extension" in query
            return self

        def fetchall(self):
            return []

        def __iter__(self):
            return iter([])

        def fetchone(self):
            assert self.vector
            return ("0.8.7",)

    result = snapshot_in(EmptyConnection())
    assert result == {
        "counts": {},
        "migrations": [],
        "models": [],
        "foreignKeys": [],
        "constraints": [],
        "pgvector": ("0.8.7",),
    }
