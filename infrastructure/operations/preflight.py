"""Offline production configuration admission; success does not claim live hosting."""

import base64
import re
from pathlib import Path
from urllib.parse import urlsplit

from backup import verify_artifacts
from database import pg_environment, secret
from dotenv import dotenv_values
from privacy import read_policy


def random_key(value) -> bool:
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9_-]{43,256}", value):
        return False
    try:
        decoded = base64.urlsafe_b64decode(value + "=" * ((-len(value)) % 4))
        return (
            len(decoded) >= 32 and base64.urlsafe_b64encode(decoded).decode().rstrip("=") == value
        )
    except ValueError:
        return False


def preflight(environment_file: Path, *, local: bool = False) -> dict:
    values = dotenv_values(environment_file)
    required = (
        "STACK_NAME",
        "API_HOST",
        "PUBLIC_HTTPS_ORIGIN",
        "CORS_ORIGINS",
        "SECRETS_DIRECTORY",
        "MODEL_DIRECTORY",
        "CLOUDINARY_CLOUD_NAME",
        "EMBEDDING_MODEL",
        "EMBEDDING_VERSION",
        "GEMINI_MODEL",
    )
    missing = [key for key in required if not values.get(key)]
    if missing:
        raise ValueError("Missing non-secret deployment configuration: " + ",".join(missing))
    if any(key in values for key in ("DATABASE_URL", "JWT_SECRET", "GEMINI_API_KEY", "REDIS_URL")):
        raise ValueError("Secrets must be mounted, not stored in the public deployment environment")
    if not re.fullmatch(r"[a-z][a-z0-9_-]{0,39}", values["STACK_NAME"]):
        raise ValueError("Invalid stack namespace")
    origin = urlsplit(values["PUBLIC_HTTPS_ORIGIN"])
    if (
        origin.scheme != "https"
        or origin.username
        or origin.password
        or origin.query
        or origin.fragment
        or origin.path not in ("", "/")
        or origin.hostname != values["API_HOST"]
    ):
        raise ValueError("Invalid external HTTPS origin")
    if not local and (
        origin.hostname.endswith((".invalid", ".test", ".localhost"))
        or origin.hostname in ("localhost", "127.0.0.1")
    ):
        raise ValueError("Hosted configuration requires an actual owned API host")
    for configured in values["CORS_ORIGINS"].split(","):
        url = urlsplit(configured)
        if (
            url.scheme != "https"
            or not url.hostname
            or url.path
            or url.query
            or url.fragment
            or url.username
            or url.password
        ):
            raise ValueError("CORS must use exact HTTPS origins")
    directory = Path(values["SECRETS_DIRECTORY"])
    models = Path(values["MODEL_DIRECTORY"])
    if not directory.is_absolute() or not models.is_absolute():
        raise ValueError("Deployment secrets and models require absolute host paths")
    if directory.resolve().is_relative_to(models.resolve()) or models.resolve().is_relative_to(
        directory.resolve()
    ):
        raise ValueError("Secret and artifact mounts must be separate")
    policy_file = Path(values.get("PRIVACY_POLICY_FILE") or "privacy-policy.example.json")
    if not policy_file.is_absolute():
        policy_file = environment_file.parent / policy_file
    policy, _ = read_policy(policy_file)
    configurations = {
        name: secret(directory / (name + ".json"))
        for name in ("node", "ai", "migration", "backup", "curator", "privacy")
    }
    node, ai = configurations["node"], configurations["ai"]
    for key in (
        "JWT_SECRET",
        "JWT_REFRESH_SECRET",
        "AI_SERVICE_TOKEN",
        "OPERATIONS_TOKEN",
    ):
        if not random_key(node.get(key)):
            raise ValueError("Invalid strong server key: " + key)
    if (
        len(
            {
                node[key]
                for key in (
                    "JWT_SECRET",
                    "JWT_REFRESH_SECRET",
                    "AI_SERVICE_TOKEN",
                    "OPERATIONS_TOKEN",
                )
            }
        )
        != 4
    ):
        raise ValueError("Purpose-specific credentials must be distinct")
    if (
        ai.get("AI_SERVICE_TOKEN") != node["AI_SERVICE_TOKEN"]
        or ai.get("OPERATIONS_TOKEN") != node["OPERATIONS_TOKEN"]
    ):
        raise ValueError("Internal service/metrics identities do not match")
    if (directory / "operations-token").read_text(encoding="utf-8") != node["OPERATIONS_TOKEN"]:
        raise ValueError("Monitoring credential does not match")
    identities = []
    expected_identities = {
        "node": "md_node",
        "ai": "md_ai",
        "migration": "md_migrator",
        "backup": "md_backup",
        "curator": "md_curator",
        "privacy": "md_privacy",
    }
    for name, config in configurations.items():
        url = config.get("DIRECT_DATABASE_URL") or config.get("DATABASE_URL")
        normalized = pg_environment(url)
        if normalized["PGSSLMODE"] != "verify-full":
            raise ValueError("Every deployed DB connection must verify TLS")
        identities.append(normalized["PGUSER"])
        if normalized["PGUSER"] != expected_identities[name]:
            raise ValueError(
                "Deployment identity must match the reviewed role/grant contract: " + name
            )
    if len(set(identities)) != 6:
        raise ValueError("All six database purpose identities must be separate")
    redis = urlsplit(node.get("REDIS_URL", ""))
    if not redis.password or (
        redis.scheme != "rediss" and not (redis.scheme == "redis" and redis.hostname == "redis")
    ):
        raise ValueError("Use authenticated private reference Redis or verified external Redis TLS")
    if (
        not ai.get("GEMINI_API_KEY")
        or not node.get("CLOUDINARY_API_SECRET")
        or not node.get("CLOUDINARY_API_KEY")
    ):
        raise ValueError("Required server-side providers are not configured")
    if len((directory / "backup-key").read_bytes()) != 32:
        raise ValueError("Backup encryption key is missing or invalid")
    hashes = verify_artifacts(Path(values["MODEL_DIRECTORY"]))
    return {
        "status": "PASS",
        "kind": "OFFLINE_CONFIGURATION_ONLY",
        "modelArtifacts": hashes,
        "databaseIdentitiesSeparated": True,
        "secretValuesPrinted": False,
        "localReference": local,
        "hostedTLSVerified": False,
        "policyErasureEnabled": policy["erasureEnabled"],
    }
