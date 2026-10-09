"""Artifact references reject traversal, changed bytes and inconsistent candidate policies."""

import csv
import hashlib
import json
from dataclasses import asdict
from pathlib import Path

import numpy as np
import pytest
from maizedoctor_preprocessing import load_config
from pydantic import ValidationError
from test_training import TinyModel, TrainingFixture, checkpoint_payload
from test_training import training_fixture as training_fixture

from dataset_preparation import CLASS_LABELS, ClassDefinition
from evaluation import compute_metrics
from fitness_artifacts import (
    REQUIRED_ROLES,
    ArtifactReference,
    CalibrationDefinition,
    FitnessBundle,
    artifact_reference,
    validate_bundle,
    verify_references,
)
from model import save_checkpoint
from train import TrainingSettings


@pytest.mark.parametrize(
    "path", ["../model.pt", "/model.pt", "C:/model.pt", "a\\b", "a//b", "a/./b", ""]
)
def test_references_reject_unsafe_paths(path: str) -> None:
    with pytest.raises(ValidationError):
        ArtifactReference(role="weights", path=path, sha256="0" * 64)


def test_reference_hash_detects_changed_bytes(tmp_path: Path) -> None:
    artifact = tmp_path / "metadata.json"
    artifact.write_bytes(b'{"version":1}')
    reference = artifact_reference(artifact, tmp_path, "metadata")
    verify_references((reference,), tmp_path)
    artifact.write_bytes(b'{"version":2}')
    with pytest.raises(ValueError, match="hash"):
        verify_references((reference,), tmp_path)


def test_reference_cannot_describe_external_artifact(tmp_path: Path) -> None:
    project = tmp_path / "project"
    project.mkdir()
    outside = tmp_path / "outside.json"
    outside.write_bytes(b"{}")
    with pytest.raises(ValueError, match="within"):
        artifact_reference(outside, project, "metadata")


@pytest.mark.parametrize(
    "policy",
    [
        {"enabled": True, "temperature": 1.4, "method": "none"},
        {"enabled": False, "temperature": 1.4, "method": "none"},
        {"enabled": True, "temperature": 0.0, "method": "validation_group_crossfit_temperature"},
        {
            "enabled": True,
            "temperature": float("nan"),
            "method": "validation_group_crossfit_temperature",
        },
    ],
)
def test_calibration_requires_coherent_finite_policy(policy: dict[str, object]) -> None:
    with pytest.raises(ValidationError):
        CalibrationDefinition.model_validate(policy)


def candidate() -> FitnessBundle:
    config = load_config(Path(__file__).parents[1] / "configs/full-frame-baseline.json")
    return FitnessBundle(
        candidate_id="synthetic-candidate",
        training_experiment_id="synthetic-training",
        architecture="mobilenet_v3_small",
        classes=tuple(
            ClassDefinition(label=label, index=index) for index, label in enumerate(CLASS_LABELS)
        ),
        preprocessing=config,
        preprocessing_hash=config.fingerprint,
        preprocessing_policy="shared_full_frame",
        dataset_version="synthetic-index",
        manifest_fingerprint="0" * 64,
        split_seed=20261007,
        training_seed=20261008,
        calibration=CalibrationDefinition(enabled=False, temperature=1.0, method="none"),
        confidence_threshold=None,
        confidence_threshold_status="unlocked",
        test_status="previously_consumed_descriptive",
        test_used_for_selection=False,
        academic_noncommercial_only=True,
        raw_image_redistribution=False,
        commercial_clearance=False,
        ready_for_phase11=True,
        verdict="FIT WITH DOCUMENTED LIMITATIONS",
        references=tuple(
            ArtifactReference(role=role, path=f"local/{role}.json", sha256="0" * 64)
            for role in REQUIRED_ROLES
        ),
    )


@pytest.mark.parametrize(
    "change",
    [
        {"test_used_for_selection": True},
        {"commercial_clearance": True},
        {"raw_image_redistribution": True},
        {"confidence_threshold": 0.9},
        {"ready_for_phase11": False},
        {"preprocessing_hash": "0" * 64},
        {"references": []},
        {
            "classes": [
                {"label": label, "index": i} for i, label in enumerate(reversed(CLASS_LABELS))
            ]
        },
    ],
)
def test_candidate_rejects_invalid_bindings(change: dict[str, object]) -> None:
    payload = candidate().model_dump(mode="json")
    payload.update(change)
    with pytest.raises(ValidationError):
        FitnessBundle.model_validate_json(json.dumps(payload))


def test_candidate_json_roundtrip() -> None:
    bundle = candidate()
    assert FitnessBundle.model_validate_json(bundle.model_dump_json()) == bundle


def _write(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, allow_nan=False), encoding="utf-8")


