"""Classification reports without changing predictions or selecting on held-out tests."""

from __future__ import annotations

import json
import math
import textwrap
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import TypedDict, cast

import numpy as np
from numpy.typing import ArrayLike, NDArray
from sklearn.metrics import roc_auc_score, roc_curve  # type: ignore[import-untyped]

HistoryValue = int | float | str | None
HistoryRecord = Mapping[str, HistoryValue]


class ClassMetrics(TypedDict):
    index: int
    label: str
    support: int
    predicted_support: int
    true_positive: int
    false_positive: int
    false_negative: int
    true_negative: int
    precision: float | None
    recall: float | None
    f1: float | None
    specificity: float | None
    roc_auc: float | None
    undefined_reasons: dict[str, str]


class AucMetrics(TypedDict):
    macro: float | None
    weighted: float | None
    undefined_reason: str | None


class EvaluationMetrics(TypedDict):
    class_names: list[str]
    sample_count: int
    accuracy: float
    macro_precision: float | None
    macro_recall: float | None
    macro_f1: float | None
    weighted_precision: float | None
    weighted_recall: float | None
    weighted_f1: float | None
    aggregate_undefined_reasons: dict[str, str]
    per_class: list[ClassMetrics]
    confusion_matrix: list[list[int]]
    roc_auc: AucMetrics
    classification_summary: str


def _validated_inputs(
    labels: ArrayLike, probabilities: ArrayLike, class_names: Sequence[str]
) -> tuple[NDArray[np.int64], NDArray[np.float64], list[str]]:
    names = list(class_names)
    if (
        isinstance(class_names, str)
        or len(names) < 2
        or any(not isinstance(name, str) or not name.strip() for name in names)
        or len(set(names)) != len(names)
    ):
        raise ValueError("The ordered class map must contain distinct nonempty class names.")
    targets = np.asarray(labels)
    scores = np.asarray(probabilities)
    if targets.ndim != 1 or targets.size == 0 or targets.dtype.kind not in "iu":
        raise ValueError("Labels must be a nonempty one-dimensional integer array.")
    if np.any(targets < 0) or np.any(targets >= len(names)):
        raise ValueError("A label index is outside the ordered class map.")
    if scores.ndim != 2 or scores.shape != (targets.size, len(names)):
        raise ValueError("Probabilities must have one row per label and one column per class.")
    if scores.dtype.kind not in "iuf" or not np.isfinite(scores).all():
        raise ValueError("Probabilities must be finite numeric values.")
    if np.any(scores < 0) or np.any(scores > 1):
        raise ValueError("Probabilities must lie between zero and one.")
    if not np.allclose(scores.sum(axis=1), 1, rtol=1e-6, atol=1e-6):
        raise ValueError("Each probability row must sum to one; values are not renormalized.")
    return targets.astype(np.int64), scores.astype(np.float64), names


def _ratio(
    numerator: int, denominator: int, name: str, reason: str, missing: dict[str, str]
) -> float | None:
    if denominator == 0:
        missing[name] = reason
        return None
    return numerator / denominator


def _average(
    values: Sequence[float | None], weights: Sequence[int], name: str, missing: dict[str, str]
) -> float | None:
    if any(value is None and weight > 0 for value, weight in zip(values, weights, strict=True)):
        missing[name] = "A contributing class metric is undefined; it is not replaced with zero."
        return None
    return sum(
        value * weight
        for value, weight in zip(values, weights, strict=True)
        if value is not None and weight > 0
    ) / sum(weights)


def _display(value: float | None) -> str:
    return "undefined" if value is None else f"{value:.4f}"


def _classification_summary(metrics: EvaluationMetrics) -> str:
    lines = ["Class | Precision | Recall | F1 | Specificity | Support"]
    for item in metrics["per_class"]:
        lines.append(
            f"{item['label']} | {_display(item['precision'])} | {_display(item['recall'])} | "
            f"{_display(item['f1'])} | {_display(item['specificity'])} | {item['support']}"
        )
    lines.append(f"Accuracy: {metrics['accuracy']:.4f} ({metrics['sample_count']} samples)")
    for average, precision, recall, f1 in (
        ("macro", metrics["macro_precision"], metrics["macro_recall"], metrics["macro_f1"]),
        (
            "weighted",
            metrics["weighted_precision"],
            metrics["weighted_recall"],
            metrics["weighted_f1"],
        ),
    ):
        lines.append(
            f"{average}: precision={_display(precision)}, "
            f"recall={_display(recall)}, F1={_display(f1)}"
        )
    return "\n".join(lines) + "\n"


