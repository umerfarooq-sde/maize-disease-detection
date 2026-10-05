# Database operations

Phase 2 uses stable Prisma **7.10.0**, matching client/pg-adapter versions, and tsx
for TypeScript seed/test commands. `prisma.config.ts` reads server-only
`DIRECT_DATABASE_URL` (falling back to `DATABASE_URL` for unpooled servers).
Runtime construction is in
[client.ts](../backend/src/database/client.ts). Phase 3 health repositories use its
reusable application client; standalone checks/seed retain isolated clients.
See [backend foundation](17-backend-foundation.md). Business routes remain future work.
Phase 4 adds [authentication](18-authentication.md), one session table and a fourth
additive migration. Runtime authentication and health reuse the same Prisma client.
Generated client source is ignored and must be regenerated after install/schema changes.

## Prerequisites and setup

Use a **development database** with PostgreSQL 16 or newer, pgvector available, and
permission to enable the extension/create schema objects. The configured connection
was verified on Neon; local Compose uses `pgvector/pgvector:0.8.7-pg18-bookworm`.
Neon's installed extension may be a different compatible release. Extension upgrades
are deliberate operations, not automatic migration side effects.

Set private connection URLs locally in `backend/.env`; keep passwords URL-encoded
and retain the provider's TLS settings. The pg adapter makes the current strict TLS
behavior explicit for `sslmode=require` aliases. Never copy credentials into templates
or Flutter. Existing `.env` files are preserved by initialization scripts.
Use the provider's **direct/unpooled** URL in `DIRECT_DATABASE_URL` for migrations,
introspection, and replay; keep the pooled URL in `DATABASE_URL` for runtime queries.
The verified Neon direct hostname is the equivalent endpoint without `-pooler`.
Running migration advisory locks through a transaction pooler can time out. Do not
disable advisory locking or terminate unrelated database sessions to work around it.
Prisma CLI configuration supplies `connect_timeout=30` when no timeout is specified
in the URL. This accommodates the observed remote connection latency; an explicit
URL timeout is preserved. Runtime pg adapter timeouts are configured separately.

From `backend/`:

```powershell
npm.cmd ci
npm.cmd run db:validate
npm.cmd run db:generate
npm.cmd run check
npm.cmd run db:migrate
npm.cmd run db:status
npm.cmd run db:seed
```

`db:migrate` uses **migrate deploy** to apply only committed pending migrations.
Running it again has no pending work. It never resets the database, starts a server,
generates features, or invokes the seed automatically. The initial migration is intended
for an empty application schema. Existing unrelated tables require a reviewed baseline,
not a reset. Each committed migration wraps its DDL in BEGIN/COMMIT.

The seed has four typed, initially empty groups: diseases, fertilizers, calculator
configs, and knowledge documents. Add only reviewed project records with source
references and correct hashes/versions. Upserts use stable unique keys and `update: {}`
so a repeat does not overwrite prior content or active settings. Publish a new version
when changing immutable data. Nested writes can provide disease sources/images.
There is no default user/password or automatic model download.

## Checks

```powershell
npm.cmd run db:check
npm.cmd run test:auth:database
npm.cmd run db:check:migrations
npm.cmd run db:diff
npm.cmd run check:database
```

| Command | What it verifies |
|---|---|
| `db:check` | Schema validation, generation, strict source/config/seed/test compilation, 20-table database catalog, all 19 domain model round trips, relationships, ownership, invalid records, versions, vector round trip, timestamps and deletion policies |
| `db:check:migrations` | All committed SQL migrations replay into a uniquely named temporary schema; verifies tables/checks/triggers, then removes only that schema |
| `db:diff` | Actual configured schema versus Prisma structural model; exit 0 means no difference, 2 means drift |
| `db:status` | Applied migration history versus migration directory |
| `check:database` | Authenticated PostgreSQL connection and temporary-table SQL round trip with rollback |
| `test:auth:database` | Real auth/HTTP, hashed session storage, concurrent rotation/replay revocation and SQL session guards; removes only its newly created fixture user/sessions |

Integration writes run in a transaction that intentionally rolls back; invalid cases
use savepoints. No cloud images, model weights, agricultural data, or provider calls
are needed. The tests verify that the synthetic user is absent afterward. They never
reset the database or overwrite an existing production model selection. Keep these
checks on development databases because transaction locks can briefly block concurrent writers.

Domain regression clients explicitly allow 30 seconds per query to accommodate
observed remote latency; HTTP/runtime keeps the 5-second bound. Auth integration
uses the runtime bound. Authentication fixtures use targeted cleanup as described
above rather than a long outer transaction, so independent connections can test races.

Replay requires CREATE/DROP SCHEMA privileges. It preserves application tables and
other schemas. If the process is forcibly killed, a schema named
`phase2_verify_<32 hexadecimal characters>` may remain; inspect ownership and contents
before removing that specific abandoned test schema. The shared vector extension
belongs in `public`, and is retained when the temporary schema is removed.

Custom CHECK constraints, trigger functions, and partial unique indexes live in SQL
migrations. Preserve them when making later migrations; Prisma diff alone is insufficient.
Never edit a successfully applied migration. Add a new migration for a correction.
`migrate dev` requires an explicitly configured disposable shadow database; this setup
does not assume permission to create/drop a managed cloud database. Avoid `db push`
as the source of schema history.

The pg 8.23 driver can emit a query-queue deprecation warning when Prisma issues
related internal queries. It does not fail the verified transactions. Keep pg below
9 until the adapter's future query scheduling compatibility is verified; do not
suppress warnings or modify installed dependency source.

## Local runtime limitations

Docker configuration is validated, but Docker Engine/Desktop is absent on this
workstation, so the updated pgvector container has not been started here. The native
Windows PostgreSQL 18 cluster remains available for the Phase 1 SQL probe and needs
pgvector binaries installed before Phase 2 migration execution. Use the configured
Neon development database or the pgvector Compose container for the complete schema.
Starting/stopping the native cluster does not change `backend/.env` to a different database.

Migration roles need DDL privileges; future application/AI roles should receive only
the tables/operations they need. Resource ownership in future APIs, connection
deployment policies, backup/retention automation, and production secrets are later work.

References: [Prisma connection configuration](https://docs.prisma.io/docs/orm/prisma-client/setup-and-configuration/databases-connections),
[PostgreSQL CLI connection arguments](https://docs.prisma.io/docs/orm/v7/core-concepts/supported-databases/postgresql),
[Neon pooled and direct connection guidance](https://github.com/neondatabase/website/blob/main/content/docs/guides/prisma.md).
