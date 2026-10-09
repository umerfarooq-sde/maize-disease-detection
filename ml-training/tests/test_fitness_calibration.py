"""Hand-computed confidence/calibration maths and group isolation contracts."""

import json
import math

import numpy as np
import pytest
from PIL import Image

from fitness_calibration import (
    PROBABILITY_FLOOR,
    apply_temperature,
    confidence_diagnostics,
    crossfit_temperature,
    fit_temperature,
    probability_metrics,
    save_diagnostic_plots,
    selective_risk_coverage,
    wilson_interval,
)

NAMES = ("a", "b")


def test_hand_computed_nll_total_brier_and_ece():
    metrics = probability_metrics([0, 1], [[0.8, 0.2], [0.7, 0.3]], bins=2)
    assert metrics.accuracy == 0.5
    assert metrics.nll == pytest.approx((-math.log(0.8) - math.log(0.3)) / 2)
    assert metrics.brier == pytest.approx((0.08 + 0.98) / 2)
    assert metrics.ece == pytest.approx(0.25)
    assert metrics.reliability_bins[0].count == 0
    assert metrics.reliability_bins[0].observed_accuracy is None
    assert metrics.reliability_bins[1].mean_confidence == pytest.approx(0.75)


def test_reliability_bin_boundary_and_exact_one_not_dropped():
    metrics = probability_metrics([0, 1, 0], [[0.5, 0.5], [0.25, 0.75], [1, 0]], bins=4)
    assert [row.count for row in metrics.reliability_bins] == [0, 0, 1, 2]
    assert metrics.ece == pytest.approx((0.5 + 0.25) / 3)
    assert sum(row.count for row in metrics.reliability_bins) == 3


def test_zero_true_probability_nll_floor_is_explicit_finite_and_not_zero_error():
    metrics = probability_metrics([0], [[0, 1]])
    assert metrics.nll == pytest.approx(-math.log(PROBABILITY_FLOOR))
    assert metrics.true_probabilities_below_floor == 1
    assert metrics.probability_values_below_floor == 1
    assert metrics.brier == 2
    assert metrics.ece == 1
    assert "max(p_true" in metrics.definitions[0]
    json.dumps(metrics.model_dump(mode="json"), allow_nan=False)


@pytest.mark.parametrize(
    ("labels", "probabilities"),
    [
        ([], []),
        ([0], [[0.5, 0.4]]),
        ([0], [[-0.1, 1.1]]),
        ([0], [[float("nan"), 0.5]]),
        ([0], [[float("inf"), 0.5]]),
        ([0], [0.5, 0.5]),
        ([0.0], [[0.5, 0.5]]),
        ([True], [[0.5, 0.5]]),
        ([2], [[0.5, 0.5]]),
        ([0, 1], [[0.5, 0.5]]),
    ],
)
def test_invalid_probability_label_inputs_rejected(labels, probabilities):
    with pytest.raises(ValueError):
        probability_metrics(labels, probabilities)


def test_invalid_bins_and_class_names_rejected():
    for bins in [1, True, 101]:
        with pytest.raises(ValueError):
            probability_metrics([0], [[0.5, 0.5]], bins=bins)
    for names in [("a",), ("a", "a"), ("a", "")]:
        with pytest.raises(ValueError):
            confidence_diagnostics([0], [[0.5, 0.5]], names)


def test_wilson_zero_events_do_not_assert_zero_population_risk():
    interval = wilson_interval(0, 100)
    assert interval.lower == pytest.approx(0, abs=1e-15)
    assert interval.upper == pytest.approx(0.03699349820698568)
    assert wilson_interval(0, 0) is None
    interval = wilson_interval(50, 100)
    assert interval.lower == pytest.approx(0.4038315303659957)
    assert interval.upper == pytest.approx(0.5961684696340044)
    for successes, total in [(-1, 3), (4, 3), (True, 3), (0, -1)]:
        with pytest.raises(ValueError):
            wilson_interval(successes, total)


