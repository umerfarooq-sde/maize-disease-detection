# Backend foundation

This document records the Phase 3 baseline. Phase 4 extends it with
[authentication](18-authentication.md), required independent JWT signing keys,
credentialed exact-origin CORS, auth-specific limits and additional tests.
The setup/token contract in that document supersedes the baseline's optional JWT
placeholders and health-only endpoint inventory.

Phase 3 implements the Node.js transport and development foundation. The only
application endpoint is `GET /api/v1/health`. Authentication, disease APIs, provider
integrations, ML, RAG, calculators and Flutter functionality remain future work.
The existing Phase 2 schema, migrations and seed data are preserved.

## Structure and layering

```text
backend/
  prisma/                     existing schema, migrations, typed seed
  prisma.config.ts
  biome.json                  authored source/foundation-test lint and format
  package.json / package-lock.json
  tsconfig.json / tsconfig.database.json
  src/
    server.ts                 executable, signals and fatal process handling
    application.ts            database readiness, HTTP listen and shutdown
    app.ts                    Express factory and middleware composition
    config/                   validated environment and structured logger
    database/                 shared client, isolated-client factory, URL normalization
    errors/                   application error codes and HTTP status mapping
    middleware/               request context/logs, rate limit, errors, not found
    modules/health/           routes, controller, service, repository
    routes/                   /api/v1 router composition
    types/                    response contracts and Express locals
    utils/                    single success-response helper
    validators/               reusable Zod request validation
    generated/prisma/         ignored, regenerated client
    database-check.ts         preserved SQL development probe
    environment-check.ts      preserved dependency probe
  tests/
    foundation/               isolated HTTP, environment and lifecycle tests
    database.integration.test.ts / database-support.ts
    migration-replay.ts
```

Health follows `Route -> Controller -> Service -> Repository -> Prisma -> PostgreSQL`.
Module directories hold their own controller/service/repository rather than empty
top-level layer directories. The controller translates HTTP; the service builds
health state; the repository performs a parameterized `SELECT 1`. Express 5 forwards
rejected async handlers to centralized errors without an additional async wrapper.

The application gets one reusable Prisma client from `getDatabaseClient`. Standalone
seed and database checks retain isolated factory clients. Runtime connection timeout
is 10 seconds, query timeout is 5 seconds, and the pool is limited to two connections.
The existing TLS URL normalization and direct migration URL remain in place.

## Setup and commands

Run from `backend/`, using the locked Node.js 24 toolchain:

```powershell
npm.cmd ci
npm.cmd run db:generate
npm.cmd run check
npm.cmd run dev
# After stopping dev:
npm.cmd run build
npm.cmd start
```

Set `DATABASE_URL` in ignored `backend/.env` or the deployment environment. Existing
environment files are preserved. The server validates settings before connecting or
listening; missing or invalid required settings produce a nonzero exit with safe
field-specific messages. It does not migrate or seed on startup.

| Setting | Required/default and meaning |
|---|---|
| `DATABASE_URL` | Required PostgreSQL URL identifying a host and database; secret |
| `NODE_ENV` | `development` by default; development/test/production only |
| `HOST` | `127.0.0.1`; set `0.0.0.0` explicitly for container/LAN binding |
| `PORT` | `3000`; integer 1-65535 |
| `CORS_ORIGINS` | Blank: deny cross-origin browser requests. Exact comma-separated HTTP(S) origins; no wildcard, path or credentials |
| `LOG_LEVEL` | `info`; supported Pino levels including `silent` |
| `SHUTDOWN_TIMEOUT_MS` | `10000`; integer 1000-60000 |
| `RATE_LIMIT_MAX` | `120` requests per IP per process in a 60-second window |
| `DIRECT_DATABASE_URL` | Existing optional CLI/replay setting; unused by HTTP runtime |

