# Phase 10.5 — model fitness and generalization audit

Audit date: 2026-10-09 (Asia/Karachi). Scope: offline fitness review, required
grouping repair, fresh bounded training and evaluation. No Phase 11 inference API,
Node orchestration or Flutter result workflow is implemented.

Phase 10.5 is complete. **FIT WITH DOCUMENTED LIMITATIONS** for a local FYP
research inference prototype. The original v1 scoring arithmetic is preserved, but
confirmed transformed-parent leakage invalidates its independent-evaluation claim.
The corrected v2 index and fresh model are verified; all 8,040 original files remain
unchanged. The new evaluation is descriptive on a previously inspected corpus,
without independent field/plant validation or commercial clearance.

Selected model version `mobilenet-v3-small-v2-20261009`, experiment
`mobilenet-v3-small-20261009-v2-01`, checkpoint `checkpoints/epoch-008.pt`,
SHA-256 `e95a2e83262637fc1a08b919e6003bddb2fe70664b9c51418f059b7c8287dc66`.
The completed run stops at epoch 11 under patience 3, out of 12 maximum. Validation:
**96.81% accuracy / 0.9589 macro F1**. One post-freeze final test: **95.83% / 0.9452**,
598 correct of 624. Test Gray Leaf Spot recall is **83.53%**, F1 **0.8659**. These are
internal benchmark scores, not measured farmer-field accuracy. Calibration remains
disabled (`T=1`): group cross-fitting worsens NLL/Brier/ECE. No confidence threshold
is locked. Read the
[safe numerical/artifact evidence](../ml-training/reports/mobilenet-v3-small-20261009-v2-01-fitness/README.md).

## Evidence and scientific boundary

The review reads actual source, configuration, indexed rows, exclusion and split
manifests, checkpoint payloads, saved prediction CSVs, numerical reports, training
curves and development-only image sheets. It preserves the original v1 experiment,
its immutable recovery and all published historical aggregate artifacts. Historical
v1 scores in [Phase 10](25-ml-training-evaluation.md) are superseded for independence
claims; they are not comparable evidence of improvement from v1 to v2.

V1's final test was already consumed. V2 is a corrected grouped partition of this
same inspected public corpus, including images previously used in v1 training or
evaluation. The new classifier starts from checked official ImageNet weights,
never v1 fitted weights. Its test is deferred until validation choices are frozen
and then evaluated once. This prevents further test-driven tuning of v2; it does
not turn the corpus into a new unseen external or plant-independent field test.

## Dataset identity and required repair

The raw directory contains 8,040 image files and 4,186 distinct byte contents.
Exact copies are represented as aliases, not extra model examples. The configured
path is read through `configuration.load_dataset_path()` / `DATASET_PATH` in ignored
local configuration; the committed template stays blank. No machine-specific source
path, raw photographs or fitted weights are redistributed in Git or this report.

Original approved exclusions remain: 11 shared-invalid inputs and three contradictory
families (seven filenames/five contents). V1 had 4,170 eligible contents in 4,161 groups.
Hash/group intersection checks alone missed some transformed copies of the same photo.

Expanded screening calculates 266,880 orientation/crop fingerprints: 64 variants
of each of the 4,170 v1-eligible unique contents, including eight dihedral orientations and full/center/
off-center regions. The development search uses perceptual-hash distance ≤8 and
difference-hash distance ≤12 to nominate pairs; these cutoffs are screening settings,
not an automatic identity or disease classifier. All 76 nominated unknown-group pairs
are manually inspected alongside registered images, distinctive tissue/background
landmarks and SIFT/RANSAC correspondence diagnostics. Geometry uses a 0.7 descriptor
ratio and 2-pixel RANSAC reprojection bound. Similar disease appearance alone is
insufficient evidence of a shared original photograph.

Review resolves 36 new parent relations: 32 same-label and four contradictory-label
families; 38 candidates are rejected as identity evidence and two Healthy pairs
(candidate IDs 24 and 58) remain unresolved. Rejection does not prove separate plants
or sessions. Of the new confirmed edges, 22 cross v1 partitions: 14 same-label
train/validation, seven same-label train/test and one conflicting train/validation.
This invalidates v1 independent-evaluation claims, even though its saved predictions
and arithmetic are internally consistent.

The four new contradictory photographic families are:

| Candidate | Gray_Leaf_Spot source member | Northern_Corn_Leaf_Blight source member | V1 relationship |
|---:|---|---|---|
| 1 | Gray_Leaf_Spot (501).jpg | Northern_Corn_Leaf_Blight (2093).jpg | validation / validation |
| 4 | Gray_Leaf_Spot (525).jpg | Northern_Corn_Leaf_Blight (1946).jpg | train / train |
| 35 | Gray_Leaf_Spot (928).jpg | Northern_Corn_Leaf_Blight (1995).jpg | validation / train |
| 56 | Gray_Leaf_Spot (600).jpg | Northern_Corn_Leaf_Blight (1822).jpg | train / train |