def test_confidence_error_counts_pairs_histograms_and_empty_summary():
    report = confidence_diagnostics([0, 1, 1], [[0.99, 0.01], [0.96, 0.04], [0.1, 0.9]], NAMES)
    assert report.correct.count == 2 and report.incorrect.count == 1
    assert report.incorrect.mean == pytest.approx(0.96)
    assert [row.incorrect_count for row in report.high_confidence_errors] == [1, 1, 0]
    assert report.high_confidence_errors[0].pairs[0].true_label == "b"
    assert report.high_confidence_errors[0].pairs[0].predicted_label == "a"
    assert sum(report.correct_histogram) == 2 and sum(report.incorrect_histogram) == 1
    assert report.per_true_class[0].incorrect.count == 0
    assert report.per_true_class[0].incorrect.mean is None


def test_selective_metrics_class_coverage_and_reject_all_are_not_fabricated():
    report = selective_risk_coverage(
        [0, 1, 1], [[0.9, 0.1], [0.8, 0.2], [0.3, 0.7]], NAMES, thresholds=[0, 0.85, 1]
    )
    all_rows, high, none = report.candidates
    assert all_rows.accepted_accuracy == pytest.approx(2 / 3)
    assert all_rows.accepted_error_rate == pytest.approx(1 / 3)
    assert high.coverage == pytest.approx(1 / 3)
    assert high.accepted_accuracy == 1
    assert high.per_true_class[1].coverage == 0
    assert high.per_true_class[1].accepted_accuracy is None
    assert none.coverage == 0 and none.rejection_rate == 1
    assert none.accepted_accuracy is none.accepted_error_rate is None
    assert none.accepted_error_interval is None
    assert report.selected_threshold is None
    assert "risk" in report.selection_reason


def test_absent_class_coverage_null_not_zero():
    report = selective_risk_coverage([0], [[0.9, 0.1]], NAMES)
    assert report.candidates[0].per_true_class[1].support == 0
    assert report.candidates[0].per_true_class[1].coverage is None
    for cuts in [[], [float("nan")], [1.1], [0.5, 0.5]]:
        with pytest.raises(ValueError):
            selective_risk_coverage([0], [[0.9, 0.1]], NAMES, thresholds=cuts)


def test_temperature_transformation_matches_square_root_and_preserves_argmax():
    values = np.array([[0.8, 0.2], [0.1, 0.9]])
    copy = values.copy()
    scaled = apply_temperature(values, 2)
    expected = np.sqrt(values) / np.sqrt(values).sum(axis=1, keepdims=True)
    np.testing.assert_allclose(scaled, expected, rtol=1e-14)
    np.testing.assert_array_equal(values, copy)
    np.testing.assert_array_equal(scaled.argmax(axis=1), values.argmax(axis=1))
    np.testing.assert_allclose(apply_temperature(values, 1), values, rtol=1e-14)
    for temperature in [0, -1, float("nan"), float("inf")]:
        with pytest.raises(ValueError):
            apply_temperature(values, temperature)


def test_overconfident_bernoulli_fit_recovers_hand_derived_temperature():
    # Identical p(a)=.99, observed frequency(a)=.75; optimum produces .75/.25.
    labels = [0] * 75 + [1] * 25
    values = [[0.99, 0.01]] * 100
    fit = fit_temperature(labels, values, upper_bound=8)
    expected = math.log(99) / math.log(3)
    assert fit.temperature == pytest.approx(expected, rel=1e-6)
    assert fit.fitted_nll < fit.raw_nll
    assert not fit.boundary_solution
    assert apply_temperature(values, fit.temperature)[0, 0] == pytest.approx(0.75, abs=1e-7)
    assert fit.fit_sample_count == 100


def test_tiny_positive_temperature_has_finite_hard_argmax_limit():
    scaled = apply_temperature([[0.8, 0.2], [0.1, 0.9]], 1e-320)
    np.testing.assert_array_equal(scaled, [[1, 0], [0, 1]])
    assert np.isfinite(scaled).all()


