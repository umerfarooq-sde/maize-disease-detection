"""Verify serving against frozen Phase 10.5 TRAIN evidence without touching TEST.

Uses configured service artifacts and DATASET_PATH. Outputs only safe numeric
metadata under a new ignored .cache destination; never saves source photographs.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import statistics
import sys
from pathlib import Path
from typing import cast

REPOSITORY = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if not output.is_relative_to((REPOSITORY / ".cache").resolve()) or output.exists():
        parser.error("Choose a new ignored .cache output file")

    sys.path.insert(0, str(REPOSITORY / "ml-training"))
    sys.path.insert(0, str(REPOSITORY / "ai-service"))
    import torch
    from app.config.settings import load_settings
    from app.inference.service import InferenceService
    from app.main import create_app
    from configuration import load_dataset_path
    from dataset_preparation import load_manifest
    from fastapi.testclient import TestClient
    from torch import nn

    report = (
        REPOSITORY / "ml-training/reports/mobilenet-v3-small-20261009-v2-01-fitness"
    )
    offline = json.loads(
        (report / "audits/offline-model-compatibility-v2.json").read_bytes()
    )
    manifest = load_manifest(
        REPOSITORY / "ml-training/manifests/maize-research-20261008-v2/manifest.json"
    )
    rows = {row.sample_id: row for row in manifest.rows_for_split("train")}
    expected = offline["environments"][0]["cases"]
    assert len(expected) == 16 and all(case["sample_id"] in rows for case in expected)
    dataset = load_dataset_path()
    settings = load_settings()
    application = create_app(settings)
    headers = {
        "Authorization": f"Bearer {settings.ai_service_token.get_secret_value()}"
    }
    captured: dict[str, str] = {}

    def capture(
        _model: nn.Module, arguments: tuple[object, ...], result: object
    ) -> None:
        tensor = arguments[0]
        assert isinstance(tensor, torch.Tensor) and isinstance(result, torch.Tensor)
        captured["tensor_sha256"] = hashlib.sha256(
            tensor[0].numpy().tobytes()
        ).hexdigest()
        captured["logits_sha256"] = hashlib.sha256(result.numpy().tobytes()).hexdigest()

    cases = []
    with TestClient(application) as client:
        service = cast(InferenceService, application.state.inference_service)
        loaded = service.loaded_model
        assert (
            loaded.checkpoint_sha256 == offline["environments"][0]["checkpoint_sha256"]
        )
        assert loaded.config.fingerprint == manifest.preprocessing_hash
        assert loaded.manifest_fingerprint == manifest.fingerprint
        hook = loaded.model.register_forward_hook(capture)
        try:
            for case in expected:
                row = rows[case["sample_id"]]
                path = dataset / row.relative_path
                content = path.read_bytes()
                assert hashlib.sha256(content).hexdigest() == row.content_hash
                suffix = path.suffix.lower()
                mime = {
                    ".jpg": "image/jpeg",
                    ".jpeg": "image/jpeg",
                    ".png": "image/png",
                    ".webp": "image/webp",
                }[suffix]
                response = client.post(
                    "/api/v1/predict",
                    content=content,
                    headers={**headers, "Content-Type": mime},
                )
                assert response.status_code == 200
                result = response.json()["data"]
                assert captured["tensor_sha256"] == case["tensor_sha256"]
                assert captured["logits_sha256"] == case["logits_sha256"]
                assert result["modelVersion"] == loaded.model_version
                assert result["preprocessingVersion"] == loaded.preprocessing_version
                assert result["predictionStatus"] == "LOW_CONFIDENCE"
                assert result["uncertaintyReason"] == "THRESHOLD_UNCONFIGURED"
                cases.append(
                    {
                        "sample_id": row.sample_id,
                        "class_index": row.class_index,
                        **captured,
                        "duration_ms": result["inferenceDurationMs"],
                    }
                )
        finally:
            hook.remove()
        health = client.get("/api/v1/model-health", headers=headers).json()["data"]
    assert application.state.inference_service is None
    durations = [float(case["duration_ms"]) for case in cases]
    result = {
        "passed": True,
        "partitions_used": ["train"],
        "case_count": len(cases),
        "class_counts": {
            label: sum(case["class_index"] == index for case in cases)
            for index, label in enumerate(loaded.class_names)
        },
        "checkpoint_sha256": loaded.checkpoint_sha256,
        "manifest_fingerprint": manifest.fingerprint,
        "preprocessing_hash": loaded.config.fingerprint,
        "model_health": health,
        "exact_training_tensors_and_logits": True,
        "model_loads": "once in the application lifespan",
        "shutdown_clears_readiness": True,
        "inference_duration_ms": {
            "mean": statistics.mean(durations),
            "median": statistics.median(durations),
            "minimum": min(durations),
            "maximum": max(durations),
            "samples": len(durations),
            "includes_decode_preprocessing_tensor_model_probability_response_data": True,
            "includes_http_transfer": False,
            "threads": settings.inference_threads,
            "limitation": "Local representative TRAIN inputs, not a concurrency SLA or field accuracy.",
        },
        "cases": cases,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("x", encoding="utf-8") as stream:
        stream.write(json.dumps(result, indent=2, allow_nan=False) + "\n")
    print(json.dumps({key: value for key, value in result.items() if key != "cases"}))


if __name__ == "__main__":
    main()