Exact relative paths and hashes are authoritative in the exclusion/relationship
manifests; this table abbreviates names for reading. These are rotations/crops of
the same photograph with 808–1,391 registered inliers, correlation 0.994–0.999 and
SSIM 0.920–0.990. Entire connected conflicting components and their aliases are
ineligible under the existing policy, with `CONTRADICTORY_LABEL_FAMILY` and
`PHASE105_NEW_CONTRADICTORY_FAMILY` reasons. No hard examples are removed merely
because the classifier fails them; no source is relabeled, deleted, renamed or edited.

V2 therefore excludes 26 files / 24 contents, including eight newly conflicting
contents (four GLS and four Blight). Of 8,040 files, 26 are ineligible, 3,852 remaining
copies are collapsed, and **4,162 eligible unique contents** remain in **4,121 groups**.
This arithmetic does not treat 8,040 filenames as independent training examples.

## Locked class mapping and partitions

The repair unions all original groups and confirmed parent relations, assigns stable
canonical group identities and calls the existing grouped stratified splitter with
the unchanged seed **20261007** and 70/15/15 targets. Group sizes determine the exact
rounded counts. The repair moves 1,783 surviving sample memberships; a new version
is required because preserving the leaking v1 split would be invalid.

| Index / literal label | Unique contents | Groups | Train | Validation | Test |
|---|---:|---:|---:|---:|---:|
| 0 / Common_Rust | 1,301 | 1,297 | 910 | 196 | 195 |
| 1 / Gray_Leaf_Spot | 564 | 563 | 394 | 85 | 85 |
| 2 / Healthy | 1,162 | 1,154 | 813 | 175 | 174 |
| 3 / Northern_Corn_Leaf_Blight | 1,135 | 1,107 | 794 | 171 | 170 |
| Total | **4,162** | **4,121** | **2,911** | **627** | **624** |

There are 2,882 known groups in TRAIN, 621 in VALIDATION and 618 in TEST. Some
groups contain multiple distinct derivatives; row counts are unique contents, not
proven independent plants or even one row per original photograph. Confidence/error
intervals are descriptive per-row intervals and do not correct this dependence.

All 21 content/alias/known-parent/group intersection checks are empty. Independent
closure of all 47 old/new confirmed relationships finds 41 within a partition,
six with both endpoints excluded and zero crossings. No eligible mixed-label group
or excluded-member leak remains. All 8,040 filenames, bytes, sizes and mtimes match
the original inventory. This is zero **known** group leakage, not proof that every
possible crop/re-encoding or physical plant/session relationship has been discovered.

Unresolved pair 24 is `Healthy (1517).jpg` (TRAIN, exact alias 2043) versus
`Healthy (1370).jpg` (VALIDATION, alias 2131). Recovered original identifiers
`R.S_HL8249` / `R.S_HL8248` have different UUIDs; 14/41 local geometric matches and
consecutive names do not establish a shared parent. This possible cross-partition
relationship remains a risk. Pair 58, `Healthy (1654).jpg` / `Healthy (1897).jpg`
(aliases 653 / 308), is TRAIN/TRAIN with 12/28 inliers and generic crease/midrib
similarity. Neither is presented as confirmed leakage or silently excluded/grouped.

Dataset version: `maize-research-20261008-v2`.
Semantic manifest fingerprint:
`a96fd5d32a8e0696df7cfc5bbfa6b78941c8a2f308f940ce295147a8832a583b`.
Persisted manifest byte SHA-256:
`7286a103820ccc0f0f85de9b8ffa5475fbea4cbae22e0d17fef0d99e22d2792d`.
Full confirmed-parent evidence SHA-256:
`7bcd7552dad9591c6a0a19b838f3a2d9e231765fcb1b9e4068fc4d9db2a35998`.

## Shared preprocessing and augmentation audit

Both independent Python environments import `maizedoctor_preprocessing` **1.0.0**.
The pinned configuration disables extraction, preserves the full oriented RGB frame,
resizes once with aspect-preserving bilinear letterboxing to 224×224 with white padding,
and emits CHW float32 with ImageNet mean `[0.485,0.456,0.406]` and standard deviation
`[0.229,0.224,0.225]`. Configuration fingerprint:
`b142e59f458d27a2d3fddbfc86c2f2f802670ab4909f1275babbef92de9cb5c8`.
The shared decoder handles EXIF, profiles, alpha/grayscale and enforces the existing
5 MiB, 16-million-pixel and minimum-side-16 admission policy. There is no second
DataLoader resize/normalization, hidden center crop or serving-specific transform.