def test_perfect_calibration_keeps_one_and_bounds_are_explicit():
    fit = fit_temperature([0] * 75 + [1] * 25, [[0.75, 0.25]] * 100)
    assert fit.temperature == pytest.approx(1, rel=1e-6)
    fit = fit_temperature([0] * 10, [[0.8, 0.2]] * 10)
    assert fit.temperature == pytest.approx(0.25)
    assert fit.boundary_solution
    for lower, upper in [(0, 4), (1, 4), (0.25, 1), (float("nan"), 4)]:
        with pytest.raises(ValueError):
            fit_temperature([0], [[0.8, 0.2]], lower_bound=lower, upper_bound=upper)


def grouped_fixture():
    labels, probabilities, groups = [], [], []
    for label in range(2):
        for group in range(10):
            for member in range(2):
                labels.append(label)
                probability = 0.98 if member == 0 else 0.8
                if group % 4 == 0:
                    probability = 1 - probability
                probabilities.append(
                    [probability, 1 - probability] if label == 0 else [1 - probability, probability]
                )
                groups.append(f"{label}:{group}")
    return np.array(labels), np.array(probabilities), groups


def test_group_crossfit_is_deterministic_stratified_and_no_group_overlap():
    labels, scores, groups = grouped_fixture()
    result = crossfit_temperature(labels, scores, groups, NAMES)
    repeated = crossfit_temperature(labels, scores, groups, NAMES)
    np.testing.assert_array_equal(result.fold_ids, repeated.fold_ids)
    np.testing.assert_array_equal(result.probabilities, repeated.probabilities)
    assert sorted(set(result.fold_ids)) == list(range(5))
    for group in set(groups):
        assert len(set(result.fold_ids[np.array(groups) == group])) == 1
    for fold in result.report.folds:
        fit_rows = result.fold_ids != fold.fold
        held_out = ~fit_rows
        independent_fit = fit_temperature(labels[fit_rows], scores[fit_rows])
        assert fold.temperature_fit == independent_fit
        np.testing.assert_allclose(
            result.probabilities[held_out],
            apply_temperature(scores[held_out], independent_fit.temperature),
        )
        assert all(value > 0 for value in fold.held_out_class_counts)
        assert fold.held_out_count == 8 and fold.fit_count == 32
    assert "not a fresh holdout" in result.report.limitations[1]


def test_group_crossfit_reports_missing_and_contradictory_group_limits():
    labels, scores, groups = grouped_fixture()
    with pytest.raises(ValueError):
        crossfit_temperature(labels, scores, groups[:-1], NAMES)
    with pytest.raises(ValueError):
        crossfit_temperature(labels, scores, ["same"] * len(labels), NAMES)
    with pytest.raises(ValueError):
        crossfit_temperature(labels, scores, groups, NAMES, n_splits=11)
    with pytest.raises(ValueError):
        crossfit_temperature(labels, scores, groups, NAMES, n_splits=1)


def test_plots_are_standalone_and_never_overwrite(tmp_path):
    labels = [0, 1, 1]
    scores = [[0.9, 0.1], [0.8, 0.2], [0.3, 0.7]]
    report = confidence_diagnostics(labels, scores, NAMES)
    risk = selective_risk_coverage(labels, scores, NAMES)
    names = save_diagnostic_plots(tmp_path, report, raw_selective=risk)
    assert names == (
        "reliability.png",
        "confidence-distribution.png",
        "selective-risk-coverage.png",
    )
    for name in names:
        with Image.open(tmp_path / name) as image:
            assert image.width >= 1000 and image.height >= 700
    before = {name: (tmp_path / name).read_bytes() for name in names}
    with pytest.raises(FileExistsError):
        save_diagnostic_plots(tmp_path, report, raw_selective=risk)
    assert before == {name: (tmp_path / name).read_bytes() for name in names}
