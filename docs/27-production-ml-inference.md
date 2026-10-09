# Phase 11 — internal classifier inference

Completed: 2026-10-09 (Asia/Karachi). This phase serves the approved Phase 10.5
research/FYP candidate in FastAPI. It does not retrain, recalibrate, select a
threshold, repeat final TEST evaluation, integrate Node, or add Flutter/RAG features.
The classifier remains **FIT WITH DOCUMENTED LIMITATIONS**; implementing a serving
interface does not certify field accuracy or grant commercial permission.

## Architecture and lifecycle

```text
Future Node request -> authenticated FastAPI /api/v1/predict
  -> bounded unchanged encoded bytes
  -> shared maizedoctor_preprocessing 1.0.0
  -> startup-loaded CPU MobileNetV3 Small
  -> validated probabilities and uncertainty -> typed JSON
```

`create_app()` remains side-effect free. The lifespan validates and loads one model
before advertising readiness or accepting requests. It checks the metadata digest,
checkpoint/sidecar sizes and SHA-256 values, explicit class/input/preprocessing and
normalization configuration, runtime dependency versions, checkpoint compatibility,
state keys/shapes/dtypes/finite values and a finite 1×4 output. It never downloads
weights, searches for a substitute checkpoint, or fills missing preprocessing defaults.

Weights are loaded from the exact verified bytes with `weights_only=True`, CPU
mapping and strict state restoration. The model is frozen and in `eval()` mode;
requests use `torch.inference_mode()`. It is not reloaded per request. Shutdown clears
the service reference/readiness after Uvicorn drains requests. Startup failure emits
a fixed `model_startup_failed` event/error code without artifact contents or paths;
the actual missing-checkpoint executable exits with code 3.

`GET /health` remains safe process liveness. It now reports inference `ready` or
`unavailable` and basic model `ready`/`not_loaded` status/version. Full model health
is authenticated at `GET /api/v1/model-health`. Liveness 200 in explicit health-only
mode does not mean inference is ready; model health and prediction return 503.

## Approved artifact and deployment inputs

| Property | Approved value |
|---|---|
| Model version | `mobilenet-v3-small-v2-20261009` |
| Training experiment | `mobilenet-v3-small-20261009-v2-01` |
| Architecture | torchvision `mobilenet_v3_small`, dropout 0.2, four outputs |
| Selected epoch / parameters | 8 / 1,521,956 |
| Checkpoint SHA-256 | `e95a2e83262637fc1a08b919e6003bddb2fe70664b9c51418f059b7c8287dc66` |
| Final metadata SHA-256 | `a831116fe1ff8b915543991412f4ab6b334736e8eaca376fab8db3b57e5b263d` |
| Shared package | `maizedoctor_preprocessing` 1.0.0 |
| Configuration fingerprint | `b142e59f458d27a2d3fddbfc86c2f2f802670ab4909f1275babbef92de9cb5c8` |
| Model input | N×3×224×224, RGB CHW float32 |
| Preprocessing | Full oriented frame; segmentation disabled; one bilinear aspect-preserving letterbox, white padding |
| Normalization | RGB/255; mean `[0.485,0.456,0.406]`, std `[0.229,0.224,0.225]` |
| Calibration | Disabled, method `none`, temperature 1.0 |
| Confidence threshold | Unlocked; `null` |

Required deployment files:

1. The selected checkpoint (6,212,695 bytes), external/ignored rather than checked in.
2. The approved [model-artifact.json](../ml-training/reports/mobilenet-v3-small-20261009-v2-01-fitness/model-artifact.json).
3. Its adjacent `calibration/calibration-config.json`, whose exact size/hash and
   classifier/class/config/dataset/validation identities are bound by the metadata.

These three files are sufficient for runtime. Other historical caches, report
plots, raw dataset, manifests and training modules are not runtime dependencies.
Copy the metadata and sidecar without editing them; configure the checkpoint path
separately. The expected metadata digest must come from this approved artifact,
not be recomputed to silently accept an unknown replacement. Hashes check integrity
against the operator's trusted configuration; they do not establish publisher identity.

Class mapping remains literal and ordered:

| Index | Label |
|---:|---|
| 0 | `Common_Rust` |
| 1 | `Gray_Leaf_Spot` |
| 2 | `Healthy` |
| 3 | `Northern_Corn_Leaf_Blight` |

