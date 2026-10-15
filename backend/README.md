# Backend

Phase 22 adds ADMIN-only `GET /api/v1/admin/model-health`: safe model registry
projection plus authenticated internal readiness, pinned evaluation and process
telemetry. No model promotion or metric recalculation. See
[model health](../docs/38-model-health-dashboard.md).

Phase 21 adds ADMIN-only knowledge/disease management, source-backed immutable
drafts, explicit FastAPI index/recheck orchestration and audited activation/archive.
Calculator draft projections support typed Admin forms and replacement audit
lineage. Class labels/slugs and numerical algorithms remain fixed. See
[Admin management](../docs/37-admin-management.md).

Phase 20 adds ADMIN-only `GET /api/v1/admin/dashboard`, one SQL statement for
bounded system scan/account aggregates and recent activity. It reuses the Phase 19
UTC/latest-prediction rules, distinguishes registered production models from
configured inference, and does not invent AI telemetry or live readiness. See
[Admin dashboard](../docs/36-admin-dashboard.md) for the response and tests.

Phase 19 adds FARMER-only `GET /api/v1/analytics/scans` and
`GET /api/v1/analytics/scans/activity`: bounded UTC date filters, SQL aggregates,
latest-per-scan predictions and private cursor pagination. No user-ID override,
anonymous reassignment or model-accuracy claim is supported. Configure the
server-only `ANALYTICS_RATE_LIMIT_MAX` (default 30/minute/IP). See
[farmer analytics](../docs/35-farmer-analytics.md) for contracts and rollback checks.

Phase 18 adds the versioned expected-yield framework and controlled ADMIN
configuration publication using existing `YIELD` calculator records. It shares
exact unit arithmetic with Phase 17, preserving fertilizer behavior. Production
yield configuration remains pending; no agronomic model/rate is invented or seeded.
See [expected yield](../docs/34-expected-yield-calculator.md) for public/admin APIs,
contracts, immutable source/version review and rollback integration checks.

Phase 17 adds public fertilizer rule/calculation endpoints and ADMIN-only reviewed
draft/publication endpoints. Exact decimal arithmetic scales a reviewed product
kg/ha rate; Gemini is not involved. Existing rule/config tables and immutable guards
are reused without migrations. The production recommendation catalogue remains
empty/PENDING_RULES until authoritative rates are approved. See
[fertilizer calculator](../docs/33-fertilizer-calculator.md) for request contracts,
version/source controls and `npm.cmd run test:fertilizer:database`.

Phase 15 adds `POST /api/v1/knowledge/ask` and
`POST /api/v1/scans/:scanId/explanation`. The dedicated internal client calls FastAPI;
Node validates cited answer contracts and unchanged persisted classifier context.
Scan explanations reuse farmer ownership or the anonymous original request-key
capability; ADMIN access is not introduced. See [grounded generation](../docs/31-grounded-generation.md)
for request bodies, uncertainty, deadlines, server-only settings and remaining limits.

Phase 14 completes the missing disease-knowledge read foundation and adds
`GET /api/v1/diseases`, `GET /api/v1/diseases/:slug` and
`POST /api/v1/knowledge/search`. The latter orchestrates authenticated FastAPI
retrieval without embedding or generation logic in Node. See
[knowledge/retrieval](../docs/30-knowledge-retrieval.md) for sources, versioning,
configuration and checks. Controlled ingestion belongs to the Python operator CLI.

Phase 13 adds FARMER-only `GET /api/v1/scans` with validated limit/UUID cursor,
owner-scoped stable pagination and the existing safe scan projection. No database
migration or ML orchestration change. See [farmer history](../docs/29-farmer-detection-history.md).
Verify real PostgreSQL pagination with
`npx.cmd tsx --test tests/scans/history.database.integration.ts`.

Phase 12 adds unchanged-byte FastAPI inference, strict model-output validation,
transactional prediction persistence, attempt-fenced recovery and
`GET /api/v1/scans/:scanId`. The sixth migration adds outcome metadata and an
inference-attempt token without additional tables. Upload/Cloudinary behavior is
preserved; saved images and scan records survive failed inference. See
[integration/setup/contracts](../docs/28-node-fastapi-integration.md).

Phase 7 adds `POST /api/v1/scans`: validated multipart images, server-only Cloudinary
storage, anonymous/farmer PENDING scans, idempotent retries and durable compensation.
The fifth migration adds only the required upload journal and upload timestamp.
See [scan uploads](../docs/20-scan-uploads.md) for the contract, limits, tests and
`npm.cmd run scans:cleanup`, which must be scheduled for crash recovery.

Phase 4 adds FARMER registration, FARMER/ADMIN login, Argon2id passwords, JWT access,
database-backed rotating refresh cookies, logout/revocation and reusable RBAC.
Phase 3 provides the Express 5 application, validated startup settings, versioned health,
centralized errors, Zod validation, CORS, Helmet, rate limiting, structured logs,
graceful lifecycle handling and foundation tests. Phase 2's Prisma 7.10.0 database,
all 19 domain models, previous migrations, seed and integration tests remain intact.
The fourth migration adds the required auth session table.
Node.js 24, strict TypeScript and dependencies are locked in `package-lock.json`.

Follow `Route -> Controller -> Service -> Repository -> Prisma -> PostgreSQL`.
Use `/api/v1` API versioning, validated requests, and centralized errors. Node owns
business rules and orchestration; Python owns ML and RAG processing.

[Backend foundation](../docs/17-backend-foundation.md) documents the directory tree,
environment settings, scripts, response contracts and lifecycle. Health remains
`GET /api/v1/health` (200 healthy, 503 database unavailable).
[Authentication](../docs/18-authentication.md) documents all five auth endpoints,
required JWT settings, cookie/custom-header contract and controlled admin command.
[API design](../docs/06-api-design.md) separates implemented health from future routes;
[database design](../docs/05-database-design.md) describes the implemented schema.
`.env.example` contains server-only settings. `DATABASE_URL` serves runtime queries;
`DIRECT_DATABASE_URL`, when set, serves Prisma CLI and migration replay.

```powershell
npm.cmd ci
npm.cmd run db:generate
npm.cmd run db:migrate
# Initialize local JWT keys from the root before starting the server; see auth docs.
npm.cmd run check
npm.cmd run dev
# Or build and run the compiled server:
npm.cmd run build
npm.cmd start
# Stop the server before continuing independent database checks:
npm.cmd run db:migrate
npm.cmd run db:status
npm.cmd run db:seed
npm.cmd run db:check
npm.cmd run test:auth:database
npm.cmd run db:check:migrations
npm.cmd run db:diff
npm.cmd run check:database
```

`check` verifies formatting, lint, types, build, foundation tests and dependencies.
Tests bind temporary loopback ports with injected health repositories; they need no database.
`check:database` requires PostgreSQL 16+ and `backend/.env`;
it writes only to a temporary table and rolls back. `pg` is used for this development
probe; application repositories use the shared Prisma client. Generated client code is
ignored and regenerated with `db:generate`. The pgvector extension is required for
migrations. Seed groups are empty until reviewed project data is supplied.
See [database operations](../docs/16-database-operations.md) for checks and permissions,
and [development setup](../docs/15-development-environment.md) for other toolchains.
Inference orchestration is implemented; Python retains all ML transforms and inference.
Disease knowledge reads, retrieval and grounded generation are implemented through
their documented boundaries. The fertilizer foundation and Flutter assistant are
implemented alongside the yield framework. Approved agronomic calculator content,
conversation retention and full admin editing remain future work.
