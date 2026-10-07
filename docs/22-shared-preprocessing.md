# Shared maize-leaf preprocessing

Phase 9 implements one installed Python package, `maizedoctor_preprocessing`, at
[`shared/preprocessing`](../shared/preprocessing/README.md). Both the AI service and
ML workspace depend on this package through their manifests and lockfiles. Their
local preprocessing modules only re-export the same callables; they contain no
separate transforms. No model is trained or loaded, no inference endpoint is added,
and no RAG or Gemini code is introduced.

This is a deterministic foreground-preparation pipeline, not a semantic maize-leaf
detector. Every result includes `leaf_identity_unverified`. Synthetic tests verify
mechanics and parity; they do not establish field accuracy or disease recognition.

Phase 9.5 subsequently exercised both unchanged policies on 8,040 configured real
images, reviewed 81 filenames/78 contents and verified 160 real consumer parity cases.
Conservative extraction falls back for 8,021 of 8,029 accepted files. Full-frame is
recommended for the first baseline; canonical policy remains unchanged pending approval.
See [dataset review](24-dataset-intake-preprocessing-review.md) for evidence and limits.

## Shared ownership and usage

```text
Actual training image bytes             Future Node -> FastAPI image bytes
               |                                       |
               +---- maizedoctor_preprocessing ---------+
                                  |
                     same configuration and mask inputs
                                  |
                 validation -> decode -> RGB standardization
                                  |
               conservative extraction or full-frame fallback
                                  |
                background removal -> crop -> letterbox resize
                                  |
                    normalization -> RGB CHW float32 array
                                  |
                     optional unchanged CPU torch tensor
```

Python owns these transforms. Node's existing upload validation remains a transport
security boundary; it does not implement this ML preprocessing. Flutter continues
to call Node. The production Node/FastAPI orchestration and classifier remain future
work.

Both environments import the installed package directly:

```python
from pathlib import Path

from maizedoctor_preprocessing import load_config, preprocess_file, preprocess_image

# Run from the repository root, or resolve this checked-in configuration explicitly.
config = load_config(Path("shared/preprocessing/configs/default.json"))

# Training/dataset use: image_file is a confirmed file from a future input manifest.
training_result = preprocess_file(image_file, config)

# Serving use: encoded_image contains validated request bytes, not a URL to fetch.
serving_result = preprocess_image(encoded_image, config)
model_input = serving_result.model_array
tensor_input = serving_result.to_tensor()  # Optional; requires installed PyTorch.
```

`image_file` and `encoded_image` above are caller-provided inputs, not an existing
project dataset or implemented HTTP request contract. `preprocess_file` performs a
bounded read and calls the same byte entrypoint. `preprocess_image` optionally accepts
`media_type`, `filename`, and `foreground_mask`. Supplied MIME/extension values must
match the decoded format. The tensor adapter copies the unchanged CHW values to a
CPU `torch.float32` tensor; it adds no batch axis and performs no additional resize
or normalization.

Future training augmentation belongs outside this deterministic package and applies
only to the training split. Validation/test and serving must keep the same declared
deterministic behavior. Never copy the implementation into a dataset loader or API
handler.

## Versioned configuration and output

The package and preprocessing contract start at version **1.0.0**. The checked-in
[default configuration](../shared/preprocessing/configs/default.json) explicitly
records these values:

| Setting | Default |
| --- | --- |
| Output dimensions | Height 224, width 224 |
| Channel order / layout / dtype | RGB / CHW / contiguous float32 |
| Scaling and normalization | `(RGB / 255 - mean) / std`, mean `(0, 0, 0)`, std `(1, 1, 1)` |
| Supported encoded formats | Still JPEG, PNG, WebP |
| Encoded byte limit | 5 MiB = 5,242,880 bytes |
| Decoded pixel limit / minimum side | 16,000,000 pixels / 16 pixels |
| Background replacement and letterbox color | White `(255, 255, 255)` |
| Resize interpolation | Bilinear, preserving aspect ratio |
| Crop padding | Maximum of 2 source pixels and 8% of the largest mask coordinate span |
| Segmentation mode / uncertainty policy | `conservative` / `preserve` |
| Segmentation working dimension | At most 512 pixels on the longest side |
| Border-band fraction | 0.03 of the shorter working dimension, rounded with minimum 1 pixel |
| Background tolerance / border variation cap | Lab distance 12 / 95th-percentile distance 6 |
| Foreground coverage bounds | 0.02 through 0.90 of the working frame |
| Significant-component threshold | 0.001 of working-frame area |
| Outward mask margin | 2 working-image pixels |

