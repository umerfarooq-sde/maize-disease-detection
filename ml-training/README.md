# ML training

Phase 1 configures an isolated Python 3.11 environment for CPU PyTorch/torchvision,
NumPy, OpenCV 4.13, Pillow, scikit-learn, and SciPy. Windows uses `opencv-python`;
Linux uses the matching headless package. Dependencies and their resolution
are recorded in `pyproject.toml` and `uv.lock`. Phase 9 adds the single
[shared preprocessing package](../shared/preprocessing/README.md), installed as a
local dependency. `preprocessing.py` re-exports the exact same functions as FastAPI.
Phase 9.5 adds configured, read-only dataset inventory and real-image comparison:
8,040 supplied images were reviewed with both shared policies, and 160 real-image
consumer parity cases pass. Source images remain unchanged. Phase 10 now implements
immutable eligibility/grouped splits, a shared full-frame transfer-learning baseline,
train-only augmentation, validation checkpoint selection and final held-out evaluation.
Current use is non-commercial academic/FYP research, without raw redistribution. See
[pipeline behavior/versioning](../docs/22-shared-preprocessing.md) and the
[dataset readiness report](../docs/24-dataset-intake-preprocessing-review.md).

The corrected [v2 index](manifests/maize-research-20261008-v2/README.md) records
4,162 eligible unique contents/4,121 groups with fixed 2,911/627/624 partitions.
The unchanged v1 is historical: confirmed transformed-parent leakage invalidated
its independent-evaluation claim. Future experiments consume v2 and resolve original
bytes only through `DATASET_PATH`. Source labels/files remain unchanged.

Phase 10.5's fresh `mobilenet-v3-small-20261009-v2-01` stops successfully at 11 epochs
under patience 3; validation selects epoch 8. Validation accuracy/macro F1 is
96.81%/0.9589; the single post-freeze descriptive test scores 95.83%/0.9452. Model version
`mobilenet-v3-small-v2-20261009` is **FIT WITH DOCUMENTED LIMITATIONS** for an FYP
prototype; source/class/confidence weakness and reused-corpus limits apply. Temperature
scaling is disabled (T=1) because group-fold evidence does not improve; no operational
threshold is locked. See [fitness report](../docs/26-model-fitness-validation.md) and
[safe numerical/artifact export](reports/mobilenet-v3-small-20261009-v2-01-fitness/README.md).
The original experiment/recovery remains immutable. No inference endpoint is added.

Import the same preprocessing implementation as production inference. Split before
augmentation, augment only training data, and keep the test set out of training and
model selection. Record dataset/preprocessing versions, class mapping, hyperparameters,
accuracy, precision, recall, F1, confusion matrix, per-class metrics, and training/validation curves.

Local datasets and model binaries are ignored by Git. Keep source provenance,
experiment metadata, and version manifests in version control when introduced;
use a chosen external artifact store for large assets. Never overwrite production models.
See [ML pipeline](../docs/09-ml-pipeline.md).

## Dataset configuration and read-only review

The supplied absolute directory is configured in ignored `ml-training/.env` as
`DATASET_PATH`. The committed [.env.example](.env.example) contains a blank placeholder;
do not copy the actual machine path into source, tests or committed documentation.
An explicitly present OS environment variable takes precedence, including a blank
value. The loader reads the training-local file independently of cwd and validates
an absolute existing directory without mutating the process environment.

All future inventory, preprocessing validation and training code must use:

```python
from configuration import load_dataset_path

dataset_path = load_dataset_path()
```

From the repository root, select a new ignored output directory for another review:

```powershell
ml-training/.venv/Scripts/python.exe ml-training/dataset_review.py --output .cache/dataset-review/local-review
```

The command reads only configured source data and calls the existing shared pipeline.
It refuses output inside the dataset or an existing output directory. Inventory,
duplicate candidates, sample bundles and contact sheets are development artifacts,
not a manually preprocessed training dataset. The completed review is under
`.cache/dataset-review/phase95-20261007/`; keep images and private provenance ignored.
The review command performs no split, augmentation or training. Phase 10 separately
implements those workflows with the approved full-frame artifact configuration;
the generic package default remains unchanged.

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-python.ps1 -Component ml-training
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Training
```

Training-project tests exercise configuration, intake, eligibility/deduplication/grouping,
split invariants, metrics, shared preprocessing, augmentation isolation, checkpoint
integrity/reload and smoke/final-test separation. Ruff and strict mypy cover all source.
`check-development.ps1 -Component Preprocessing` runs the shared suite in both environments
plus exact baseline-config synthetic
cross-environment parity. These checks do not train a model or load the supplied
dataset; the separate review command performs the real-image inspection.
See the [development setup](../docs/15-development-environment.md).

## Offline fitness workflow

Use `train.py --defer-test` for a new reviewed experiment: fit/select using TRAIN/VAL,
then review validation errors, confidence/group-fold calibration, source and fixed
robustness probes. `fitness_artifacts.validate_bundle()` checks hash-bound frozen
choices before `final_evaluation.py` permits one final checkpoint/index evaluation.
Global claims refuse test replay/output reuse. Never fit temperature or select a
threshold from final test; read the complete [commands and scope](../docs/26-model-fitness-validation.md).

`fitness_integrity.py` audits known relationship intersections; `dataset_group_repair.py`
persists approved newly confirmed group/exclusion evidence in a new dataset version.
`fitness_calibration.py` supplies typed confidence/risk diagnostics and group cross-fit;
`fitness_visual.py` supplies development-only actual input/CAM/augmentation and fixed
validation perturbations. `scripts/check-model-compatibility.py` checks the checkpoint
in both environments on TRAIN only, without implementing serving. Outputs must remain
new/ignored; never publish raw image sheets or weights through the repository.