JWT, Cloudinary and AI-service placeholders are unused and are not required at
startup. Environment defaults are operational settings, never credentials.
CORS permits clients without an Origin header, including native mobile clients.
Credentialed browser CORS is disabled. CORS does not provide authentication.

Scripts: `dev` watches with tsx; `start` runs compiled JavaScript; `build`,
`typecheck`, `lint`, `format`, `format:check`, and `test` are independently available.
`check` runs formatting verification, lint, strict types, build, foundation tests and
the dependency probe. Database checks remain separate under `db:*` and
`check:database`; they require a migrated development database.
Biome excludes generated output and preserved Phase 2 seed/test/config source from
formatting/linting. TypeScript checks source, generated client, seed, config and all
tests. Prisma schema formatting remains `db:format`.

## HTTP contracts

Success uses one envelope:

```json
{
  "success": true,
  "data": {
    "status": "ok",
    "service": "maizedoctor-backend",
    "timestamp": "2026-10-05T00:00:00.000Z",
    "uptimeSeconds": 12,
    "checks": { "database": "up" }
  },
  "requestId": "server-generated UUID"
}
```

Health is a readiness probe: HTTP 200 when the database round trip succeeds, or
503 with `status: degraded` and `database: down` when it fails. Both responses have
the same health-data envelope: `success` means the probe returned a report, not that
all dependencies are healthy. Consumers must check HTTP status and `data.status`.
It returns no connection URLs, credentials, hostnames or raw driver errors, and is
marked `Cache-Control: no-store`. Query parameters and JSON bodies are not accepted.

Errors use `{ "success": false, "error": { "code": "NOT_FOUND",
"message": "Resource not found." }, "requestId": "..." }`.
Validation errors optionally include `error.details` containing field paths and
Zod issue codes, without echoed values or arbitrary schema messages.
Codes cover validation (400), authentication (401), authorization (403), not found
(404), conflict (409), payload size (413), encoding (415), rate limits (429), and
internal errors (500). Auth error types establish a contract only; no authentication
middleware or endpoints exist. Unexpected exceptions always return a generic 500.
Unknown routes and unsupported endpoint methods return the same 404 contract.

`validateRequest` parses `{ body, params, query }` using a route-supplied Zod schema.
Coerced/parsed values go into `response.locals.validated`; future controllers can
type them using the schema's inferred type. It does not mutate Express 5's query
getter. Test-only fixture routes verify all three input sources; they are not
registered in the application.

## Middleware and lifecycle

The order is request ID/logging, Helmet, CORS, rate limiting, bounded JSON parsing,
versioned routes, not found, centralized errors. JSON is limited to 100 KiB;
compressed bodies are rejected. Each response exposes an `X-Request-Id` generated
by the server. Logs contain method, registered route pattern, ID, duration and
status; no headers, bodies, query values, client IDs or raw dependency errors.
Helmet headers apply to error responses too. Express's identifying header is off.

Rate limiting uses an in-memory store and the socket IP with proxy trust disabled.
Health requests count toward the limit; CORS preflight is handled first. Multiple
replicas require an explicitly selected shared limiter store and reviewed proxy
trust configuration during deployment. Forwarded client headers are not trusted.

Startup connects and executes the readiness query before opening HTTP. Failure
cleans up the database and exits nonzero. HTTP request/header/keep-alive timeouts
are 15/10/5 seconds. SIGINT, SIGTERM and Windows SIGBREAK stop accepting connections,
drain in-flight HTTP requests, then disconnect Prisma. Repeated shutdown calls
share one promise. Fatal process/server errors use the same shutdown path with a
failure exit code. The shutdown deadline closes remaining sockets and forces a
failure exit if cleanup cannot finish.

Dependencies follow the locked [Express error handling](https://expressjs.com/en/guide/error-handling/),
[Biome](https://biomejs.dev/linter/), and
[rate limiter configuration](https://express-rate-limit.mintlify.app/reference/configuration)
guides. See [project state](PROJECT_STATE.md) for actual verification and remaining issues.
