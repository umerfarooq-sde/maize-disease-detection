"""Load the approved CPU classifier once from verified deployment artifacts.

Deploy three files: the checkpoint, the configured final ``model-artifact.json``
and its sibling ``calibration/calibration-config.json``. The configuration pins
the metadata digest; that metadata pins both remaining files. Training datasets,
historical reports, caches and training code are not runtime dependencies.
"""

import hashlib
import io
import json
import pickle
import re
from dataclasses import dataclass
from importlib.metadata import PackageNotFoundError, version
from pathlib import Path
from typing import Literal, cast

import torch
from maizedoctor_preprocessing import (
    PREPROCESSING_VERSION,
    NormalizationConfig,
    PreprocessingConfig,
    SegmentationConfig,
)
from pydantic import BaseModel, ConfigDict, Field, JsonValue, ValidationError
from torch import Tensor, nn
from torchvision.models import mobilenet_v3_small  # type: ignore[import-untyped]

CLASS_NAMES = (
    "Common_Rust",
    "Gray_Leaf_Spot",
    "Healthy",
    "Northern_Corn_Leaf_Blight",
)
_METADATA_LIMIT = 512 * 1024
_CHECKPOINT_LIMIT = 32 * 1024 * 1024


class ModelStartupError(Exception):
    """Fail startup without disclosing paths or rejected artifact content."""

    def __init__(self, code: str) -> None:
        self.code = code
        super().__init__(f"Model startup failed ({code}); check the configured model artifacts.")


@dataclass(frozen=True)
class LoadedModel:
    model: nn.Module
    config: PreprocessingConfig
    class_names: tuple[str, ...]
    model_version: str
    preprocessing_version: str
    checkpoint_sha256: str
    manifest_fingerprint: str
    validation_predictions_sha256: str
    calibration_temperature: float
    confidence_threshold: float | None


class _Metadata(BaseModel):
    """Strict required compatibility subset; other report fields are retained elsewhere."""

    model_config = ConfigDict(
        strict=True, extra="ignore", frozen=True, allow_inf_nan=False, hide_input_in_errors=True
    )


class _Reference(_Metadata):
    sha256: str = Field(pattern=r"^[a-f0-9]{64}$")
    size_bytes: int = Field(gt=0)


class _CheckpointReference(_Reference):
    selected_epoch: int = Field(ge=1)


class _Class(_Metadata):
    label: str
    index: int


class _Normalization(_Metadata):
    decoded_byte_range: list[int]
    formula: str
    mean: list[float]
    std: list[float]


class _Input(_Metadata):
    shape: list[int]
    color_space: Literal["RGB"]
    layout: Literal["NCHW"]
    dtype: Literal["float32"]
    resize: Literal["aspect-preserving bilinear letterbox; white padding"]
    normalization: _Normalization


class _Preprocessing(_Metadata):
    version: str
    semantic_sha256: str = Field(pattern=r"^[a-f0-9]{64}$")
    segmentation_policy: Literal["disabled; full oriented frame retained"]
    configuration: dict[str, JsonValue]


class _Dataset(_Metadata):
    version: str
    manifest_fingerprint: str = Field(pattern=r"^[a-f0-9]{64}$")


class _Training(_Metadata):
    seed: int
    selected_epoch: int
    hyperparameters: dict[str, JsonValue]
    final_test_deferred_during_fit: Literal[True]


class _Calibration(_Metadata):
    enabled: Literal[False]
    temperature: float = Field(ge=1.0, le=1.0)
    method: Literal["none"]
    operational_threshold: None
    diagnostic_fitted_temperature_applied: Literal[False]
    no_test_refit: Literal[True]
    configuration: _Reference


class _Distribution(_Metadata):
    name: str
    version: str


class _Environment(_Metadata):
    torch: str
    distributions: list[_Distribution]


class _ResearchPolicy(_Metadata):
    commercial_clearance: Literal[False]
    permitted_use: Literal["non-commercial academic/FYP research only"]
    raw_image_redistribution: Literal[False]