def compute_metrics(
    labels: ArrayLike, probabilities: ArrayLike, class_names: Sequence[str]
) -> EvaluationMetrics:
    """Compute argmax classification/OVR metrics for the declared ordered class map.

    No threshold fitting, score renormalization or absent-class zero filling occurs.
    Macro averages require every declared class metric; weighted averages ignore
    zero-support classes but preserve undefined values in supported classes.
    """
    targets, scores, names = _validated_inputs(labels, probabilities, class_names)
    predictions = scores.argmax(axis=1)
    matrix = np.zeros((len(names), len(names)), dtype=np.int64)
    np.add.at(matrix, (targets, predictions), 1)
    total = int(targets.size)
    per_class: list[ClassMetrics] = []
    for index, label in enumerate(names):
        tp = int(matrix[index, index])
        support = int(matrix[index].sum())
        predicted_support = int(matrix[:, index].sum())
        fn, fp = support - tp, predicted_support - tp
        tn = total - tp - fn - fp
        missing: dict[str, str] = {}
        auc: float | None = None
        if support == 0:
            missing["roc_auc"] = "No positive examples for this class."
        elif support == total:
            missing["roc_auc"] = "No negative examples for this class."
        else:
            auc = float(roc_auc_score(targets == index, scores[:, index]))
        per_class.append(
            {
                "index": index,
                "label": label,
                "support": support,
                "predicted_support": predicted_support,
                "true_positive": tp,
                "false_positive": fp,
                "false_negative": fn,
                "true_negative": tn,
                "precision": _ratio(tp, tp + fp, "precision", "No predicted positives.", missing),
                "recall": _ratio(tp, tp + fn, "recall", "No labeled positives available.", missing),
                "f1": _ratio(
                    2 * tp, 2 * tp + fp + fn, "f1", "No true or predicted positives.", missing
                ),
                "specificity": _ratio(
                    tn, tn + fp, "specificity", "No labeled negatives available.", missing
                ),
                "roc_auc": auc,
                "undefined_reasons": missing,
            }
        )
    aggregate_missing: dict[str, str] = {}
    supports = [item["support"] for item in per_class]
    aggregates: dict[str, float | None] = {}
    for field, values in (
        ("precision", [item["precision"] for item in per_class]),
        ("recall", [item["recall"] for item in per_class]),
        ("f1", [item["f1"] for item in per_class]),
    ):
        aggregates[f"macro_{field}"] = _average(
            values, [1] * len(names), f"macro_{field}", aggregate_missing
        )
        aggregates[f"weighted_{field}"] = _average(
            values, supports, f"weighted_{field}", aggregate_missing
        )
    auc_values = [item["roc_auc"] for item in per_class]
    auc_metrics: AucMetrics = {"macro": None, "weighted": None, "undefined_reason": None}
    if any(value is None for value in auc_values):
        auc_metrics["undefined_reason"] = (
            "Multiclass OVR ROC-AUC requires positive and negative examples "
            "for every declared class."
        )
    else:
        auc_metrics["macro"] = _average(auc_values, [1] * len(names), "roc_auc_macro", {})
        auc_metrics["weighted"] = _average(auc_values, supports, "roc_auc_weighted", {})
    result: EvaluationMetrics = {
        "class_names": names,
        "sample_count": total,
        "accuracy": int(np.trace(matrix)) / total,
        "macro_precision": aggregates["macro_precision"],
        "macro_recall": aggregates["macro_recall"],
        "macro_f1": aggregates["macro_f1"],
        "weighted_precision": aggregates["weighted_precision"],
        "weighted_recall": aggregates["weighted_recall"],
        "weighted_f1": aggregates["weighted_f1"],
        "aggregate_undefined_reasons": aggregate_missing,
        "per_class": per_class,
        "confusion_matrix": matrix.tolist(),
        "roc_auc": auc_metrics,
        "classification_summary": "",
    }
    result["classification_summary"] = _classification_summary(result)
    return result


