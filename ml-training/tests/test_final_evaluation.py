"""A frozen synthetic candidate evaluates test exactly once and refuses changed weights."""

import hashlib
import json
from dataclasses import asdict
from pathlib import Path

import pytest
import torch
from test_training import TinyModel, TrainingFixture, checkpoint_payload
from test_training import training_fixture as training_fixture
from torch import nn

import final_evaluation
from fitness_artifacts import CalibrationDefinition, FitnessBundle, artifact_reference
from model import save_checkpoint
from train import TrainingSettings, evaluate, save_evaluation
from training_data import MaizeDataset, make_loader


def frozen_fixture(
    tmp_path: Path, fixture: TrainingFixture, *, threshold: float | None = None
) -> Path:
    settings = TrainingSettings(
        warmup_epochs=1, fine_tune_epochs=1, pretrained=False, defer_test=True
    )
    torch.set_num_threads(2)
    model = TinyModel().eval()
    validation = evaluate(
        model,
        make_loader(
            MaizeDataset(
                fixture.manifest.rows_for_split("validation"), fixture.config, split="validation"
            ),
            batch_size=16,
            seed=settings.seed,
        ),
        nn.CrossEntropyLoss(),
        tuple(item.label for item in fixture.manifest.classes),
    )
    save_evaluation(
        tmp_path / "validation",
        validation,
        [],
        validation.metrics["class_names"],
        split="validation",
    )
    checkpoint = tmp_path / "weights.pt"
    payload = {
        **checkpoint_payload(model, fixture),
        "class_to_index": {item.label: item.index for item in fixture.manifest.classes},
        "experiment_id": "synthetic-training",
        "dataset_version": fixture.manifest.version,
        "research_policy": fixture.manifest.research_policy,
        "preprocessing_version": fixture.config.preprocessing_version,
        "epoch": 1,
        "seed": settings.seed,
        "hyperparameters": asdict(settings),
        "validation_macro_f1": validation.metrics["macro_f1"],
        "validation_loss": validation.loss,
    }
    save_checkpoint(checkpoint, payload)
    temperature = CalibrationDefinition(enabled=False, temperature=1.0, method="none")
    source = tmp_path / "fixture-source.py"
    source.write_text("# synthetic fixture source\n", encoding="utf-8")
    metadata = {
        "environment.json": {
            "python": "3.11.0",
            "torch": str(torch.__version__),
            "distributions": [{"name": "torch", "version": str(torch.__version__)}],
            "source_hashes": {"fixture-source.py": hashlib.sha256(source.read_bytes()).hexdigest()},
        },
        "hyperparameters.json": asdict(settings),
        "experiment.json": {
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
        "summary.json": {
            "status": "completed",
            "mode": "full",
            "experiment_id": "synthetic-training",
            "final_test_deferred": True,
            "test_evaluated_once": False,
            "test_metrics": None,
            "best_epoch": 1,
            "best_checkpoint": "weights.pt",
            "best_checkpoint_sha256": hashlib.sha256(checkpoint.read_bytes()).hexdigest(),
            "manifest_fingerprint": fixture.manifest.fingerprint,
            "preprocessing_hash": fixture.config.fingerprint,
            "train_samples": len(fixture.manifest.splits.train),
            "validation_samples": len(fixture.manifest.splits.validation),
        },
        "calibration-config.json": {
            "classifier_experiment_id": "synthetic-training",
            "checkpoint_sha256": hashlib.sha256(checkpoint.read_bytes()).hexdigest(),
            "manifest_fingerprint": fixture.manifest.fingerprint,
            "preprocessing_hash": fixture.config.fingerprint,
            "preprocessing_version": fixture.config.preprocessing_version,
            "class_names": validation.metrics["class_names"],
            "temperature": 1.0,
            "operational_threshold": threshold,
            "valid_for_candidate_promotion": True,
            "test_probabilities_read": False,
            "source_sha256": {"fixture-source.py": hashlib.sha256(source.read_bytes()).hexdigest()},
            "validation_csv_sha256": hashlib.sha256(
                (tmp_path / "validation/predictions.csv").read_bytes()
            ).hexdigest(),
        },
    }
    for name, record in metadata.items():
        (tmp_path / name).write_text(json.dumps(record), encoding="utf-8")
    references = (
        artifact_reference(checkpoint, tmp_path, "weights"),
        artifact_reference(fixture.manifest_path, tmp_path, "index"),
        artifact_reference(tmp_path / "summary.json", tmp_path, "training_summary"),
        artifact_reference(tmp_path / "environment.json", tmp_path, "training_environment"),
        artifact_reference(tmp_path / "hyperparameters.json", tmp_path, "training_configuration"),
        artifact_reference(tmp_path / "experiment.json", tmp_path, "training_experiment"),
        artifact_reference(
            tmp_path / "validation/predictions.csv", tmp_path, "validation_predictions"
        ),
        artifact_reference(tmp_path / "validation/metrics.json", tmp_path, "validation_metrics"),
        artifact_reference(
            tmp_path / "calibration-config.json", tmp_path, "calibration_configuration"
        ),
    )
    decision = tmp_path / "freeze.json"
    decision.write_text(
        json.dumps(
            {
                "candidate_id": "synthetic-frozen",
                "checkpoint_sha256": hashlib.sha256(checkpoint.read_bytes()).hexdigest(),
                "calibration": temperature.model_dump(mode="json"),
                "confidence_threshold": threshold,
                "test_used_for_selection": False,
                "manifest_fingerprint": fixture.manifest.fingerprint,
                "preprocessing_hash": fixture.config.fingerprint,
                "split_seed": fixture.manifest.split_seed,
                "training_seed": settings.seed,
                "artifact_sha256": {reference.path: reference.sha256 for reference in references},
            }
        ),
        encoding="utf-8",
    )
    bundle = FitnessBundle(
        candidate_id="synthetic-frozen",
        training_experiment_id="synthetic-training",
        architecture="mobilenet_v3_small",
        classes=fixture.manifest.classes,
        preprocessing=fixture.config,
        preprocessing_hash=fixture.config.fingerprint,
        preprocessing_policy="shared_full_frame",
        dataset_version=fixture.manifest.version,
        manifest_fingerprint=fixture.manifest.fingerprint,
        split_seed=fixture.manifest.split_seed,
        training_seed=settings.seed,
        calibration=temperature,
        confidence_threshold=threshold,
        confidence_threshold_status="unlocked" if threshold is None else "validation_selected",
        test_status="previously_consumed_descriptive",
        test_used_for_selection=False,
        academic_noncommercial_only=True,
        raw_image_redistribution=False,
        commercial_clearance=False,
        ready_for_phase11=True,
        verdict="FIT WITH DOCUMENTED LIMITATIONS",
        references=(*references, artifact_reference(decision, tmp_path, "decision_freeze")),
    )
    path = tmp_path / "candidate.json"
    path.write_text(bundle.model_dump_json(indent=2), encoding="utf-8")
    return path


def test_frozen_final_evaluation_is_single_use_and_preserves_source(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, training_fixture: TrainingFixture
) -> None:
    bundle_path = frozen_fixture(tmp_path, training_fixture)
    output = tmp_path / ".cache/test-once"
    monkeypatch.setattr(final_evaluation, "build_model", lambda *args, **kwargs: TinyModel())
    before = {path: path.read_bytes() for path in training_fixture.root.rglob("*.png")}
    result = final_evaluation.run_final_evaluation(bundle_path, tmp_path, output)
    assert result["test_evaluated_once"] is True
    assert result["test_used_for_selection"] is False
    assert result["sample_count"] == len(training_fixture.manifest.splits.test)
    assert result["argmax_unchanged_by_calibration"] is True
    assert result["raw_metrics"] == result["calibrated_metrics"]
    assert json.loads((output / "raw-confidence.json").read_bytes()) == json.loads(
        (output / "calibrated-confidence.json").read_bytes()
    )
    assert (output / "selection-lock.json").is_file()
    assert (output / "raw/predictions.csv").is_file()
    assert all(path.read_bytes() == content for path, content in before.items())
    with pytest.raises(ValueError, match="new ignored"):
        final_evaluation.run_final_evaluation(bundle_path, tmp_path, output)
    with pytest.raises(ValueError, match="already claimed"):
        final_evaluation.run_final_evaluation(
            bundle_path, tmp_path, tmp_path / ".cache/second-output"
        )
    assert not (tmp_path / ".cache/second-output").exists()


def test_changed_weight_bytes_block_final_evaluation(
    tmp_path: Path, training_fixture: TrainingFixture
) -> None:
    bundle_path = frozen_fixture(tmp_path, training_fixture)
    with (tmp_path / "weights.pt").open("ab") as stream:
        stream.write(b"changed")
    with pytest.raises(ValueError, match="hash"):
        final_evaluation.run_final_evaluation(bundle_path, tmp_path, tmp_path / ".cache/rejected")
    assert not (tmp_path / ".cache/rejected").exists()


def test_changed_frozen_decision_cannot_be_rebound_silently(
    tmp_path: Path, training_fixture: TrainingFixture
) -> None:
    bundle_path = frozen_fixture(tmp_path, training_fixture)
    bundle = FitnessBundle.model_validate_json(bundle_path.read_bytes())
    decision = tmp_path / "freeze.json"
    payload = json.loads(decision.read_bytes())
    payload["confidence_threshold"] = 0.9
    decision.write_text(json.dumps(payload), encoding="utf-8")
    rebound = bundle.model_copy(
        update={
            "references": tuple(
                artifact_reference(decision, tmp_path, "decision_freeze")
                if reference.role == "decision_freeze"
                else reference
                for reference in bundle.references
            )
        }
    )
    bundle_path.write_text(rebound.model_dump_json(), encoding="utf-8")
    with pytest.raises(ValueError, match="[Ff]rozen"):
        final_evaluation.run_final_evaluation(bundle_path, tmp_path, tmp_path / ".cache/rejected")


def test_frozen_threshold_is_reported_without_refitting(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, training_fixture: TrainingFixture
) -> None:
    path = frozen_fixture(tmp_path, training_fixture, threshold=0.7)
    monkeypatch.setattr(final_evaluation, "build_model", lambda *args, **kwargs: TinyModel())
    output = tmp_path / ".cache/selected-threshold"
    final_evaluation.run_final_evaluation(path, tmp_path, output)
    report = json.loads((output / "selected-threshold.json").read_bytes())
    assert report["selected_threshold"] == 0.7
    assert len(report["candidates"]) == 1 and report["candidates"][0]["threshold"] == 0.7
