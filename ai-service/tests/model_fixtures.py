"""Offline architecture-compatible synthetic artifacts; no trained weights or raw images."""

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import cast

import torch
from pydantic import JsonValue
from torch import nn
from torchvision.models import mobilenet_v3_small  # type: ignore[import-untyped]

from app.model_management.artifacts import LoadedModel, load_model

REPORT_ROOT = (
    Path(__file__).resolve().parents[2]
    / "ml-training/reports/mobilenet-v3-small-20261009-v2-01-fitness"
)


@dataclass(frozen=True)
class ModelFixture:
    checkpoint_path: Path
    metadata_path: Path
    model_version: str
    preprocessing_version: str

    @property
    def metadata_sha256(self) -> str:
        return hashlib.sha256(self.metadata_path.read_bytes()).hexdigest()

    def load(self) -> LoadedModel:
        return load_model(
            checkpoint_path=self.checkpoint_path,
            metadata_path=self.metadata_path,
            metadata_sha256=self.metadata_sha256,
            model_version=self.model_version,
            preprocessing_version=self.preprocessing_version,
            threads=2,
        )


def read_json(path: Path) -> dict[str, JsonValue]:
    return cast(dict[str, JsonValue], json.loads(path.read_bytes()))


def write_json(path: Path, payload: dict[str, JsonValue]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, allow_nan=False) + "\n", encoding="utf-8")


def section(payload: dict[str, JsonValue], name: str) -> dict[str, JsonValue]:
    value = payload[name]
    assert isinstance(value, dict)
    return value


def refresh_checkpoint_pins(fixture: ModelFixture) -> None:
    metadata = read_json(fixture.metadata_path)
    checkpoint = section(metadata, "checkpoint")
    checkpoint["sha256"] = hashlib.sha256(fixture.checkpoint_path.read_bytes()).hexdigest()
    checkpoint["size_bytes"] = fixture.checkpoint_path.stat().st_size
    sidecar_path = fixture.metadata_path.parent / "calibration/calibration-config.json"
    sidecar = read_json(sidecar_path)
    sidecar["checkpoint_sha256"] = checkpoint["sha256"]
    write_json(sidecar_path, sidecar)
    reference = section(section(metadata, "calibration"), "configuration")
    reference["sha256"] = hashlib.sha256(sidecar_path.read_bytes()).hexdigest()
    reference["size_bytes"] = sidecar_path.stat().st_size
    write_json(fixture.metadata_path, metadata)


def write_model_fixture(root: Path, *, class_index: int | None = None) -> ModelFixture:
    """None yields uniform scores; 0..3 yields that literal class at high confidence."""
    if class_index is not None and not 0 <= class_index < 4:
        raise ValueError("Fixture class index must be between zero and three")
    root.mkdir(parents=True, exist_ok=True)
    metadata = read_json(REPORT_ROOT / "model-artifact.json")
    model = cast(nn.Module, mobilenet_v3_small(weights=None, progress=False, dropout=0.2))
    classifier = cast(nn.Sequential, model.classifier)
    last = cast(nn.Linear, classifier[-1])
    classifier[-1] = nn.Linear(last.in_features, 4)
    final = cast(nn.Linear, classifier[-1])
    with torch.no_grad():
        final.weight.zero_()
        final.bias.zero_()
        if class_index is not None:
            final.bias[class_index] = 10.0
    training = section(metadata, "training")
    dataset = section(metadata, "dataset")
    preprocessing = section(metadata, "preprocessing")
    payload: dict[str, object] = {
        "format_version": 1,
        "architecture": metadata["architecture"],
        "class_names": [
            item["label"] for item in cast(list[dict[str, JsonValue]], metadata["classes"])
        ],
        "class_to_index": metadata["class_to_index"],
        "experiment_id": metadata["training_experiment_id"],
        "dataset_version": dataset["version"],
        "epoch": training["selected_epoch"],
        "dropout": section(training, "hyperparameters")["dropout"],
        "seed": training["seed"],
        "manifest_fingerprint": dataset["manifest_fingerprint"],
        "preprocessing_hash": preprocessing["semantic_sha256"],
        "preprocessing_version": preprocessing["version"],
        "preprocessing": preprocessing["configuration"],
        "hyperparameters": training["hyperparameters"],
        "state_dict": model.state_dict(),
    }
    checkpoint_path = root / "synthetic.pt"
    torch.save(payload, checkpoint_path)
    metadata_path = root / "model-artifact.json"
    write_json(metadata_path, metadata)
    write_json(
        root / "calibration/calibration-config.json",
        read_json(REPORT_ROOT / "calibration/calibration-config.json"),
    )
    fixture = ModelFixture(
        checkpoint_path=checkpoint_path,
        metadata_path=metadata_path,
        model_version=cast(str, metadata["model_version"]),
        preprocessing_version=cast(str, preprocessing["version"]),
    )
    refresh_checkpoint_pins(fixture)
    return fixture
