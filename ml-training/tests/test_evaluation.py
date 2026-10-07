"""Hand-computed evaluation contracts and immutable, finite standalone reports."""

import json
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

from evaluation import analyze_generalization, compute_metrics, save_reports

NAMES = ["Common_Rust", "Gray_Leaf_Spot", "Healthy", "Northern_Corn_Leaf_Blight"]


def example():
    labels = np.array([0, 0, 1, 1, 2, 2, 3, 3], dtype=np.int64)
    probabilities = np.array(
        [
            [0.7, 0.1, 0.1, 0.1],
            [0.2, 0.6, 0.1, 0.1],
            [0.1, 0.7, 0.1, 0.1],
            [0.1, 0.3, 0.5, 0.1],
            [0.1, 0.1, 0.7, 0.1],
            [0.1, 0.1, 0.7, 0.1],
            [0.6, 0.1, 0.1, 0.2],
            [0.1, 0.1, 0.1, 0.7],
        ],
        dtype=np.float32,
    )
    return labels, probabilities


def history():
    return [
        {
            "epoch": 1,
            "stage": "head",
            "learning_rate": 0.001,
            "train_loss": 1.0,
            "validation_loss": 1.2,
            "train_accuracy": 0.3,
            "validation_accuracy": 0.3,
            "validation_macro_f1": 0.3,
        },
        {
            "epoch": 2,
            "stage": "head",
            "learning_rate": 0.001,
            "train_loss": 0.8,
            "validation_loss": 0.7,
            "train_accuracy": 0.6,
            "validation_accuracy": 0.65,
            "validation_macro_f1": 0.65,
        },
        {
            "epoch": 3,
            "stage": "fine_tune",
            "learning_rate": 0.0001,
            "train_loss": 0.4,
            "validation_loss": 0.9,
            "train_accuracy": 0.9,
            "validation_accuracy": 0.6,
            "validation_macro_f1": 0.6,
        },
    ]


def test_hand_computed_confusion_accuracy_precision_recall_f1_and_specificity():
    labels, probabilities = example()
    metrics = compute_metrics(labels, probabilities, NAMES)
    assert metrics["class_names"] == NAMES
    assert metrics["sample_count"] == 8
    assert metrics["confusion_matrix"] == [[1, 1, 0, 0], [0, 1, 1, 0], [0, 0, 2, 0], [1, 0, 0, 1]]
    assert metrics["accuracy"] == 5 / 8
    assert metrics["macro_precision"] == pytest.approx(2 / 3)
    assert metrics["macro_recall"] == pytest.approx(5 / 8)
    assert metrics["macro_f1"] == pytest.approx(37 / 60)
    assert metrics["weighted_f1"] == pytest.approx(37 / 60)
    assert metrics["per_class"][0]["specificity"] == pytest.approx(5 / 6)
    assert metrics["per_class"][2]["precision"] == pytest.approx(2 / 3)
    assert metrics["per_class"][2]["recall"] == 1
    assert metrics["per_class"][3]["specificity"] == 1
    assert metrics["per_class"][3]["false_negative"] == 1
    assert metrics["aggregate_undefined_reasons"] == {}


def test_ovr_auc_from_pairwise_positive_negative_rankings():
    metrics = compute_metrics(*example(), NAMES)
    assert [item["roc_auc"] for item in metrics["per_class"]] == pytest.approx(
        [11 / 12, 11 / 12, 1, 1]
    )
    assert metrics["roc_auc"]["macro"] == pytest.approx(23 / 24)
    assert metrics["roc_auc"]["weighted"] == pytest.approx(23 / 24)
    assert metrics["roc_auc"]["undefined_reason"] is None


def test_tied_auc_scores_are_half_credit():
    metrics = compute_metrics([0, 1, 2, 3], np.full((4, 4), 0.25), NAMES)
    assert [item["roc_auc"] for item in metrics["per_class"]] == [0.5] * 4
    assert metrics["roc_auc"]["macro"] == 0.5