TRAIN-only horizontal flip probability 0.5 and mild affine (±6°, translation 0.02,
scale 0.97–1.03, bilinear) run **after shared normalization**, with correspondingly
normalized white fill. This order is mathematically consistent for the channelwise
affine normalization and spatial interpolation. No random color modification is added.
Validation/test constructors reject augmentation; neither partition is augmented.
Actual augmented training images are inspected, rather than judging configuration alone.
Small boundary clipping and white wedges are possible; no exhaustive lesion-retention
guarantee or annotated pathological ground truth is claimed.

## Bounded correction experiment and reproducibility

New smoke: `smoke-20261009-v2-01`; 32 training / 16 validation examples, one warmup
epoch, finite outputs, strict selected-checkpoint reload, no test access. It passed.
Smoke accuracy is an execution check, not a model-quality claim.

Fresh full experiment: `mobilenet-v3-small-20261009-v2-01`, initialized from the verified
official MobileNetV3 Small ImageNet file (SHA-256
`047dcff4addef86ea5bc2eff13c9614dc11f47ab1160d0a71a25e7db994f4e1f`).
The sole classifier correction changes dataset membership/grouping and defers test;
architecture, augmentation and training hyperparameters remain the approved baseline.

| Setting | Value |
|---|---|
| Architecture / head | torchvision MobileNetV3 Small, four logits, dropout 0.2 |
| Seed / batch / threads | 20261007 / 16 / 4 CPU threads |
| Warmup | Two epochs, features frozen including BatchNorm statistics, head LR 0.001 |
| Fine-tuning | Up to ten epochs; all features unfrozen, feature LR 0.0001 / head LR 0.0003 |
| Optimizer / loss | AdamW, weight decay 0.0001; ordinary unweighted cross entropy |
| Scheduler | ReduceLROnPlateau on validation macro F1, factor 0.5, patience 1; fresh fine-tune scheduler |
| Selection / stop | Best validation macro F1, lower validation loss breaks exact ties; patience 3 |
| Numerical safeguards | Deterministic algorithms, finite loss/logits, gradient norm limit 5 |
| Test | `--defer-test`; no test loader during fitting, selection or calibration |

Source-integrity checks may hash every original, including indexed test filenames;
that mechanical verification is distinct from decoding test model inputs, using test
loss/probabilities or tuning from test labels. No test predictions are generated
during smoke, fitting, classifier selection or calibration.

Separate exclusive directories and per-epoch checkpoints preserve all old experiments.
The hidden independent Windows process avoids the previous foreground interruption;
stdout/stderr and environment/source hashes are saved. Environment is Python 3.11.0,
PyTorch 2.10 CPU / torchvision 0.25 on an i5-1145G7 four-core/eight-logical CPU with
16 GB RAM and no CUDA. Full dependency versions are pinned in the environment report
and lock files. Checkpoints do not contain complete optimizer/RNG resume state; an
exact interrupted-run continuation is not claimed.

The dataset has approximately 31.26% Rust, 13.55% GLS, 27.92% Healthy and 27.27% Blight;
largest/smallest ratio is 2.31. Unweighted cross entropy is retained initially.
Per-class validation diagnostics, rather than accuracy alone or the ratio alone,
determine whether another controlled training intervention is warranted. Validation
and test are never duplicated or balanced through synthetic augmentation.

## Confidence, threshold and diagnostic methods

Saved validation probabilities are analyzed using negative log likelihood, the sum
over classes multiclass Brier score and top-label equal-width 15-bin ECE. Bin counts
and reliability curves are saved; ECE is a binning-dependent finite-sample diagnostic,
not a universal guarantee. Confidence histograms distinguish correct/wrong examples,
and high-confidence errors are counted explicitly at 0.90, 0.95 and 0.99.