def _validated_history(history: Sequence[HistoryRecord]) -> list[dict[str, HistoryValue]]:
    rows: list[dict[str, HistoryValue]] = []
    previous_epoch = 0
    required = ("train_loss", "validation_loss", "train_accuracy", "validation_accuracy")
    allowed = {"epoch", "stage", "learning_rate", "validation_macro_f1", *required}
    for row in history:
        if set(row) - allowed:
            raise ValueError("History contains unsupported fields.")
        epoch = row.get("epoch")
        if isinstance(epoch, bool) or not isinstance(epoch, int) or epoch <= previous_epoch:
            raise ValueError("History epochs must be positive, strictly increasing integers.")
        previous_epoch = epoch
        cleaned: dict[str, HistoryValue] = {"epoch": epoch}
        for name in (*required, "learning_rate", "validation_macro_f1"):
            if name not in row and name not in required:
                continue
            value = row.get(name)
            if name == "validation_macro_f1" and value is None:
                cleaned[name] = None
                continue
            if (
                isinstance(value, bool)
                or not isinstance(value, int | float)
                or not math.isfinite(value)
                or value < 0
                or (("accuracy" in name or name == "validation_macro_f1") and value > 1)
                or (name == "learning_rate" and value == 0)
            ):
                raise ValueError(
                    "History losses/rates and scores must be finite and within bounds."
                )
            cleaned[name] = float(value)
        if "stage" in row:
            if not isinstance(row["stage"], str) or not row["stage"]:
                raise ValueError("History stage must be a nonempty string.")
            cleaned["stage"] = row["stage"]
        rows.append(cleaned)
    return rows


def _history_analysis(rows: Sequence[Mapping[str, HistoryValue]]) -> dict[str, object]:
    analysis: dict[str, object] = {
        "epoch_count": len(rows),
        "source": "Training/validation history only; no held-out test tuning or thresholds.",
        "overfitting_signal": "insufficient_history",
        "underfitting_signal": "not_established",
        "observations": [],
    }
    if not rows:
        analysis["observations"] = ["No learning history is available."]
        return analysis
    first, final = rows[0], rows[-1]
    best = min(rows, key=lambda row: cast("float", row["validation_loss"]))
    analysis.update(
        {
            "final_epoch": final["epoch"],
            "best_validation_loss_epoch": best["epoch"],
            "final_accuracy_gap": cast("float", final["train_accuracy"])
            - cast("float", final["validation_accuracy"]),
            "final_loss_gap": cast("float", final["validation_loss"])
            - cast("float", final["train_loss"]),
            "train_loss_change": cast("float", final["train_loss"])
            - cast("float", first["train_loss"]),
            "validation_loss_change": cast("float", final["validation_loss"])
            - cast("float", first["validation_loss"]),
        }
    )
    observations = [
        "Accuracy/loss gaps describe this split, not independent field or plant generalization.",
        "Underfitting is not established without a task baseline, convergence "
        "evidence and capacity checks.",
    ]
    if len(rows) > 1:
        divergence = cast("float", final["train_loss"]) < cast(
            "float", best["train_loss"]
        ) and cast("float", final["validation_loss"]) > cast("float", best["validation_loss"])
        analysis["overfitting_signal"] = (
            "possible_overfitting" if divergence else "no_clear_divergence"
        )
        if divergence:
            observations.append(
                "Training loss improved while validation loss worsened after its minimum; "
                "this is directional overfitting evidence, not proof or "
                "a test-based selection rule."
            )
        elif cast("float", final["train_loss"]) >= cast("float", first["train_loss"]) and cast(
            "float", final["validation_loss"]
        ) >= cast("float", first["validation_loss"]):
            observations.append(
                "Neither loss improved across recorded epochs; investigate optimization/data "
                "before attributing the result to insufficient model capacity."
            )
        else:
            observations.append("No final train/validation loss divergence was established.")
    analysis["observations"] = observations
    return analysis


