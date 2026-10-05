# High-Level Architecture (HLA)

> **Status:** Target architecture derived from the project architecture baseline; not an as-built inventory.

## Architectural style

MAIZEDOCTOR is organized as a mobile client, a business API, an AI service, and supporting data/infrastructure services. The client communicates with the Node.js API; it does not access databases, Cloudinary credentials, Gemini, or the AI service directly.

## Logical components

| Component | Responsibility |
|---|---|
| Flutter application | Farmer/admin user experience, local form state, secure token storage, API calls through repositories |
| Node.js + TypeScript backend | API versioning, authentication, authorization, validation, scan orchestration, persistence, and centralized errors |
| PostgreSQL + Prisma | Durable relational data and controlled schema access |
| Cloudinary | Image object storage; secrets remain server-side |
| Python + FastAPI AI service | Image validation and preprocessing, model inference, RAG retrieval, Gemini interaction, AI health |
| PyTorch model | Disease classification; versioned artifacts are loaded by the AI service |
| Agricultural knowledge base | Curated, attributable information used to ground explanations |

## Dependency direction

```text
Flutter -> Backend API -> Service -> Repository -> Prisma -> PostgreSQL
                         |
                         +-> Cloudinary
                         |
                         +-> AI service -> shared preprocessing -> model
                                           |
                                           +-> retrieval -> Gemini (grounded explanation)
```

The backend is the mobile application's sole application-facing API. The AI service is an internal dependency called by the backend. The AI service must not own farmer account or scan workflow policy.

## Trust boundaries

1. **Device to backend:** untrusted client input; authenticate where applicable, validate all fields and uploaded files, and rate-limit.
2. **Backend to AI service:** service-to-service boundary; protect internal credentials and apply timeouts and bounded payload sizes.
3. **Backend to storage/database:** server-side credentials only; apply least privilege.
4. **AI service to external model provider:** protect Gemini credentials, minimize submitted data, and handle provider failures explicitly.

## Quality attributes

- **Safety of guidance:** retrieval-grounded, source-aware recommendations; clearly communicate when evidence is insufficient.
- **Reliability:** bounded timeouts, explicit errors, and durable scan state transitions.
- **Security:** JWT access/refresh flows, RBAC, upload validation, rate limiting, secret isolation.
- **Maintainability:** service boundaries, typed contracts, shared preprocessing, versioned model artifacts.
- **Usability:** accessible layouts and clear loading, empty, success, and failure states.

## Open decisions

Confirm supported disease classes and languages, scan retention policy, model confidence behavior, AI-service authentication, and deployment topology before implementation. Do not treat the diagram as evidence these concerns are already implemented.