def test_support_weighted_averages_do_not_equal_macro_for_imbalanced_labels():
    metrics = compute_metrics([0, 0, 0, 1, 2, 3], np.eye(4)[[0, 0, 1, 1, 2, 3]], NAMES)
    assert metrics["macro_precision"] == pytest.approx(7 / 8)
    assert metrics["weighted_precision"] == pytest.approx(11 / 12)
    assert metrics["macro_recall"] == pytest.approx(11 / 12)
    assert metrics["weighted_recall"] == pytest.approx(5 / 6)
    assert metrics["macro_f1"] == pytest.approx(13 / 15)
    assert metrics["weighted_f1"] == pytest.approx(38 / 45)


def test_absent_class_and_no_negatives_are_null_with_reasons():
    metrics = compute_metrics([0, 0], [[0.7, 0.1, 0.1, 0.1]] * 2, NAMES)
    positive, absent = metrics["per_class"][:2]
    assert positive["specificity"] is None
    assert "specificity" in positive["undefined_reasons"]
    assert positive["roc_auc"] is None
    assert absent["precision"] is None
    assert absent["recall"] is None
    assert absent["f1"] is None
    assert absent["specificity"] == 1
    assert absent["support"] == 0
    assert "No positive" in absent["undefined_reasons"]["roc_auc"]
    assert metrics["macro_f1"] is None
    assert "macro_f1" in metrics["aggregate_undefined_reasons"]
    assert metrics["weighted_f1"] == 1
    assert metrics["roc_auc"]["macro"] is None
    assert metrics["roc_auc"]["weighted"] is None
    assert metrics["roc_auc"]["undefined_reason"]
    assert "undefined" in metrics["classification_summary"]
    assert "NaN" not in json.dumps(metrics, allow_nan=False)


def test_present_missed_class_f1_is_defined_zero_but_precision_is_undefined():
    metrics = compute_metrics([0, 1, 2, 3], [[0.7, 0.1, 0.1, 0.1]] * 4, NAMES)
    assert metrics["per_class"][1]["precision"] is None
    assert metrics["per_class"][1]["recall"] == 0
    assert metrics["per_class"][1]["f1"] == 0
    assert metrics["macro_f1"] == pytest.approx(0.1)
    assert metrics["weighted_precision"] is None


@pytest.mark.parametrize(
    ("labels", "probabilities"),
    [
        ([], np.empty((0, 4))),
        ([[0]], [[0.7, 0.1, 0.1, 0.1]]),
        ([0.0], [[0.7, 0.1, 0.1, 0.1]]),
        ([True], [[0.7, 0.1, 0.1, 0.1]]),
        ([-1], [[0.7, 0.1, 0.1, 0.1]]),
        ([4], [[0.7, 0.1, 0.1, 0.1]]),
        ([0], [[0.8, 0.1, 0.1]]),
        ([0, 1], [[0.7, 0.1, 0.1, 0.1]]),
        ([0], [0.7, 0.1, 0.1, 0.1]),
        ([0], [[float("nan"), 0.1, 0.1, 0.1]]),
        ([0], [[float("inf"), 0.1, 0.1, 0.1]]),
        ([0], [[-0.1, 0.5, 0.3, 0.3]]),
        ([0], [[1.1, 0, 0, 0]]),
        ([0], [[0.2, 0.2, 0.2, 0.2]]),
        ([0], [["0.7", "0.1", "0.1", "0.1"]]),
    ],
)
def test_invalid_predictions_are_rejected_without_silent_repairs(labels, probabilities):
    with pytest.raises(ValueError):
        compute_metrics(labels, probabilities, NAMES)


@pytest.mark.parametrize("names", [[], ["only"], ["a", "a", "b", "c"], ["", "b", "c", "d"], "abcd"])
def test_invalid_class_maps_are_rejected(names):
    with pytest.raises(ValueError):
        compute_metrics(*example(), names)


