# API Design

> **Status:** Phase 3 implements only `GET /api/v1/health` and the response conventions below. The candidate business routes remain design guidance.

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
| Read scan result | `GET /api/v1/scans/{scanId}` | Owner/admin policy; no implicit anonymous read |
| List farmer scan history | `GET /api/v1/scans` | Authenticated farmer, owner-scoped |
| Read service health | `GET /api/v1/health` | Public or restricted details |

Only health exists: 200 when the database is reachable, 503 with a safe degraded
report otherwise. See [backend foundation](17-backend-foundation.md) for its exact
data shape, validation, security settings and lifecycle. Other candidate names
are examples to confirm in their feature phases.

## Scan contract considerations

The create-scan request should define accepted image formats, maximum byte size, and whether upload is multipart or uses a separately issued upload reference. The response should define scan ID/status, predicted class, confidence semantics, model version, and grounded guidance/provenance. Include an explicit unavailable/insufficient-evidence representation; do not invent agricultural facts when retrieval is weak.

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