def analyze_generalization(
    train_metrics: EvaluationMetrics,
    validation_metrics: EvaluationMetrics,
    history: Sequence[HistoryRecord] = (),
) -> dict[str, object]:
    """Compare the selected model on deterministic train/validation data only.

    A score gap is evidence to investigate, not proof of overfitting. Failure to
    beat both majority references suggests insufficient learning/optimization, not
    a certified model-capacity diagnosis. This helper never receives test metrics.
    """
    if train_metrics["class_names"] != validation_metrics["class_names"]:
        raise ValueError("Generalization comparisons must use the same ordered class map.")
    train_reference = (
        max(item["support"] for item in train_metrics["per_class"]) / train_metrics["sample_count"]
    )
    validation_reference = (
        max(item["support"] for item in validation_metrics["per_class"])
        / validation_metrics["sample_count"]
    )
    accuracy_gap = train_metrics["accuracy"] - validation_metrics["accuracy"]
    train_f1, validation_f1 = train_metrics["macro_f1"], validation_metrics["macro_f1"]
    observations = [
        "These selected-model scores use deterministic, unaugmented train/validation inputs.",
        "Distribution differences and finite-sample variation can also create accuracy gaps.",
        "Independent field/plant generalization is not established by these internal splits.",
        "Neither this comparison nor the held-out test chooses hyperparameters or thresholds.",
    ]
    if accuracy_gap > 0:
        observations.append(
            "Selected-model training accuracy exceeds validation accuracy; investigate the "
            "gap with history/per-class evidence rather than claiming overfitting from it alone."
        )
    insufficient_learning = (
        train_metrics["accuracy"] <= train_reference
        and validation_metrics["accuracy"] <= validation_reference
    )
    if insufficient_learning:
        observations.append(
            "Both accuracies fail to exceed their majority-class references; insufficient "
            "learning or optimization failure is possible. This does not prove model undercapacity."
        )
    return {
        "comparison_source": "Selected checkpoint; deterministic training and validation only.",
        "train_accuracy": train_metrics["accuracy"],
        "validation_accuracy": validation_metrics["accuracy"],
        "accuracy_gap": accuracy_gap,
        "train_macro_f1": train_f1,
        "validation_macro_f1": validation_f1,
        "macro_f1_gap": None
        if train_f1 is None or validation_f1 is None
        else train_f1 - validation_f1,
        "train_majority_accuracy_reference": train_reference,
        "validation_majority_accuracy_reference": validation_reference,
        "overfitting_signal": "train_validation_gap"
        if accuracy_gap > 0
        else "no_positive_accuracy_gap",
        "underfitting_signal": "possible_underfitting_or_optimization_failure"
        if insufficient_learning
        else "not_established",
        "history": _history_analysis(_validated_history(history)),
        "observations": observations,
    }


