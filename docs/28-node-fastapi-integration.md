# Phase 12 — Node/FastAPI scan inference

Implementation date: 2026-10-10 (Asia/Karachi). Phase 12 connects the existing
Phase 7 upload workflow to the approved Phase 11 classifier and persists validated
results. The selected model, shared preprocessing, raw dataset and frozen evaluation
artifacts remain unchanged. The model retains its **FIT WITH DOCUMENTED LIMITATIONS**
verdict and non-commercial academic/FYP research scope.

## End-to-end flow

```text
Flutter multipart image -> Node scan route/controller/service
  -> upload admission -> existing Cloudinary upload -> PostgreSQL PENDING scan
  -> conditional PROCESSING attempt -> typed internal FastAPI client
  -> unchanged encoded bytes -> exact shared preprocessing -> startup-loaded model
  -> validated Node prediction -> repository transaction -> PostgreSQL COMPLETED
  -> stable Node scan response -> Flutter
```

Flutter continues to use Node only. Gallery/camera selection, preview, progress,
request keys, Cloudinary upload, anonymous ownership and farmer ownership are
preserved. Mobile scan parsing now accepts the lifecycle states introduced here;
disease-result presentation belongs to the next UI phase. Node controllers remain
thin; orchestration belongs to the scan service, transport to the inference client,
and database operations to repositories.

Node saves the Cloudinary asset and scan before inference. It sends its already
validated original image buffer directly to the fixed internal
`POST /api/v1/predict?top_k=4` endpoint. It does not fetch a user or Cloudinary URL,
follow redirects, send base64/multipart to Python, or move ML transforms into Node.
FastAPI still owns decoding/color standardization, full-frame letterboxing,
normalization, tensor conversion and classification through the exact shared
package. See the [Phase 11 runtime contract](27-production-ml-inference.md).

## Compatible image admission

Node's security admission now applies the shared preprocessing 1.0.0 eligibility
bounds before a Cloudinary upload or inference request:

| Condition | Policy |
|---|---|
| Encoded bytes | Nonempty, maximum 5,242,880 bytes inclusive |
| Formats | Still JPEG, PNG or WebP; one image/frame |
| MIME | Canonical `image/jpeg`, `image/png` or `image/webp`, matching signature bytes |
| Filename extension | Case-insensitive `.jpg`/`.jpeg`, `.png` or `.webp`, matching the detected type |
| Dimensions | Each encoded side at least 16 pixels; width × height at most 16,000,000 |
| Container integrity | JPEG end marker, PNG IEND/chunk bounds, exact WebP RIFF length; no accepted trailing data |
| Animation | Reject multiple-frame PNG/WebP, including APNG declarations that libvips can otherwise expose as a single page |
| Decoding | Require complete pixel decoding, reject decoder warnings/corruption; five-second Sharp processing timeout |
| Orientation | Accept valid EXIF orientations 1–8; reject malformed/out-of-range raw orientation tags |
| Color | Permit valid grayscale, alpha and CMYK inputs; Python remains authoritative for RGB/ICC conversion |

Node retains the original buffer without resizing, rotating, re-encoding,
segmenting, normalizing or converting it to a model tensor. Its narrow container
and raw orientation checks address differences between libvips and Pillow admission;
they do not create a second ML preprocessing pipeline. FastAPI validation remains
authoritative and has not been weakened.

The cross-language contract probe passes **56 synthetic cases: 21 accepted and
35 rejected**, with exact agreement between Node and the actual shared full-frame
preprocessor. Accepted cases retain the exact original buffer. Coverage includes
JPEG/PNG/WebP, 16-pixel boundaries, portrait/landscape frames, grayscale/alpha/palette/
CMYK, valid ICC/EXIF, truncation, trailing bytes, CRC corruption, wrong MIME/extension,
invalid orientation, excess pixels/bytes, animation and unsupported formats.
The previously accepted 1×1 PNG and PNG trailing-byte cases are rejected before upload.
This finite fixture corpus is evidence for the declared contract, not proof that
different codec libraries accept every possible image identically. Python can still
reject an image that passes Node; that outcome becomes an explicitly failed saved scan.

