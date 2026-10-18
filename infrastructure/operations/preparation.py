"""Prepare isolated local secrets/configuration from already configured developer inputs."""

import json
import os
import secrets
import shutil
import subprocess
from pathlib import Path
from urllib.parse import quote, urlencode


def redis_configuration(namespace: str, password: str) -> str:
    import re

    if not re.fullmatch(r"[a-z][a-z0-9_-]{0,39}", namespace) or not re.fullmatch(
        r"[A-Za-z0-9_-]{43,}", password
    ):
        raise ValueError("Invalid Redis namespace or generated password")
    return (
        "bind 0.0.0.0\nprotected-mode yes\nport 6379\ndir /data\n"
        "appendonly yes\nappendfsync everysec\nmaxmemory 128mb\n"
        "maxmemory-policy noeviction\nuser default off\n"
        f"user quota on >{password} ~{{{namespace}}}:* "
        "+ping +hello +auth +client|setinfo +client|setname +eval +get +set "
        "+incr +pexpire +pttl +time +zremrangebyscore +zcard +zadd +zrem +del\n"
    )


def prepare_local(root: Path) -> dict:
    from backup import verify_artifacts
    from dotenv import dotenv_values
    from roles import ROLES

    runtime = root / "infrastructure/runtime"
    directory = runtime / "secrets"
    if directory.exists():
        raise ValueError(
            "Local secret directory already exists; never overwrite existing identities"
        )
    backend = dotenv_values(root / "backend/.env")
    ai = dotenv_values(root / "ai-service/.env")
    for key in (
        "GEMINI_API_KEY",
        "MODEL_PATH",
        "MODEL_METADATA_PATH",
        "EMBEDDING_MODEL",
        "EMBEDDING_VERSION",
        "GEMINI_MODEL",
    ):
        if not ai.get(key):
            raise ValueError("Complete the existing AI configuration before local preparation")
    for key in ("CLOUDINARY_CLOUD_NAME", "CLOUDINARY_API_KEY", "CLOUDINARY_API_SECRET"):
        if not backend.get(key):
            raise ValueError("Complete the existing storage configuration before local preparation")
    directory.mkdir(parents=True, mode=0o700)
    os.chmod(directory, 0o700)
    if os.name == "nt":
        # A new owned secret directory only. Windows chmod alone does not set ACLs.
        identity = subprocess.check_output(["whoami"], text=True).strip()
        subprocess.run(
            [
                "icacls",
                str(directory),
                "/inheritance:r",
                "/grant:r",
                identity + ":(OI)(CI)F",
                "SYSTEM:(OI)(CI)F",
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    def write(name: str, value) -> None:
        target = directory / name
        target.write_text(
            json.dumps(value, indent=2) if isinstance(value, dict) else value,
            encoding="utf-8",
        )
        # Compose file-backed secrets must be readable by their assigned non-root
        # containers. The enclosing host directory is private (0700/Windows ACL).
        os.chmod(target, 0o444)

    passwords = {role: secrets.token_urlsafe(32) for role in ROLES}
    postgres_password = secrets.token_urlsafe(32)
    service_token = secrets.token_urlsafe(32)
    operations_token = secrets.token_urlsafe(32)
    redis_password = secrets.token_urlsafe(32)
    namespace = "maizedoctor-local"
    options = urlencode({"sslmode": "verify-full", "sslrootcert": "/certificates/root.crt"})

    def url(role, password):
        return f"postgresql://{role}:{quote(password, safe='')}@postgres:5432/maizedoctor?{options}"

    write(
        "node.json",
        {
            "DATABASE_URL": url("md_node", passwords["md_node"]),
            "JWT_SECRET": secrets.token_urlsafe(32),
            "JWT_REFRESH_SECRET": secrets.token_urlsafe(32),
            "AI_SERVICE_TOKEN": service_token,
            "OPERATIONS_TOKEN": operations_token,
            "CLOUDINARY_API_KEY": backend["CLOUDINARY_API_KEY"],
            "CLOUDINARY_API_SECRET": backend["CLOUDINARY_API_SECRET"],
            "REDIS_URL": f"redis://quota:{redis_password}@redis:6379",
        },
    )
    write(
        "ai.json",
        {
            "DATABASE_URL": url("md_ai", passwords["md_ai"]),
            "AI_SERVICE_TOKEN": service_token,
            "OPERATIONS_TOKEN": operations_token,
            "GEMINI_API_KEY": ai["GEMINI_API_KEY"],
        },
    )
    write(
        "curator.json",
        {
            "DATABASE_URL": url("md_curator", passwords["md_curator"]),
            "AI_SERVICE_TOKEN": service_token,
            "OPERATIONS_TOKEN": operations_token,
            "GEMINI_API_KEY": ai["GEMINI_API_KEY"],
        },
    )
    write(
        "migration.json",
        {"DIRECT_DATABASE_URL": url("md_migrator", passwords["md_migrator"])},
    )
    write(
        "operator.json",
        {"DATABASE_URL": url("postgres", postgres_password), "roles": passwords},
    )
    write("backup.json", {"DATABASE_URL": url("md_backup", passwords["md_backup"])})
    write(
        "privacy.json",
        {
            "DATABASE_URL": url("md_privacy", passwords["md_privacy"]),
            "provider": {
                "cloudName": backend["CLOUDINARY_CLOUD_NAME"],
                "apiKey": backend["CLOUDINARY_API_KEY"],
                "apiSecret": backend["CLOUDINARY_API_SECRET"],
            },
        },
    )
    write("postgres-password", postgres_password)
    write("operations-token", operations_token)
    write("grafana-password", secrets.token_urlsafe(32))
    write(
        "redis.conf",
        redis_configuration(namespace, redis_password),
    )
    (directory / "backup-key").write_bytes(os.urandom(32))
    os.chmod(directory / "backup-key", 0o444)
    artifacts = runtime / "artifacts"
    (artifacts / "calibration").mkdir(parents=True, exist_ok=True)
    service = root / "ai-service"

    def path(value):
        candidate = Path(value)
        return candidate if candidate.is_absolute() else (service / candidate).resolve()

    checkpoint = path(ai["MODEL_PATH"])
    metadata = path(ai["MODEL_METADATA_PATH"])
    for source, name in [
        (checkpoint, "epoch-008.pt"),
        (metadata, "model-artifact.json"),
        (
            metadata.parent / "calibration/calibration-config.json",
            "calibration/calibration-config.json",
        ),
    ]:
        target = artifacts / name
        if target.exists() and target.read_bytes() != source.read_bytes():
            raise ValueError("Never overwrite a different artifact")
        if not target.exists():
            shutil.copyfile(source, target)
    verify_artifacts(artifacts)
    environment = {
        "STACK_NAME": namespace,
        "API_HOST": "api.localhost",
        "PUBLIC_HTTPS_ORIGIN": "https://api.localhost:8443",
        "CORS_ORIGINS": "https://api.localhost:8443",
        "SECRETS_DIRECTORY": directory.as_posix(),
        "MODEL_DIRECTORY": artifacts.as_posix(),
        "CLOUDINARY_CLOUD_NAME": backend["CLOUDINARY_CLOUD_NAME"],
        "EMBEDDING_MODEL": ai["EMBEDDING_MODEL"],
        "EMBEDDING_VERSION": ai["EMBEDDING_VERSION"],
        "EMBEDDING_DIMENSIONS": ai.get("EMBEDDING_DIMENSIONS", "768"),
        "GEMINI_MODEL": ai["GEMINI_MODEL"],
    }
    (runtime / ".env.local").write_text(
        "".join(f"{key}={value}\n" for key, value in environment.items()),
        encoding="utf-8",
    )
    return {
        "status": "PASS",
        "secretValuesPrinted": False,
        "separateIdentities": True,
        "providerCredentials": "copied server-side into private ignored files",
        "artifactsVerified": True,
        "hostedDeployment": False,
    }