class _Artifact(_Metadata):
    schema_version: Literal[1]
    model_version: str
    candidate_id: str
    training_experiment_id: str
    architecture: Literal["mobilenet_v3_small"]
    parameter_count: Literal[1521956]
    verdict: Literal["FIT WITH DOCUMENTED LIMITATIONS"]
    readiness_scope: str = Field(min_length=1)
    production_model_promoted: Literal[False]
    checkpoint: _CheckpointReference
    classes: list[_Class]
    class_to_index: dict[str, int]
    input: _Input
    preprocessing: _Preprocessing
    dataset: _Dataset
    training: _Training
    calibration: _Calibration
    environment: _Environment
    research_policy: _ResearchPolicy


class _CalibrationSidecar(_Metadata):
    checkpoint_sha256: str = Field(pattern=r"^[a-f0-9]{64}$")
    classifier_experiment_id: str
    class_names: list[str]
    dataset_version: str
    manifest_fingerprint: str
    preprocessing_hash: str
    preprocessing_version: str
    validation_csv_sha256: str = Field(pattern=r"^[a-f0-9]{64}$")
    calibration: dict[str, JsonValue]
    temperature: float = Field(ge=1.0, le=1.0)
    calibration_method: Literal["none"]
    operational_threshold: None
    test_probabilities_read: Literal[False]
    test_application_performed: Literal[False]
    valid_for_candidate_promotion: Literal[True]


class _CheckpointMetadata(_Metadata):
    format_version: Literal[1]
    architecture: Literal["mobilenet_v3_small"]
    class_names: list[str]
    class_to_index: dict[str, int]
    experiment_id: str
    dataset_version: str
    epoch: int
    dropout: float = Field(ge=0, lt=1)
    seed: int
    manifest_fingerprint: str
    preprocessing_hash: str
    preprocessing_version: str
    preprocessing: dict[str, JsonValue]
    hyperparameters: dict[str, JsonValue]


def _read_verified(
    path: Path, *, expected_sha256: str, limit: int, prefix: str, size_bytes: int | None = None
) -> bytes:
    if not re.fullmatch(r"[a-f0-9]{64}", expected_sha256):
        raise ModelStartupError("MODEL_CONFIGURATION_INVALID")
    try:
        with path.open("rb") as source:
            encoded = source.read(limit + 1)
    except OSError:
        raise ModelStartupError(f"{prefix}_MISSING") from None
    if (
        not encoded
        or len(encoded) > limit
        or (size_bytes is not None and len(encoded) != size_bytes)
    ):
        raise ModelStartupError(f"{prefix}_INVALID")
    if hashlib.sha256(encoded).hexdigest() != expected_sha256:
        raise ModelStartupError(f"{prefix}_HASH_MISMATCH")
    return encoded


def _explicit_config(configuration: dict[str, JsonValue]) -> PreprocessingConfig:
    """Require every recorded setting, including otherwise optional shared defaults."""
    normalization = configuration.get("normalization")
    segmentation = configuration.get("segmentation")
    if (
        set(configuration) != set(PreprocessingConfig.model_fields)
        or not isinstance(normalization, dict)
        or set(normalization) != set(NormalizationConfig.model_fields)
        or not isinstance(segmentation, dict)
        or set(segmentation) != set(SegmentationConfig.model_fields)
    ):
        raise ModelStartupError("MODEL_PREPROCESSING_INCOMPATIBLE")
    return PreprocessingConfig.model_validate_json(json.dumps(configuration, allow_nan=False))


def _validate_artifact(
    artifact: _Artifact, *, model_version: str, preprocessing_version: str
) -> PreprocessingConfig:
    config = _explicit_config(artifact.preprocessing.configuration)
    expected_classes = {name: index for index, name in enumerate(CLASS_NAMES)}
    normalization = artifact.input.normalization
    if (
        artifact.model_version != model_version
        or artifact.candidate_id != model_version
        or artifact.preprocessing.version != preprocessing_version
        or preprocessing_version != PREPROCESSING_VERSION
        or config.preprocessing_version != preprocessing_version
        or config.fingerprint != artifact.preprocessing.semantic_sha256
        or [(item.label, item.index) for item in artifact.classes] != list(expected_classes.items())
        or artifact.class_to_index != expected_classes
        or artifact.input.shape != [1, 3, 224, 224]
        or (config.target_height, config.target_width) != (224, 224)
        or config.segmentation.mode != "disabled"
        or config.interpolation != "bilinear"
        or config.background_rgb != (255, 255, 255)
        or config.normalization.mean != (0.485, 0.456, 0.406)
        or config.normalization.std != (0.229, 0.224, 0.225)
        or normalization.mean != list(config.normalization.mean)
        or normalization.std != list(config.normalization.std)
        or normalization.decoded_byte_range != [0, 255]
        or normalization.formula != "((RGB / 255.0) - mean) / std"
        or artifact.training.selected_epoch != artifact.checkpoint.selected_epoch
    ):
        raise ModelStartupError("MODEL_METADATA_INCOMPATIBLE")
    _validate_runtime(artifact)
    return config


