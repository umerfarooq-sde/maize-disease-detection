# Corrected V2 fitness audit — MobileNetV3 Small

This immutable report preserves exact aggregate results, saved probability CSVs,
configuration/provenance metadata and numerical Matplotlib plots. It contains no
raw photographs, Grad-CAM/contact/augmentation sheets, pixel caches or model weights.
Use is non-commercial academic/FYP research only. Licensing or source replacement
is required before commercial use; raw-image redistribution is prohibited.

The fresh corrected-index fit completed 11 epochs, stopped through the configured
validation patience rule and selected epoch 8 using validation macro F1 and loss
for exact ties. The old V1 split/evaluation was invalidated by newly confirmed
same-parent leakage. V2 has 4,162 eligible contents in 4,121 groups, with partitions
2,911 TRAIN / 627 VALIDATION / 624 TEST. Four new contradictory families (eight
contents) are wholly excluded, without deleting or relabeling any source file.

The pre-TEST candidate and decision freeze are copied without modification. The
selected policy retains raw probabilities: calibration disabled, temperature 1.0,
confidence threshold `null`. The diagnostic validation-fitted temperature is not
applied because group cross-fitting worsened NLL, Brier and ECE. Final TEST evaluated
the frozen checkpoint/index once: 598/624 correct (95.8333%), macro F1 0.9451708648.
The final addendum binds that frozen decision and makes no new model/policy choice.

These are descriptive results on a previously inspected corpus, not an unseen
external field holdout. Unknown plant/field/session identities and unresolved
Healthy candidate 24 across TRAIN/VALIDATION remain explicit risks. Source and GLS
weaknesses, high-confidence errors and single-seed limits remain. Verdict:
**FIT WITH DOCUMENTED LIMITATIONS**, restricted to an offline/FYP research inference
prototype; field/commercial farmer-diagnosis suitability is not established.
No Phase 11 API or production promotion was implemented.

`model-artifact.json` specifies the exact local checkpoint SHA/location, class map,
224×224 RGB shared preprocessing/normalization, V2 split/exclusions, seeds,
hyperparameters/dependencies, calibration policy, validation and final TEST results,
research restrictions and the untouched pre-TEST candidate bindings.
`model-artifact-validation.json` documents fail-closed critical-field checks.
`copy-provenance.json` maps every exact source-byte copy. `integrity.json` hashes
every report file except itself. `orchestration/*.txt` archives exact helper source
for audit, not serving code. `visual-metadata/` and `visual-review/` contain numerical
observations only; associated source-image sheets stay local and ignored.

The full local experiment and checkpoint remain under
`.cache/phase105/experiments/mobilenet-v3-small-20261009-v2-01/`.
Checkpoint `checkpoints/epoch-008.pt`, SHA-256:
`e95a2e83262637fc1a08b919e6003bddb2fe70664b9c51418f059b7c8287dc66`.
The canonical metadata-only index is
`ml-training/manifests/maize-research-20261008-v2/`.
Never overwrite this report or promote the checkpoint without preserving the
shared preprocessing, class mapping, hash bindings and documented limitations.
