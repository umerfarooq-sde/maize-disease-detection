# ML training

Phase 1 configures an isolated Python 3.11 environment for CPU PyTorch/torchvision,
NumPy, OpenCV 4.13, Pillow, scikit-learn, and SciPy. Windows uses `opencv-python`;
Linux uses the matching headless package. Dependencies and their resolution
are recorded in `pyproject.toml` and `uv.lock`. Phase 9 adds the single
[shared preprocessing package](../shared/preprocessing/README.md), installed as a
local dependency. `preprocessing.py` re-exports the exact same functions as FastAPI.
Phase 9.5 adds configured, read-only dataset inventory and real-image comparison:
8,040 supplied images were reviewed with both shared policies, and 160 real-image
consumer parity cases pass. Source images remain unchanged. Training/evaluation
execution and models remain deferred. See
[pipeline behavior/versioning](../docs/22-shared-preprocessing.md) and the
[dataset readiness report](../docs/24-dataset-intake-preprocessing-review.md).

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
No split, augmentation or model training is performed. The full-frame policy is a
recommendation awaiting approval; the canonical default is unchanged.

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-python.ps1 -Component ml-training
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Training
```

The 29 training-project tests exercise configuration, read-only fixture intake,
synthetic tensor/autograd, compiled torchvision operators, image libraries, metrics
and shared callable identity. Ruff and strict mypy check the configuration and intake
source as well as the preprocessing re-export. `check-development.ps1 -Component
Preprocessing` runs the shared suite in both environments plus exact synthetic
cross-environment parity. These checks do not train a model or load the supplied
dataset; the separate review command performs the real-image inspection.
See the [development setup](../docs/15-development-environment.md).