## Server configuration and transport

All settings live in server environment configuration. Nothing exposes the internal
service URL, service token, artifact locations or Cloudinary credentials to Flutter.
Backend startup validates complete configuration without echoing supplied values.
`GET /api/v1/health` continues to report backend/database health, not guaranteed
classifier availability; operators can inspect FastAPI's authenticated model-health
endpoint. An unavailable classifier remains a recoverable scan-analysis failure.

| Setting | Contract |
|---|---|
| `AI_SERVICE_URL` | Blank disables integration together with the three identity settings below; otherwise an operator-controlled HTTP(S) origin, optionally ending in `/` |
| `AI_SERVICE_TOKEN` | Same server credential as FastAPI; canonical base64url, 43–256 characters, at least 32 decoded bytes |
| `AI_MODEL_VERSION` | Explicit expected approved classifier version, maximum 80 characters |
| `AI_PREPROCESSING_VERSION` | Explicit expected shared version, maximum 120 characters |
| `AI_SERVICE_TIMEOUT_MS` | Complete request/response deadline, default 10,000 ms; integer 1,000–20,000 |

The four origin/token/version values must all be configured or all blank. Partial
configuration fails startup. The template contains no secret or guessed model version.
An old placeholder URL alone must be cleared or completed when upgrading a local
environment. With integration disabled, uploaded scans become
`FAILED/INFERENCE_UNAVAILABLE`; they are not left indefinitely pending.

Origin validation excludes userinfo, paths, query strings and fragments. Trusted
private Docker/network HTTP origins are permitted, including in production mode;
operators must keep Python private and provide appropriate private networking/TLS.
CORS is not service authentication. Farmer JWTs are never forwarded as service tokens.

The dedicated client sends raw bytes with the matching MIME, exact Content-Length,
`Authorization: Bearer <service token>`, JSON Accept and identity Accept-Encoding.
It refuses redirects. Its deadline covers connection, inference response and streamed
body reading, with abort/cancellation on timeout or completion. JSON responses are
bounded to **64 KiB** by both an early declared-length guard and the actual streamed
byte count; malformed lengths, invalid UTF-8, non-JSON content types and unknown
success-envelope fields are rejected.

Before persistence, strict Zod checks require the four literal classes, four unique
sorted probabilities, class-index order for exact ties, values finite in `[0,1]`,
sum within `1e-5` of one, and winning confidence within `1e-6` of its probability.
Configured model/preprocessing versions must match exactly. Inference duration must
be finite in `[0,20000]` ms, and threshold/status/reason must be coherent. Provider
messages, bodies and transport exceptions never enter public errors or logs.

## Scan lifecycle, persistence and recovery

| State | Meaning |
|---|---|
| `PENDING` | Cloudinary image and scan are committed; inference has not been claimed |
| `PROCESSING` | One worker owns a persisted random attempt UUID |
| `COMPLETED` | Validated prediction and terminal scan state committed together |
| `FAILED` | Analysis failed or was interrupted; saved image/scan remain available for retry |

The repository conditionally claims only `PENDING`/`FAILED` scans without an existing
prediction. The attempt UUID fences both success and failure writes: a delayed worker
cannot overwrite a later retry or an interrupted outcome. The prediction transaction
locks the matching active attempt, verifies the registered model/class/preprocessing
identity, inserts a prediction and marks the scan `COMPLETED` atomically. Database
operations use the reusable Prisma client; transaction max-wait is 10 seconds and
timeout is 15 seconds.

`scan_predictions` stores the literal label, confidence, full class-probability JSON,
registered model-version relation, preprocessing version through that immutable
model record, prediction status, uncertainty reason, threshold, inference duration
and inference timestamp. The migration adds only the required attempt UUID and
uncertainty/timing fields, retaining existing lifecycle enums. Historical prediction
rows can retain all new outcome fields as null; no certainty or timing is invented.
SQL checks and existing immutable-history protections complement application validation.

