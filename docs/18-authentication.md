# Authentication and authorization

Phase 4 implements FARMER and ADMIN backend authentication through
routes -> controllers -> service -> repository -> Prisma. No Flutter auth screens,
disease/provider APIs or AI/ML/RAG implementation belongs to this phase.

## Setup and configuration

After initializing backend/.env with the existing development setup, run from root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/initialize-auth-env.ps1
Set-Location backend
npm.cmd ci
npm.cmd run db:generate
npm.cmd run db:migrate
npm.cmd run check
npm.cmd run dev
```

The initializer creates independent 64-byte random base64url keys only for missing
or blank values, preserves existing values and prints no secrets. The general dev
initializer invokes it too. Deployment keys belong in secret management/environment,
never Git, Flutter, logs or JSON responses.

| Variable | Contract |
|---|---|
| JWT_SECRET | Required access key: canonical base64url, at least 32 decoded bytes |
| JWT_REFRESH_SECRET | Required refresh key, same format, distinct from access key |
| JWT_ISSUER | maizedoctor by default; nonempty, max 160 characters |
| JWT_ACCESS_TTL_SECONDS | 900 default; integer 60-900 |
| JWT_REFRESH_TTL_SECONDS | 604800 (7 days) default; integer 3600-2592000 |
| AUTH_RATE_LIMIT_MAX | 10 default; combined login/register requests per IP in 15 minutes |

Provider settings remain unused. Changing a signing key invalidates its tokens;
there is no hidden fallback key or default user.

## Endpoints

| Endpoint | Input/access | Success |
|---|---|---|
| POST /api/v1/auth/register | email/password; public FARMER only | 201 with safe user; no automatic login |
| POST /api/v1/auth/login | email/password | 200 access grant plus refresh cookie |
| POST /api/v1/auth/refresh | JSON {} plus refresh cookie | 200 new grant plus rotated cookie |
| POST /api/v1/auth/logout | JSON {} plus valid refresh cookie | 200 loggedOut, session revoked, cookie cleared |
| GET /api/v1/auth/me | Bearer access token | 200 current safe user |

All POSTs require Content-Type: application/json and X-Auth-Request: 1. Zod rejects
unknown fields, params/query, role injection and body refresh tokens. Email is trimmed,
lowercased and bounded to 254 characters; dots/plus tags are preserved. Registration
passwords contain 15-128 Unicode code points, without trimming or composition rules.
Login accepts existing passwords up to 128 code points. Existing JSON byte limits apply.

The foundation response envelope stays unchanged. User DTOs expose only email,
role and ISO creation time. Login/refresh data contains accessToken, tokenType: Bearer,
expiresIn and user. Refresh credentials travel only in Set-Cookie/Cookie, never JSON.
Password hashes, account/session database IDs, digests, account status and signing
keys are not JSON fields. All auth responses use Cache-Control: no-store.

Statuses: validation 400; duplicate account 409/ACCOUNT_EXISTS; bad credentials
401/INVALID_CREDENTIALS; missing/invalid/expired/revoked token 401; role/CSRF denial
403; unsupported type/encoding 415; rate limit 429; unexpected failures generic 500.
Unknown email, wrong password and inactive accounts share one login error. Missing
accounts still incur hashing work. Duplicate registration deliberately reports email
existence, as requested, and is rate limited. Repeated valid logout is idempotent;
missing/invalid/expired refresh cookies return 401 and are cleared.

## Password and session flow

Argon2id uses 64 MiB, three iterations, one lane and a library-generated random salt.
Only encoded hashes are persisted. This exceeds the current
[OWASP minimum](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html).
The pinned native library works on this Windows toolchain; deployment must verify
binary/build compatibility and benchmark hashing capacity.

JWTs explicitly allow HS256 and validate issuer, separate audiences, JWT header
type, purpose, opaque session subject, random 256-bit jti, issued-at and expiry.
They contain no user UUID, email or role. The subject is an opaque token/session
handle, not a public account ID. Future issued-at and missing claims are rejected.

1. Login verifies an active account, creates an independent session and stores SHA-256
   of the issued refresh JWT. Plain refresh tokens are never stored in PostgreSQL.
2. Access authentication verifies the JWT and loads the session/current user. Revoked,
   expired or inactive identities fail closed. Access expiry cannot exceed session expiry.
3. Refresh atomically consumes the current digest with a conditional UPDATE in a
   transaction. PostgreSQL row locking prevents two requests consuming the same token.
   A new digest replaces the old one; absolute session expiry never extends.
4. Valid old-token reuse revokes the entire session, including its newest refresh/access
   tokens. The repository commits revocation before the service raises rejection.
5. Logout revokes that session immediately; other logins remain active. Subsequent
   access requests check revocation in PostgreSQL.

Clients must serialize refresh calls. Concurrent/retried reuse deliberately revokes
the session and requires login again; there is no grace window. Detected stolen-token
reuse ends both branches; without detected reuse, absolute expiry bounds credential
life. See the rotation/replay principle in
[RFC 9700](https://www.rfc-editor.org/rfc/rfc9700.html#section-4.14.2).

## Cookies, CSRF and persistence

Production sets host-only __Host-maizedoctor_refresh with Secure, HttpOnly,
SameSite=Strict, Path=/ and no Domain. Local dev/test uses maizedoctor_refresh
without Secure for HTTP; production requires HTTPS. Browser clients use credentialed
requests and explicit CORS origins. Strict cookies require same-site browser hosting,
not arbitrary cross-site frontends. Native clients use a cookie jar and send the
custom header; future persistent native credentials must use platform secure storage.

Exact Origin checks, non-simple X-Auth-Request, JSON-only POSTs and SameSite protect
against CSRF including login CSRF. Hostile preflights/simple form requests are denied.
Originless native clients remain supported. Credentialed CORS has no wildcard.
Refresh/logout share 30 requests per IP/minute in addition to the global limit.
Limits are in-memory/per-process; production replicas require shared counters and
reviewed proxy trust. Logs omit request headers/bodies/URL values and raw errors;
defensive redaction covers tokens, hashes, keys and Set-Cookie too.

The additive fourth migration creates auth_sessions: UUID ID, user FK/cascade,
unique current digest, immutable absolute expiry, irreversible revoked_at and
timestamps. Indexes cover user/revocation and expiry. SQL checks enforce hash/time
shape; triggers protect identity/owner/lifetime/revocation and update timestamps.
All three previous migrations are preserved. Totals: 20 application tables,
20 CHECK constraints and 35 custom triggers. Inert expired/revoked rows remain
until a reviewed retention/cleanup policy is implemented.

## RBAC and admin provisioning

Reusable authenticate(service) sets an internal principal; authorize(...roles)
returns 401 without authentication and 403 for disallowed roles. /auth/me accepts
FARMER and ADMIN. Roles/status come from the current database, avoiding stale JWT
privileges. Future resource routes still need ownership checks. Farmer/admin-only
fixture routes exist solely in tests, not in the application.

Public registration cannot select ADMIN. Provision a new admin as a trusted operator
with database access:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/create-admin.ps1
```

The helper uses a masked SecureString prompt, UTF-8 JSON over stdin and the same
password/input policy in npm.cmd run admin:create. Passwords are never command
arguments, history entries, printed output or seed data. Existing accounts are not
promoted or overwritten. No admin is created automatically by this phase.

## Verification and remaining boundaries

check runs lint/types/build plus isolated foundation/auth HTTP and service tests.
test:auth:database verifies real Prisma/HTTP, digest persistence, rotation races,
committed revocation and SQL guards. Its newly created synthetic UUID+email is
removed in finally with cascading sessions; no pre-existing record is targeted.
Constraint probes roll back. db:check retains the 13 domain regression tests;
db:check:migrations replays all four migrations in a temporary schema then removes it.

Email verification, recovery/password changes, MFA, session UI, administrative
security-event auditing, retention cleanup and deployment abuse monitoring are
future work. Future password/status management must revoke affected sessions as
part of that workflow. Existing dependency audit reports are retained in
[project state](PROJECT_STATE.md); no forced ORM downgrade is applied.