def test_standalone_json_classification_confusion_history_and_roc_reports(tmp_path: Path):
    labels, probabilities = example()
    metrics = compute_metrics(labels, probabilities, NAMES)
    artifacts = save_reports(
        tmp_path, metrics, history(), labels=labels, probabilities=probabilities, split="validation"
    )
    assert set(artifacts) == {
        "metrics",
        "classification_summary",
        "confusion_matrix",
        "history_curves",
        "roc_curves",
    }
    payload = json.loads((tmp_path / artifacts["metrics"]).read_text(encoding="utf-8"))
    assert payload["accuracy"] == 5 / 8
    assert payload["generalization"]["best_validation_loss_epoch"] == 2
    assert payload["generalization"]["overfitting_signal"] == "possible_overfitting"
    assert payload["generalization"]["underfitting_signal"] == "not_established"
    for name in ("confusion_matrix", "history_curves", "roc_curves"):
        with Image.open(tmp_path / artifacts[name]) as image:
            assert image.format == "PNG"
            assert min(image.size) >= 600
    assert "Common_Rust" in (tmp_path / artifacts["classification_summary"]).read_text()
    original = (tmp_path / artifacts["metrics"]).read_bytes()
    with pytest.raises(FileExistsError):
        save_reports(tmp_path, metrics, history(), labels=labels, probabilities=probabilities)
    assert (tmp_path / artifacts["metrics"]).read_bytes() == original


def test_no_roc_plot_is_invented_for_no_defined_auc(tmp_path: Path):
    labels = [0, 0]
    probabilities = [[0.7, 0.1, 0.1, 0.1]] * 2
    metrics = compute_metrics(labels, probabilities, NAMES)
    artifacts = save_reports(tmp_path, metrics, [], labels=labels, probabilities=probabilities)
    assert "roc_curves" not in artifacts
    assert "history_curves" not in artifacts
    payload = json.loads((tmp_path / "metrics.json").read_text())
    assert payload["generalization"]["epoch_count"] == 0


def test_mismatched_plot_predictions_do_not_create_output(tmp_path: Path):
    labels, probabilities = example()
    metrics = compute_metrics(labels, probabilities, NAMES)
    output = tmp_path / "invalid"
    with pytest.raises(ValueError, match="do not match"):
        save_reports(output, metrics, history(), labels=labels, probabilities=np.eye(4)[labels])
    assert not output.exists()


@pytest.mark.parametrize(
    "change",
    [
        {"epoch": 0},
        {"train_loss": -1.0},
        {"validation_accuracy": 1.1},
        {"validation_macro_f1": float("nan")},
        {"learning_rate": 0},
        {"stage": 12},
        {"dataset_path": "private"},
    ],
)
def test_invalid_history_is_rejected_before_artifact_writes(tmp_path: Path, change):
    rows = history()
    rows[0].update(change)
    output = tmp_path / "invalid"
    with pytest.raises(ValueError):
        save_reports(output, compute_metrics(*example(), NAMES), rows)
    assert not output.exists()


def test_selected_deterministic_train_val_comparison_not_augmented_epoch_accuracy():
    labels, probabilities = example()
    train = compute_metrics(labels, np.eye(4)[labels], NAMES)
    validation = compute_metrics(labels, probabilities, NAMES)
    analysis = analyze_generalization(train, validation, history())
    assert analysis["train_accuracy"] == 1
    assert analysis["validation_accuracy"] == 5 / 8
    assert analysis["accuracy_gap"] == 3 / 8
    assert analysis["train_majority_accuracy_reference"] == 1 / 4
    assert analysis["overfitting_signal"] == "train_validation_gap"
    assert analysis["underfitting_signal"] == "not_established"
    assert "test" in str(analysis["observations"])


def test_poor_learning_analysis_uses_train_val_majority_references():
    poor = compute_metrics([0, 1, 2, 3], np.eye(4)[[1, 2, 3, 0]], NAMES)
    analysis = analyze_generalization(poor, poor)
    assert analysis["underfitting_signal"] == "possible_underfitting_or_optimization_failure"
    assert analysis["overfitting_signal"] == "no_positive_accuracy_gap"
