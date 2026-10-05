# Low-Level Design (LLD)

> **Status:** Feature implementation guidance. Phase 3 now implements the backend transport foundation; see [actual layout and lifecycle](17-backend-foundation.md). Workflows below remain future work.

## Backend layering

```text
src/
  routes/        HTTP route registration and middleware
  controllers/   HTTP request/response translation
  services/      business workflows and policy
  repositories/  persistence operations via Prisma
  clients/       AI service and Cloudinary integrations
  middleware/    auth, validation, rate limits, error handling
  types/         shared backend types and API contracts
```

This is a suggested organization, not a required directory layout. Preserve existing repository conventions when code is introduced.

### Scan workflow

The scan service should coordinate, in order:

1. Validate the caller's role and optional farmer identity.
2. Enforce file constraints and accepted image formats.
3. Store the original image through a backend-only Cloudinary client.
4. Call the AI service with a bounded timeout and traceable request identifier.
5. Validate the AI response against a typed contract.
6. Persist the scan, model version, prediction, and image reference.
7. Return a client-safe response.

Define compensation/orphan cleanup behavior for failures between image storage and scan persistence. Do not return raw internal URLs or credentials unless the product contract explicitly requires a safe, time-limited URL.

### Authentication and authorization

Use JWT access tokens and refresh tokens with secure client storage. Apply role checks at the service/API boundary, not only in the Flutter UI. Farmer-owned scan reads must be scoped to the authenticated farmer. Anonymous scan creation is permitted; anonymous access to another scan must not be implied.

### Error handling

Use typed application errors and a centralized HTTP error handler. Map validation, authentication, authorization, not-found, dependency, and unexpected errors to stable response shapes. Log internal diagnostics with correlation IDs, but return no stack traces or secrets.

## Flutter layering

```text
View -> ChangeNotifier ViewModel -> Repository -> API client -> Backend
```

Views render state and forward user actions. ViewModels own presentation state and invoke repositories. Repositories provide typed domain data and isolate transport details. Keep API calls and business decisions out of widgets.

## AI service modules

Separate the FastAPI transport layer from image validation, shared preprocessing, inference/model loading, retrieval, and explanation generation. Load a pinned model artifact and expose health/readiness information that distinguishes service availability from model readiness.

## Contracts and validation

Define explicit request/response schemas at every network boundary. Validate backend inputs and AI service inputs independently; internal calls are still untrusted boundaries. Pin and record model/preprocessing versions so each stored prediction is reproducible enough to investigate.

## Persistence consistency

Persist a scan only with a defined lifecycle and status. If analysis is synchronous, represent only states the workflow actually uses. If it becomes asynchronous, add explicit pending/failed/completed states and transitions with tests. Avoid storing derived values that can be calculated consistently unless auditability requires a snapshot.