def _digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bound_fixture(tmp_path: Path, fixture: TrainingFixture) -> Path:
    """Complete synthetic metadata; validation probabilities need no image inference."""
    rows = fixture.manifest.rows_for_split("validation")
    labels = np.array([row.class_index for row in rows])
    scores = np.full((len(rows), 4), 0.05)
    scores[np.arange(len(rows)), labels] = 0.85
    metrics = compute_metrics(labels, scores, CLASS_LABELS)
    predictions = tmp_path / "validation.csv"
    with predictions.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["sample_id", "true_index", "predicted_index", *CLASS_LABELS])
        for row, probabilities in zip(rows, scores, strict=True):
            writer.writerow([row.sample_id, row.class_index, row.class_index, *probabilities])
    configuration = asdict(TrainingSettings(seed=20261008, defer_test=True))
    weights = tmp_path / "weights.pt"
    payload = checkpoint_payload(TinyModel().eval(), fixture)
    payload.update(
        {
            "experiment_id": "synthetic-training",
            "seed": 20261008,
            "class_to_index": {label: index for index, label in enumerate(CLASS_LABELS)},
            "preprocessing_version": fixture.config.preprocessing_version,
            "dataset_version": fixture.manifest.version,
            "hyperparameters": configuration,
            "epoch": 3,
            "validation_macro_f1": metrics["macro_f1"],
        }
    )
    save_checkpoint(weights, payload)
    _write(tmp_path / "configuration.json", configuration)
    _write(
        tmp_path / "environment.json",
        {
            "python": "3.11",
            "torch": "2.10.0+cpu",
            "distributions": [{"name": "torch", "version": "2.10.0+cpu"}],
            "source_hashes": {"source.py": "1" * 64},
        },
    )
    _write(
        tmp_path / "summary.json",
        {
            "status": "completed",
            "mode": "full",
            "experiment_id": "synthetic-training",
            "final_test_deferred": True,
            "test_evaluated_once": False,
            "test_metrics": None,
            "best_epoch": 3,
            "best_checkpoint_sha256": _digest(weights),
            "manifest_fingerprint": fixture.manifest.fingerprint,
            "preprocessing_hash": fixture.config.fingerprint,
            "train_samples": len(fixture.manifest.splits.train),
            "validation_samples": len(fixture.manifest.splits.validation),
        },
    )
    _write(
        tmp_path / "experiment.json",
        {
            "experiment_id": "synthetic-training",
            "mode": "full",
            "architecture": "mobilenet_v3_small",
            "dataset_version": fixture.manifest.version,
            "manifest_fingerprint": fixture.manifest.fingerprint,
            "preprocessing_hash": fixture.config.fingerprint,
            "preprocessing_version": fixture.config.preprocessing_version,
            "final_test_deferred": True,
            "test_selection_usage": "never",
        },
    )
    _write(tmp_path / "metrics.json", metrics)
    _write(
        tmp_path / "calibration.json",
        {
            "classifier_experiment_id": "synthetic-training",
            "checkpoint_sha256": _digest(weights),
            "manifest_fingerprint": fixture.manifest.fingerprint,
            "preprocessing_hash": fixture.config.fingerprint,
            "preprocessing_version": fixture.config.preprocessing_version,
            "class_names": list(CLASS_LABELS),
            "temperature": 1.0,
            "operational_threshold": None,
            "validation_csv_sha256": _digest(predictions),
            "valid_for_candidate_promotion": True,
            "test_probabilities_read": False,
            "source_sha256": {"calibrator.py": "2" * 64},
        },
    )
    _write(tmp_path / "freeze.json", {})
    files = {
        "weights": weights,
        "index": fixture.manifest_path,
        "decision_freeze": tmp_path / "freeze.json",
        "training_summary": tmp_path / "summary.json",
        "training_environment": tmp_path / "environment.json",
        "training_configuration": tmp_path / "configuration.json",
        "training_experiment": tmp_path / "experiment.json",
        "validation_predictions": predictions,
        "validation_metrics": tmp_path / "metrics.json",
        "calibration_configuration": tmp_path / "calibration.json",
    }
    bundle = candidate().model_copy(
        update={
            "dataset_version": fixture.manifest.version,
            "manifest_fingerprint": fixture.manifest.fingerprint,
            "references": tuple(
                artifact_reference(files[role], tmp_path, role) for role in REQUIRED_ROLES
            ),
        }
    )
    path = tmp_path / "candidate.json"
    path.write_text(bundle.model_dump_json(), encoding="utf-8")
    refresh_bindings(path)
    return path


def refresh_bindings(path: Path) -> None:
    """Re-pin every modified byte so mismatch tests exercise semantics, not checksums."""
    bundle = FitnessBundle.model_validate_json(path.read_bytes())
    by_role = {reference.role: reference for reference in bundle.references}
    root = path.parent
    weights_hash = _digest(root / by_role["weights"].path)
    summary_path = root / by_role["training_summary"].path
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    summary["best_checkpoint_sha256"] = weights_hash
    _write(summary_path, summary)
    calibration_path = root / by_role["calibration_configuration"].path
    calibration = json.loads(calibration_path.read_text(encoding="utf-8"))
    calibration["checkpoint_sha256"] = weights_hash
    calibration["validation_csv_sha256"] = _digest(root / by_role["validation_predictions"].path)
    _write(calibration_path, calibration)
    references = tuple(
        artifact_reference(root / reference.path, root, reference.role)
        for reference in bundle.references
    )
    _write(
        root / by_role["decision_freeze"].path,
        {
            "candidate_id": bundle.candidate_id,
            "checkpoint_sha256": weights_hash,
            "calibration": bundle.calibration.model_dump(mode="json"),
            "confidence_threshold": bundle.confidence_threshold,
            "manifest_fingerprint": bundle.manifest_fingerprint,
            "preprocessing_hash": bundle.preprocessing_hash,
            "split_seed": bundle.split_seed,
            "training_seed": bundle.training_seed,
            "test_used_for_selection": False,
            "artifact_sha256": {
                reference.path: reference.sha256
                for reference in references
                if reference.role != "decision_freeze"
            },
        },
    )
    updated = bundle.model_copy(
        update={
            "references": tuple(
                artifact_reference(root / reference.path, root, reference.role)
                for reference in references
            )
        }
    )
    path.write_text(updated.model_dump_json(), encoding="utf-8")


