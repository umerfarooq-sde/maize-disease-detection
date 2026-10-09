"""One immutable test evaluation after a hash-bound validation-only decision.

Use after --defer-test fitting and validation diagnostics. A new partition on this
already-inspected corpus is not a fresh external holdout; reports say so explicitly.
"""

import argparse
import hashlib
import json
from pathlib import Path

from torch import nn

from dataset_preparation import CLASS_LABELS, load_manifest
from evaluation import compute_metrics
from fitness_artifacts import validate_bundle
from fitness_calibration import (
    apply_temperature,
    confidence_diagnostics,
    save_diagnostic_plots,
    selective_risk_coverage,
)
from model import build_model, read_checkpoint, restore_checkpoint
from train import (
    FinalTestGuard,
    TrainingSettings,
    configure_reproducibility,
    evaluate,
    save_evaluation,
    write_json,
)
from training_data import MaizeDataset, make_loader


def run_final_evaluation(bundle_path: Path, repository: Path, output: Path) -> dict[str, object]:
    bundle = validate_bundle(bundle_path, repository)
    destination = output.resolve()
    if not destination.is_relative_to((repository / ".cache").resolve()) or destination.exists():
        raise ValueError("Final evaluation requires a new ignored .cache destination.")
    references = {reference.role: reference for reference in bundle.references}
    claim_path = (
        repository
        / ".cache/model-test-claims"
        / f"{references['weights'].sha256}-{bundle.manifest_fingerprint}.json"
    )
    if claim_path.exists():
        raise ValueError("This checkpoint/index test evaluation was already claimed.")
    manifest = load_manifest(repository / references["index"].path)
    config = manifest.load_preprocessing()
    settings = TrainingSettings(seed=bundle.training_seed, threads=2)
    configure_reproducibility(settings)
    checkpoint = repository / references["weights"].path
    payload = read_checkpoint(
        checkpoint,
        class_names=CLASS_LABELS,
        preprocessing_hash=config.fingerprint,
        manifest_hash=manifest.fingerprint,
    )
    model = build_model(4, pretrained=False)
    restore_checkpoint(model, payload, 4)
    guard = FinalTestGuard(smoke=False, model_selected=True)
    destination.mkdir(parents=True, exist_ok=False)
    write_json(
        destination / "selection-lock.json",
        {
            "candidate_id": bundle.candidate_id,
            "bundle_sha256": hashlib.sha256(bundle_path.read_bytes()).hexdigest(),
            "checkpoint_sha256": references["weights"].sha256,
            "manifest_fingerprint": manifest.fingerprint,
            "preprocessing_hash": config.fingerprint,
            "split_seed": bundle.split_seed,
            "training_seed": bundle.training_seed,
            "calibration": bundle.calibration.model_dump(mode="json"),
            "confidence_threshold": bundle.confidence_threshold,
            "test_used_for_selection": False,
            "test_evaluated_before_this_lock": False,
            "corpus_prior_test_consumption": True,
            "limitation": (
                "Grouped repair of a previously inspected corpus, not an unseen field holdout."
            ),
        },
    )
    try:
        guard.claim()
        write_json(
            claim_path,
            {
                "candidate_id": bundle.candidate_id,
                "bundle_sha256": hashlib.sha256(bundle_path.read_bytes()).hexdigest(),
                "checkpoint_sha256": references["weights"].sha256,
                "manifest_fingerprint": manifest.fingerprint,
                "test_used_for_selection": False,
            },
        )
        dataset = MaizeDataset(manifest.rows_for_split("test"), config, split="test")
        result = evaluate(
            model,
            make_loader(dataset, batch_size=16, seed=bundle.training_seed),
            nn.CrossEntropyLoss(),
            CLASS_LABELS,
        )
        save_evaluation(destination / "raw", result, [], CLASS_LABELS, split="test")
        calibrated = (
            apply_temperature(result.probabilities, bundle.calibration.temperature)
            if bundle.calibration.enabled
            else result.probabilities.copy()
        )
        raw_confidence = confidence_diagnostics(result.labels, result.probabilities, CLASS_LABELS)
        calibrated_confidence = confidence_diagnostics(result.labels, calibrated, CLASS_LABELS)
        raw_selective = selective_risk_coverage(result.labels, result.probabilities, CLASS_LABELS)
        calibrated_selective = selective_risk_coverage(result.labels, calibrated, CLASS_LABELS)
        write_json(destination / "raw-confidence.json", raw_confidence.model_dump(mode="json"))
        write_json(
            destination / "calibrated-confidence.json",
            calibrated_confidence.model_dump(mode="json"),
        )
        write_json(destination / "raw-selective.json", raw_selective.model_dump(mode="json"))
        write_json(
            destination / "calibrated-selective.json",
            calibrated_selective.model_dump(mode="json"),
        )
        if bundle.confidence_threshold is not None:
            selected_threshold = selective_risk_coverage(
                result.labels, calibrated, CLASS_LABELS, thresholds=(bundle.confidence_threshold,)
            )
            selected_threshold = selected_threshold.model_copy(
                update={
                    "selected_threshold": bundle.confidence_threshold,
                    "selection_reason": (
                        "Frozen validation-selected threshold; this test report never refits it."
                    ),
                }
            )
            write_json(
                destination / "selected-threshold.json",
                selected_threshold.model_dump(mode="json"),
            )
        calibrated_metrics = compute_metrics(result.labels, calibrated, CLASS_LABELS)
        write_json(destination / "calibrated-metrics.json", calibrated_metrics)
        save_diagnostic_plots(
            destination / "confidence-plots",
            raw_confidence,
            calibrated_report=calibrated_confidence,
            raw_selective=raw_selective,
            calibrated_selective=calibrated_selective,
        )
        summary: dict[str, object] = {
            "status": "completed",
            "candidate_id": bundle.candidate_id,
            "sample_count": len(result.labels),
            "test_evaluated_once": guard.evaluated,
            "test_used_for_selection": False,
            "corpus_prior_test_consumption": True,
            "argmax_unchanged_by_calibration": bool(
                (calibrated.argmax(axis=1) == result.probabilities.argmax(axis=1)).all()
            ),
            "checkpoint_sha256": references["weights"].sha256,
            "manifest_fingerprint": manifest.fingerprint,
            "preprocessing_hash": config.fingerprint,
            "raw_metrics": result.metrics,
            "calibrated_metrics": calibrated_metrics,
        }
        write_json(destination / "summary.json", summary)
        return summary
    except Exception as error:
        write_json(
            destination / "failure.json",
            {"error_type": type(error).__name__, "test_claimed": guard.evaluated},
        )
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    repository = Path(__file__).resolve().parents[1]
    result = run_final_evaluation(args.bundle, repository, args.output)
    print(json.dumps({key: value for key, value in result.items() if not key.endswith("metrics")}))


if __name__ == "__main__":
    main()