Upload compensation is isolated from inference. A Cloudinary/initial database failure
uses the existing durable upload journal and asset cleanup. Once a scan is saved,
inference failure never deletes its Cloudinary asset or original scan. A lost database
acknowledgement is reconciled by reading the scan: committed completion is returned;
otherwise the owning attempt is marked failed. If the database remains unavailable,
the API returns a safe 503 and persisted state awaits conditional recovery.

Same-photo/account retries reuse the original UUIDv4 Idempotency-Key. Completed scans
are returned without uploading or classifying again. Failed scans retry inference
from the caller's resubmitted identical image bytes, preserving the scan and asset.
The original byte digest must match; different bytes with the same key cause 409.
Concurrent requests do not acquire a second active attempt. A current processing
record can be returned for a same-key retry; callers can read its latest state.

`PENDING`/`PROCESSING` scans older than **two minutes** are recoverable as
`FAILED/INFERENCE_INTERRUPTED`. Reads/retries perform conditional stale recovery.
The running backend also executes recovery every **60 seconds**, at most **100 rows
per pass**, using parameterized SQL and `FOR UPDATE SKIP LOCKED`; overlapping workers
cannot overwrite active or completed outcomes. Shutdown stops the timer and waits for
an in-flight recovery within the existing graceful-shutdown deadline. A stopped server
performs no background work; recovery resumes after restart.

Failure timestamps use PostgreSQL clock time clamped to creation. Successful terminal
timestamps account for PostgreSQL microsecond precision when Prisma returns milliseconds.
Host clocks still need synchronization because the stale-lease cutoff comes from Node.
Clock skew can delay recovery or prematurely expire a live attempt; attempt fencing
preserves consistency but does not establish a deployment SLA.

`npm.cmd run scans:cleanup` also recovers stale inference before the existing orphan
upload cleanup. Schedule that command for upload crash recovery: the inference timer
does not delete Cloudinary assets. Existing cleanup retains its 15-minute stale-upload
grace period, bounded batches, retries and one-day failed-attempt journal retention.

## Public Node API and ownership

`POST /api/v1/scans` preserves the Phase 7 request contract: one multipart file named
`image`, no text fields/extra files/query, lowercase UUIDv4 `Idempotency-Key`,
`X-Auth-Request: 1`, and optional FARMER bearer access token. No token means a scan
with `user_id=NULL`. A supplied invalid/expired/revoked token is rejected, never
downgraded to anonymous; authenticated ADMIN access is denied on this farmer route.
Existing per-IP scan limits, exact-origin CORS and security headers remain in place.
Two active upload/analysis slots per Node process bound retained buffers and work;
the slot remains owned until processing ends even if the client disconnects after
sending its complete request. GET reads have their own 60-per-minute route limit.

**201 means a new image/scan was saved; 200 means a same-key saved scan was returned.**
Neither status promises successful classification. A saved scan whose analysis failed
still returns the standard successful scan-creation envelope with `data.status=FAILED`,
`prediction=null` and `analysisError`. This preserves a usable resource rather than
claiming a failed inference succeeded. Validation/upload failures before saving use the
existing centralized HTTP error envelope. A database outage that prevents reconciling
the saved scan uses 503 `SCAN_PROCESSING_UNAVAILABLE`.

`GET /api/v1/scans/:scanId` returns the same representation with HTTP 200:

- A FARMER bearer token can read only that farmer's scan; another farmer gets 404.
- An anonymous caller needs the original `Idempotency-Key` capability and an anonymous
  scan; missing credentials give 401 and an incorrect key/ownership gives 404.
- ADMIN is denied; malformed identifiers/keys/extra query parameters give 400.
- GET does not fetch an image or initiate inference. It may mark an expired attempt
  interrupted before returning its current state. Responses use `Cache-Control: no-store`.

Example completed response, with synthetic probability values:

```json
{
  "success": true,
  "data": {
    "id": "<scan UUID>",
    "status": "COMPLETED",
    "createdAt": "<UTC timestamp>",
    "finishedAt": "<UTC timestamp>",
    "prediction": {
      "predictedClass": "Healthy",
      "confidence": 0.7,
      "probabilities": {
        "Healthy": 0.7,
        "Common_Rust": 0.2,
        "Gray_Leaf_Spot": 0.07,
        "Northern_Corn_Leaf_Blight": 0.03
      },
      "modelVersion": "mobilenet-v3-small-v2-20261009",
      "preprocessingVersion": "1.0.0",
      "predictionStatus": "LOW_CONFIDENCE",
      "uncertaintyReason": "THRESHOLD_UNCONFIGURED",
      "confidenceThreshold": null,
      "inferenceDurationMs": 17.25,
      "inferredAt": "<UTC timestamp>"
    },
    "analysisError": null,
    "image": {
      "url": "<signed HTTPS Cloudinary image URL>",
      "mimeType": "image/png",
      "bytes": 12345,
      "uploadedAt": "<UTC timestamp>"
    }
  },
  "requestId": "<Node-generated UUID>"
}
```

Unfinished/failed scans have `prediction=null`; failed scans expose only a fixed
`analysisError.code/message`. The complete public field set is shown above. Owner IDs,
journal IDs/digests, attempt IDs, model database IDs, Cloudinary public IDs, internal
service metadata/request IDs, credentials and artifact paths are excluded as separate
fields. Signed image URLs and anonymous request keys are bearer capabilities; clients
must protect them and avoid logging or sharing them publicly.

| Analysis failure | Saved scan code |
|---|---|
| Service disabled, unreachable, busy, unavailable or invalid server credential | `INFERENCE_UNAVAILABLE` |
| Node deadline or authoritative upload timeout | `INFERENCE_TIMEOUT` |
| Authoritative image rejection | `INVALID_IMAGE` |
| Invalid envelope, probabilities, versions, redirect or oversized response | `INFERENCE_INVALID_RESPONSE` |
| Classifier/preprocessing failure | `INFERENCE_FAILED` |
| Result transaction/model registration failure | `INFERENCE_PERSISTENCE_FAILED` |
| Expired interrupted attempt | `INFERENCE_INTERRUPTED` |

## Controlled model registration and uncertainty

Before accepting successful inference, register the approved metadata against the
configured expected versions. From `backend`:

```powershell
npm.cmd run db:migrate
npm.cmd run models:register -- --metadata ../ml-training/reports/mobilenet-v3-small-20261009-v2-01-fitness/model-artifact.json --sha256 a831116fe1ff8b915543991412f4ab6b334736e8eaca376fab8db3b57e5b263d
```

The local operator command checks the exact metadata SHA/512-KiB cap, supported
architecture/input/version/class mapping, disabled calibration/unlocked threshold and
research-only declarations. It records checkpoint SHA identity as `sha256:<digest>`,
dataset/preprocessing/configuration/experiment provenance and the exact ordered labels.
It reads no checkpoint or source images and downloads nothing; FastAPI independently
checks and loads the actual checkpoint at startup.

New registry rows have status **VALIDATED**, not PRODUCTION. Re-running with the exact
same identity is idempotent; any conflicting existing artifact/configuration is refused,
including a concurrent registration race. No version, artifact or existing status is
overwritten and no model is promoted. Existing compatible VALIDATED/PRODUCTION records
can be used without changing their status. Registration is an operator command, not
a public/admin management API.

Class indices remain `0=Common_Rust`, `1=Gray_Leaf_Spot`, `2=Healthy`,
`3=Northern_Corn_Leaf_Blight`. The model is `mobilenet-v3-small-v2-20261009`, shared
preprocessing is `1.0.0`, and the approved full-frame policy is unchanged.
Every current result preserves **LOW_CONFIDENCE / THRESHOLD_UNCONFIGURED / null**,
even when its numerical softmax score is high. A valid low-confidence result can still
complete a scan. Node validates uncertainty semantics but chooses no threshold,
calibration or test-dependent rule. Future approved validation-derived policies follow
the existing Phase 11 hash-bound policy mechanism.

