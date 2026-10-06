# Shared preprocessing package

`maizedoctor_preprocessing` is the single versioned preprocessing implementation for
both `ai-service` and `ml-training`. Their manifests install this package as an
editable local dependency; their small preprocessing modules only re-export its
public callables. Do not copy transforms into either consumer.

```text
configs/default.json
src/maizedoctor_preprocessing/
  config.py          immutable settings and canonical configuration hash
  decoding.py        bounded validation, orientation, RGB/profile/alpha handling
  segmentation.py    conservative full-color extraction and uncertainty policy
  pipeline.py        common file/bytes entrypoints, crop, letterbox, normalization
  types.py           read-only outputs, provenance, optional unchanged tensor
  errors.py          safe typed failures
  debug.py           opt-in local inspection artifacts and CLI
tests/               synthetic validation, lesion-preservation and parity mechanics
```

The **1.0.0** default produces contiguous RGB CHW `float32` arrays shaped
`(3, 224, 224)`, scaled to `[0, 1]` with mean zero/std one. It uses aspect-preserving
bilinear letterboxing, supports still JPEG/PNG/WebP, and limits input to 5 MiB,
16 million pixels and a minimum side of 16 pixels. A future model must pin its
actual compatible configuration; these are not evaluated model hyperparameters.

Extraction uses supplied masks or alpha where present; otherwise it removes only
uniform-color background connected to the image perimeter. Enclosed non-green
lesions remain foreground. Ambiguous scenes preserve the full frame by default;
strict rejection is configurable. There is no semantic leaf classifier, random
augmentation, training, inference endpoint, RAG or Gemini integration.

From the repository root, with either consumer environment activated:

```python
from pathlib import Path

from maizedoctor_preprocessing import load_config, preprocess_image

config = load_config(Path("shared/preprocessing/configs/default.json"))
# encoded_image is caller-provided bytes from an actual file or future request.
result = preprocess_image(encoded_image, config)
array = result.model_array
metadata = result.metadata
```

`preprocess_file(Path(...), config)` reads a confirmed input file with the same
bounded byte pipeline. `result.to_tensor()` copies unchanged values into a CPU
PyTorch tensor when PyTorch is installed; it adds no batch axis. Supplied masks must
be identical in training and serving, match the oriented image, and retain their
recorded hash provenance.

For opt-in inspection, replace the clearly marked placeholders with an actual
existing image and a new ignored output directory:

```powershell
python -m maizedoctor_preprocessing 'REPLACE_WITH_EXISTING_IMAGE_FILE' --output '.cache/preprocessing-review-NEW_NAME' --config shared/preprocessing/configs/default.json
python scripts/check-preprocessing-parity.py
```

The parity script compares eight synthetic image/configuration cases through both
independently installed consumer environments. Real maize data is not supplied;
representative field-image validation remains pending. Perimeter-camouflaged tissue,
small lesions, unusual scenes and platform codec differences require review before
model adoption.

See the [full algorithm, configuration and limitations](../../docs/22-shared-preprocessing.md),
[ML contract](../../docs/09-ml-pipeline.md) and
[recorded check results](../../docs/PROJECT_STATE.md).