The loader requires the recorded CPU torch/torchvision, shared package, NumPy,
Pillow and OpenCV versions. Windows OpenCV and the identically versioned Linux
headless package are supported for dependency validation; Linux codec parity and
deployment behavior still need verification on the target platform.

## Configure and run

Use ignored `ai-service/.env` or the deployment environment; OS values take
precedence. Artifact paths resolve relative to `ai-service`, independent of cwd.
The template leaves model paths/hashes/versions and secrets blank. Defaults do not
invent a model: `INFERENCE_ENABLED=true` requires valid settings/files at startup.

| Setting | Requirement/default |
|---|---|
| `AI_SERVICE_TOKEN` | Required for inference, including loopback; existing base64url 43–256-character validation |
| `INFERENCE_ENABLED` | `true`; explicit `false` is health-only maintenance/test mode, with no ready classifier |
| `MODEL_PATH` | Explicit selected checkpoint location |
| `MODEL_METADATA_PATH` | Explicit approved final metadata location |
| `MODEL_METADATA_SHA256` | Explicit lowercase 64-character approved digest |
| `MODEL_VERSION` | Explicit expected model version, checked against metadata |
| `PREPROCESSING_VERSION` | Explicit expected shared version, checked against installed package/config/checkpoint |
| `INFERENCE_THREADS` | 2; integer 1–8 |
| `INFERENCE_MAX_CONCURRENCY` | 1; integer 1–4 per process |
| `INFERENCE_UPLOAD_TIMEOUT_SECONDS` | 10; finite value 1–60 |
| `CONFIDENCE_POLICY_PATH`, `CONFIDENCE_POLICY_SHA256` | Both blank for current policy; otherwise both required and hash-bound |

