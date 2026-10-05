# Backend

Phase 2 adds Prisma 7.10.0, its PostgreSQL adapter, all 19 requested models,
versioned SQL migrations, a typed seed structure, and database integration checks.
Node.js 24, strict TypeScript, Express, Zod, dotenv, and `pg` remain locked in
`package-lock.json`. Business routes, controllers, and services are future work.

Follow `Route -> Controller -> Service -> Repository -> Prisma -> PostgreSQL`.
Use `/api/v1` API versioning, validated requests, and centralized errors. Node owns
business rules and orchestration; Python owns ML and RAG processing.

[API design](../docs/06-api-design.md) remains a draft;
[database design](../docs/05-database-design.md) describes the implemented schema.
`.env.example` contains server-only settings. `DATABASE_URL` serves runtime queries;
`DIRECT_DATABASE_URL`, when set, serves Prisma CLI and migration replay.

```powershell
npm.cmd ci
npm.cmd run db:generate
npm.cmd run check
npm.cmd run db:migrate
npm.cmd run db:status
npm.cmd run db:seed
npm.cmd run db:check
npm.cmd run db:check:migrations
npm.cmd run db:diff
npm.cmd run check:database
```

`check` compiles and runs a dependency probe without starting an HTTP server.
`check:database` requires PostgreSQL 16+ and `backend/.env`;
it writes only to a temporary table and rolls back. `pg` is used for this development
probe; future application repositories will use Prisma. Generated client code is
ignored and regenerated with `db:generate`. The pgvector extension is required for
migrations. Seed groups are empty until reviewed project data is supplied.
See [database operations](../docs/16-database-operations.md) for checks and permissions,
and [development setup](../docs/15-development-environment.md) for other toolchains.
