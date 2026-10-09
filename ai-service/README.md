# AI service

Phase 11 serves the approved `mobilenet-v3-small-v2-20261009` research/FYP classifier.
The lifespan validates pinned metadata, checkpoint and calibration sidecar, then
loads one frozen CPU model. Requests import the exact
[shared preprocessing package](../shared/preprocessing/README.md) 1.0.0 and recorded
full-frame configuration; no independent transforms or weight downloads occur.
Read [production ML inference](../docs/27-production-ml-inference.md) for artifact
setup, complete contracts, security, tests and limitations.

Endpoints:

- `GET /health`: safe process status and basic model readiness.
- `GET /api/v1/model-health`: authenticated readiness, class mapping and confidence policy.
- `POST /api/v1/predict?top_k=4`: authenticated raw JPEG/PNG/WebP bytes, at most 5 MiB,
  each side at least 16 pixels and at most 16 million pixels total; shared full decode
  and container checks are authoritative.

Current results always report `LOW_CONFIDENCE/THRESHOLD_UNCONFIGURED`, with a null
threshold and raw probabilities. No numerical cutoff or calibration is fitted here.
The model remains non-commercial academic/FYP research with documented source/domain,
GLS, confident-error and field-validation limitations. No Node orchestration, training,
RAG or Gemini is implemented in this phase.

The isolated Python 3.11 environment and existing locked CPU/image dependencies are
preserved. `pyproject.toml` and `uv.lock` additionally configure Pydantic settings,
Ruff formatting/lint and strict mypy for application source.

Training and production inference import the exact same preprocessing
implementation in `shared/preprocessing`, version 1.0.0. Artifacts
pin the evaluated configuration and version; do not create independent pipelines
in this directory and `ml-training/`.
Gemini must explain retrieved agricultural evidence and report insufficient information.

See [AI architecture](../docs/08-ai-architecture.md), [ML pipeline](../docs/09-ml-pipeline.md),
and [RAG architecture](../docs/10-rag-architecture.md). The
[AI foundation guide](../docs/21-ai-service-foundation.md) describes the structure,
contracts, network/auth policy, tests and future boundaries.

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-python.ps1 -Component ai-service
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component AI
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/start-ai.ps1
```

Or from `ai-service/`, run `.venv/Scripts/python.exe -m app.server`. It listens on
`127.0.0.1:8000` by default; Ctrl+C drains/shuts down through Uvicorn and the lifespan.
`Invoke-RestMethod http://127.0.0.1:8000/health` checks the running service.

Settings come from OS environment over the ignored service-local `.env`, independent
of launcher directory. `.env.example` leaves credentials blank. Loopback development
health needs no token. Inference startup, including loopback, requires a random
base64url `AI_SERVICE_TOKEN` (43-256 characters), explicit model/metadata paths,
approved metadata hash and expected model/preprocessing versions. Missing/invalid
artifacts fail startup. Explicit `INFERENCE_ENABLED=false` is health-only mode;
predictions/model readiness then return unavailable. No browser CORS is enabled: Flutter talks
to Node, and Node will call FastAPI over a private network. Production docs are disabled.
Database/Gemini template values remain unused. Optional confidence-policy path/hash
must both be supplied or blank; both remain blank for the approved model.

All 219 AI tests pass, including model lifecycle, artifact compatibility, authenticated
API/image admission, uncertainty, repeated inference and bounded concurrency. Ruff and
strict mypy pass. Shared tests pass 78 cases in each environment; 16 actual TRAIN
serving cases match frozen Phase 10.5 tensors/logits exactly. Real Uvicorn and safe
missing-checkpoint startup checks pass without reading TEST images. See the
[development setup](../docs/15-development-environment.md) for bootstrap tooling.