The local ignored configuration is populated for the approved artifact; existing
nonblank values are preserved and credentials are not printed. No model binary,
actual dataset path or service secret is committed. Database/Gemini values remain
unused. Start from repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/start-ai.ps1
```

Or from `ai-service`: `.venv/Scripts/python.exe -m app.server`. Default binding is
loopback. Keep the service private, use TLS on an actual deployment and configure
the shared token only in Node/server environments. No browser CORS is enabled;
CORS is not authentication. Flutter must continue to call Node, which will
orchestrate this interface in Phase 12. Public farmer JWTs are not service tokens.

## Prediction request contract

`POST /api/v1/predict?top_k=4`

- `Authorization: Bearer <server service token>` is mandatory and checked before
  query/image processing.
- Body is the **unchanged encoded image bytes**, without JSON/base64, multipart,
  URLs or remote-image fetching.
- Exactly one `Content-Type`: `image/jpeg`, `image/png` or `image/webp`. Media type
  case/whitespace and optional parameters are normalized before shared validation.
- `Content-Encoding` must be absent or `identity`.
- `top_k` is an integer 1–4, default 4. Unknown query fields are rejected.
- `Content-Length` is optional, but must be one bounded nonnegative decimal when
  supplied. A length above the limit fails early; the streamed byte counter is
  authoritative even when length is absent or falsely small.

No filenames/extensions are supplied by this raw-body contract. The shared
preprocessor still supports optional filename/extension checking for internal
direct callers; image type is always checked against bytes and full decoding.

## Exact image-admission contract for Phase 12

The authoritative image implementation is the unchanged shared package:

| Condition | Contract |
|---|---|
| Encoded size | Nonempty; at most **5,242,880 bytes (5 MiB)** inclusive |
| Formats | Still JPEG, PNG, WebP; no GIF/BMP/TIFF/SVG or animated/multiple-frame input |
| Type | Signature, declared MIME, container length/end markers, verify and full decode must agree |
| Dimensions | Each encoded side ≥16; width×height ≤16,000,000; checked before full decode |
| Integrity | Reject corrupt/truncated containers and trailing data under the shared format checks |
| Color/orientation | Shared EXIF orientation, RGB/grayscale/16-bit grayscale, alpha compositing and ICC standardization |
| Invalid profiles/orientation | Safe rejection; no guessed recovery |
| Model preparation | Shared full-frame configuration and `PreprocessingResult.to_tensor()`; no second resize, normalization or random augmentation |

The configured full-frame RGB/white-background/ImageNet policy is the exact policy
used in training. Admission failure precedes model execution. A valid image is not
thereby proven to contain a maize leaf or a supported disease.

Stable API errors use the existing `success=false/error/meta` envelope:

| HTTP | Code | Meaning |
|---:|---|---|
| 401 | `AUTHENTICATION_ERROR` | Missing/invalid service credentials |
| 408 | `REQUEST_TIMEOUT` | Upload stream deadline exceeded |
| 413 | `REQUEST_TOO_LARGE` | Encoded body above the byte cap |
| 415 | `IMAGE_UNSUPPORTED` | Missing/unsupported declared MIME, body format, encoding or animation |
| 422 | `VALIDATION_ERROR` | Invalid query or length syntax |
| 422 | `IMAGE_INVALID` | Empty/corrupt/truncated image, type mismatch or invalid color standardization |
| 422 | `IMAGE_DIMENSIONS` | Too small or excessive pixel count |
| 500 | `PREPROCESSING_FAILED` | Unexpected processing/configuration failure |
| 500 | `INFERENCE_FAILED` | Invalid output or unexpected classifier execution failure |
| 503 | `MODEL_UNAVAILABLE` | Lifespan/model not ready or inference explicitly disabled |
| 503 | `INFERENCE_BUSY` | Per-process capacity occupied; caller may retry later |

Unknown signatures are classified as unsupported format; known-format corrupt
containers are invalid images. Messages never echo paths, filenames, body bytes,
headers, codec exceptions or stack traces.

**Phase 12 mismatch boundary:** actual FastAPI probes reject the 1×1 PNG and PNG
trailing-byte cases that Node previously accepted. This phase documents and serves
the strict shared policy; Node's existing upload validator/scan workflow is unchanged.
Phase 12 must align eligibility or explicitly record accepted-scan processing failure.
Do not duplicate image preprocessing in Node or silently relax Python admission.

## Prediction response contract

One standard envelope, with camelCase fields:

```json
{
  "success": true,
  "data": {
    "predictedClass": "Healthy",
    "confidence": 0.9119033217,
    "topProbabilities": [
      {"className": "Healthy", "probability": 0.9119033217},
      {"className": "Common_Rust", "probability": 0.0580177829},
      {"className": "Northern_Corn_Leaf_Blight", "probability": 0.0264879037},
      {"className": "Gray_Leaf_Spot", "probability": 0.0035909917}
    ],
    "modelVersion": "mobilenet-v3-small-v2-20261009",
    "preprocessingVersion": "1.0.0",
    "inferenceDurationMs": 27.61,
    "predictionStatus": "LOW_CONFIDENCE",
    "uncertaintyReason": "THRESHOLD_UNCONFIGURED",
    "confidenceThreshold": null
  },
  "meta": {"requestId": "server-generated UUID"}
}
```

This is a synthetic live-probe output, not evidence that a blank/green image is
healthy maize. The numeric confidence is the four-class softmax maximum, not a
probability of agronomic correctness/OOD membership. Top-k probabilities are sorted,
with class-index tie order; truncated top-k values are not renormalized. Responses
and logs omit checkpoint/configuration paths and private credentials. Existing
request-ID, no-store and nosniff headers remain in place.

## Confidence and uncertainty policy

Phase 10.5 left the threshold unlocked because validation cutoffs retain confident
errors, sharply reduce GLS coverage and lack a product risk/coverage objective.
Calibration is disabled; raw probabilities are preserved. Phase 11 does not select
or fit anything from the consumed final test.

With current configuration every prediction has `LOW_CONFIDENCE`, reason
`THRESHOLD_UNCONFIGURED`, threshold `null`, even for a high score. This expresses
an unestablished operational certainty policy rather than claiming the numerical
score is below an invented threshold. Model health reports `confidencePolicy=UNCONFIGURED`.

A future explicitly approved **validation-based** research policy may be supplied
through a separate pinned JSON file. Required fields are `schema_version=1`,
`decision_status="approved_for_research"`, `selected_using="validation"`,
`model_version`, `checkpoint_sha256`, `validation_predictions_sha256`, a finite
`threshold` strictly between 0 and 1 and a documented `rationale`. The source hashes
must match the loaded model's exact checkpoint and saved validation predictions.
Missing fields, wrong hashes, TEST selection, experimental status and invalid cutoffs
fail startup. The operator must establish and approve the actual risk objective and
validation evidence; the loader checks declared provenance/integrity, not whether
the written rationale constitutes a scientifically adequate product decision.

No ready-to-use numerical policy is shipped. Synthetic test policies exercise the
branches without approving a real cutoff. A configured score below threshold is
`LOW_CONFIDENCE/BELOW_VALIDATION_THRESHOLD`; a score at/above it is `CONFIDENT`.
That status still does not mean guaranteed correctness. Policy changes do not
alter weights, class order, shared configuration or calibration.

## Resources, verification and measurements

The route reserves capacity **before buffering** an upload; the service separately
bounds direct CPU callers. Excess requests return 503 without an unbounded work
queue. Default is one admitted prediction and two CPU threads per process. Buffering
is capped, uploads have a 10-second default deadline, and heavy preprocessing/model
work runs off the event loop. Model-health/liveness can respond while inference runs.
Uvicorn retains its 100-connection/task cap and 10-second graceful drain.

The upload deadline does not forcibly terminate a native decoder/model thread.
Deployment must measure peak memory, throughput and process-supervisor limits;
16 MP processing may still allocate substantial memory. Multiple workers each own
a model and capacity limit. Target-platform codec checks and private network/TLS
deployment are separate from this verified local service.

Checks executed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component AI
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Preprocessing
ai-service/.venv/Scripts/python.exe -m ruff format --check scripts/check-inference-parity.py
ai-service/.venv/Scripts/python.exe -m ruff check scripts/check-inference-parity.py
ai-service/.venv/Scripts/python.exe -m compileall -q ai-service/app ai-service/tests scripts/check-inference-parity.py
ai-service/.venv/Scripts/python.exe scripts/check-inference-parity.py --output .cache/phase11/train-serving-parity-01.json
.cache/tools/Scripts/uv.exe pip check --python ai-service/.venv/Scripts/python.exe
.cache/tools/Scripts/uv.exe lock --check --project ai-service
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-repository.ps1
git diff --check
```

