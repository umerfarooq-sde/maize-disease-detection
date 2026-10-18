"""Database operator boundary. URLs/secrets never enter command-line arguments."""

import json
import os
import re
import shutil
import subprocess
from pathlib import Path
from urllib.parse import parse_qsl, unquote, urlsplit

import psycopg
from psycopg import sql


def secret(path: Path) -> dict:
    if path.stat().st_size > 65536:
        raise ValueError("Secret file exceeds limit")
    result = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(result, dict):
        raise ValueError("Expected a secret object")
    return result


def pg_environment(url: str) -> dict[str, str]:
    parsed = urlsplit(url)
    if parsed.scheme not in {"postgres", "postgresql"} or not parsed.hostname:
        raise ValueError("Invalid database URL")
    query = dict(parse_qsl(parsed.query))
    allowed = {
        "sslmode",
        "sslrootcert",
        "schema",
        "connect_timeout",
        "pgbouncer",
        "uselibpqcompat",
        "channel_binding",
    }
    if set(query) - allowed:
        raise ValueError("Unsupported database URL options")
    mode = query.get("sslmode", "")
    if mode in {"require", "prefer", "verify-ca"}:
        mode = "verify-full"
    if parsed.hostname not in {"localhost", "127.0.0.1", "::1"} and mode != "verify-full":
        raise ValueError("Remote database requires verified TLS")
    env = {key: value for key, value in os.environ.items() if not key.startswith("PG")}
    env.update(
        {
            "PGHOST": parsed.hostname,
            "PGPORT": str(parsed.port or 5432),
            "PGDATABASE": unquote(parsed.path.lstrip("/")),
            "PGUSER": unquote(parsed.username or ""),
            "PGPASSWORD": unquote(parsed.password or ""),
            "PGCONNECT_TIMEOUT": "8",
            "PGSSLMODE": mode or "prefer",
        }
    )
    if "sslrootcert" in query:
        env["PGSSLROOTCERT"] = query["sslrootcert"]
    elif mode == "verify-full":
        import ssl

        # Windows/libpq needs an explicit public root bundle. Optional certifi is
        # already present in the developer AI environment; containers use OS roots.
        try:
            import certifi

            env["PGSSLROOTCERT"] = certifi.where()
        except ImportError:
            roots = ssl.get_default_verify_paths().cafile
            if roots:
                env["PGSSLROOTCERT"] = roots
    if "channel_binding" in query:
        if query["channel_binding"] not in {"require", "prefer", "disable"}:
            raise ValueError("Invalid channel binding policy")
        env["PGCHANNELBINDING"] = query["channel_binding"]
    return env


def connect(url: str, *, autocommit: bool = False):
    env = pg_environment(url)
    params = {
        "host": env["PGHOST"],
        "port": env["PGPORT"],
        "dbname": env["PGDATABASE"],
        "user": env["PGUSER"],
        "password": env["PGPASSWORD"],
        "sslmode": env["PGSSLMODE"],
        "connect_timeout": 8,
    }
    if "PGSSLROOTCERT" in env:
        params["sslrootcert"] = env["PGSSLROOTCERT"]
    if "PGCHANNELBINDING" in env:
        params["channel_binding"] = env["PGCHANNELBINDING"]
    return psycopg.connect(**params, autocommit=autocommit)


def pg_tool(name: str) -> str:
    configured = os.getenv("PG_BIN")
    executable = (
        Path(configured) / (name + (".exe" if os.name == "nt" else "")) if configured else None
    )
    found = str(executable) if executable and executable.is_file() else shutil.which(name)
    if not found and os.name == "nt":
        candidate = Path("C:/Program Files/PostgreSQL/18/bin") / (name + ".exe")
        found = str(candidate) if candidate.is_file() else None
    if not found:
        raise ValueError(f"Required PostgreSQL client unavailable: {name}")
    return found


