"""Small transfer-learning baseline and checked, immutable checkpoint loading."""

import hashlib
import io
import json
from collections.abc import Sequence
from pathlib import Path
from typing import cast

import torch
from maizedoctor_preprocessing import PreprocessingConfig
from torch import Tensor, nn
from torchvision.models import mobilenet_v3_small  # type: ignore[import-untyped]

ARCHITECTURE = "mobilenet_v3_small"
WEIGHTS_NAME = "MobileNet_V3_Small_Weights.IMAGENET1K_V1"
WEIGHTS_URL = "https://download.pytorch.org/models/mobilenet_v3_small-047dcff4.pth"
WEIGHTS_SHA256 = "047dcff4addef86ea5bc2eff13c9614dc11f47ab1160d0a71a25e7db994f4e1f"


def build_model(num_classes: int, *, pretrained: bool = True, dropout: float = 0.2) -> nn.Module:
    if num_classes < 2 or not 0 <= dropout < 1:
        raise ValueError("Invalid model class count or dropout.")
    model = cast(
        nn.Module,
        mobilenet_v3_small(
            weights=None,
            progress=False,
            dropout=dropout,
        ),
    )
    if pretrained:
        weight_path = Path(torch.hub.get_dir()) / "checkpoints" / Path(WEIGHTS_URL).name
        weight_path.parent.mkdir(parents=True, exist_ok=True)
        if not weight_path.exists():
            torch.hub.download_url_to_file(
                WEIGHTS_URL, str(weight_path), hash_prefix=WEIGHTS_SHA256, progress=False
            )
        content = weight_path.read_bytes()
        if hashlib.sha256(content).hexdigest() != WEIGHTS_SHA256:
            raise ValueError("Official pretrained weight checksum does not match provenance.")
        # Deserialize the exact verified bytes, including for an existing hub cache.
        state = torch.load(io.BytesIO(content), map_location="cpu", weights_only=True)
        model.load_state_dict(state, strict=True)
    classifier = cast(nn.Sequential, model.classifier)
    final = cast(nn.Linear, classifier[-1])
    classifier[-1] = nn.Linear(final.in_features, num_classes)
    return model


def set_feature_training(model: nn.Module, *, enabled: bool) -> None:
    for parameter in cast(nn.Module, model.features).parameters():
        parameter.requires_grad_(enabled)


def validate_output(model: nn.Module, num_classes: int, *, image_size: int = 224) -> None:
    was_training = model.training
    model.eval()
    with torch.inference_mode():
        output = cast(Tensor, model(torch.zeros(2, 3, image_size, image_size)))
    model.train(was_training)
    if output.shape != (2, num_classes) or not torch.isfinite(output).all():
        raise ValueError("Model output shape or numerical values are invalid.")


def save_checkpoint(destination: Path, payload: dict[str, object]) -> None:
    """Each improving epoch has its own filename, including within one experiment."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("xb") as target:
        torch.save(payload, target)


def read_checkpoint(
    path: Path, *, class_names: Sequence[str], preprocessing_hash: str, manifest_hash: str
) -> dict[str, object]:
    loaded: object = torch.load(path, map_location="cpu", weights_only=True)
    if not isinstance(loaded, dict):
        raise ValueError("Checkpoint payload must be a mapping.")
    payload = cast(dict[str, object], loaded)
    if (
        payload.get("format_version") != 1
        or payload.get("architecture") != ARCHITECTURE
        or payload.get("class_names") != list(class_names)
        or payload.get("preprocessing_hash") != preprocessing_hash
        or payload.get("manifest_fingerprint") != manifest_hash
    ):
        raise ValueError("Checkpoint compatibility metadata does not match this experiment.")
    config = PreprocessingConfig.model_validate_json(json.dumps(payload.get("preprocessing")))
    if config.fingerprint != preprocessing_hash:
        raise ValueError("Checkpoint preprocessing content does not match its hash.")
    state = payload.get("state_dict")
    if not isinstance(state, dict) or not state:
        raise ValueError("Checkpoint model parameters are missing.")
    if any(
        not isinstance(name, str)
        or not isinstance(value, Tensor)
        or not torch.isfinite(value).all()
        for name, value in state.items()
    ):
        raise ValueError("Checkpoint model parameters are invalid.")
    return payload


def restore_checkpoint(model: nn.Module, payload: dict[str, object], num_classes: int) -> None:
    state = cast(dict[str, Tensor], payload["state_dict"])
    model.load_state_dict(state, strict=True)
    validate_output(model, num_classes)
    model.eval()