Results: **219 AI tests pass**, Ruff format/lint over 40 AI files and strict mypy
over 24 application files pass. Shared preprocessing has **78 passing tests in each
independent environment**, with 12 exact synthetic parity cases. The QA script also
passes its own Ruff/compile checks. The commands above record the completed run;
choose a new output filename for another authorized parity run.

AI tests cover all four literal classes through synthetic architecture-compatible
fixtures, actual shared JPEG/PNG/WebP/color handling, MIME/malformed/truncated/
unsupported/animated/tiny/oversize inputs, strict startup compatibility and dtypes,
policy provenance/boundaries, safe errors, repeated inference, once-per-lifespan
loading, shutdown readiness, actual upload deadline and bounded six-request concurrency.
Shared tests pass in both consumer environments, with 12 exact synthetic parity cases.
One existing Starlette/HTTPX TestClient deprecation warning remains; dependencies
are unchanged, with all 43 installed packages compatible and the lock valid.

Real approved-model serving matches **16 TRAIN cases**, four per class, against
the frozen Phase 10.5 tensor and logit SHA values **exactly**. No real TEST images
are read, and the dataset path comes only from the existing `DATASET_PATH` loader.
Representative preprocessing-plus-inference duration: **17.75 ms mean**, **15.94 ms
median**, **11.20–51.40 ms range**, batch one/two threads. This includes shared decoding/
preprocessing, tensor conversion and classification/probability work, excluding
upload transfer and response serialization/network latency. It is not a serving SLA.

Actual loopback Uvicorn checks pass JPEG/PNG/WebP, token protection, strict Node-mismatch
cases, invalid MIME/corruption/size, ready model health and six simultaneous requests
(one 200, five explicit busy 503). The owned process loads once and shuts down cleanly
with exit 0; the actual executable with a missing checkpoint exits 3 without exposing
the rejected path/secret. Local numerical evidence and safe logs stay under
`.cache/phase11/`; no source-image sheets or weights are published.

Final review also passes repository/template/ignore checks, all **235 local Markdown
links**, whitespace checks and credential/machine-dataset-path scans over **452 source
candidates**. All **171 frozen Phase 10.5 source/report/index files** match their
working and committed byte hashes; the approved checkpoint is unchanged. Backend,
Flutter and the shared package have no changes. Approved-model startup/readiness
and shutdown pass after the final strict dtype guard, without another prediction.

Known model limitations from [Phase 10.5](26-model-fitness-validation.md) remain:
source-domain/GLS weakness, high-confidence errors, unresolved possible parent identity,
previously inspected corpus, no independent field/plant validation or OOD detector,
and non-commercial academic/FYP rights restrictions. Stop after Phase 11.