def test_complete_binding_accepts_distinct_training_seed_on_same_fixed_split(
    tmp_path, training_fixture
):
    path = bound_fixture(tmp_path, training_fixture)
    bundle = validate_bundle(path, tmp_path)
    assert bundle.split_seed == 20261007 and bundle.training_seed == 20261008


@pytest.mark.parametrize("role", REQUIRED_ROLES)
def test_each_critical_evidence_role_is_mandatory(role):
    payload = candidate().model_dump(mode="json")
    payload["references"] = [row for row in payload["references"] if row["role"] != role]
    with pytest.raises(ValidationError, match="Exactly one"):
        FitnessBundle.model_validate_json(json.dumps(payload))


@pytest.mark.parametrize(
    "field,value",
    [
        ("experiment_id", "wrong-training"),
        ("seed", 20261009),
        ("class_to_index", {label: 3 - index for index, label in enumerate(CLASS_LABELS)}),
        ("preprocessing_version", "9.9.9"),
        ("dataset_version", "wrong-index"),
        ("hyperparameters", {"seed": 20261008, "defer_test": False}),
        ("validation_macro_f1", 0.4),
    ],
)
def test_checkpoint_metadata_mismatch_rejected_even_after_repin(
    tmp_path, training_fixture, field, value
):
    import torch

    path = bound_fixture(tmp_path, training_fixture)
    weights = tmp_path / "weights.pt"
    payload = torch.load(weights, weights_only=True)
    payload[field] = value
    torch.save(payload, weights)
    refresh_bindings(path)
    with pytest.raises(ValueError):
        validate_bundle(path, tmp_path)


@pytest.mark.parametrize(
    "name,field,value",
    [
        ("summary.json", "test_evaluated_once", True),
        ("summary.json", "final_test_deferred", False),
        ("summary.json", "mode", "smoke"),
        ("summary.json", "best_epoch", 4),
        ("configuration.json", "defer_test", False),
        ("configuration.json", "seed", 20261009),
        ("experiment.json", "test_selection_usage", "sometimes"),
        ("metrics.json", "accuracy", 0.5),
        ("calibration.json", "valid_for_candidate_promotion", False),
        ("calibration.json", "test_probabilities_read", True),
        ("calibration.json", "temperature", 1.5),
        ("calibration.json", "manifest_fingerprint", "0" * 64),
        ("environment.json", "distributions", []),
        ("environment.json", "source_hashes", {}),
    ],
)
def test_crossfile_mismatch_rejected_after_all_bytes_repin(
    tmp_path, training_fixture, name, field, value
):
    path = bound_fixture(tmp_path, training_fixture)
    changed = tmp_path / name
    payload = json.loads(changed.read_text(encoding="utf-8"))
    payload[field] = value
    _write(changed, payload)
    refresh_bindings(path)
    with pytest.raises(ValueError):
        validate_bundle(path, tmp_path)


def test_validation_truth_labels_rejected_despite_repin(tmp_path, training_fixture):
    path = bound_fixture(tmp_path, training_fixture)
    predictions = tmp_path / "validation.csv"
    lines = predictions.read_text(encoding="utf-8").splitlines()
    first = lines[1].split(",")
    first[1] = "3"
    lines[1] = ",".join(first)
    predictions.write_text("\n".join(lines) + "\n", encoding="utf-8")
    refresh_bindings(path)
    with pytest.raises(ValueError, match="labels"):
        validate_bundle(path, tmp_path)


def test_freeze_must_bind_every_reference_and_both_seeds(tmp_path, training_fixture):
    path = bound_fixture(tmp_path, training_fixture)
    freeze = tmp_path / "freeze.json"
    payload = json.loads(freeze.read_text(encoding="utf-8"))
    payload["artifact_sha256"].pop("metrics.json")
    _write(freeze, payload)
    bundle = FitnessBundle.model_validate_json(path.read_bytes())
    updated = bundle.model_copy(
        update={
            "references": tuple(
                artifact_reference(freeze, tmp_path, "decision_freeze")
                if reference.role == "decision_freeze"
                else reference
                for reference in bundle.references
            )
        }
    )
    path.write_text(updated.model_dump_json(), encoding="utf-8")
    with pytest.raises(ValueError, match="Frozen"):
        validate_bundle(path, tmp_path)
