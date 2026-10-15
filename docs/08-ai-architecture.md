# AI Service Architecture

> **Status:** Phase 15 adds bounded Gemini evidence selection and cited reviewed-corpus excerpts to Phase 14 retrieval, Phase 12 Node orchestration and the Phase 11 classifier. Read [grounded generation](31-grounded-generation.md) and [knowledge/retrieval](30-knowledge-retrieval.md) for implemented contracts. The Phase 16 Flutter assistant and Phase 22 model-health UI are integrated; deployment remains later work.

Both Python environments now install the same [shared preprocessing package](22-shared-preprocessing.md).
Serving and training re-export identical functions and must pin the same configuration
and mask policy. The selected model uses the approved full-frame configuration;
health distinguishes library availability from actual loaded-model readiness.

The current lifespan validates three pinned deployment files and loads one CPU
classifier before requests. It exposes safe `GET /health`, authenticated
`POST /api/v1/predict` and `GET /api/v1/model-health`. It binds to loopback by default,
enables no browser CORS and requires the server-only shared token for inference.
See [inference contracts](27-production-ml-inference.md) for startup, exact image
admission, bounded resources, uncertainty and verification. Flutter calls Node; Node
orchestrates FastAPI through authenticated unchanged image bytes, validates output
and persists model-bound predictions. See [integration](28-node-fastapi-integration.md).

## Ownership boundary

The Python/FastAPI service owns image validation, decoding, preprocessing, disease inference, model health, knowledge retrieval, and Gemini interaction. The Node.js backend owns user-facing business workflows, authorization, and orchestration. Do not move ML logic into Node.js.

## Inference flow

```text
Backend request
  -> validate request and image
  -> decode and color-convert
  -> shared preprocessing pipeline
  -> load/use pinned PyTorch model
  -> validate output shape and class mapping
  -> retrieve relevant knowledge
  -> optionally generate grounded explanation
  -> return typed result with model/provenance metadata
```

Each stage should fail explicitly. Reject unsupported or corrupt images before inference; reject malformed model output instead of returning a success-shaped fallback.

The current classifier flow ends with typed probabilities and uncertainty.
Retrieval is independently available; classifier prediction does not invoke it automatically.
An explicit owner-checked scan explanation uses persisted classifier context and
retrieved evidence without rerunning or changing inference. Gemini selects reviewed
evidence IDs; the server renders verified excerpts and citations. No operational threshold is
approved: current predictions report `LOW_CONFIDENCE/THRESHOLD_UNCONFIGURED`.

## Service interface

Define versioned, typed request/response schemas and explicit maximum image size and formats. Protect internal service access, use bounded timeouts, and avoid exposing internal endpoints to the mobile client. A response should distinguish prediction, confidence semantics, model version, retrieval evidence, and explanation status.

## Model lifecycle

Load a named, immutable model artifact with recorded version and class mapping. Keep liveness separate from readiness: a process can be alive while the model or required retrieval dependency is unavailable. Never silently replace a model or overwrite a production artifact.

## Gemini and grounding

Use Gemini only to explain facts supported by retrieved agricultural material or deterministic calculator outputs. Preserve source references or equivalent provenance for displayed guidance. When relevant evidence is insufficient, return that state explicitly rather than asking the model to fill gaps.

## Reliability and observability

Set timeouts and resource limits for image processing, inference, retrieval, and provider calls. Record sanitized errors, model version, latency, and request correlation ID. Do not log image contents, credentials, or unnecessary personal information. Configure concurrency and memory based on the chosen model and hosting environment.