def _validate_runtime(artifact: _Artifact) -> None:
    distributions = artifact.environment.distributions
    recorded = {distribution.name: distribution.version for distribution in distributions}
    if len(recorded) != len(distributions) or recorded.get("torch") != artifact.environment.torch:
        raise ModelStartupError("MODEL_RUNTIME_INCOMPATIBLE")
    # Exact inference/preprocessing dependencies preserve the independently checked CPU parity.
    for package in ("torch", "torchvision", "maizedoctor-preprocessing", "numpy", "pillow"):
        try:
            installed = version(package)
        except PackageNotFoundError:
            raise ModelStartupError("MODEL_RUNTIME_INCOMPATIBLE") from None
        if recorded.get(package) != installed:
            raise ModelStartupError("MODEL_RUNTIME_INCOMPATIBLE")
    recorded_opencv = recorded.get("opencv-python")
    try:
        installed_opencv = version("opencv-python")
    except PackageNotFoundError:
        try:
            installed_opencv = version("opencv-python-headless")
        except PackageNotFoundError:
            raise ModelStartupError("MODEL_RUNTIME_INCOMPATIBLE") from None
    if recorded_opencv != installed_opencv:
        raise ModelStartupError("MODEL_RUNTIME_INCOMPATIBLE")


def _validate_calibration(artifact: _Artifact, sidecar: _CalibrationSidecar) -> None:
    if (
        sidecar.checkpoint_sha256 != artifact.checkpoint.sha256
        or sidecar.classifier_experiment_id != artifact.training_experiment_id
        or sidecar.class_names != list(CLASS_NAMES)
        or sidecar.dataset_version != artifact.dataset.version
        or sidecar.manifest_fingerprint != artifact.dataset.manifest_fingerprint
        or sidecar.preprocessing_hash != artifact.preprocessing.semantic_sha256
        or sidecar.preprocessing_version != artifact.preprocessing.version
        or sidecar.calibration != {"enabled": False, "method": "none", "temperature": 1.0}
    ):
        raise ModelStartupError("MODEL_CALIBRATION_INCOMPATIBLE")


