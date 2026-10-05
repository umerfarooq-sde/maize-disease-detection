# ML training

Phase 1 configures an isolated Python 3.11 environment for CPU PyTorch/torchvision,
NumPy, OpenCV 4.13, Pillow, scikit-learn, and SciPy. Windows uses `opencv-python`;
Linux uses the matching headless package. Dependencies and their resolution
are recorded in `pyproject.toml` and `uv.lock`. No dataset, preprocessing, training
pipeline, or model is supplied.

Import the same preprocessing implementation as production inference. Split before
augmentation, augment only training data, and keep the test set out of training and
model selection. Record dataset/preprocessing versions, class mapping, hyperparameters,
accuracy, precision, recall, F1, confusion matrix, per-class metrics, and training/validation curves.

Local datasets and model binaries are ignored by Git. Keep source provenance,
experiment metadata, and version manifests in version control when introduced;
use a chosen external artifact store for large assets. Never overwrite production models.
See [ML pipeline](../docs/09-ml-pipeline.md).

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-python.ps1 -Component ml-training
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Training
```

The tests exercise synthetic tensor/autograd, compiled torchvision operators, image
libraries, and metrics. They do not train a model or use project data.
See the [development setup](../docs/15-development-environment.md).