def _save_plots(
    output: Path,
    metrics: EvaluationMetrics,
    history: Sequence[Mapping[str, HistoryValue]],
    targets: NDArray[np.int64] | None,
    scores: NDArray[np.float64] | None,
    split: str,
) -> dict[str, str]:
    from matplotlib.backends.backend_agg import FigureCanvasAgg
    from matplotlib.figure import Figure

    artifacts: dict[str, str] = {}
    figure = Figure(figsize=(9, 8), layout="constrained")
    FigureCanvasAgg(figure)
    axis = figure.subplots()
    matrix = np.asarray(metrics["confusion_matrix"])
    image = axis.imshow(matrix, cmap="Blues", vmin=0)
    figure.colorbar(image, ax=axis, label="Samples")
    names = [textwrap.fill(name, width=22) for name in metrics["class_names"]]
    axis.set(
        xticks=range(len(names)),
        yticks=range(len(names)),
        xticklabels=names,
        yticklabels=names,
        xlabel="Predicted class",
        ylabel="True class",
        title=f"{split.capitalize()} confusion matrix",
    )
    axis.tick_params(axis="x", rotation=30)
    for row in range(len(names)):
        for column in range(len(names)):
            axis.text(
                column,
                row,
                str(matrix[row, column]),
                ha="center",
                va="center",
                color="white" if matrix[row, column] > matrix.max() / 2 else "black",
            )
    figure.savefig(output / "confusion-matrix.png", dpi=160)
    figure.clear()
    artifacts["confusion_matrix"] = "confusion-matrix.png"
    if history:
        figure = Figure(figsize=(12, 5), layout="constrained")
        FigureCanvasAgg(figure)
        loss_axis, accuracy_axis = figure.subplots(1, 2)
        epochs = [cast("int", row["epoch"]) for row in history]
        for prefix, caption, color in (
            ("train", "Train", "#2563eb"),
            ("validation", "Validation", "#d97706"),
        ):
            loss_axis.plot(
                epochs,
                [row[f"{prefix}_loss"] for row in history],
                label=caption,
                color=color,
                marker="o",
            )
            accuracy_axis.plot(
                epochs,
                [row[f"{prefix}_accuracy"] for row in history],
                label=caption,
                color=color,
                marker="o",
            )
        for axis, title, ylabel in (
            (loss_axis, "Learning loss", "Loss"),
            (accuracy_axis, "Learning accuracy", "Accuracy"),
        ):
            axis.set(title=title, xlabel="Epoch", ylabel=ylabel)
            axis.grid(alpha=0.2)
            axis.legend()
        accuracy_axis.set_ylim(0, 1)
        figure.savefig(output / "training-history.png", dpi=160)
        figure.clear()
        artifacts["history_curves"] = "training-history.png"
    if (
        targets is not None
        and scores is not None
        and any(item["roc_auc"] is not None for item in metrics["per_class"])
    ):
        figure = Figure(figsize=(8, 6), layout="constrained")
        FigureCanvasAgg(figure)
        axis = figure.subplots()
        for item in metrics["per_class"]:
            if item["roc_auc"] is None:
                continue
            false_positive, true_positive, _ = roc_curve(
                targets == item["index"], scores[:, item["index"]]
            )
            axis.plot(
                false_positive, true_positive, label=f"{item['label']} (AUC={item['roc_auc']:.4f})"
            )
        axis.plot([0, 1], [0, 1], linestyle="--", color="gray", label="Chance reference")
        axis.set(
            title=f"{split.capitalize()} defined one-vs-rest ROC curves",
            xlabel="False positive rate",
            ylabel="True positive rate",
            xlim=(0, 1),
            ylim=(0, 1),
        )
        axis.grid(alpha=0.2)
        axis.legend(fontsize="small")
        figure.savefig(output / "roc-curves.png", dpi=160)
        figure.clear()
        artifacts["roc_curves"] = "roc-curves.png"
    return artifacts


def save_reports(
    output_dir: Path,
    metrics: EvaluationMetrics,
    history: Sequence[HistoryRecord],
    *,
    labels: ArrayLike | None = None,
    probabilities: ArrayLike | None = None,
    split: str = "test",
) -> dict[str, str]:
    """Write JSON/text and standalone plots; refuse existing report artifacts.

    Only class names, aggregate counts/scores and train/validation history enter
    reports. Dataset paths/raw images are not accepted or redistributed here.
    """
    if split not in {"train", "validation", "test"}:
        raise ValueError("The report split must be train, validation or test.")
    rows = _validated_history(history)
    if (labels is None) != (probabilities is None):
        raise ValueError("ROC plotting requires labels and probabilities together.")
    targets: NDArray[np.int64] | None = None
    scores: NDArray[np.float64] | None = None
    if labels is not None and probabilities is not None:
        targets, scores, _ = _validated_inputs(labels, probabilities, metrics["class_names"])
        if compute_metrics(targets, scores, metrics["class_names"]) != metrics:
            raise ValueError("Plot inputs do not match the supplied evaluation metrics.")
    payload = {**metrics, "generalization": _history_analysis(rows)}
    encoded = json.dumps(payload, indent=2, allow_nan=False) + "\n"
    names = ["metrics.json", "classification-summary.txt", "confusion-matrix.png"]
    if rows:
        names.append("training-history.png")
    if targets is not None and any(item["roc_auc"] is not None for item in metrics["per_class"]):
        names.append("roc-curves.png")
    if any((output_dir / name).exists() for name in names):
        raise FileExistsError("A report artifact already exists; choose a new output directory.")
    output_dir.mkdir(parents=True, exist_ok=True)
    artifacts = _save_plots(output_dir, metrics, rows, targets, scores, split)
    (output_dir / "metrics.json").write_text(encoded, encoding="utf-8")
    (output_dir / "classification-summary.txt").write_text(
        metrics["classification_summary"], encoding="utf-8"
    )
    artifacts.update(metrics="metrics.json", classification_summary="classification-summary.txt")
    return artifacts
