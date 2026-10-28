"""Read actual native settings and verify approved artifacts without loading another model.

No secret or exception text is serialized. These probes do not call Google/Cloudinary.
"""

import hashlib
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "ai-service"))

from app.config.settings import load_settings  # noqa: E402

VERSION = "mobilenet-v3-small-v2-20261009"
METADATA_SHA = "a831116fe1ff8b915543991412f4ab6b334736e8eaca376fab8db3b57e5b263d"
CHECKPOINT_SHA = "e95a2e83262637fc1a08b919e6003bddb2fe70664b9c51418f059b7c8287dc66"
CALIBRATION_SHA = "641e5b1c2daaa1082bd17ddfe4ba401d13e2a69700c48c0860bb15279d41d14d"
CLASSES = {
    name: i
    for i, name in enumerate(
        ["Common_Rust", "Gray_Leaf_Spot", "Healthy", "Northern_Corn_Leaf_Blight"]
    )
}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def require(condition: bool, code: str) -> None:
    if not condition:
        raise RuntimeError(code)


def verified_json(path: Path, expected: str) -> dict:
    require(path.is_file(), "REQUIRED_ARTIFACT_MISSING")
    require(path.stat().st_size <= 512 * 1024, "ARTIFACT_SIZE_INVALID")
    encoded = path.read_bytes()
    require(hashlib.sha256(encoded).hexdigest() == expected, "ARTIFACT_HASH_MISMATCH")
    return json.loads(encoded)