These are foundation defaults, not normalization values or dimensions selected for
an evaluated classifier. The default array lies in `[0, 1]`; a custom mean/std changes
that range. A future model artifact must pin its exact preprocessing version,
configuration, normalization, masking policy, library versions, and class mapping.
Do not silently substitute ImageNet statistics or a different image size.

Configuration is immutable, rejects extra fields/nonfinite values, and validates
bounds and coherent settings. JSON configuration reads are limited to 64 KiB. The
configuration fingerprint is SHA-256 of the canonical sorted JSON representation,
so changing resize, normalization, crop, segmentation or limits changes the hash.

Returned arrays are read-only. Metadata records the preprocessing version,
configuration hash, original encoded-image hash, optional supplied-mask hash,
encoded/oriented dimensions, crop/content bounds, target size, applied ICC status,
segmentation diagnostics, warnings and NumPy/Pillow/OpenCV versions. Bounds use
`(left, top, right, bottom)` with exclusive right/bottom edges; sizes use `(width,
height)`, while the model array uses `(3, height, width)`.

Record this provenance with future dataset/experiment/model manifests. Behavioral
changes require a new reviewed preprocessing version and compatibility checks;
different dependency/platform implementations must be revalidated rather than
assumed bit-identical.

## Validation and color standardization

The decoder checks nonempty encoded bytes and limits before processing. It sniffs
JPEG/PNG/WebP signatures, checks optional supplied MIME and extensions, verifies
container end markers/length, verifies the image, and then fully decodes it. It
rejects unsupported formats, malformed/truncated inputs, multiple-frame/animated
images and excessive dimensions. Decoder/provider details and input filenames do
not appear in the package's safe error messages.

EXIF orientation must be a valid value from 1 through 8 and is applied before
segmentation or supplied-mask validation. Grayscale becomes three RGB channels.
Unsigned 16-bit grayscale PNG is mapped using fixed-range rounding of intensity
divided by 257, preserving gradations without per-image contrast stretching.
Paletted transparency and alpha channels are handled explicitly: colors are
composited onto the configured background, and any alpha greater than zero remains
eligible foreground. Fully opaque alpha does not bypass geometric extraction.

