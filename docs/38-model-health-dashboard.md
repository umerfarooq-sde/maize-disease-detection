# ML model health dashboard — Phase 22

Admin overview → Model health opens `/admin/model-health`, outside farmer navigation.
Flutter uses a scoped ChangeNotifier → repository → authenticated Node API. No Flutter
call reaches FastAPI, a model file, Google, or a dataset directly.

## Registry and deployment

`GET /api/v1/admin/model-health` requires a live ADMIN session, with no-store,
rate limiting, strict empty query validation and centralized safe errors. Farmer
access returns 403; missing/invalid/revoked sessions return 401 before work.
The route/controller/service/repository separation is preserved.

The repository reads existing `model_versions` in a repeatable-read transaction:
the latest 50 safe registrations and up to two production identities. It projects
version, architecture, dataset version, preprocessing version, status and registration
timestamp; it never returns model paths, training environment blobs or secret values.
Zero production rows means NOT_PROMOTED; more than one means MULTIPLE_PRODUCTION,
not an arbitrary winner. No registration/status/artifact is changed by this phase.

The fixed-origin, authenticated, bounded Node service client probes internal
`GET /api/v1/model-dashboard`. It reuses the existing deadline/response-size/strict
UTF-8/no-redirect transport. Unknown/malformed or unavailable replies produce an
explicit unavailable service section while retaining registry data. A loaded version
or preprocessing mismatch produces INCOMPATIBLE without publishing that snapshot.
Health polling does not invoke inference or increment prediction counters.

The envelope is the existing `{success, data, requestId}`. Data contains:

- `asOf`: UTC observation time.
- `registry`: promotion status, single productionVersion or null, safe models list.
- `service`: READY/NOT_LOADED/UNAVAILABLE/INCOMPATIBLE, configuredVersion,
  registration presence in the displayed registry, matchesProduction, validated data.
- `drift`: NOT_AVAILABLE_NO_GROUND_TRUTH.

Registry promotion and live readiness are independent: a ready research model is
not automatically a production deployment. The current approved model is
`mobilenet-v3-small-v2-20261009`; it remains academic/FYP research only, with no
commercial clearance or independent field-performance claim.

## Offline evaluation evidence

The startup loader first performs all existing metadata/checkpoint/calibration SHA
and compatibility checks. It then projects evaluation fields from the same pinned
metadata bytes into the single loaded model. Health requests do not reread files,
load weights, calculate predictions or rerun the test partition. Incompatible saved
evaluation labels, support counts, confusion totals or accuracy fail startup safely.
No shared preprocessing implementation/configuration or model artifact is changed.

The `service.data.development` projection includes architecture, experiment ID,
dataset/index version and fingerprint, null `trainedAt`, and `evaluation`:
class names, sample count, accuracy, macro precision/recall/F1, per-class support,
precision/recall/F1/specificity and the saved 4×4 confusion matrix. Axes are explicitly
actual rows / predicted columns in literal class order. Registration time is shown
separately: the approved artifact has no recorded training timestamp, so it is not
invented from a filename, experiment ID or database creation date.

Current saved final-test evidence has **624 unique contents**, accuracy **95.8333%**,
macro precision **94.9640%**, macro recall **94.1365%**, macro F1 **94.5171%**.
These are descriptive results on a previously inspected corpus with documented
identity/domain/field-independence limits, not accuracy over 8,040 independent files.
See [model fitness](26-model-fitness-validation.md). Existing `model_metrics` records
are not populated or overwritten from runtime predictions. Offline evidence is
unavailable when the compatible pinned model snapshot is unavailable; no runtime
statistic is substituted. This view shows the loaded model's saved report, not
invented evaluation for every historical registry entry.

## Runtime operational statistics

`service.data.runtime` contains PROCESS_SINCE_START, UTC `since`, requests,
inFlight, successes, failures, lowConfidence, lowConfidenceRate,
meanLatencyMs and four-class predictionDistribution.

Counters use a fixed-size thread-safe object owned by FastAPI lifespan. They reset
on restart and cover only the worker responding to this probe. There is no durable
request journal, cross-worker aggregation, retained image, identity or unbounded
latency sample list. This is appropriate for the current single-process local
deployment; a shared metrics sink is required for cluster-wide operational history.

Requests count entries into the authenticated, query-valid prediction handler.
Failures include missing model, busy capacity, read/admission/preprocessing/inference
errors. Auth and query validation failures are excluded. Every started handler is
finished in a finally block; requests = successes + failures + inFlight. Distribution
counts sum to successful outputs. Low-confidence rate uses successful outputs only;
it is null before any success. Average latency uses completed handlers (including
failures), covering body reading + preprocessing + inference and error handling,
excluding Node/Cloudinary/PostgreSQL and network travel to the service. It is null
before completion; no p95 is claimed from an average.

The current confidence policy is UNCONFIGURED: no validation-approved operational
threshold exists. Therefore every successful result is LOW_CONFIDENCE, irrespective
of its score. The UI explicitly explains why a 100% low-confidence rate is not
evidence of deterioration. No threshold is selected from final-test or user scans.

No verified production ground-truth labels exist. Prediction distribution is neither
accuracy nor disease prevalence. Uncertainty/latency/label counts are possible future
monitoring signals; formal data/concept/performance drift detection is not implemented
or claimed. Farmer scans do not update offline test metrics.

## Verification

Run backend format/lint/typecheck/build/tests and Prisma validation/status; Flutter
format/analyze/tests; AI Ruff/mypy/pytest. Tests cover all RBAC denials, corrupt saved
evidence, counter reconciliation/concurrency/reset, bounded client errors, missing/
incompatible service, Flutter repository/ViewModel/session fencing, retry and narrow
320px/200% text layouts. The opt-in full contract is:

```powershell
ai-service/.venv/Scripts/python.exe scripts/check-model-health.py
```

It starts a private loopback service using configured pinned model paths, disables
RAG/generation, enforces PostgreSQL `default_transaction_read_only=on`, uses ephemeral
in-memory Admin auth and synthetic images, and exercises real Flutter/Node/FastAPI
contracts. No raw dataset is accessed; no account, metric, scan, model registration
or production promotion is written. Helpers never print credentials or raw failures.
Flutter SDK discovery uses PATH. Local proof/log files remain ignored under `.cache`.

See [project state](PROJECT_STATE.md) for final results. Stop after Phase 22.