## Verification and remaining deployment work

Recorded checks:

| Check | Result |
|---|---|
| Backend unit/API regression suite | 156 passing tests |
| PostgreSQL schema/domain SQL regression | 13 passing tests |
| Authentication database integration | 6 passing tests |
| Phase 7 upload database regression | 7 passing tests |
| PostgreSQL inference integration | 7 passing tests, including atomic persistence, version identity, ownership and recovery |
| Prisma/migration verification | 6 migrations, 23 SQL checks and 37 triggers verified; no schema drift |
| Cross-language admission | 56 matching synthetic cases: 21 accepted, 35 rejected |
| AI service | 219 passing tests; Ruff and strict mypy pass |
| Shared preprocessing | 78 passing tests in each independent consumer environment |
| Preprocessing parity | 12 exact synthetic parity cases |
| Flutter | Analyzer/format checks and 59 tests pass, including lifecycle parser compatibility |
| Live Node → Cloudinary/FastAPI → PostgreSQL | Four synthetic image scans pass: three guests and one farmer, JPEG/PNG/WebP, safe GET and replay, exact model identity; owned fixtures cleaned |
| Live Flutter → Node → Cloudinary/FastAPI → PostgreSQL | Full round trip and prediction assertions pass; owned fixtures cleaned |

Backend checks include formatting, lint, strict types, build, auth/scan regression,
typed client failures/timeout/redirects/body bounds, model metadata/research declarations
and service-token log redaction. Database tests exercise anonymous/farmer persistence,
uncertainty/model versions, malformed outcomes, stale-worker fencing, interrupted
recovery, transactions, registry immutability and existing Phase 7 cleanup protection.
The AI/shared implementation is unchanged. No training or final TEST evaluation occurs.
Live verification uses the real approved FastAPI model, real Cloudinary storage and
the configured Neon PostgreSQL database. The four Node synthetic probes average
**41.687 ms** of reported AI preprocessing-plus-inference time. This excludes
Cloudinary transfer and end-to-end network/database latency, is not an SLA, and makes
no accuracy claim about synthetic images. All 171 frozen Phase 10.5 files, approved
weights, AI/shared source and the five historical migrations remain unchanged.

From `backend`, use `npm.cmd run check`, `npm.cmd run db:validate`,
`npm.cmd run db:generate`, `npm.cmd run test:inference:database`,
`npm.cmd run test:scans:database`, `npm.cmd run db:check`,
`npm.cmd run db:check:migrations`, `npm.cmd run db:status` and `npm.cmd run db:diff`.
Database checks require the configured PostgreSQL/pgvector environment; this run
used Neon rather than a local database. Negative SQL-check fixtures use a 30-second
test transaction limit to accommodate remote round trips; runtime limits are unchanged.
From repository root:

```powershell
ai-service/.venv/Scripts/python.exe scripts/check-image-admission-contract.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component AI
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Preprocessing
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Flutter
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-repository.ps1
git diff --check
```

Serving integration does not establish independent plant/field accuracy, detect OOD
inputs, resolve source-domain/GLS weaknesses, approve a numerical certainty policy or
clear commercial dataset rights. Preserve the [model fitness limitations](26-model-fitness-validation.md)
and source/license information; raw images and weights are not redistributed through
this implementation. Target-platform codecs, latency/memory/throughput, synchronized
clocks, private TLS/networking and scheduled upload cleanup remain deployment work.
Finite per-leg deadlines do not constitute an end-to-end SLA. A lost mobile response
must retry the same photo/key rather than invent a new scan.
Aborting Node's request does not forcibly terminate native Python decoder/model work;
capacity and process-supervisor limits must be measured on the deployment platform.

Stop after Phase 12. Disease-result UI, further business features, training and RAG
are not implemented by this phase.
