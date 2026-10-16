# API Design

**Phase24.6 current addendum (2026-10-17):** The generated backend/openapi.json now covers59 runtime operations with actual Zod request schemas and shared checked response contracts. New ADMIN telemetry/catalogue/media/product/model-intake and public reference endpoints are listed in the remediation report. Private image contracts and existing versioning remain.

See [remediation and current evidence](phase-24-6-pre-deployment-remediation.md). Historical phase details follow.

> **Status:** Phase 14 adds active disease catalogue/detail and semantic knowledge search to the existing health/auth/scan/history routes. Read [knowledge contracts](30-knowledge-retrieval.md); other candidate business routes remain design guidance.

## Conventions

- Prefix application routes with `/api/v1`.
- Use JSON for structured request/response data and multipart upload only where required.
- Validate and bound every client-controlled field and uploaded file.
- Use bearer access tokens for authenticated operations; anonymous scan creation is an explicit supported flow.
- Return stable error codes/messages and a correlation ID. Do not expose stack traces or dependency internals.

## Candidate resource surface

| Capability | Candidate route | Access |
|---|---|---|
| Create account / sign in | `POST /api/v1/auth/...` | Public, rate-limited |
| Refresh / revoke session | `POST /api/v1/auth/...` | Refresh-token policy |
| Create disease scan | `POST /api/v1/scans` | Anonymous or authenticated |
| Read scan result | `GET /api/v1/scans/{scanId}` | Own FARMER scan, or anonymous scan with original private request key; ADMIN denied |
| List farmer scan history | `GET /api/v1/scans` | Authenticated farmer, owner-scoped |
| Read service health | `GET /api/v1/health` | Public or restricted details |
| Read sourced diseases | `GET /api/v1/diseases`, `GET /api/v1/diseases/:slug` | Public, active sourced content only |
| Retrieve knowledge evidence | `POST /api/v1/knowledge/search` | Public, bounded/rate-limited; Node invokes internal FastAPI |

Health returns 200 when the database is reachable, 503 with a safe degraded
report otherwise. See [backend foundation](17-backend-foundation.md) for its exact
data shape, validation, security settings and lifecycle. Other candidate names
for disease/business capabilities are examples to confirm in their feature phases.
Implemented authentication: POST `/api/v1/auth/register`, `/login`, `/refresh`,
`/logout`, and GET `/api/v1/auth/me`. See [auth contracts](18-authentication.md)
for validation, safe DTOs, cookie transport, expiry, CSRF protection and RBAC.

## Scan contract considerations

Phase 20 adds ADMIN-only `GET /api/v1/admin/dashboard` for system-wide account/scan
aggregates and ten recent minimal activity entries. FARMER access is denied; paired
bounded UTC dates reuse analytics validation. Registered production/configured
inference versions remain distinct and unrecorded/unchecked telemetry is explicit.
See [Admin dashboard](36-admin-dashboard.md).

Phase 19 adds private FARMER-only `GET /api/v1/analytics/scans` and
`GET /api/v1/analytics/scans/activity`. Both derive ownership from the session,
accept bounded paired UTC dates and omit anonymous scans. Activity supports
bounded UUID cursor pages. Summary describes usage/latest-prediction counts,
not measured model accuracy. See [farmer analytics](35-farmer-analytics.md).

Phase 11 implements private FastAPI `POST /api/v1/predict` and
`GET /api/v1/model-health`, protected by a server service token. These accept raw
encoded image bytes and return the AI service's single `data/meta` envelope. See
[the exact internal contract](27-production-ml-inference.md). They are separate
from Node's public scan/auth routes; Phase 12 calls prediction through a dedicated
configured server client and never exposes the FastAPI endpoint to Flutter.

`POST /api/v1/scans` is now implemented with exactly one multipart image,
JPEG/PNG/WebP validation, 5 MiB/16-megapixel bounds and required idempotency/custom
headers. Phase 12 returns 201 for a newly saved scan or 200 for a same-key retry,
with explicit lifecycle, nullable prediction and safe analysisError. These statuses
describe scan persistence; inference failure is explicitly `FAILED`, never a
successful diagnosis. `GET /api/v1/scans/:scanId` reads the same representation;
anonymous callers need their original private `Idempotency-Key`, farmers need their
own valid access token. See [integration contract](28-node-fastapi-integration.md).
`GET /api/v1/scans` now returns owned FARMER history with a validated UUID cursor,
default limit 20/max50, descending timestamp/ID ordering and `nextCursor`.
Guests/admins cannot list farmer scans; foreign cursors return 404. Flutter now
provides result/history UI with explicit model uncertainty. See
[farmer workflow and history contracts](29-farmer-detection-history.md).
Grounded guidance remains future work.

Future inference responses must define predicted class, confidence semantics, model
version, and grounded guidance/provenance. Include an unavailable/insufficient-evidence
representation; do not invent agricultural facts when retrieval is weak.

Define synchronous completion versus asynchronous status polling before implementing the route. Include idempotency behavior if clients may retry a submission after a timeout.

## Error response shape

The implemented error envelope is:

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed.",
    "details": [{ "path": "query", "code": "unrecognized_keys" }]
  },
  "requestId": "..."
}
```

Messages must be safe for clients; detailed diagnostics belong in protected server logs. Specify status codes consistently (for example, 400/422 validation, 401 unauthenticated, 403 unauthorized, 404 not found, 429 rate-limited, and 5xx server/dependency failures).

Successful responses use `{ "success": true, "data": ..., "requestId": "..." }`.
Validation uses HTTP 400. Details are optional field paths/issue codes without
submitted values. Both envelopes include the server-generated ID also returned
in `X-Request-Id`; no additional response wrapping is used. Health retains its
report envelope at HTTP 503 so monitoring can inspect `data.status` and checks.

## Authorization

Enforce RBAC and ownership in the backend. A farmer may read only their own history. An administrator's access should be explicit and audited. Anonymous creation does not grant unauthenticated access to other scan records.

## Contract governance

Maintain an OpenAPI specification alongside implementation, use schema validation at route boundaries, and add contract tests for success and error responses. Version breaking changes rather than silently changing the meaning or shape of an existing response.

## Phase 22 Admin model health

ADMIN-only `GET /api/v1/admin/model-health` has an empty query contract and the existing
`{success, data, requestId}` envelope. It returns safe registry/deployment identities,
separate probed service readiness, saved offline evaluation and process-local runtime
statistics; no raw artifact/private path, source images or recalculated test metric.
Node alone calls protected internal `GET /api/v1/model-dashboard`. See the
[model-health contract](38-model-health-dashboard.md) for exact scopes and limits.