Temperature scaling uses validation only. Five **group-aware** folds, seed 20261007,
fit on four folds and score held-out probabilities; out-of-fold NLL/Brier/ECE establish
whether calibration helps without reporting in-sample improvement as independent.
If justified, a separate temperature fitted to all validation rows is frozen for the
final candidate; its fit-set diagnostic remains explicitly in-sample. The classifier
weights and argmax labels are unchanged. See the primary
[temperature-scaling study](https://proceedings.mlr.press/v70/guo17a.html).

Validation-only threshold diagnostics report accepted count, coverage, observed
accepted error, rejected frequency and per-class acceptance with 95% Wilson error
intervals. Sparse error-free subsets do not establish zero deployment risk. No
application risk/coverage objective is defined, so no arbitrary operational threshold
is locked. Final-test threshold selection and temperature fitting are prohibited.

Grad-CAM uses gradient-weighted final convolution activations for predicted-class
logits, ReLU and coarse 7×7 localization upsampled for review. Correct, wrong and
confident-wrong cases across classes are inspected. Border/padding attention is
interpreted relative to the fraction of the image occupied by those regions.
Activation outside lesions is diagnostic evidence to investigate, not proof of
causal shortcut use or annotated lesion detection. See the primary
[Grad-CAM paper](https://arxiv.org/abs/1610.02391).

The fixed validation-only robustness suite applies brightness/contrast 0.8 and 1.2,
rotations −5°/+5° on a fixed canvas, scale 0.97, JPEG quality 70, Gaussian blur radius
0.7 and a horizontal flip. Temporary copies pass through the same shared pipeline.
Prediction/confidence changes and per-class metrics are saved for each probe. If an
encoded copy exceeds the unchanged admission limits, that failure is counted and
the baseline is recomputed on the identical accepted subset. These are modest
controlled perturbations, not measured mobile field accuracy or out-of-distribution
detection. Source-archive subgroup membership is reconstructed only where documented;
overlapping publisher collections are not assumed to be independent domains.

## Packaging, final evaluation and checks

The hash-bound candidate binds checkpoint, full dataset index, literal class mapping,
shared configuration/version, architecture, split/training seeds, selected training
summary/config/environment, exact validation CSV/metrics and calibration metadata.
Every reference is checked for containment/hash and semantic agreement, including
recomputed validation metrics and the recorded checkpoint macro F1. Source hashes
are independently checked against the bytes used for the fresh run. Sensitive data,
raw photos and temporary image sheets stay ignored.

A separate immutable selection freeze binds every referenced hash and records
test-independent choices. `final_evaluation.py` refuses an already claimed
checkpoint/index pair through an exclusive global claim and refuses output reuse;
failure retains the claim rather than silently evaluating again. Strict reload and
unaugmented test evaluation happen only after the freeze. A selected validation
temperature is applied without refitting; raw and calibrated reports remain separate.
No model/calibration/threshold adjustment is made from that final result.

Offline compatibility restores the selected checkpoint in both training and AI
environments without adding an endpoint, checks 16 TRAIN cases for exact shared
tensors and model logits, verifies input/output metadata, and measures warm batch-one
CPU forward latency and whole-process memory. Measurements exclude decoding and
preprocessing and do not certify deployment throughput, concurrency or a service SLA.

Relevant verification passes: **219 ML tests**, Ruff format/lint over 32
files and strict mypy over 15 source modules; **50 AI tests** with its Ruff/mypy;
**78 shared tests in each environment** and **12 exact synthetic baseline parity
cases**. Real smoke, independent all-source/family-closure checks, numerical metric
verification, candidate validation, actual model compatibility and safe export checks
pass. Their final results are recorded below. Unrelated backend/Flutter code is preserved.

## Research limits and phase boundary

Source and license declarations from [Phase 9.5](24-dataset-intake-preprocessing-review.md)
remain preserved. Current use is **non-commercial academic/FYP research**, without
raw dataset redistribution. No commercial license clearance is assumed; licensing
review or source replacement is required before commercial deployment.

Missing verified plant/field/session identity, two unresolved similarity candidates,
unknown derivatives and source/background/label ambiguity limit independence claims.
Small lesions may lose detail at 224 pixels. No maize/OOD detector, agronomic severity
estimate, lesion masks or external field validation is available. One bounded fresh
classifier correction is run on the existing CPU; multi-seed classifier repeats and
group-aware classifier cross-validation are not practical within this correction
budget, so seed stability is not established. Calibration cross-fitting is distinct
from classifier retraining or classifier cross-validation.

Phase 11 remains unimplemented. Its eventual serving must validate these exact hashes,
reuse the shared pipeline, distinguish probability from certainty and handle errors/
uncertainty rather than presenting internal benchmark confidence as field accuracy.

## Final selection and fitness verdict

**FIT WITH DOCUMENTED LIMITATIONS. Phase 11 may begin** for an FYP/research inference
prototype when separately instructed; no Phase 11 work is started here. This verdict
does not certify clinical/agronomic diagnosis, field-domain accuracy or commercial
deployment. Source/label ambiguity, confident errors, an unresolved possible parent
relationship, consumed-corpus evaluation and missing plant/session independence
remain explicit limitations.

The frozen candidate is `mobilenet-v3-small-v2-20261009`. Fresh fit
`mobilenet-v3-small-20261009-v2-01` completed 11 epochs / 1,687.625 seconds (28.13
minutes): two frozen-feature warmup and nine full fine-tune epochs. The predeclared
validation macro-F1 criterion selects epoch **8**, not the final epoch or lowest-loss
epoch. Its 6,212,695-byte checkpoint has 1,521,956 parameters (6,087,824 parameter
bytes), 594,948 trainable during warmup and all 1,521,956 during fine-tuning. Input is
`N×3×224×224`, RGB CHW float32; output is `N×4` logits in the pinned literal class order.

## Training behavior, gaps and convergence

| Epoch | Stage | Feature/head LR reference | Train loss | Val loss | Train accuracy | Val accuracy | Val macro F1 |
|---:|---|---:|---:|---:|---:|---:|---:|
| 1 | warmup | 0.001 | 0.281517 | 0.158747 | 89.316% | 92.982% | 0.911337 |
| 2 | warmup | 0.001 | 0.169911 | 0.129344 | 93.370% | 94.737% | 0.931500 |
| 3 | fine_tune | 0.0001 | 0.235378 | 0.138507 | 90.897% | 95.375% | 0.940927 |
| 4 | fine_tune | 0.0001 | 0.135481 | 0.135991 | 94.778% | 94.418% | 0.929950 |
| 5 | fine_tune | 0.0001 | 0.106510 | 0.114306 | 96.256% | 95.215% | 0.940297 |
| 6 | fine_tune | 5e-05 | 0.066970 | 0.101401 | 97.733% | 96.172% | 0.953314 |
| 7 | fine_tune | 5e-05 | 0.065552 | 0.114163 | 97.355% | 95.694% | 0.945376 |
| 8 | fine_tune | 5e-05 | 0.050009 | 0.095972 | 98.145% | 96.810% | 0.958909 |
| 9 | fine_tune | 5e-05 | 0.040744 | 0.139806 | 98.523% | 95.215% | 0.940423 |
| 10 | fine_tune | 5e-05 | 0.047969 | 0.098148 | 98.076% | 96.172% | 0.951337 |
| 11 | fine_tune | 2.5e-05 | 0.039614 | 0.087667 | 98.592% | 96.491% | 0.955779 |


LR entries above are the warmup head or fine-tuning feature group. Fine-tuning head
starts at 0.0003 and is reduced proportionally, to 0.00015 at epoch 6 and 0.000075
at epoch 11. There is an expected online train-loss increase at unfreezing (0.169911
to 0.235378); validation macro F1 improves rather than catastrophically degrading.
Scheduler reductions stabilize learning. No nonfinite loss, exploding logits or
failed model reload occurs. Epoch 9's validation loss spike recovers in epochs 10/11.

**GENERALIZATION GAP ANALYSIS:** best epoch 8 online augmented train/validation
accuracy is 98.1450%/96.8102% (gap **1.3348 percentage points**), losses
0.050009/0.095972 (validation minus train **0.045964**). Final epoch 11 online values
are 98.5915%/96.4912% (gap **2.1003 points**), losses 0.039614/0.087667 (gap **0.048054**).
Selected-checkpoint deterministic unaugmented TRAIN/VAL accuracy is
99.3817%/96.8102% (gap **2.5714 points**), macro F1 0.992201/0.958909 (gap **0.033292**).
Online training metrics include augmentation/dropout/BatchNorm training behavior;
they are not directly interchangeable with selected unaugmented inference metrics.

Overfitting: **mild**, based on the positive selected gap and temporary late loss
spike, without sustained final validation-loss divergence or large performance
collapse. Underfitting: **none significant** on this internal task, with high TRAIN
and VAL results well above the trivial reference. Domain weakness is not dismissed
by those aggregate scores. Convergence: stable bounded fitting and a validation
macro-F1 plateau; **patience 3 stops after epochs 9–11 fail to beat epoch 8**. Epoch 11
has the minimum validation loss but lower macro F1. No mathematical/global optimum,
completed 12-epoch budget or multi-seed stability is claimed.

## Validation and single final-test metrics

| Partition | Accuracy | Macro precision | Macro recall | Macro F1 | Weighted F1 | Macro OVR AUC |
|---|---:|---:|---:|---:|---:|---:|
| Validation | 96.8102% | 0.963476 | 0.955049 | 0.958909 | 0.967845 | 0.997086 |
| Final test (descriptive) | 95.8333% | 0.949640 | 0.941365 | 0.945171 | 0.957813 | 0.995358 |


TRAIN-majority classifier predicts Rust: validation accuracy 196/627 (**31.260%**),
macro F1 0.119077; test accuracy 195/624 (**31.25%**), macro F1
0.119048. The selected model substantially exceeds this appropriate
trivial reference. V1 and v2 scores are not a fair improvement comparison: partitions
and eligibility changed and v1 independence was invalid. No external published
accuracy number is treated as an equivalent benchmark.

Test is 598/624 correct, accuracy **0.9769 points** below validation; macro F1 is
lower by **0.013738**. This is a modest internal gap, with a genuine weaker GLS class.
No retraining, temperature fitting, threshold selection or other adjustment follows
the test result. Its raw and 'calibrated' metrics are identical because calibration
is explicitly disabled, preserving the exact raw probabilities.

| Partition / literal class | Support | Precision | Recall | F1 | Specificity | OVR AUC |
|---|---:|---:|---:|---:|---:|---:|
| Val / Common_Rust | 196 | 0.979695 | 0.984694 | 0.982188 | 0.990719 | 0.999384 |
| Val / Gray_Leaf_Spot | 85 | 0.936709 | 0.870588 | 0.902439 | 0.990775 | 0.993293 |
| Val / Healthy | 175 | 1.000000 | 1.000000 | 1.000000 | 1.000000 | 1.000000 |
| Val / Northern_Corn_Leaf_Blight | 171 | 0.937500 | 0.964912 | 0.951009 | 0.975877 | 0.995665 |
| Test / Common_Rust | 195 | 0.970000 | 0.994872 | 0.982278 | 0.986014 | 0.999582 |
| Test / Gray_Leaf_Spot | 85 | 0.898734 | 0.835294 | 0.865854 | 0.985158 | 0.988846 |
| Test / Healthy | 174 | 1.000000 | 1.000000 | 1.000000 | 1.000000 | 1.000000 |
| Test / Northern_Corn_Leaf_Blight | 170 | 0.929825 | 0.935294 | 0.932551 | 0.973568 | 0.993003 |


Healthy is easiest on these publisher-style images: 175/175 validation and 174/174
test correct. This does not establish Healthy field/OOD recognition. GLS has the
lowest precision, recall and F1 in both partitions. Validation GLS recall is 74/85
(87.06%); test is 71/85 (83.53%). Tiny lesions, extensive dead tissue, variable
backgrounds and interclass morphology/label ambiguity are visible factors rather
than pathology-confirmed causes.

## Confusion and representative errors

Rows are true / columns predicted, order Rust, GLS, Healthy, Blight:

```text
Validation               Final test
193   0   0   3          194   0   0   1
  3  74   0   8            3  71   0  11
  0   0 175   0            0   0 174   0
  1   5   0 165            3   8   0 159
```

GLS→Blight / Blight→GLS contributes 8+5 = **13/20 validation errors (65%)** and
11+8 = **19/26 test errors (73.08%)**. Test class-conditional rates are 11/85 =
12.94% GLS→Blight and 8/170 = 4.71% Blight→GLS. Additional test errors are GLS→Rust
three, Blight→Rust three and Rust→Blight one. No Healthy↔disease error occurs in
these unperturbed benchmark partitions. Raw and row-normalized matrices/plots are
saved, with supports rather than unlabeled percentages.

All 20 validation errors, correct representatives across every class, border cases
and actual training transforms are inspected in 11 validation sheets (41 contents)
and three augmentation sheets (11 TRAIN contents / 33 variants). Exact sample/group
IDs, literal labels and top probabilities are in metadata; source-image sheets remain
ignored. Strongly confident validation errors include Rust `(1780).jpg` → Blight
0.994585 (field leaf with yellow/brown longitudinal damage) and GLS `(387).JPG` →
Blight 0.991695 (large pale elongated necrotic region). Both CAMs focus on damaged
tissue; class ambiguity is plausible, not proof of mislabeled source data. GLS
`(353).jpg` → Rust 0.901410 is bright/backlit with background/padding activation.
GLS `(888).jpg` → Blight 0.509513 illustrates a borderline error. Blight `(346).jpg`
and GLS `(226).JPG` are borderline-correct at 0.511173 / 0.506693. Small spot/partial
leaf examples and blurred/bright Healthy closeups are also reviewed.

After the freeze and one test evaluation, eight descriptive test errors are viewed
without any further model inference or choices. Highest-confident errors GLS
`(218).JPG` / `(1070).JPG` / `(661).jpg` → Blight have probabilities
0.998318 / 0.997346 / 0.995972: broad pale lesions on gray-backed leaves and a dense
field frame. Reciprocal Blight `(1182).JPG` → GLS is 0.984487 with mixed punctate/
elongated damage. Rust `(1855).jpg` → Blight 0.966762 contains few small spots in a
bright field frame. GLS `(464).jpg` and Blight `(1836).jpg` show uncertain incorrect
maxima 0.481977 / 0.397897. These consumed-test findings are reported, never used to
relabel, exclude or tune the selected model.

## Confidence, calibration and rejection policy results

Validation correct mean/median confidence is 0.980452/0.999952; incorrect is
0.778008/0.842879. Final test correct is 0.979200/0.999931; incorrect
0.759846/0.750721. Lower average wrong confidence is useful but does not eliminate
dangerously confident exceptions. Validation wrong counts ≥0.90 / ≥0.95 / ≥0.99
are **4 / 2 / 2**; final test **8 / 6 / 3**, all three ≥0.99 test errors are GLS→Blight.

| Validation probability diagnostic | Raw | Five-fold group OOF temperature |
|---|---:|---:|
| NLL | 0.095972243 | 0.096397245 |
| Multiclass Brier | 0.051347124 | 0.051633390 |
| ECE, 15 equal-width bins | 0.016285386 | 0.017946717 |

All three out-of-fold diagnostics worsen, despite NLL improving in three of five
individual folds. The all-validation fitted temperature **1.2394404603** is not
selected; its apparent fit-set improvement is resubstitution. **Calibration disabled,
method `none`, T=1.0**, frozen before test. Final raw/unchanged calibrated test
NLL/Brier/ECE is **0.119123690 / 0.062548243 / 0.026670970**. Confidence is
distribution-dependent, and sparse lower bins vary markedly; overall ECE does not
certify every confidence level. Group cross-fitting removes calibrator-fit overlap
but does not undo classifier epoch selection on the same validation set.

| Validation diagnostic cutoff | Accepted / 627 | Coverage | Errors | Accepted accuracy | 95% Wilson error interval |
|---:|---:|---:|---:|---:|---|
| 0.90 | 572 | 91.228% | 4 | 99.301% | 0.272–1.784% |
| 0.95 | 561 | 89.474% | 2 | 99.643% | 0.098–1.290% |
| 0.99 | 505 | 80.542% | 2 | 99.604% | 0.109–1.432% |

At 0.95, GLS coverage is 57/85 = 67.06%, Healthy 175/175 = 100%; at 0.99 GLS falls
to 36/85 = 42.35% while both confident errors persist. With no predefined risk/
coverage/class-cost objective, **no operational threshold is locked**. Operational
accepted accuracy/low-confidence frequency are therefore not defined. The already
predeclared 0.95 diagnostic on final test accepts 551/624 (88.30%), with six errors
(98.91% accepted accuracy); this is descriptive confirmation of the caution, not
a selected application policy or a reason to refit from test. All diagnostic risk
points remain available, including rejected counts and per-class coverage.

## Explainability, source bias and capacity interpretation

Grad-CAM often follows damaged leaf regions (e.g. GLS387, Blight1931, Rust1780), but
several maps focus partly on background, padding or corners: GLS649/353/916 and
Blight15/1484/649/227. Rust2399 includes black background; Rust2125 contains an
attribution watermark and right-side heat. This is suspected context sensitivity,
not proven causal shortcut use. For example GLS353 has 32.74% heat on letterbox
covering 24.55% of pixels, whereas Rust2063 has 42.74% heat on padding covering
53.125% of pixels: large raw mass alone is not evidence of enrichment. There are
no semantic leaf/lesion masks, and 7×7 CAM is too coarse for lesion-ground-truth claims.

Documented archive membership: PlantVillage-color overlap **570/579 correct (98.45%)**;
Corn-collection-only, original field origin not independently verified,
**37/48 (77.08%)**. Corn-only class supports Rust15/GLS9/Healthy0/Blight24; recalls
80% / **22.22% (2/9)** / undefined / 95.83%. Its four-class macro F1 is undefined
because Healthy is absent. PlantVillage-overlap GLS recall is 72/76 (94.74%). This
substantial source/class weakness must be disclosed, with small-subgroup uncertainty,
overlapping archive provenance and no verified plant/session/domain independence.

The 2.31 class-size ratio and minority GLS contribute plausible representation risk;
the actual failures are strongly concentrated in a small source subgroup and overlapping
lesion morphologies. Generic weighting or a bigger model is not established as a
solution. Strong selected TRAIN performance and modest perturbation stability do
not show a capacity/optimization collapse. Retain cross entropy and the baseline
capacity. No unsupported additional classifier sweep is launched; new independently
collected/verified field data is the defensible next generalization validation.

## Fixed validation robustness results

| Probe | N / admission failures | Accuracy | Macro F1 | Class changes | GLS recall | Mean confidence change |
|---|---:|---:|---:|---:|---:|---:|
| brightness_0.8 | 627 / 0 | 96.172% | 0.952307 | 7 (1.116%) | 85.882% | -0.005934 |
| brightness_1.2 | 627 / 0 | 96.491% | 0.955161 | 4 (0.638%) | 85.882% | -0.002435 |
| contrast_0.8 | 627 / 0 | 96.651% | 0.956490 | 4 (0.638%) | 85.882% | -0.001392 |
| contrast_1.2 | 627 / 0 | 96.332% | 0.953538 | 5 (0.797%) | 84.706% | -0.002397 |
| rotation_minus_5 | 627 / 0 | 97.289% | 0.964530 | 9 (1.435%) | 87.059% | -0.001198 |
| rotation_plus_5 | 627 / 0 | 96.651% | 0.958374 | 14 (2.233%) | 88.235% | -0.003449 |
| scale_0.97 | 627 / 0 | 96.651% | 0.957498 | 17 (2.711%) | 83.529% | +0.000263 |
| jpeg_quality_70 | 627 / 0 | 96.491% | 0.954110 | 3 (0.478%) | 84.706% | -0.002581 |
| blur_radius_0.7 | 627 / 0 | 96.491% | 0.953844 | 11 (1.754%) | 83.529% | -0.001377 |
| horizontal_flip | 627 / 0 | 96.651% | 0.958081 | 7 (1.116%) | 85.882% | +0.000700 |


All 6,270 probe cases are admitted, zero malformed/oversize temporary variants in
v2. Each compares the same 627 original validation contents. Accuracy range is
**96.17–97.29%**, maximum drop 0.638 percentage points; class-change range
**0.48–2.71%**. Minor scale and mild blur reduce GLS recall from 87.06% to 83.53%,
which remains a class weakness despite stable aggregate scores. Per-case original/
perturbed labels, probabilities and confidence changes are saved. V1's temporary
PNG admission failures remain historical; they do not recur on this v2 partition.
No perturbation score measures uncontrolled field accuracy or drives a test-set change.

## Final artifact checks, commands and handoff

The candidate's **48** frozen references pass byte and semantic validation before
test; bundle SHA-256 `d8115ae08724f014c70828c1f419eda38921d0fd32205e59bd25ee472ee360ec`.
Checkpoint, classmap, full preprocessing/config hash, dataset/exclusion/split versions,
seeds, hyperparameters, selected validation results and actual environment/source
bytes agree. The post-test addendum binds final metrics to this untouched freeze;
critical missing/disagreeing metadata fails the export audit. Test prediction CSV
and raw/calibrated results are preserved alongside calibration configuration and
final package metadata; no raw photo or weight file is committed. The safe export
contains 98 files, including 93 exact byte copies and 16 numerical plots. All 13
final model-artifact references and 48 frozen candidate references validate; fifteen
missing/mismatched critical-field cases are rejected. Final model-artifact SHA-256:
`a831116fe1ff8b915543991412f4ab6b334736e8eaca376fab8db3b57e5b263d`.

Offline training/AI compatibility: 16 TRAIN cases, exact tensors and logits; strict
zero-input 1×4 finite restore also passes. Local AI two-thread/batch-one forward-only
median **7.45 ms**, p95 **10.57 ms** (five warmup / 30 samples), process working set
382,988,288 bytes / peak 387,182,592. These exclude decoding/preprocessing and
measure the Python process after imports, not concurrent FastAPI deployment. CPU
contention can affect timing; training-environment median/p95 is 13.86/28.12 ms.

Commands performed from repository root (existing output names are immutable;
choose new destinations for any authorized repeat, and never replay the consumed test):

```powershell
ml-training/.venv/Scripts/python.exe ml-training/train.py --manifest ml-training/manifests/maize-research-20261008-v2/manifest.json --config ml-training/configs/full-frame-baseline.json --output .cache/phase105/experiments/smoke-20261009-v2-01 --smoke --defer-test
ml-training/.venv/Scripts/python.exe ml-training/train.py --manifest ml-training/manifests/maize-research-20261008-v2/manifest.json --config ml-training/configs/full-frame-baseline.json --output .cache/phase105/experiments/mobilenet-v3-small-20261009-v2-01 --defer-test
ml-training/.venv/Scripts/python.exe ml-training/fitness_visual.py --manifest .cache/phase105/datasets/maize-research-20261008-v2/manifest.json --experiment .cache/phase105/experiments/mobilenet-v3-small-20261009-v2-01 --output .cache/phase105/visual-20261009-v2 --threads 2
ml-training/.venv/Scripts/python.exe scripts/check-model-compatibility.py --manifest ml-training/manifests/maize-research-20261008-v2/manifest.json --experiment .cache/phase105/experiments/mobilenet-v3-small-20261009-v2-01 --output .cache/phase105/offline-model-compatibility-v2.json
ml-training/.venv/Scripts/python.exe ml-training/final_evaluation.py --bundle .cache/phase105/candidates/mobilenet-v3-small-v2-20261009/candidate.json --output .cache/phase105/final-test-20261009-v2
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Training
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component AI
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Preprocessing
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-repository.ps1
git diff --check
```

The smoke/full fit actually consumed the ignored local v2 manifest; the published
file above is byte-identical. Windows long-running commands used `Start-Process`
with hidden windows, independent logs and no foreground-session dependence.
Additional safe orchestration records relationship repair, group cross-fitting,
decision freeze, numerical normalized plots, descriptive image review and independent
saved-CSV arithmetic. All label/metric/OVR AUC values independently match; no extra
test inference is performed by those numerical auditors. Tests: **219 ML**, **50 AI**,
**78 shared in each environment**, **12 synthetic parity**, **16 actual TRAIN
tensor/logit parity**; formatting/lint/types pass. One existing Starlette TestClient
deprecation warning remains. Repository/templates/ignore, local links, private
dataset-path/secret and Git byte-integrity checks pass. All 216 local Markdown links
resolve, and all 439 source/commit candidates omit the configured dataset path and
private environment credentials. Git staging excludes the earlier user-owned ignore
rules and documentation scaffold sections; their working copies remain preserved.

Read the [safe aggregate report](../ml-training/reports/mobilenet-v3-small-20261009-v2-01-fitness/README.md) and the immutable
[v2 index](../ml-training/manifests/maize-research-20261008-v2/README.md).
The selected weights and image-bearing development artifacts remain local/ignored.
All application/backend/database/shared preprocessing source is preserved; no
Phase 11 route or feature is introduced. Further field validation/licensing and
deployment error/uncertainty policy remain future work.
