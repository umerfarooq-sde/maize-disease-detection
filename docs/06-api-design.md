# API Design

> **Status:** Contract guidance, not an implemented endpoint inventory. Finalize schemas and routes before client/server integration.

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

These names are examples to be confirmed; they are not claimed to exist.

## Scan contract considerations

The create-scan request should define accepted image formats, maximum byte size, and whether upload is multipart or uses a separately issued upload reference. The response should define scan ID/status, predicted class, confidence semantics, model version, and grounded guidance/provenance. Include an explicit unavailable/insufficient-evidence representation; do not invent agricultural facts when retrieval is weak.

Define synchronous completion versus asynchronous status polling before implementing the route. Include idempotency behavior if clients may retry a submission after a timeout.

## Error response shape

Adopt a consistent envelope such as:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The submitted image is not supported.",
    "requestId": "..."
  }
}
```

Messages must be safe for clients; detailed diagnostics belong in protected server logs. Specify status codes consistently (for example, 400/422 validation, 401 unauthenticated, 403 unauthorized, 404 not found, 429 rate-limited, and 5xx server/dependency failures).

## Authorization

Enforce RBAC and ownership in the backend. A farmer may read only their own history. An administrator's access should be explicit and audited. Anonymous creation does not grant unauthenticated access to other scan records.

## Contract governance

Maintain an OpenAPI specification alongside implementation, use schema validation at route boundaries, and add contract tests for success and error responses. Version breaking changes rather than silently changing the meaning or shape of an existing response.
