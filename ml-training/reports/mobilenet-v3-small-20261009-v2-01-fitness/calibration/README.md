# Corrected-v2 validation-only calibration

All diagnostics use this new classifier's 627 saved validation probabilities. No test probabilities or images were read. Five calibration folds use seed 20261007 and keep known v2 groups intact. No prior v1 temperature is reused.

Scalar temperature is enabled only when the non-boundary all-validation fit has directional out-of-fold NLL/Brier/ECE support and a majority of folds improves held-out NLL. Otherwise raw probabilities are preserved with disabled calibration. Full-validation fitted metrics are descriptive resubstitution. Classifier selection already used validation, so calibration cross-fitting does not establish a fresh independent classifier holdout.

No operational threshold is locked: acceptable risk, coverage and class-specific costs are undefined. Candidate risk curves and high-confidence cutoffs are diagnostics only. Wilson intervals are descriptive per-row intervals and do not correct unknown plant/source dependence or threshold search.

Plots compare raw and out-of-fold calibrator probabilities. Brier sums squared errors across classes; NLL uses natural logarithms with a recorded 1e-15 floor; top-label ECE uses 15 equal-width bins with one included in the final bin. Raw source images, local machine paths and private metadata are absent. The underlying corpus's earlier test consumption remains a scientific limitation.
