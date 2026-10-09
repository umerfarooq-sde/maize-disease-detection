"""Hash-bound research candidate metadata; no serving or production promotion."""

from __future__ import annotations

import csv
import hashlib
from pathlib import Path, PurePosixPath
from typing import Literal

import numpy as np
from maizedoctor_preprocessing import PreprocessingConfig
from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    JsonValue,
    TypeAdapter,
    field_validator,
    model_validator,
)

from dataset_preparation import CLASS_LABELS, ClassDefinition, Digest, load_manifest
from evaluation import compute_metrics
from fitness_integrity import verify_artifact_hashes
from model import ARCHITECTURE, read_checkpoint

ArtifactRole = Literal[
    "weights",
    "index",
    "metadata",
    "source",
    "decision_freeze",
    "diagnostic",
    "training_summary",
    "training_environment",
    "training_configuration",
    "training_experiment",
    "validation_predictions",
    "validation_metrics",
    "calibration_configuration",
]
REQUIRED_ROLES: tuple[ArtifactRole, ...] = (
    "weights",
    "index",
    "decision_freeze",
    "training_summary",
    "training_environment",
    "training_configuration",
    "training_experiment",
    "validation_predictions",
    "validation_metrics",
    "calibration_configuration",
)


class ArtifactReference(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid", strict=True)

    role: ArtifactRole
    path: str
    sha256: Digest

    @field_validator("path")
    @classmethod
    def safe_relative_path(cls, value: str) -> str:
        path = PurePosixPath(value)
        if (
            not value
            or path.is_absolute()
            or "\\" in value
            or any(part in {".", "..", ""} or ":" in part for part in value.split("/"))
            or path.as_posix() != value
        ):
            raise ValueError("Artifact references must be safe repository-relative paths.")
        return value


class CalibrationDefinition(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid", strict=True)

    enabled: bool
    temperature: float = Field(gt=0, allow_inf_nan=False)
    method: Literal["validation_group_crossfit_temperature", "none"]

    @model_validator(mode="after")
    def coherent_policy(self) -> CalibrationDefinition:
        if self.enabled != (self.method != "none"):
            raise ValueError("Calibration enabled flag and method must agree.")
        if not self.enabled and self.temperature != 1.0:
            raise ValueError("Disabled calibration must preserve raw probabilities.")
        return self


class FitnessBundle(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid", strict=True)

    format_version: Literal[1] = 1
    candidate_id: str = Field(min_length=1)
    training_experiment_id: str = Field(min_length=1)
    architecture: Literal["mobilenet_v3_small"]
    classes: tuple[ClassDefinition, ...]
    preprocessing: PreprocessingConfig
    preprocessing_hash: Digest
    preprocessing_policy: Literal["shared_full_frame"]
    dataset_version: str
    manifest_fingerprint: Digest
    split_seed: int
    training_seed: int
    calibration: CalibrationDefinition
    confidence_threshold: float | None = Field(ge=0, le=1, allow_inf_nan=False)
    confidence_threshold_status: Literal["unlocked", "validation_selected"]
    test_status: Literal["previously_consumed_descriptive"]
    test_used_for_selection: Literal[False]
    academic_noncommercial_only: Literal[True]
    raw_image_redistribution: Literal[False]
    commercial_clearance: Literal[False]
    ready_for_phase11: bool
    verdict: Literal[
        "FIT FOR PHASE 11",
        "FIT WITH DOCUMENTED LIMITATIONS",
        "NOT FIT — RETRAINING REQUIRED",
        "INVALID EVALUATION — DATA/SPLIT PROBLEM",
    ]
    references: tuple[ArtifactReference, ...]

    @model_validator(mode="after")
    def coherent_bundle(self) -> FitnessBundle:
        if tuple(item.label for item in self.classes) != CLASS_LABELS or tuple(
            item.index for item in self.classes
        ) != tuple(range(len(CLASS_LABELS))):
            raise ValueError("The literal ordered four-class mapping must be preserved.")
        if self.preprocessing.fingerprint != self.preprocessing_hash:
            raise ValueError("Preprocessing content and fingerprint disagree.")
        if self.preprocessing.segmentation.mode != "disabled":
            raise ValueError("This candidate requires the approved full-frame policy.")
        if (self.confidence_threshold is None) != (self.confidence_threshold_status == "unlocked"):
            raise ValueError("A locked threshold requires its validation-selected value.")
        if self.ready_for_phase11 != self.verdict.startswith("FIT"):
            raise ValueError("Readiness must agree with the model fitness verdict.")
        roles = [reference.role for reference in self.references]
        for role in REQUIRED_ROLES:
            if roles.count(role) != 1:
                raise ValueError(f"Exactly one {role} reference is required.")
        if len({reference.path for reference in self.references}) != len(self.references):
            raise ValueError("Artifact reference paths must be unique.")
        return self


def artifact_reference(path: Path, repository: Path, role: ArtifactRole) -> ArtifactReference:
    """Describe existing bytes; the machine-specific dataset path never enters metadata."""
    root = repository.resolve(strict=True)
    resolved = path.resolve(strict=True)
    if not resolved.is_relative_to(root) or not resolved.is_file():
        raise ValueError("Artifact file must remain within the repository.")
    return ArtifactReference(
        role=role,
        path=resolved.relative_to(root).as_posix(),
        sha256=hashlib.sha256(resolved.read_bytes()).hexdigest(),
    )


def verify_references(references: tuple[ArtifactReference, ...], repository: Path) -> None:
    verify_artifact_hashes(repository, {item.path: item.sha256 for item in references})


def _object(path: Path) -> dict[str, JsonValue]:
    return TypeAdapter(dict[str, JsonValue]).validate_json(path.read_bytes())


def _binding(
    actual: dict[str, JsonValue] | dict[str, object], expected: dict[str, object], name: str
) -> None:
    for key, value in expected.items():
        observed = actual.get(key)
        if (
            key not in actual
            or observed != value
            or (isinstance(value, bool) and observed is not value)
            or (type(value) is int and type(observed) is not int)
        ):
            raise ValueError(f"{name} metadata binding differs: {key}.")


def _digest_mapping(value: JsonValue | None, name: str) -> None:
    if not isinstance(value, dict) or not value:
        raise ValueError(f"{name} must include nonempty source hashes.")
    for path, digest in value.items():
        if (
            not isinstance(digest, str)
            or len(digest) != 64
            or any(c not in "0123456789abcdef" for c in digest)
        ):
            raise ValueError(f"{name} contains an invalid source hash.")
        ArtifactReference.safe_relative_path(path)


def _validation_metrics(path: Path, manifest_path: Path) -> dict[str, object]:
    """Recompute from VALIDATION rows only; no image loading or test access."""
    manifest = load_manifest(manifest_path)
    by_id = {row.sample_id: row for row in manifest.rows_for_split("validation")}
    with path.open(encoding="utf-8", newline="") as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames != ["sample_id", "true_index", "predicted_index", *CLASS_LABELS]:
            raise ValueError("Validation predictions have an invalid schema.")
        rows = list(reader)
    if [row["sample_id"] for row in rows] != list(manifest.splits.validation):
        raise ValueError("Validation predictions differ from exact immutable split membership.")
    try:
        labels = np.array([int(row["true_index"]) for row in rows], dtype=np.int64)
        probabilities = np.array(
            [[float(row[label]) for label in CLASS_LABELS] for row in rows], dtype=np.float64
        )
        predictions = np.array([int(row["predicted_index"]) for row in rows], dtype=np.int64)
    except (ValueError, TypeError) as error:
        raise ValueError("Validation prediction values are malformed.") from error
    if not all(
        int(labels[index]) == by_id[row["sample_id"]].class_index for index, row in enumerate(rows)
    ):
        raise ValueError("Validation labels disagree with the immutable class mapping.")
    if not np.array_equal(predictions, probabilities.argmax(axis=1)):
        raise ValueError("Validation predicted indices disagree with probabilities.")
    return dict(compute_metrics(labels, probabilities, CLASS_LABELS))


def validate_bundle(path: Path, repository: Path) -> FitnessBundle:
    """Fail closed on byte, class, preprocessing, index or checkpoint disagreement."""
    bundle = FitnessBundle.model_validate_json(path.read_bytes())
    verify_references(bundle.references, repository)
    by_role = {item.role: item for item in bundle.references}
    manifest = load_manifest(repository / by_role["index"].path)
    if (
        manifest.version != bundle.dataset_version
        or manifest.fingerprint != bundle.manifest_fingerprint
        or manifest.preprocessing_hash != bundle.preprocessing_hash
        or manifest.split_seed != bundle.split_seed
        or manifest.classes != bundle.classes
        or bundle.architecture != ARCHITECTURE
    ):
        raise ValueError("Candidate and immutable dataset manifest disagree.")
    payload = read_checkpoint(
        repository / by_role["weights"].path,
        class_names=CLASS_LABELS,
        preprocessing_hash=bundle.preprocessing_hash,
        manifest_hash=bundle.manifest_fingerprint,
    )
    configuration = _object(repository / by_role["training_configuration"].path)
    _binding(
        configuration,
        {"seed": bundle.training_seed, "defer_test": True, "smoke": False},
        "Training configuration",
    )
    if type(configuration.get("seed")) is not int or configuration.get("defer_test") is not True:
        raise ValueError("Training seed and deferred flag require strict types.")
    _binding(
        payload,
        {
            "experiment_id": bundle.training_experiment_id,
            "seed": bundle.training_seed,
            "class_to_index": {label: index for index, label in enumerate(CLASS_LABELS)},
            "preprocessing_version": bundle.preprocessing.preprocessing_version,
            "preprocessing": bundle.preprocessing.model_dump(mode="json"),
            "dataset_version": bundle.dataset_version,
            "hyperparameters": configuration,
        },
        "Checkpoint",
    )
    if type(payload.get("seed")) is not int:
        raise ValueError("Checkpoint training seed must be an integer.")
    class_map = payload.get("class_to_index")
    if not isinstance(class_map, dict) or any(
        type(index) is not int for index in class_map.values()
    ):
        raise ValueError("Checkpoint class indices must be integers.")
    summary = _object(repository / by_role["training_summary"].path)
    _binding(
        summary,
        {
            "status": "completed",
            "mode": "full",
            "experiment_id": bundle.training_experiment_id,
            "final_test_deferred": True,
            "test_evaluated_once": False,
            "test_metrics": None,
            "best_epoch": payload.get("epoch"),
            "best_checkpoint_sha256": by_role["weights"].sha256,
            "manifest_fingerprint": bundle.manifest_fingerprint,
            "preprocessing_hash": bundle.preprocessing_hash,
            "train_samples": len(manifest.splits.train),
            "validation_samples": len(manifest.splits.validation),
        },
        "Training summary",
    )
    if (
        summary.get("final_test_deferred") is not True
        or summary.get("test_evaluated_once") is not False
    ):
        raise ValueError("Training must defer its unconsumed test before final evaluation.")
    experiment = _object(repository / by_role["training_experiment"].path)
    _binding(
        experiment,
        {
            "experiment_id": bundle.training_experiment_id,
            "mode": "full",
            "architecture": bundle.architecture,
            "dataset_version": bundle.dataset_version,
            "manifest_fingerprint": bundle.manifest_fingerprint,
            "preprocessing_hash": bundle.preprocessing_hash,
            "preprocessing_version": bundle.preprocessing.preprocessing_version,
            "final_test_deferred": True,
            "test_selection_usage": "never",
        },
        "Training experiment",
    )
    environment = _object(repository / by_role["training_environment"].path)
    if any(
        not isinstance(environment.get(key), str) or not environment[key]
        for key in ("python", "torch")
    ):
        raise ValueError("Training environment must identify Python and PyTorch versions.")
    distributions = environment.get("distributions")
    if (
        not isinstance(distributions, list)
        or not distributions
        or any(
            not isinstance(item, dict)
            or not isinstance(item.get("name"), str)
            or not item.get("name")
            or not isinstance(item.get("version"), str)
            or not item.get("version")
            for item in distributions
        )
    ):
        raise ValueError("Training environment must record dependency versions.")
    _digest_mapping(environment.get("source_hashes"), "Training environment")
    calculated = _validation_metrics(
        repository / by_role["validation_predictions"].path, repository / by_role["index"].path
    )
    metrics = _object(repository / by_role["validation_metrics"].path)
    _binding(metrics, calculated, "Validation metrics")
    if payload.get("validation_macro_f1") != calculated["macro_f1"]:
        raise ValueError("Selected checkpoint macro F1 differs from validation predictions.")
    calibration = _object(repository / by_role["calibration_configuration"].path)
    _binding(
        calibration,
        {
            "classifier_experiment_id": bundle.training_experiment_id,
            "checkpoint_sha256": by_role["weights"].sha256,
            "manifest_fingerprint": bundle.manifest_fingerprint,
            "preprocessing_hash": bundle.preprocessing_hash,
            "preprocessing_version": bundle.preprocessing.preprocessing_version,
            "class_names": list(CLASS_LABELS),
            "temperature": bundle.calibration.temperature,
            "operational_threshold": bundle.confidence_threshold,
            "validation_csv_sha256": by_role["validation_predictions"].sha256,
            "valid_for_candidate_promotion": True,
            "test_probabilities_read": False,
        },
        "Calibration configuration",
    )
    if (
        calibration.get("valid_for_candidate_promotion") is not True
        or calibration.get("test_probabilities_read") is not False
    ):
        raise ValueError("Calibration must be valid and frozen before test use.")
    _digest_mapping(calibration.get("source_sha256"), "Calibration configuration")
    decision = _object(repository / by_role["decision_freeze"].path)
    _binding(
        decision,
        {
            "candidate_id": bundle.candidate_id,
            "checkpoint_sha256": by_role["weights"].sha256,
            "calibration": bundle.calibration.model_dump(mode="json"),
            "confidence_threshold": bundle.confidence_threshold,
            "manifest_fingerprint": bundle.manifest_fingerprint,
            "preprocessing_hash": bundle.preprocessing_hash,
            "split_seed": bundle.split_seed,
            "training_seed": bundle.training_seed,
            "test_used_for_selection": False,
            "artifact_sha256": {
                reference.path: reference.sha256
                for reference in bundle.references
                if reference.role != "decision_freeze"
            },
        },
        "Frozen candidate decision",
    )
    if decision.get("test_used_for_selection") is not False:
        raise ValueError("Frozen candidate decision must not use test for selection.")
    return bundle
