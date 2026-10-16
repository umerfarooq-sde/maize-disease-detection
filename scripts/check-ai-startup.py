"""Opt-in smoke of the actual configured application, without settings overrides."""

import hashlib
import io
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "ai-service"))

from fastapi.testclient import TestClient  # noqa: E402
from PIL import Image  # noqa: E402

from app.config.settings import load_settings  # noqa: E402
from app.main import create_app  # noqa: E402


def main() -> None:
    settings = load_settings()
    if not settings.inference_enabled:
        raise SystemExit("Configured inference is disabled; startup smoke cannot verify a model.")
    headers = {"Authorization": f"Bearer {settings.ai_service_token.get_secret_value()}"}
    with TestClient(create_app(settings)) as client:
        health = client.get("/api/v1/model-health", headers=headers)
        assert health.status_code == 200, "Configured model is not ready"
        image = io.BytesIO()
        Image.new("RGB", (32, 48), (80, 110, 60)).save(image, format="PNG")
        response = client.post(
            "/api/v1/predict",
            content=image.getvalue(),
            headers={**headers, "Content-Type": "image/png"},
        )
        assert response.status_code == 200, "Configured inference smoke failed"
        result = response.json()["data"]
        assert result["modelVersion"] == settings.model_version
        assert result["preprocessingVersion"] == settings.preprocessing_version
        loaded = client.app.state.inference_service.loaded_model
        assert loaded.class_names == (
            "Common_Rust",
            "Gray_Leaf_Spot",
            "Healthy",
            "Northern_Corn_Leaf_Blight",
        )
        assert loaded.calibration_temperature == 1
        if settings.confidence_policy_path is None:
            assert result["confidenceThreshold"] is None
            assert result["predictionStatus"] == "LOW_CONFIDENCE"
            assert result["uncertaintyReason"] == "THRESHOLD_UNCONFIGURED"
        assert settings.model_path is not None and settings.model_metadata_path is not None
        print(
            json.dumps(
                {
                    "configuredStartup": "PASS",
                    "inference": "PASS",
                    "modelVersion": settings.model_version,
                    "classMapping": dict(enumerate(loaded.class_names)),
                    "preprocessingVersion": loaded.preprocessing_version,
                    "metadataSha256": hashlib.sha256(
                        settings.model_metadata_path.read_bytes()
                    ).hexdigest(),
                    "checkpointSha256": hashlib.sha256(
                        settings.model_path.read_bytes()
                    ).hexdigest(),
                    "confidenceThreshold": result["confidenceThreshold"],
                }
            )
        )


if __name__ == "__main__":
    main()