A valid embedded ICC profile is converted to sRGB using Pillow/LittleCMS perceptual
rendering. Profiles above 256 KiB or incompatible/malformed profiles fail safely.
Without a profile, normal image-mode conversion supplies RGB; untagged colors are
not measured or calibrated. Orientation/profile metadata is not copied into debug
PNG artifacts. See the primary references for [Pillow EXIF transforms](https://pillow.readthedocs.io/en/stable/reference/ImageOps.html)
and [Pillow image verification, modes and conversion](https://pillow.readthedocs.io/en/stable/reference/Image.html).

## Conservative foreground extraction

Mask precedence is explicit:

1. A caller-supplied boolean mask must match the EXIF-oriented frame. All selected
   regions are retained; the mask is not reduced to its largest component. A
   supplied mask takes precedence even when automatic segmentation is disabled.
2. With automatic extraction enabled, a non-opaque alpha channel supplies a mask
   retaining every pixel with nonzero alpha.
3. Otherwise, a bounded working image is converted from RGB to full-color Lab.
   The median border-band color estimates the background. Heterogeneous borders
   fail the variation gate. Pixels within the declared color-distance tolerance
   become background candidates, but only candidate components connected to the
   image perimeter are removed.

This third step leaves enclosed holes in the foreground: gray, brown, yellow,
rust-colored, dead or even background-colored pixels inside a surrounding leaf
region are retained. It requires no green hue or healthy-leaf assumption. Original
standardized RGB pixels remain the source for the crop; the working image is used
only to estimate the mask.

Foreground coverage must be plausible, the estimated foreground must not touch the
frame boundary, and exactly one significant component must remain. Small components
below the significance threshold are still retained rather than erased. An outward
mask dilation provides a safety margin; no erosion, color-directed lesion removal,
denoising or random optimization is applied. The mask returns to source resolution
with nearest-neighbor interpolation. Crop bounds include explicit padding, masked
background pixels use the configured replacement color, and the crop is resized
into a centered letterbox without stretching portrait or landscape inputs.

OpenCV supplies deterministic color conversion and connected-component/morphology
operations; the color-distance and fallback policy belong to this shared package.
See [OpenCV connected-component and morphology operations](https://docs.opencv.org/4.x/d3/dc0/group__imgproc__shape.html)
for the component API and [OpenCV dilation](https://docs.opencv.org/4.x/d4/d86/group__imgproc__filter.html)
for outward expansion semantics.

## Uncertainty and mask parity

The default `uncertain_policy="preserve"` returns a full-frame crop with no mask or
background removal when extraction is uncertain. Reasons include heterogeneous
borders, implausible foreground area, foreground touching the frame, multiple
significant regions, or empty alpha/provided masks. The metadata status is
`fallback`, with a reason and warning. The frame is still letterboxed and normalized;
fallback is not evidence that a leaf exists.

Set `uncertain_policy="raise"` to receive `SEGMENTATION_UNCERTAIN` instead. Set
`mode="disabled"` to retain the full standardized frame without automatic/alpha
extraction. A supplied mask retains its explicit precedence. Choose and pin these
policies identically for training, validation/test and serving.

Provided masks must come from the same reproducible input policy in every consumer.
Training-only manually annotated masks would create a serving distribution mismatch
even though both consumers call the same function. Metadata hashes supplied mask
dimensions and row-major boolean bytes, so different masks remain distinguishable
when image/configuration hashes match. Preserve that mask provenance with future
artifacts; never introduce a separate production masker unnoticed.

## Local inspection and verification

Activate either configured consumer environment, then run from the repository root:

```powershell
python -m maizedoctor_preprocessing 'REPLACE_WITH_EXISTING_IMAGE_FILE' --output '.cache/preprocessing-review-NEW_NAME' --config shared/preprocessing/configs/default.json
```

Replace the image placeholder with an actual file you have permission to inspect;
replace the output name with a new directory. This command does not name or download
a project dataset. `.cache/` is ignored by Git. The command refuses to overwrite an
existing directory and produces `standardized.png`, `mask.png`, `prepared.png`,
`contact-sheet.png` and `metadata.json`. Debug files contain image content; create
them only intentionally and do not commit private/licensed samples. A full-frame
debug mask is explicitly labeled when extraction falls back.

Unit coverage exercises format validation, corruption/limits, EXIF/ICC, 8/16-bit
grayscale, alpha, lesion-colored foreground, enclosed lesions, uncertain scenes,
mask validation/provenance, aspect ratio, normalization, deterministic concurrent
calls, immutable configuration/output, tensor conversion and debug artifacts.
Consumer tests assert exact shared callable identities. The cross-environment check
runs four synthetic scenes with two configurations, comparing eight cases through
the independently installed AI and training virtual environments:

```powershell
python scripts/check-preprocessing-parity.py
```

It compares implementation identity, masks, CHW array bytes, unchanged tensor bytes,
shape, dtype and metadata; its generated temporary fixtures are removed afterward.
Completed check results and final counts are recorded in
[PROJECT_STATE.md](PROJECT_STATE.md), rather than claiming unrun verification here.

## Limitations and pending field validation

Phase 9 originally had only generated fixtures and launcher graphics. Phase 9.5
resolved that gap using an external dataset configured through `DATASET_PATH`; raw
images remain outside Git. Dataset-wide mechanical checks and sampled visual review
are complete, without annotated lesion masks, clinical accuracy or deployment-device
validation. See the [real-image results](24-dataset-intake-preprocessing-review.md).

- A leaf edge/tip whose color blends with perimeter-connected background can be
  removed before the border-touching gate sees it. The safety margin helps but
  cannot guarantee recovery. Once cropped/masked away, such tissue is unavailable
  to a later classifier; retain originals and inspect debug masks before adopting
  the configuration for a model.
- Highly textured backgrounds, overlapping/multiple leaves, shadows, blur and
  ambiguous scenes commonly produce fallback. Contrast-based foreground may be
  another object rather than maize. Alpha or supplied masks may also be inaccurate.
- Low-resolution acquisition, JPEG artifacts, 16-bit-to-8-bit quantization,
  segmentation working-image reduction and final resizing can lose very small
  lesions. No interpolation can reconstruct details absent from the input.
- ICC assumptions, camera processing, lighting and background replacement change
  appearance. Extraction/fallback mixtures can change the training distribution;
  evaluate both using representative data and pin the chosen policy.
- Repeated/concurrent calls and separate local environments are tested for parity.
  Different platform libraries/codec builds may differ slightly; revalidate target
  deployments and record dependency versions. The byte/pixel caps bound individual
  work, but future HTTP serving still needs suitable concurrency/time/memory limits.

Before training, resolve the recorded contradictory labels, use eligibility and
preprocessing-policy choice. Continue target-device/independent-field validation before
production use. The shared contract and real-image evidence support a reproducible
baseline; neither supplies measured disease-classification accuracy.
