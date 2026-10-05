# AI Service Architecture

> **Status:** Target architecture. Model, API, deployment, and dependency choices must be verified during implementation.

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

## Service interface

Define versioned, typed request/response schemas and explicit maximum image size and formats. Protect internal service access, use bounded timeouts, and avoid exposing internal endpoints to the mobile client. A response should distinguish prediction, confidence semantics, model version, retrieval evidence, and explanation status.

## Model lifecycle

Load a named, immutable model artifact with recorded version and class mapping. Keep liveness separate from readiness: a process can be alive while the model or required retrieval dependency is unavailable. Never silently replace a model or overwrite a production artifact.

## Gemini and grounding

Use Gemini only to explain facts supported by retrieved agricultural material or deterministic calculator outputs. Preserve source references or equivalent provenance for displayed guidance. When relevant evidence is insufficient, return that state explicitly rather than asking the model to fill gaps.

## Reliability and observability

Set timeouts and resource limits for image processing, inference, retrieval, and provider calls. Record sanitized errors, model version, latency, and request correlation ID. Do not log image contents, credentials, or unnecessary personal information. Configure concurrency and memory based on the chosen model and hosting environment.
