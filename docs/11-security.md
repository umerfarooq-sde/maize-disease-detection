# Security

> **Status:** Security requirements baseline; implementation controls must be verified before release.

Phase 4 implements password hashing, independent JWT keys, bounded token lifetimes,
rotating/revocable database sessions, role middleware, auth limits and cookie/CSRF
controls. See [implementation and remaining boundaries](18-authentication.md).
Phase 7 implements upload validation, authenticated Cloudinary assets and recovery;
Phase 8 implements safe internal-service configuration/logging/errors, and Phase 9
implements bounded shared decoding/preprocessing. Remaining inference, deployment
and release controls below are future requirements.

## Identity and access

- Use JWT access tokens and refresh tokens with defined expiry, rotation, revocation, and secure storage.
- Apply RBAC for `FARMER` and `ADMIN` on the server.
- Enforce farmer ownership for scan reads; UI visibility is not authorization.
- Keep anonymous scan creation separate from anonymous access to scan records.

## Upload and API protection

- Enforce allowlisted image MIME types and verify actual decoded file content.
- Set request, image dimension, and byte-size limits.
- Rate-limit authentication and scan operations; add abuse monitoring.
- Validate and normalize all request fields and use safe ORM/query patterns.
- Use TLS for network traffic and bounded timeouts for internal/external dependencies.

## Secrets and data

- Store JWT, database, Cloudinary, AI-service, and Gemini credentials in environment/secret-manager configuration.
- Never place secrets in Flutter, logs, committed files, or API responses.
- Apply least-privilege database and provider credentials; rotate them.
- Define retention/deletion rules for scan images, results, and logs.
- Avoid logging raw images, authorization headers, refresh tokens, or unnecessary personal data.

## Application behavior

- Use centralized error handling and client-safe messages; never return stack traces.
- Verify authorization on every protected operation and audit administrative actions.
- Restrict AI service access to the backend and validate its responses.
- Escape or safely render retrieved text; treat uploaded content and retrieved documents as untrusted input.
- Keep model and knowledge outputs separate from trusted business decisions and deterministic calculations.

## Release controls

Before production, run dependency and static analysis checks, secret scanning, authorization tests, upload validation tests, and API abuse checks. Document incident response, backup/restore, vulnerability reporting, and credential rotation procedures. Establish a privacy review for external AI-provider data handling.