class PgToolError(RuntimeError):
    def __init__(self, tool: str, code: int, category: str, diagnostic: str):
        self.category = category
        self.diagnostic = diagnostic
        super().__init__(f"{tool} failed: {category} (exit {code})")


def run_pg(name: str, url: str, arguments: list[str], timeout: int = 300) -> bytes:
    result = subprocess.run(
        [pg_tool(name), *arguments],
        env=pg_environment(url),
        stdin=subprocess.DEVNULL,
        capture_output=True,
        timeout=timeout,
        check=False,
        **({"creationflags": subprocess.CREATE_NO_WINDOW} if os.name == "nt" else {}),
    )
    if result.returncode:
        # Never dump raw SQL/connection messages into CI/operator output.
        message = result.stderr.decode("utf-8", errors="replace").lower()
        category = next(
            (
                kind
                for phrase, kind in [
                    ('type "public.vector" does not exist', "MISSING_VECTOR_TYPE"),
                    ('schema "public" already exists', "SCHEMA_EXISTS"),
                    ('extension "vector" is not available', "VECTOR_UNAVAILABLE"),
                    ("permission denied", "DATABASE_PERMISSION"),
                    ("connection to server", "DATABASE_CONNECTION"),
                ]
                if phrase in message
            ),
            "DATABASE_TOOL_FAILURE",
        )
        # Retain only a bounded server error template, never SQL/DETAIL lines or
        # quoted identifiers/values. This distinguishes tool defects safely.
        line = next(
            (
                line.split("ERROR:", 1)[1].strip()
                for line in result.stderr.decode("utf-8", errors="replace").splitlines()
                if "ERROR:" in line
            ),
            "No server error template",
        )
        line = re.sub(r'"[^"]*"|\'[^\']*\'', "<redacted>", line)
        for key in ("PGHOST", "PGUSER", "PGPASSWORD", "PGDATABASE"):
            value = pg_environment(url).get(key, "")
            if value:
                line = line.replace(value, "<redacted>")
        raise PgToolError(name, result.returncode, category, line[:240])
    if len(result.stdout) > 16 * 1024 * 1024:
        raise ValueError("Database tool output exceeds limit")
    return result.stdout


def snapshot(url: str) -> dict:
    with connect(url) as connection:
        connection.execute("SET TRANSACTION READ ONLY")
        return snapshot_in(connection)


def snapshot_in(connection) -> dict:
    connection.execute("SET LOCAL statement_timeout='5000ms'")
    tables = [
        row[0]
        for row in connection.execute(
            "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename"
        )
    ]
    counts = {
        table: connection.execute(
            sql.SQL("SELECT count(*) FROM public.{}").format(sql.Identifier(table))
        ).fetchone()[0]
        for table in tables
    }
    migrations = connection.execute(
        "SELECT migration_name FROM public._prisma_migrations WHERE f"
        "inished_at IS NOT NULL AND rolled_back_at IS NULL ORDER BY m"
        "igration_name"
    ).fetchall()
    models = connection.execute(
        "SELECT version,status::text,preprocessing_version FROM publi"
        "c.model_versions ORDER BY version"
    ).fetchall()
    foreign_keys = connection.execute(
        "SELECT conname FROM pg_constraint WHERE connamespace='public"
        "'::regnamespace AND contype='f' AND convalidated ORDER BY co"
        "nname"
    ).fetchall()
    structures = connection.execute(
        "SELECT contype,count(*) FROM pg_constraint WHERE connamespac"
        "e='public'::regnamespace GROUP BY contype ORDER BY contype"
    ).fetchall()
    vector = connection.execute(
        "SELECT extversion FROM pg_extension WHERE extname='vector'"
    ).fetchone()
    return {
        "counts": counts,
        "migrations": migrations,
        "models": models,
        "foreignKeys": foreign_keys,
        "constraints": structures,
        "pgvector": vector,
    }


def owned_database(name: str) -> None:
    if not re.fullmatch(r"phase25_restore_[a-f0-9]{32}", name):
        raise ValueError("Restore target must be a freshly generated owned database")
