"""Validation-only calibration diagnostics; no model, image or test-set loading.

Temperature scaling operates on saved probabilities as softmax(log(p) / T).
The recorded floor handles unavailable underflowed logits; it is never hidden.
Cross-fitting holds out whole known groups for the calibrator, but cannot undo
the classifier's earlier selection on the same validation set. Neither a high
confidence cutoff nor a selective curve establishes an operational risk policy.
"""

import math
from collections import defaultdict
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import cast

import numpy as np
from numpy.typing import ArrayLike, NDArray
from pydantic import BaseModel, ConfigDict

PROBABILITY_FLOOR = 1e-15
DIAGNOSTIC_CUTOFFS = (0.90, 0.95, 0.99)
CANDIDATE_THRESHOLDS = (0.0, 0.5, 0.6, 0.7, 0.8, 0.85, 0.9, 0.95, 0.97, 0.99)


class Report(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid", strict=True, allow_inf_nan=False)


class BinomialInterval(Report):
    lower: float
    upper: float
    confidence_level: float = 0.95


class ReliabilityBin(Report):
    lower: float
    upper: float
    count: int
    mean_confidence: float | None
    observed_accuracy: float | None


class ProbabilityMetrics(Report):
    sample_count: int
    accuracy: float
    nll: float
    brier: float
    ece: float
    bin_count: int
    reliability_bins: tuple[ReliabilityBin, ...]
    probability_floor: float = PROBABILITY_FLOOR
    true_probabilities_below_floor: int
    probability_values_below_floor: int
    definitions: tuple[str, ...] = (
        "NLL: mean -log(max(p_true, probability_floor)); natural logarithm.",
        "Brier: mean sum_k (p_k - onehot_k)^2; not divided by class count.",
        "ECE: sum_bin count/N * abs(observed top-label accuracy - mean confidence).",
        "Equal-width confidence bins are [lower,upper); the last includes 1.",
        "Empty bins have null accuracy/confidence and contribute zero to ECE.",
    )


class ConfidenceSummary(Report):
    count: int
    mean: float | None
    median: float | None
    tenth_percentile: float | None
    ninetieth_percentile: float | None


class ClassConfidence(Report):
    index: int
    label: str
    support: int
    correct: ConfidenceSummary
    incorrect: ConfidenceSummary


class ErrorPair(Report):
    true_label: str
    predicted_label: str
    count: int


class HighConfidenceErrors(Report):
    diagnostic_cutoff: float
    accepted_count: int
    incorrect_count: int
    pairs: tuple[ErrorPair, ...]


class ConfidenceReport(Report):
    class_names: tuple[str, ...]
    metrics: ProbabilityMetrics
    correct: ConfidenceSummary
    incorrect: ConfidenceSummary
    per_true_class: tuple[ClassConfidence, ...]
    high_confidence_errors: tuple[HighConfidenceErrors, ...]
    correct_histogram: tuple[int, ...]
    incorrect_histogram: tuple[int, ...]
    cutoff_usage: str = "Diagnostic cutoffs only; no operational threshold is selected."


class ClassCoverage(Report):
    index: int
    label: str
    support: int
    accepted_count: int
    coverage: float | None
    accepted_correct_count: int
    accepted_accuracy: float | None
    accepted_error_interval: BinomialInterval | None


class SelectivePoint(Report):
    threshold: float
    accepted_count: int
    correct_count: int
    error_count: int
    coverage: float
    rejection_rate: float
    accepted_accuracy: float | None
    accepted_error_rate: float | None
    accepted_error_interval: BinomialInterval | None
    per_true_class: tuple[ClassCoverage, ...]


class RiskCoverageReport(Report):
    class_names: tuple[str, ...]
    sample_count: int
    candidates: tuple[SelectivePoint, ...]
    selected_threshold: float | None = None
    selection_reason: str = (
        "No threshold locked: acceptable risk, minimum coverage, class-specific costs "
        "and field-domain evidence have not been defined."
    )
    interval_assumption: str = (
        "95% Wilson binomial intervals are descriptive per-row intervals. Unknown "
        "plant/source dependence and data-dependent threshold search are not corrected."
    )


class TemperatureFit(Report):
    temperature: float
    raw_nll: float
    fitted_nll: float
    lower_bound: float
    upper_bound: float
    boundary_solution: bool
    fit_sample_count: int
    probability_floor: float = PROBABILITY_FLOOR
    fitting_objective: str = "Multiclass NLL on supplied calibration-fit rows only."
    interpretation: str = "Fit-set NLL is resubstitution, not an independent performance estimate."


class FoldDiagnostics(Report):
    fold: int
    fit_count: int
    held_out_count: int
    fit_group_count: int
    held_out_group_count: int
    fit_class_counts: tuple[int, ...]
    held_out_class_counts: tuple[int, ...]
    temperature_fit: TemperatureFit
    raw_held_out: ProbabilityMetrics
    calibrated_held_out: ProbabilityMetrics


class CrossFitReport(Report):
    n_splits: int
    seed: int
    raw: ProbabilityMetrics
    out_of_fold: ProbabilityMetrics
    folds: tuple[FoldDiagnostics, ...]
    scope: str = (
        "Calibration-only group-aware stratified cross-fitting of supplied validation rows."
    )
    limitations: tuple[str, ...] = (
        "Each calibrator sees no labels or probabilities from its held-out groups.",
        "Classifier weights were already selected using this validation set; "
        "this is not a fresh holdout.",
        "Known image groups do not establish independent plants, fields or sources.",
        "ECE is bin-dependent; fit selection must not use the consumed test partition.",
    )


@dataclass(frozen=True)
class CrossFitResult:
    report: CrossFitReport
    probabilities: NDArray[np.float64]
    fold_ids: NDArray[np.int64]


def _scores(probabilities: ArrayLike) -> NDArray[np.float64]:
    values = np.asarray(probabilities, dtype=np.float64)
    if values.ndim != 2 or values.shape[0] == 0 or values.shape[1] < 2:
        raise ValueError("Probabilities must have nonempty N by K shape with K >= 2.")
    if not np.isfinite(values).all() or (values < 0).any() or (values > 1).any():
        raise ValueError("Probabilities must be finite and bounded by zero and one.")
    if not np.allclose(values.sum(axis=1), 1, atol=1e-6, rtol=1e-6):
        raise ValueError("Probability rows must sum to one.")
    return values


def _inputs(
    labels: ArrayLike, probabilities: ArrayLike, class_names: Sequence[str] | None = None
) -> tuple[NDArray[np.int64], NDArray[np.float64]]:
    scores = _scores(probabilities)
    raw = np.asarray(labels)
    if raw.ndim != 1 or len(raw) != len(scores) or raw.dtype.kind not in {"i", "u"}:
        raise ValueError("Labels must be one integer per probability row.")
    if (raw < 0).any() or (raw >= scores.shape[1]).any():
        raise ValueError("Labels must reference a probability-column index.")
    if class_names is not None and (
        len(class_names) != scores.shape[1]
        or len(set(class_names)) != len(class_names)
        or any(not isinstance(name, str) or not name.strip() for name in class_names)
    ):
        raise ValueError("Class names must be distinct nonempty probability-column names.")
    return raw.astype(np.int64), scores


def wilson_interval(successes: int, total: int) -> BinomialInterval | None:
    """95% two-sided Wilson interval; zero accepted rows are undefined, not zero risk."""
    if type(successes) is not int or type(total) is not int or not 0 <= successes <= total:
        raise ValueError("Binomial counts must be integers with 0 <= successes <= total.")
    if total == 0:
        return None
    z = 1.959963984540054
    rate = successes / total
    divisor = 1 + z * z / total
    centre = (rate + z * z / (2 * total)) / divisor
    half = z * math.sqrt(rate * (1 - rate) / total + z * z / (4 * total**2)) / divisor
    return BinomialInterval(lower=max(0.0, centre - half), upper=min(1.0, centre + half))


def probability_metrics(
    labels: ArrayLike, probabilities: ArrayLike, *, bins: int = 15
) -> ProbabilityMetrics:
    targets, scores = _inputs(labels, probabilities)
    if type(bins) is not int or not 2 <= bins <= 100:
        raise ValueError("Reliability bin count must be an integer between two and 100.")
    confidence = scores.max(axis=1)
    correct = scores.argmax(axis=1) == targets
    indices = np.minimum((confidence * bins).astype(np.int64), bins - 1)
    reports: list[ReliabilityBin] = []
    ece = 0.0
    for index in range(bins):
        selected = indices == index
        count = int(selected.sum())
        mean = float(confidence[selected].mean()) if count else None
        accuracy = float(correct[selected].mean()) if count else None
        if mean is not None and accuracy is not None:
            ece += count / len(scores) * abs(accuracy - mean)
        reports.append(
            ReliabilityBin(
                lower=index / bins,
                upper=(index + 1) / bins,
                count=count,
                mean_confidence=mean,
                observed_accuracy=accuracy,
            )
        )
    true_scores = scores[np.arange(len(targets)), targets]
    one_hot = np.eye(scores.shape[1])[targets]
    return ProbabilityMetrics(
        sample_count=len(scores),
        accuracy=float(correct.mean()),
        nll=float(-np.log(np.maximum(true_scores, PROBABILITY_FLOOR)).mean()),
        brier=float(np.square(scores - one_hot).sum(axis=1).mean()),
        ece=float(ece),
        bin_count=bins,
        reliability_bins=tuple(reports),
        true_probabilities_below_floor=int((true_scores < PROBABILITY_FLOOR).sum()),
        probability_values_below_floor=int((scores < PROBABILITY_FLOOR).sum()),
    )


def _summary(values: NDArray[np.float64]) -> ConfidenceSummary:
    if len(values) == 0:
        return ConfidenceSummary(
            count=0, mean=None, median=None, tenth_percentile=None, ninetieth_percentile=None
        )
    return ConfidenceSummary(
        count=len(values),
        mean=float(values.mean()),
        median=float(np.median(values)),
        tenth_percentile=float(np.quantile(values, 0.1)),
        ninetieth_percentile=float(np.quantile(values, 0.9)),
    )


def _thresholds(values: Sequence[float]) -> tuple[float, ...]:
    if not values or any(not math.isfinite(value) or not 0 <= value <= 1 for value in values):
        raise ValueError("Thresholds must be a nonempty sequence of finite values in [0,1].")
    if len(set(values)) != len(values):
        raise ValueError("Duplicate candidate thresholds are not allowed.")
    return tuple(float(value) for value in values)


def confidence_diagnostics(
    labels: ArrayLike,
    probabilities: ArrayLike,
    class_names: Sequence[str],
    *,
    bins: int = 15,
    error_cutoffs: Sequence[float] = DIAGNOSTIC_CUTOFFS,
) -> ConfidenceReport:
    targets, scores = _inputs(labels, probabilities, class_names)
    predictions = scores.argmax(axis=1)
    confidence = scores.max(axis=1)
    correct = predictions == targets
    cuts: list[HighConfidenceErrors] = []
    for cutoff in _thresholds(error_cutoffs):
        accepted = confidence >= cutoff
        pairs = tuple(
            ErrorPair(true_label=true, predicted_label=predicted, count=count)
            for count, true, predicted in sorted(
                (
                    (
                        int(((targets == i) & (predictions == j) & accepted).sum()),
                        class_names[i],
                        class_names[j],
                    )
                    for i in range(len(class_names))
                    for j in range(len(class_names))
                    if i != j and ((targets == i) & (predictions == j) & accepted).any()
                ),
                reverse=True,
            )
        )
        cuts.append(
            HighConfidenceErrors(
                diagnostic_cutoff=cutoff,
                accepted_count=int(accepted.sum()),
                incorrect_count=int((accepted & ~correct).sum()),
                pairs=pairs,
            )
        )
    histogram_edges = np.linspace(0, 1, bins + 1)
    return ConfidenceReport(
        class_names=tuple(class_names),
        metrics=probability_metrics(targets, scores, bins=bins),
        correct=_summary(confidence[correct]),
        incorrect=_summary(confidence[~correct]),
        per_true_class=tuple(
            ClassConfidence(
                index=index,
                label=label,
                support=int((targets == index).sum()),
                correct=_summary(confidence[(targets == index) & correct]),
                incorrect=_summary(confidence[(targets == index) & ~correct]),
            )
            for index, label in enumerate(class_names)
        ),
        high_confidence_errors=tuple(cuts),
        correct_histogram=tuple(
            int(count) for count in np.histogram(confidence[correct], histogram_edges)[0]
        ),
        incorrect_histogram=tuple(
            int(count) for count in np.histogram(confidence[~correct], histogram_edges)[0]
        ),
    )


def selective_risk_coverage(
    labels: ArrayLike,
    probabilities: ArrayLike,
    class_names: Sequence[str],
    *,
    thresholds: Sequence[float] = CANDIDATE_THRESHOLDS,
) -> RiskCoverageReport:
    targets, scores = _inputs(labels, probabilities, class_names)
    confidence = scores.max(axis=1)
    correct = scores.argmax(axis=1) == targets
    candidates: list[SelectivePoint] = []
    for threshold in _thresholds(thresholds):
        accepted = confidence >= threshold
        count = int(accepted.sum())
        successes = int((accepted & correct).sum())
        class_reports: list[ClassCoverage] = []
        for index, name in enumerate(class_names):
            selected = targets == index
            support = int(selected.sum())
            class_count = int((accepted & selected).sum())
            class_correct = int((accepted & selected & correct).sum())
            class_reports.append(
                ClassCoverage(
                    index=index,
                    label=name,
                    support=support,
                    accepted_count=class_count,
                    coverage=class_count / support if support else None,
                    accepted_correct_count=class_correct,
                    accepted_accuracy=class_correct / class_count if class_count else None,
                    accepted_error_interval=wilson_interval(
                        class_count - class_correct, class_count
                    ),
                )
            )
        candidates.append(
            SelectivePoint(
                threshold=threshold,
                accepted_count=count,
                correct_count=successes,
                error_count=count - successes,
                coverage=count / len(targets),
                rejection_rate=1 - count / len(targets),
                accepted_accuracy=successes / count if count else None,
                accepted_error_rate=(count - successes) / count if count else None,
                accepted_error_interval=wilson_interval(count - successes, count),
                per_true_class=tuple(class_reports),
            )
        )
    return RiskCoverageReport(
        class_names=tuple(class_names), sample_count=len(targets), candidates=tuple(candidates)
    )


def apply_temperature(probabilities: ArrayLike, temperature: float) -> NDArray[np.float64]:
    scores = _scores(probabilities)
    if not math.isfinite(temperature) or temperature <= 0:
        raise ValueError("Temperature must be positive and finite.")
    centred = np.log(np.maximum(scores, PROBABILITY_FLOOR))
    centred -= centred.max(axis=1, keepdims=True)
    # Centre before dividing so tiny positive T can approach a hard argmax
    # without the inf-minus-inf indeterminacy of uncentred log probabilities.
    with np.errstate(over="ignore", under="ignore"):
        powered = np.exp(centred / temperature)
    return cast(NDArray[np.float64], powered / powered.sum(axis=1, keepdims=True))


def fit_temperature(
    labels: ArrayLike,
    probabilities: ArrayLike,
    *,
    lower_bound: float = 0.25,
    upper_bound: float = 4.0,
) -> TemperatureFit:
    """Deterministic scalar NLL minimization; always include T=1 as a reference."""
    targets, scores = _inputs(labels, probabilities)
    if not (
        math.isfinite(lower_bound)
        and math.isfinite(upper_bound)
        and 0 < lower_bound < 1 < upper_bound
    ):
        raise ValueError("Temperature bounds must be finite, positive and bracket one.")
    log_scores = np.log(np.maximum(scores, PROBABILITY_FLOOR))

    def objective(log_temperature: float) -> float:
        logits = log_scores / math.exp(log_temperature)
        maximum = logits.max(axis=1)
        normalizer = maximum + np.log(np.exp(logits - maximum[:, None]).sum(axis=1))
        return float((normalizer - logits[np.arange(len(targets)), targets]).mean())

    left, right = math.log(lower_bound), math.log(upper_bound)
    ratio = (math.sqrt(5) - 1) / 2
    a, b = right - ratio * (right - left), left + ratio * (right - left)
    fa, fb = objective(a), objective(b)
    for _ in range(96):
        if right - left < 1e-9:
            break
        if fa < fb:
            right, b, fb = b, a, fa
            a = right - ratio * (right - left)
            fa = objective(a)
        else:
            left, a, fa = a, b, fb
            b = left + ratio * (right - left)
            fb = objective(b)
    candidates = [math.log(lower_bound), math.log(upper_bound), 0.0, (left + right) / 2]
    chosen = min(candidates, key=objective)
    temperature = math.exp(chosen)
    return TemperatureFit(
        temperature=temperature,
        raw_nll=probability_metrics(targets, scores).nll,
        fitted_nll=objective(chosen),
        lower_bound=lower_bound,
        upper_bound=upper_bound,
        boundary_solution=any(
            math.isclose(temperature, bound, rel_tol=1e-8) for bound in (lower_bound, upper_bound)
        ),
        fit_sample_count=len(targets),
    )


def crossfit_temperature(
    labels: ArrayLike,
    probabilities: ArrayLike,
    groups: Sequence[str],
    class_names: Sequence[str],
    *,
    n_splits: int = 5,
    seed: int = 20261008,
) -> CrossFitResult:
    targets, scores = _inputs(labels, probabilities, class_names)
    if len(groups) != len(targets) or any(
        not isinstance(group, str) or not group for group in groups
    ):
        raise ValueError("One nonempty group identity is required per row.")
    if type(n_splits) is not int or n_splits < 2:
        raise ValueError("Cross-fitting requires at least two folds.")
    members: dict[str, list[int]] = defaultdict(list)
    for index, group in enumerate(groups):
        members[group].append(index)
    by_class: dict[int, list[str]] = defaultdict(list)
    for group, indices in members.items():
        classes = set(int(targets[index]) for index in indices)
        if len(classes) != 1:
            raise ValueError("Contradictory class groups cannot enter calibration cross-fitting.")
        by_class[classes.pop()].append(group)
    if any(len(by_class[index]) < n_splits for index in range(len(class_names))):
        raise ValueError("Each class requires at least one distinct group in every fold.")
    random = np.random.default_rng(seed)
    folds = np.full(len(targets), -1, dtype=np.int64)
    fold_total = [0] * n_splits
    for index in range(len(class_names)):
        class_groups = by_class[index]
        random.shuffle(class_groups)
        class_groups.sort(key=lambda group: -len(members[group]))
        class_total = [0] * n_splits
        for group in class_groups:
            chosen = min(
                range(n_splits), key=lambda fold: (class_total[fold], fold_total[fold], fold)
            )
            folds[members[group]] = chosen
            class_total[chosen] += len(members[group])
            fold_total[chosen] += len(members[group])
    result = np.empty_like(scores)
    reports: list[FoldDiagnostics] = []
    for fold in range(n_splits):
        held_out = folds == fold
        fit_rows = ~held_out
        fit_groups = {group for index, group in enumerate(groups) if fit_rows[index]}
        held_out_groups = {group for index, group in enumerate(groups) if held_out[index]}
        if fit_groups & held_out_groups:
            raise ValueError("Calibration-fit groups overlap held-out groups.")
        fitted = fit_temperature(targets[fit_rows], scores[fit_rows])
        result[held_out] = apply_temperature(scores[held_out], fitted.temperature)
        reports.append(
            FoldDiagnostics(
                fold=fold,
                fit_count=int(fit_rows.sum()),
                held_out_count=int(held_out.sum()),
                fit_group_count=len(fit_groups),
                held_out_group_count=len(held_out_groups),
                fit_class_counts=tuple(
                    int(x) for x in np.bincount(targets[fit_rows], minlength=len(class_names))
                ),
                held_out_class_counts=tuple(
                    int(x) for x in np.bincount(targets[held_out], minlength=len(class_names))
                ),
                temperature_fit=fitted,
                raw_held_out=probability_metrics(targets[held_out], scores[held_out]),
                calibrated_held_out=probability_metrics(targets[held_out], result[held_out]),
            )
        )
    return CrossFitResult(
        report=CrossFitReport(
            n_splits=n_splits,
            seed=seed,
            raw=probability_metrics(targets, scores),
            out_of_fold=probability_metrics(targets, result),
            folds=tuple(reports),
        ),
        probabilities=result,
        fold_ids=folds,
    )


def save_diagnostic_plots(
    output: Path,
    raw_report: ConfidenceReport,
    *,
    calibrated_report: ConfidenceReport | None = None,
    raw_selective: RiskCoverageReport | None = None,
    calibrated_selective: RiskCoverageReport | None = None,
) -> tuple[str, ...]:
    """Standalone numerical figures only; existing files are never overwritten."""
    from matplotlib.backends.backend_agg import FigureCanvasAgg
    from matplotlib.figure import Figure

    names = ["reliability.png", "confidence-distribution.png"]
    if raw_selective is not None:
        names.append("selective-risk-coverage.png")
    if any((output / name).exists() for name in names):
        raise FileExistsError("Diagnostic plots already exist; choose a new destination.")
    if calibrated_report is not None and calibrated_report.class_names != raw_report.class_names:
        raise ValueError("Compared confidence reports must have identical class mapping.")
    output.mkdir(parents=True, exist_ok=True)
    figure = Figure(figsize=(8, 6), layout="constrained")
    FigureCanvasAgg(figure)
    axis = figure.subplots()
    axis.plot([0, 1], [0, 1], linestyle="--", color="gray", label="Ideal reference")
    for confidence_report, name in [(raw_report, "Raw"), (calibrated_report, "Calibrated")]:
        if confidence_report is None:
            continue
        populated = [row for row in confidence_report.metrics.reliability_bins if row.count]
        axis.plot(
            [cast(float, row.mean_confidence) for row in populated],
            [cast(float, row.observed_accuracy) for row in populated],
            marker="o",
            label=f"{name} ECE={confidence_report.metrics.ece:.4f}",
        )
    axis.set(
        xlabel="Mean top-label confidence",
        ylabel="Observed accuracy",
        title="Equal-width reliability diagnostic",
        xlim=(0, 1),
        ylim=(0, 1),
    )
    axis.legend()
    figure.savefig(output / names[0], dpi=160)
    figure.clear()
    figure = Figure(figsize=(10, 5), layout="constrained")
    FigureCanvasAgg(figure)
    axis = figure.subplots()
    bin_count = raw_report.metrics.bin_count
    positions = (np.arange(bin_count) + 0.5) / bin_count
    axis.bar(
        positions, raw_report.correct_histogram, width=0.8 / bin_count, alpha=0.6, label="Correct"
    )
    axis.bar(
        positions,
        raw_report.incorrect_histogram,
        width=0.8 / bin_count,
        alpha=0.6,
        label="Incorrect",
    )
    axis.set(
        xlabel="Raw top-label confidence",
        ylabel="Count",
        title="Correct and incorrect confidence",
        xlim=(0, 1),
    )
    axis.legend()
    figure.savefig(output / names[1], dpi=160)
    figure.clear()
    if raw_selective is not None:
        figure = Figure(figsize=(8, 6), layout="constrained")
        FigureCanvasAgg(figure)
        axis = figure.subplots()
        for risk_report, name in [(raw_selective, "Raw"), (calibrated_selective, "Calibrated")]:
            if risk_report is None:
                continue
            points = [row for row in risk_report.candidates if row.accepted_count]
            axis.plot(
                [row.coverage for row in points],
                [cast(float, row.accepted_error_rate) for row in points],
                marker="o",
                label=name,
            )
            axis.fill_between(
                [row.coverage for row in points],
                [
                    row.accepted_error_interval.lower if row.accepted_error_interval else 0
                    for row in points
                ],
                [
                    row.accepted_error_interval.upper if row.accepted_error_interval else 1
                    for row in points
                ],
                alpha=0.15,
            )
        axis.set(
            xlabel="Accepted coverage",
            ylabel="Accepted error rate",
            title="Diagnostic selective risk; shaded 95% Wilson intervals",
            xlim=(0, 1),
            ylim=(0, 1),
        )
        axis.legend()
        figure.savefig(output / names[2], dpi=160)
        figure.clear()
    return tuple(names)
