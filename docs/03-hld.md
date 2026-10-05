# High-Level Design (HLD)

> **Status:** Proposed component and runtime design. Validate details against implementation when source code is added.

## Runtime components

### Mobile client

Flutter implements the farmer and administrator experiences. It calls the public, versioned backend API and uses secure storage for tokens. The primary farmer action is disease scanning.

### Backend API

The Node.js/TypeScript API exposes `/api/v1/...` routes. Keep request handling thin and separate responsibilities:

```text
Route -> Controller -> Service -> Repository -> Prisma -> PostgreSQL
                           |              |
                           +-> AI client  +-> Cloudinary client
```

Routes bind endpoints and middleware. Controllers translate HTTP input/output. Services enforce business policy and coordinate dependencies. Repositories encapsulate persistence.

### AI service

FastAPI owns image input validation, decoding, color conversion, applicable segmentation/background removal, crop/resize/normalization, tensor conversion, PyTorch inference, retrieval, Gemini interaction, and model health. Training and inference import the same preprocessing implementation.

### Data and external services

PostgreSQL stores structured application and knowledge data. Prisma maps relational models. Cloudinary stores image objects. Gemini is an external language-model provider used only to explain grounded context, not as the source of agronomic truth.

## Scan request sequence

```text
Flutter       Backend        Cloudinary       AI service       PostgreSQL
   |              |               |                |                |
   |-- image ---->|               |                |                |
   |              |-- validate -->|                |                |
   |              |-- store ----->|                |                |
   |              |<-- asset ref -|                |                |
   |              |-- analyze -------------------->|                |
   |              |<-- prediction / guidance -----|                |
   |              |-- persist scan -------------------------------->|
   |<-- result ---|               |                |                |
```

This sequence is a logical target, not a commitment to synchronous execution. If model latency or reliability requires asynchronous processing, define and document a job/status contract rather than silently changing the API.

## Failure handling

- Reject invalid image types and oversized payloads before costly work.
- Apply bounded timeouts to Cloudinary, AI service, and Gemini interactions.
- Return stable client-safe error responses; never expose stack traces or provider secrets.
- Avoid reporting a successful completed scan if required inference or persistence failed.
- Define idempotency and retry behavior before adding automatic retries to operations that store images or create scans.

## Deployment topology

Deploy the mobile app separately from the backend and AI service. PostgreSQL and Cloudinary are managed dependencies or separately operated services. The AI service should be reachable by the backend without exposing internal credentials in the app. Environment-specific URLs, secrets, and model artifact locations belong in deployment configuration, not source.

## Operational signals

Record request correlation IDs, scan lifecycle outcomes, latency by dependency, model version, and sanitized error categories. Do not log raw images, tokens, or sensitive personal data. Define retention and alert thresholds alongside the deployment environment.
