# Backend

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
No disease APIs or provider/AI/ML/RAG/UI functionality is implemented.