def probe(action: str) -> dict:
    settings = load_settings()
    require(settings.environment == "development", "DEVELOPMENT_CONFIGURATION_REQUIRED")
    require(settings.host in {"localhost", "127.0.0.1", "::1"}, "LOOPBACK_AI_BIND_REQUIRED")
    require(
        bool(settings.ai_service_token) and settings.inference_enabled,
        "INTERNAL_INFERENCE_REQUIRED",
    )
    host = "[::1]" if settings.host == "::1" else settings.host
    origin = f"http://{host}:{settings.port}"
    if action == "config":
        require(settings.model_version == VERSION, "APPROVED_MODEL_REQUIRED")
        require(settings.preprocessing_version == "1.0.0", "PREPROCESSING_MISMATCH")
        require(
            settings.confidence_policy_path is None and not settings.confidence_policy_sha256,
            "APPROVED_NULL_CONFIDENCE_POLICY_REQUIRED",
        )
        require(
            settings.model_path is not None and settings.model_metadata_path is not None,
            "MODEL_CONFIGURATION_INCOMPLETE",
        )
        require(settings.model_path.is_file(), "CHECKPOINT_MISSING")
        require(settings.model_path.stat().st_size <= 32 * 1024 * 1024, "CHECKPOINT_SIZE_INVALID")
        require(settings.model_metadata_sha256 == METADATA_SHA, "METADATA_PIN_MISMATCH")
        artifact = verified_json(settings.model_metadata_path, METADATA_SHA)
        require(
            artifact["model_version"] == VERSION and artifact["class_to_index"] == CLASSES,
            "CLASS_MAPPING_MISMATCH",
        )
        require(artifact["checkpoint"]["sha256"] == CHECKPOINT_SHA, "CHECKPOINT_PIN_MISMATCH")
        require(
            hashlib.sha256(settings.model_path.read_bytes()).hexdigest() == CHECKPOINT_SHA,
            "CHECKPOINT_HASH_MISMATCH",
        )
        require(
            artifact["preprocessing"]["version"] == "1.0.0"
            and artifact["preprocessing"]["configuration"]["segmentation"]["mode"] == "disabled",
            "FULL_FRAME_PREPROCESSING_REQUIRED",
        )
        from maizedoctor_preprocessing import PreprocessingConfig

        config = PreprocessingConfig.model_validate_json(
            json.dumps(artifact["preprocessing"]["configuration"])
        )
        require(
            config.fingerprint == artifact["preprocessing"]["semantic_sha256"],
            "PREPROCESSING_HASH_MISMATCH",
        )
        calibration = verified_json(
            settings.model_metadata_path.parent / "calibration/calibration-config.json",
            CALIBRATION_SHA,
        )
        require(
            calibration["temperature"] == 1 and calibration["operational_threshold"] is None,
            "CALIBRATION_MISMATCH",
        )
        if settings.generation_enabled:
            require(
                settings.generation_corpus_path is not None
                and settings.generation_corpus_path.is_file()
                and settings.generation_review_path is not None
                and settings.generation_review_path.is_file(),
                "GENERATION_REVIEW_FILES_MISSING",
            )
        return {
            "origin": origin,
            "port": settings.port,
            "modelVersion": VERSION,
            "preprocessingVersion": "1.0.0",
            "classMapping": CLASSES,
            "checkpointSha256": CHECKPOINT_SHA,
            "metadataSha256": METADATA_SHA,
            "confidenceThreshold": None,
            "temperature": 1,
            "ragConfigured": settings.rag_enabled,
            "generationConfigured": settings.generation_enabled,
        }
    if action == "database":
        if not settings.rag_enabled:
            return {"ragDatabase": "not_configured"}
        from app.rag.repository import KnowledgeRepository

        repository = KnowledgeRepository(settings, "phone-launcher-read-only")
        try:
            with repository.connection() as connection:
                row = connection.execute(
                    "SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname='vector') AS present"
                ).fetchone()
                require(bool(row and row["present"]), "PGVECTOR_UNAVAILABLE")
            return {"ragDatabase": "up", "pgvector": "installed"}
        finally:
            repository.close()
    require(action == "health", "UNKNOWN_PROBE")
    url = origin + "/api/v1/model-health"
    # No proxy credentials or proxy routing for loopback internal requests.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    try:
        with opener.open(url, timeout=5):
            raise RuntimeError("INTERNAL_AUTHENTICATION_NOT_ENFORCED")
    except urllib.error.HTTPError as error:
        require(error.code == 401, "INTERNAL_AUTHENTICATION_NOT_ENFORCED")
    request = urllib.request.Request(
        url, headers={"Authorization": "Bearer " + settings.ai_service_token.get_secret_value()}
    )
    with opener.open(request, timeout=8) as response:
        result = json.load(response)
    data = result["data"]
    require(
        result["success"] is True
        and data["status"] == "ready"
        and data["modelVersion"] == VERSION
        and data["preprocessingVersion"] == "1.0.0"
        and data["classMapping"] == CLASSES
        and data["confidenceThreshold"] is None
        and data["confidencePolicy"] == "UNCONFIGURED"
        and data["calibration"] == "none",
        "MODEL_HEALTH_INCOMPATIBLE",
    )
    with opener.open(origin + "/health", timeout=8) as response:
        health = json.load(response)["data"]
    require(
        health["service"] == "maizedoctor-ai-service" and health["status"] == "ok",
        "AI_HEALTH_INCOMPATIBLE",
    )
    for name, enabled in [
        ("rag", settings.rag_enabled),
        ("generation", settings.generation_enabled),
    ]:
        require(not enabled or health["capabilities"][name] == "ready", "AI_CAPABILITY_NOT_READY")
    return {
        "status": "ready",
        "modelVersion": VERSION,
        "authentication": "enforced",
        "confidencePolicy": "UNCONFIGURED",
        "capabilities": health["capabilities"],
    }


if __name__ == "__main__":
    try:
        print(json.dumps({"ok": True, "data": probe(sys.argv[1])}))
    except Exception as error:
        code = str(error) if isinstance(error, RuntimeError) else "AI_PROBE_FAILED"
        if not code.replace("_", "").isupper() or len(code) > 80:
            code = "AI_PROBE_FAILED"
        print(json.dumps({"ok": False, "code": code}))
        sys.exit(1)