def _restore_model(encoded: bytes, artifact: _Artifact, config: PreprocessingConfig) -> nn.Module:
    payload: object = torch.load(io.BytesIO(encoded), map_location="cpu", weights_only=True)
    if not isinstance(payload, dict):
        raise ModelStartupError("MODEL_CHECKPOINT_INVALID")
    checked = _CheckpointMetadata.model_validate(payload)
    if (
        checked.class_names != list(CLASS_NAMES)
        or checked.class_to_index != artifact.class_to_index
        or checked.experiment_id != artifact.training_experiment_id
        or checked.dataset_version != artifact.dataset.version
        or checked.epoch != artifact.checkpoint.selected_epoch
        or checked.seed != artifact.training.seed
        or checked.manifest_fingerprint != artifact.dataset.manifest_fingerprint
        or checked.preprocessing_hash != config.fingerprint
        or checked.preprocessing_version != config.preprocessing_version
        or checked.preprocessing != artifact.preprocessing.configuration
        or checked.hyperparameters != artifact.training.hyperparameters
        or checked.dropout != artifact.training.hyperparameters.get("dropout")
    ):
        raise ModelStartupError("MODEL_CHECKPOINT_INCOMPATIBLE")
    state: object = payload.get("state_dict")
    if not isinstance(state, dict) or not state:
        raise ModelStartupError("MODEL_CHECKPOINT_INVALID")
    if any(
        not isinstance(name, str)
        or not isinstance(value, Tensor)
        or not bool(torch.isfinite(value).all())
        for name, value in state.items()
    ):
        raise ModelStartupError("MODEL_CHECKPOINT_INVALID")
    model = cast(
        nn.Module,
        mobilenet_v3_small(weights=None, progress=False, dropout=checked.dropout),
    )
    classifier = cast(nn.Sequential, model.classifier)
    final = cast(nn.Linear, classifier[-1])
    classifier[-1] = nn.Linear(final.in_features, len(CLASS_NAMES))
    typed_state = cast(dict[str, Tensor], state)
    expected_state = model.state_dict()
    if set(typed_state) != set(expected_state) or any(
        tensor.dtype != expected_state[name].dtype or tensor.shape != expected_state[name].shape
        for name, tensor in typed_state.items()
    ):
        raise ModelStartupError("MODEL_CHECKPOINT_INCOMPATIBLE")
    model.load_state_dict(typed_state, strict=True)
    model.requires_grad_(False)
    model.eval()
    if sum(parameter.numel() for parameter in model.parameters()) != artifact.parameter_count:
        raise ModelStartupError("MODEL_CHECKPOINT_INCOMPATIBLE")
    with torch.inference_mode():
        output: object = model(torch.zeros(1, 3, config.target_height, config.target_width))
    if (
        not isinstance(output, Tensor)
        or output.shape != (1, len(CLASS_NAMES))
        or output.dtype != torch.float32
        or not bool(torch.isfinite(output).all())
    ):
        raise ModelStartupError("MODEL_OUTPUT_INVALID")
    return model


def load_model(
    *,
    checkpoint_path: Path,
    metadata_path: Path,
    metadata_sha256: str,
    model_version: str,
    preprocessing_version: str,
    threads: int,
) -> LoadedModel:
    """Verify all configuration before exposing a ready, frozen CPU model."""
    if isinstance(threads, bool) or not 1 <= threads <= 8:
        raise ModelStartupError("MODEL_CONFIGURATION_INVALID")
    encoded_metadata = _read_verified(
        metadata_path,
        expected_sha256=metadata_sha256,
        limit=_METADATA_LIMIT,
        prefix="MODEL_METADATA",
    )
    try:
        artifact = _Artifact.model_validate_json(encoded_metadata)
        config = _validate_artifact(
            artifact, model_version=model_version, preprocessing_version=preprocessing_version
        )
        encoded_calibration = _read_verified(
            metadata_path.parent / "calibration" / "calibration-config.json",
            expected_sha256=artifact.calibration.configuration.sha256,
            size_bytes=artifact.calibration.configuration.size_bytes,
            limit=_METADATA_LIMIT,
            prefix="MODEL_CALIBRATION",
        )
        sidecar = _CalibrationSidecar.model_validate_json(encoded_calibration)
        _validate_calibration(artifact, sidecar)
        encoded_checkpoint = _read_verified(
            checkpoint_path,
            expected_sha256=artifact.checkpoint.sha256,
            size_bytes=artifact.checkpoint.size_bytes,
            limit=_CHECKPOINT_LIMIT,
            prefix="MODEL_CHECKPOINT",
        )
        torch.set_num_threads(threads)
        model = _restore_model(encoded_checkpoint, artifact, config)
    except ModelStartupError:
        raise
    except (
        ValidationError,
        ValueError,
        TypeError,
        RuntimeError,
        OSError,
        EOFError,
        IndexError,
        KeyError,
        UnicodeError,
        pickle.UnpicklingError,
    ):
        raise ModelStartupError("MODEL_ARTIFACT_INVALID") from None
    return LoadedModel(
        model=model,
        config=config,
        class_names=CLASS_NAMES,
        model_version=artifact.model_version,
        preprocessing_version=config.preprocessing_version,
        checkpoint_sha256=artifact.checkpoint.sha256,
        manifest_fingerprint=artifact.dataset.manifest_fingerprint,
        validation_predictions_sha256=sidecar.validation_csv_sha256,
        calibration_temperature=artifact.calibration.temperature,
        confidence_threshold=artifact.calibration.operational_threshold,
    )
