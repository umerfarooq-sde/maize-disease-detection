# Project state

Updated: 2026-10-06 (Asia/Karachi).

## Current phase

Phase 5 Flutter application foundation is complete: MVVM/Provider structure,
centralized light theme/design tokens, responsive farmer shell, preserved tab routing,
safe API infrastructure and reusable loading/empty/error UI. Home, Scan, Knowledge,
Tools and Profile are available; feature destinations show their current availability.
All 37 isolated mobile tests pass; one optional live test is skipped by default and
passes separately against the actual Node/Prisma/PostgreSQL health endpoint. Formatting,
Flutter analysis and repository checks pass. See [Flutter foundation](19-flutter-foundation.md).
The verified Phase 4 auth backend and Phase 2 database/migrations are preserved.
Stop after Phase 5. Mobile auth workflows, camera/disease detection, calculations,
complete admin UI and AI/ML/RAG remain outside scope.

## Initial workspace findings

- Git was already initialized at `E:\MAIZEDOCTOR`, on `main`, one commit ahead of
  the local `origin/main` reference. No network fetch was performed.
- All seven root directories required by `AGENTS.md` existed; component directories were empty.
- `README.md` was a placeholder and `.gitignore` covered basic environment, Python,
  Node, and editor files.
- Thirteen architecture drafts already existed under `docs/` as untracked files.
- `docs/PROJECT_STATE.md` existed but was empty.
- `AGENTS.md` had pre-existing local changes. Its contents and the architecture drafts
  were preserved. No commits, pushes, or dependency installations were performed.

## Phase 0 changes

- Replaced the root README placeholder with project scope, architecture, directory
  links, configuration guidance, checks, and the next phase boundary.
- Added a documentation index and the phased development roadmap.
- Added component README files so all planned directories persist in Git.
- Added environment examples for backend, AI service, infrastructure, and public
  mobile configuration. Credential placeholders are blank; no environment loader exists.
- Expanded centralized ignore rules for secrets, generated Flutter/Python/Node
  output, local datasets/model binaries, uploads, and infrastructure data.
- Added a read-only PowerShell check for structure, templates, Git root, and ignore rules.

## Current implementation inventory

| Component | Verified implementation |
|---|---|
| Mobile | Flutter 3.41.9/Dart 3.11.5 Android foundation, Material 3 light tokens/theme, five-area responsive farmer shell, go_router 17.5.0, scoped Provider/ChangeNotifier MVVM, http 1.6.0 API client, state UI, 37 isolated tests and one separately verified live health integration |
| Backend | Express 5 versioned health/auth, strict TypeScript/Zod, safe responses/errors, Argon2id, separate-key JWTs, rotating/revocable sessions, live-account RBAC, operator admin CLI, security/logging middleware, graceful lifecycle, shared Prisma 7.10.0; 20 tables/four migrations and 55 passing tests across three suites |
| AI service | Python 3.11 manifest/lock, isolated virtual environment, and dependency/ASGI smoke tests; no production service |
| ML training | Python 3.11 manifest/lock, isolated virtual environment, and synthetic dependency tests; no dataset or model |
| Infrastructure | Neon PostgreSQL 18.6 with pgvector 0.8.6 migrated; pgvector 0.8.7/PostgreSQL 18 Compose configuration; preserved native 18.4 cluster; private local settings ignored |
| Documentation | Architecture drafts, database design/ERD/operations, backend foundation/auth contracts, implemented Flutter foundation/design/routes/setup, decisions, roadmap, development guide, and verification history |
| Scripts | Repository checks, environment/random JWT-key initialization, secure admin provisioning, native PostgreSQL management, locked Python setup, and independent development/Prisma checks |

Mobile authentication workflows, disease detection, ML pipeline, RAG, calculator
execution, notification delivery and the admin dashboard remain future work. Flutter
feature introduction/empty screens are foundation UI; the FastAPI test route remains
a scaffold fixture.

## Phase 0 verification history

| Check | Result |
|---|---|
| PowerShell repository check | Passed: required nonempty files, seven directories, template keys, blank credentials, correct Git root, and ignore behavior |
| Directory comparison with `AGENTS.md` | Passed: all seven required root directories match |
| Local Markdown links | Passed: 48 links resolve |
| Component file inventory | Passed: README files and environment examples only; no feature source |
| `git diff --check` | Passed; Git emitted line-ending conversion notices |
| Final file/status inspection | Phase 0 changes present; original `AGENTS.md` changes and architecture drafts preserved |

Application tests are not applicable because no application source exists. No external
services, dependencies, data, or models were required or verified.

Commands/checks performed:

- `Get-Content AGENTS.md` before workspace inspection; read existing README, ignore
  rules, state file, and all architecture drafts before changes.
- `Get-ChildItem -Force`, `rg --files --hidden -g '!.git'`, and component file inspection.
- `git --version` (2.52.0.windows.1), `git rev-parse --show-toplevel`,
  `git status --short --branch`, `git log -1`, and `git diff --stat`.
- `./scripts/check-repository.ps1` initially blocked by Windows execution policy;
  `powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/check-repository.ps1`
  passed after correcting Windows CRLF handling in the Git probe invocation.
- `git check-ignore --no-index` checks for secrets/build outputs and source/template visibility.
- PowerShell validation of local Markdown links and directory names against `AGENTS.md`.
- `git diff --check`; final nonempty-file, whitespace, and file inventory checks.

## Files created during Phase 0

- `mobile/README.md`, `mobile/.env.example`
- `backend/README.md`, `backend/.env.example`
- `ai-service/README.md`, `ai-service/.env.example`
- `ml-training/README.md`
- `infrastructure/README.md`, `infrastructure/.env.example`
- `scripts/README.md`, `scripts/check-repository.ps1`
- `docs/README.md`, `docs/14-roadmap.md`

Updated existing files: `README.md`, `.gitignore`, and `docs/PROJECT_STATE.md`.
No root directory or Git initialization was necessary because they already existed.

## Phase 0 open issues and decisions (historical)

- No blocking Phase 0 issues remain. Windows disables direct script execution;
  the documented process-only override runs checks without changing persistent policy.
- Git has `core.autocrlf=true` and reports LF-to-CRLF conversion notices; whitespace
  checks pass. Existing Git configuration was preserved.
- Toolchain/dependency versions, PostgreSQL setup, and pgvector support are not selected.
- Database ERD and Prisma schema are still pending; existing designs are drafts.
- Shared preprocessing package location/version contract must be settled before ML code.
- Actual dataset, disease classes, curated agricultural sources, calculator rules,
  credentials, and model artifacts have not been supplied.
- Hosting, scan retention, confidence handling, detailed API contracts, and the
  Flutter screen map/design system remain future work.

These are later-phase inputs and decisions, not implemented behavior.

## Phase 1 changes and toolchains

- Node.js 24.12.0 / npm 11.6.2; TypeScript 7.0.2 with strict NodeNext compilation.
  Express 5.2.1, Zod 4.6.5, dotenv 18.0.5, and pg 8.23.1 are locked.
- Flutter 3.41.9 / Dart 3.11.5 Android scaffold; Provider 6.1.5+1 and dependency lock.
- Python 3.11.0 with uv 0.12.23; separate AI and training `.venv` environments and
  lockfiles. Windows CPU torch 2.10.0+cpu and torchvision 0.25.0+cpu match across both.
- Locked AI dependencies include FastAPI 0.142.2 and Uvicorn 0.54.0; shared image
  dependencies include NumPy 2.4.6 and OpenCV 4.13.0.92 (standard package on Windows,
  matching headless package on Linux). Training includes scikit-learn 1.8.0 and
  SciPy 1.17.1. Both use pytest 9.1.1.
- PostgreSQL 18.4 native development cluster at `infrastructure/data/postgres`,
  listening on localhost port 5433. The existing system service on 5432 was preserved.
- PostgreSQL-only Compose image `postgres:18.4-bookworm`, named persistent volume,
  localhost binding, and healthcheck. Official portable Compose 5.6.0 downloaded
  to ignored `.cache/tools` and SHA256 checked against the release checksum.
- Generated ignored local `.env` files with random database credentials without
  printing credentials. Provider/JWT secrets remain blank and unused.
- Interrupted scientific-library downloads were resolved by pinning stable versions
  and reusing existing wheel archives only after comparing their SHA256 to the registry
  hashes in the committed locks. Wheels were installed into separate project virtual
  environments; global site-packages remain disabled.
- Installed the missing official Android command-line tools into the existing SDK
  after SHA256 verification. Existing SDK packages/licenses were preserved; no
  outstanding license agreement was accepted automatically.
- Development guide, component README updates, script commands, and roadmap scope
  clarification added. No commits, pushes, model downloads, or dataset operations.

## Phase 1 files created

- Backend: `package.json`, `package-lock.json`, `tsconfig.json`, `.node-version`,
  `src/environment-check.ts`, `src/database-check.ts`.
- Python components: each has `pyproject.toml`, `uv.lock`, `.python-version`,
  and `tests/test_environment.py`.
- Mobile: `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `.flutter-version`,
  `.metadata`, `.gitignore`, `lib/main.dart`, `test/environment_test.dart`, and generated
  Android Gradle/Kotlin/manifest/resource configuration including `android/.gitignore`.
- Infrastructure: `compose.yaml`.
- Scripts: `initialize-dev-env.ps1`, `postgres-local.ps1`, `setup-python.ps1`,
  `check-development.ps1`, `requirements-tools.txt`.
- Documentation: `docs/15-development-environment.md`.
- Ignored local artifacts: `.cache/`, component Python virtual environments,
  `backend/node_modules`, compiled output, Flutter-generated caches, local `.env`
  files, and PostgreSQL data/logs. These are not source files to commit.

Updated root/component README files, `.gitignore`, `infrastructure/.env.example`,
`backend/.env.example`, `scripts/check-repository.ps1`, documentation index/roadmap,
and this state file. The system overview status now links to current project state;
architecture content and existing `AGENTS.md` edits were preserved.

## Phase 1 verification

- Passed: strict TypeScript typecheck, emitted compilation, and compiled dependency probe.
- Passed: Flutter analyzer (no issues) and one scaffold widget test.
- Passed: authenticated PostgreSQL 18.4 connection and temporary-table SQL round trip;
  all probe writes rolled back.
- Passed: actual Compose schema/interpolation validation with official Compose 5.6.0;
  blank required credentials are rejected.
- Passed: all PowerShell scripts parse; both uv locks match their manifests; rerunning
  local environment initialization preserves existing files; repository structure,
  ignore rules, 58 local Markdown links, and source/configuration whitespace checks.
- Passed: three AI environment tests and four ML environment tests; imports, ASGI
  request handling, image codecs, CPU tensor/autograd, compiled torchvision operators,
  and scikit-learn metrics verified without project data or model weights.
- Passed: `uv pip check` in both environments and lockfile consistency checks.
- The AI smoke test uses HTTPX ASGI transport, avoiding the new Starlette test-client
  deprecation warning without adding another HTTP client dependency.
- `flutter doctor -v`: SDK and Android command-line tools are available after repair;
  some Android SDK licenses remain unaccepted. Android packaging is not verified.

Commands include `npm.cmd install`, `npm.cmd run check`, `npm.cmd run check:database`,
`flutter create --empty --platforms=android --no-pub`, `flutter pub get`, `flutter analyze`,
`flutter test`, `flutter doctor -v`, uv lock/sync, the development scripts, official
Compose download/SHA256 comparison, cached-wheel hash validation/offline installation,
Python module compilation/pytest/import checks, `uv pip check`, `git diff --check`,
PowerShell syntax and environment-idempotence checks, and repository inspection.
Dependency downloads, Flutter SDK cache writes, and native database startup required
approved execution outside the sandbox, as did installing the missing Android SDK tools.
Persistent OS policy and existing services were not changed.

## Phase 2 changes

- Read `AGENTS.md`, this state file, the database architecture draft, and relevant LLD,
  API, ML, and RAG documentation before implementation; inspected existing workspace and dependencies.
- Installed and locked stable Prisma/client/PostgreSQL adapter 7.10.0 and tsx 4.23.15.
  Prisma 8 was a release candidate, so no major-version prerelease was adopted.
- Implemented all **19** requested application tables: users, farmer_profiles, diseases,
  disease_images, disease_sources, scans, scan_predictions, knowledge_documents,
  knowledge_chunks, fertilizers, fertilizer_rules, calculator_configs, model_versions,
  model_metrics, ai_queries, ai_responses, audit_logs, notifications, and history.
  `_prisma_migrations` is Prisma's additional internal bookkeeping table.
- Added UUID defaults, snake-case SQL mappings, timezone-aware timestamps, lifecycle
  enums, FK/delete policies, ownership composite keys, uniqueness, and lookup indexes.
  Anonymous scans keep nullable immutable ownership; authenticated scan/history ownership
  requires a farmer and cross-farmer/anonymous history links are rejected.
- Added 19 SQL CHECK constraints, four partial unique indexes, and 33 custom triggers
  for values, source/content hashes, vector dimensions, model class mapping, ownership,
  immutable records/versions, and database-side timestamp updates.
- Enabled pgvector in `public`; nullable chunk embeddings retain model/dimension/status
  metadata. Production embedding dimensions, distance/index choice, and retrieval remain pending.
- Created atomic initial and corrective migrations. Integration tests caught null trigger
  arguments bypassing immutable-event checks; a second migration fixed the function without
  modifying the checksum of the applied initial migration.
- Kept all seed groups empty until reviewed records are supplied. Idempotent upserts
  preserve existing and versioned data; no default credentials or invented agricultural facts.
- Preserved the user's existing pooled Neon `DATABASE_URL`. Added an equivalent ignored
  `DIRECT_DATABASE_URL` for migration/introspection/replay sessions and a blank template key.
  Migrations target the configured Neon development database, not the Phase 1 native cluster.
- Changed PostgreSQL-only Compose to the pgvector maintainer's `0.8.7-pg18-bookworm`
  image because the initial schema now requires the vector extension. No app containers added.
- Updated schema documentation/ERD, operations guide, root/component documentation,
  environment checks, source ignore rules, and the roadmap's explicit Phase 2 scope.
  Existing `AGENTS.md` edits and Git history were preserved; no commits or pushes.

## Phase 2 files created

- `backend/prisma.config.ts`
- `backend/prisma/schema.prisma`
- `backend/prisma/migrations/migration_lock.toml`
- `backend/prisma/migrations/20261005000000_initial_schema/migration.sql`
- `backend/prisma/migrations/20261005010000_enforce_immutable_records/migration.sql`
- `backend/prisma/seed.ts`, `backend/prisma/seed-data.ts`
- `backend/tsconfig.database.json`
- `backend/src/database/client.ts`
- `backend/tests/database-support.ts`
- `backend/tests/database.integration.test.ts`
- `backend/tests/migration-replay.ts`
- `docs/16-database-operations.md`

Updated `.gitignore`, root/backend/infrastructure/scripts README files,
backend `package.json`/lock, `.env.example`, SQL probe, infrastructure Compose,
repository/development check scripts, database design, docs index/roadmap/development
guide, and this state file. Generated Prisma source and compiled output are ignored.
Private `.env` changes and one-off diagnostic helpers under `.cache/` are local artifacts.

## Phase 2 verification

| Check | Result |
|---|---|
| Prisma format/validate/generate | Passed with all 19 requested models |
| Strict TypeScript config/source/seed/test check and emitted build | Passed; compiled dependency probe passes |
| Initial and corrective migrations | Applied successfully to the configured Neon PostgreSQL 18.6 database |
| Migration replay | Both committed SQL migrations replay in an isolated schema with 19 tables/19 checks/33 triggers; schema removed afterward |
| Repeat migration deploy | Passed: no pending migrations; no reset/data replacement |
| Migration status | Passed: both migrations applied, schema up to date |
| Structural Prisma diff | Passed: no difference; custom SQL additionally verified by integration/catalog checks |
| Database integration | Passed: 12 tests, including all model round trips, invalid values, ownership, versioning, vectors, timestamps, immutable payloads, and FK deletion policies |
| Seed repeatability | Passed twice with empty reviewed-data groups; existing records preserved |
| PostgreSQL SQL probe | Passed on Neon 18.6 with temporary table and rollback |
| Durable application/test data | Verified 19 application tables, zero rows, and no remaining migration test schemas |
| Compose configuration | Passed using the standalone official Compose CLI; runtime unavailable |
| Repository/templates/ignore rules | Passed, including blank direct URL template and ignored generated Prisma source |
| PowerShell syntax/Markdown links/whitespace | Scripts parse, local links resolve, Git whitespace checks pass |

Commands/checks performed from `backend/` unless noted:

- `npm.cmd install` for exact Prisma/client/adapter/tsx versions; package lock updated.
- `npm.cmd run db:format`, `db:validate`, `db:generate`, and `npm.cmd run check`.
- `prisma migrate diff --from-empty --to-schema prisma/schema.prisma --script --output ...`
  to generate the relational migration, followed by reviewed PostgreSQL-only invariants.
- `npm.cmd run db:migrate`, `db:status`, `db:check:migrations`, and `db:diff`.
- `npm.cmd run db:check` (12 passing tests), `db:seed` twice, and `check:database`.
- Read-only database extension/table preflight; final table/row/migration/temporary-schema
  inventory and migration-lock diagnostics, without printing credentials.
- Root PowerShell repository and Docker development checks; PowerShell syntax parsing,
  local Markdown link checks, `git diff --check`, and Git status/source inspection.

Networked database commands required approved execution outside the sandbox. A pooled
Neon session temporarily retained Prisma's advisory lock, causing a migration retry timeout.
The lock expired naturally; a narrowly checked cleanup command found no eligible session
and terminated none. Final direct-session migration deployment succeeds with advisory locking
enabled. No unrelated sessions, system services, persistent OS policy, or existing data were reset.
An initially short seed transaction timeout was increased for remote startup latency.

## Phase 2 audit (2026-10-05)

Read `AGENTS.md`, this state file, and relevant PostgreSQL/Prisma configurations,
schema, migrations, seed structure, checks, and database documentation before changes.
`docs/DECISIONS.md` was absent, including a repository search; it was created from
the existing design and the confirmed audit corrections. Phase 2 was audited in place.
No tables, schema fields, packages, APIs, authentication, or Phase 3 behavior were added.

### Audit coverage

| Area | Finding |
|---|---|
| PostgreSQL and connection configuration | Neon PostgreSQL 18.6 connects; runtime and direct URLs target the same database. Client TLS is encrypted with certificate verification. Local Compose interpolation/schema validates. |
| Prisma | Matching CLI/client/adapter 7.10.0, PostgreSQL provider, generated ESM client, config-file URL, and strict TypeScript compile successfully. |
| Environment and secrets | Database URLs come from environment, runtime/direct settings are separate, template credentials are blank, private files/generated output are ignored. Source candidates were checked against actual private environment credentials without printing them. |
| Architecture and schema scope | All 19 requested entities remain. No ML/RAG logic in Node and no application behavior was introduced. |
| Relationships and constraints | UUID PKs, FK indexes, unique/version keys, role/status enums, nullable context references, timezone-aware timestamps, four partial indexes, 19 CHECK constraints, and 33 triggers remain intact. |
| Anonymous and authenticated scans | Rollback tests confirm NULL ownership, valid farmer association, rejection of ADMIN ownership, immutable ownership, and cross-farmer/anonymous history restrictions. |
| Future authentication and profiles | Unique normalized email, password-hash field, FARMER/ADMIN, account status, and one optional farmer profile exist. Token/session flows remain Phase 3 work. |
| Disease/admin knowledge foundation | Disease content/images/sources and versioned source-grounded documents/chunks support future management; creator provenance correction is tested. |
| Scans, predictions, models, metrics | Exact model/preprocessing/dataset/artifact metadata, class/probability mapping, bounded metrics, per-class/confusion/curve JSON, and immutable prediction history remain verified. |
| Fertilizers and calculators | Fixed-point label composition, sourced units/parameters, version keys, active uniqueness, and configuration-linked history remain verified. |
| AI/RAG and audits | Optional scan/disease context, retained responses/citations, provenance presence, nullable actors, and immutable audit payloads remain verified; retrieval and authorization are future services. |
| Migration safety | Previous migrations/checksums were preserved. A new corrective migration was applied; all three replay in an isolated schema. No reset, manual table replacement, or retained synthetic data. |

### Problems found and fixes

1. `docs/DECISIONS.md` was missing. Added the decisions register and documentation
   link; repository checks now require it.
2. Knowledge-document and calculator version creators could be reassigned to another
   account because `created_by_id` was excluded to allow FK SET NULL. A rollback probe
   reproduced both cases. Added `20261005020000_protect_version_creator`, preserving
   old migration checksums and all table definitions. Creator reassignment/restoration
   now fails with SQLSTATE 23514, unchanged creators remain valid, and creator deletion
   still clears references. Added a regression test covering these cases.
3. Prisma CLI connections intermittently failed with schema-engine/P1001 errors at
   the default connection timeout while pg connected to the same direct database.
   A temporary CLI override with `connect_timeout=30` connected successfully without
   changing TLS settings. `prisma.config.ts` now defaults this parameter to 30 seconds
   only when absent; explicit settings and runtime driver timeouts remain unchanged.

Updated database design/operations and the backend environment template comments.
No existing migration was edited and no existing working feature source was rewritten.

### Audit verification and commands

- Passed: `npm.cmd run db:format`, `db:validate`, and `db:generate`.
- Passed: `npm.cmd run check`, strict typecheck of config/source/seed/tests, and emitted build.
- Passed: baseline `db:check` (12 tests), then the revised `db:check` (13 tests).
  Both fixture transactions rolled back; anonymous/farmer/admin and provenance cases verified.
- Passed: `npm.cmd run db:migrate` applied only the new corrective migration;
  `db:status` reports all three migrations applied/up to date; `db:diff` reports no difference.
- Passed: `npm.cmd run db:check:migrations` replays all three atomic migrations in
  an isolated schema and removes it; tables/checks/triggers match expectations.
- Passed: `npm.cmd run check:database` against PostgreSQL 18.6.
- Passed: direct connection/TLS/certificate and migration SHA256/history checks;
  targeted creator regression probes run through savepoints and roll back.
- Passed: PowerShell repository check and Docker component configuration validation;
  private environment values do not occur in source/commit candidates.
- Checked: PowerShell script syntax, local Markdown links, source/Git whitespace,
  final database row/temporary-schema inventory, Git status, and remote history.

Migration status: **three applied, none pending**. Prisma validation status: **valid**.
The actual relational schema remains unchanged; corrections affect trigger behavior
and connection configuration. Original Phase 2 verification above is retained as history.

The previously completed foundation files were still uncommitted at audit start.
The Git handoff checkpoints the existing Phase 0-2 foundation together with these
audit fixes; local credentials, dependencies, generated client/build output, caches,
and database data are excluded. The existing AGENTS.md instruction content is preserved.
Commit/push outcome is reported in the final audit handoff.

## Phase 3 backend foundation (2026-10-05)

Inspected `AGENTS.md`, project state, decisions, backend source/configuration and
Prisma schema before implementation. The existing strict NodeNext TypeScript
settings and Phase 2 database design remain intact. No schema/migration/seed change.

### Implementation

- Added separate Express app factory, startup/shutdown lifecycle and executable.
  Health uses route -> controller -> service -> repository -> shared Prisma -> PostgreSQL.
  Health's module contains its own layers; no empty generic directories or DI container.
- Added startup Zod validation for DATABASE_URL and used operational settings.
  Templates document loopback binding, exact CORS allowlist, log level, shutdown
  deadline and request limit. Existing private settings are preserved; unused
  JWT/provider placeholders are optional. Invalid values are never echoed.
- Added typed success/error envelopes, server-generated request IDs and application
  errors for validation/authentication/authorization/not-found/conflict/internal
  failures, plus parser/encoding/size/rate-limit errors. Authentication itself is absent.
- Added reusable async Zod validation for body, params and query. Parsed values
  are stored in Express locals; request.query is not reassigned. Client details
  contain paths/codes only; internal errors cannot expose details or raw exceptions.
- Added Helmet, explicit CORS, in-memory per-IP rate limiting, 100 KiB JSON limit
  and compressed-body rejection. Request logs omit headers/bodies/query/param values
  and client IDs. Errors after headers are sent delegate only a sanitized error.
- Added one shared application Prisma client; isolated seed/test clients remain
  available. Extracted URL normalization for reuse by startup validation, preserving
  TLS behavior. Added a 5-second query timeout; existing database checks still pass.
- Startup performs a database round trip before HTTP listens. Shutdown drains HTTP
  before Prisma disconnect, is idempotent, and has a configurable deadline. Signals
  and fatal process/server errors use the same path, with failure exit codes when needed.
- Added dev/start/lint/format/test scripts with pinned Helmet 8.3.0, CORS 2.8.6,
  Pino 10.4.0, express-rate-limit 8.7.0 and Biome 2.5.15; reused built-in Node tests/tsx.
  Preserved strict TypeScript configuration rather than replacing it.
- Updated root/backend README, LLD/API guidance, roadmap scope, environment/database
  operations, docs index, repository/development checks and actual architectural decisions.

Endpoint: **GET `/api/v1/health`**. Reports service, time, uptime and database up/down;
HTTP 200 or degraded 503, without sensitive infrastructure details. Both use the
same health-report envelope; monitoring must inspect HTTP status and data.status.
Express also provides HEAD handling; CORS handles OPTIONS preflight. No business routes.

### Important files

Created:

- `backend/biome.json`
- `backend/src/app.ts`, `application.ts`, `server.ts`
- `backend/src/config/environment.ts`, `logger.ts`
- `backend/src/database/connection-url.ts`, `errors/app-error.ts`
- `backend/src/middleware/request-context.ts`, `rate-limit.ts`, `error-handler.ts`
- `backend/src/modules/health/health.routes.ts`, `health.controller.ts`,
  `health.service.ts`, `health.repository.ts`
- `backend/src/routes/index.ts`, `types/api.ts`, `types/express.d.ts`,
  `utils/respond.ts`, `validators/request.ts`
- `backend/tests/foundation/helpers.ts`, `environment.test.ts`, `http.test.ts`,
  `lifecycle.test.ts`
- `docs/17-backend-foundation.md` (complete directory tree and operational contracts)

Changed: backend package/lock/template/README, shared database client, formatting
of the existing SQL probe, root README, docs 04/06/14/15/16/index/decisions/state,
and repository/development check scripts. No Flutter/Python/ML/infrastructure changes.
Generated client, compiled output, live-check helpers and credentials remain ignored.

### Verification and commands

| Check | Result |
|---|---|
| `npm.cmd run format`, `format:check`, `lint` | Passed: authored source/foundation tests formatted; no lint errors |
| `npm.cmd run typecheck`, `build` (through `check`) | Passed: strict source/config/seed/test types and emitted build |
| `npm.cmd test` (through `check`) | 20 passed: health/outages, contracts, CORS/headers, parser limits, Zod body/params/query, logging, rate limiting, singleton, startup failures, draining/idempotence/deadline |
| `npm.cmd run check` | Passed: all foundation checks and preserved dependency probe |
| `npm.cmd run db:check` | Prisma validation/generation/types and all 13 database integration tests passed; fixtures rolled back |
| `npm.cmd run db:status`, `db:diff` | Three migrations applied, none pending; no structural difference |
| `node ../.cache/phase3-live-check.mjs` from backend | Compiled app connects through Prisma/Neon and serves health; executable rejects bad settings safely and exits 0 through SIGTERM shutdown |
| PowerShell repository check | Passed: complete structure/templates, blank secrets, Git root and ignore rules |
| Source/commit credential scan | Passed: no actual private environment credentials in commit candidates |
| Local Markdown links, `git diff --check` | Passed; existing CRLF conversion notices remain informational |
| Source review | No authored TypeScript `any`, duplicate query logic, extra client construction, dead feature code or speculative abstractions found |
| `npm.cmd audit --json`, `--omit=dev --json` | Four high-severity package reports in the pre-existing Prisma dependency graph; unresolved, details below |

An initial strict-type error in a test tuple was corrected. Biome configuration was
updated to its current preset syntax. A final review restricted error details to
validation errors and ensured after-header exceptions delegate a sanitized error.
Live Windows signal verification uses a test-only IPC preload to emit SIGTERM
because Windows child.kill does not deliver a POSIX signal; production has no IPC hook.
The server and test listeners are stopped after verification. No application rows
were persisted and no database reset, new migration or automatic seed was performed.

Git handoff: Phase 3 changes are committed/pushed separately from the completed
Phase 2 checkpoint; commit identifier and push result are reported in the final response.

## Phase 4 authentication and authorization

### Implementation

- Inspected `AGENTS.md`, current state/decisions, Prisma schema, migrations and existing
  backend layers before modification. Preserved the Phase 3 foundation and all three
  Phase 2 migrations. Auth follows route -> controller -> service -> repository -> Prisma.
- Added FARMER-only registration, normalized email, strict Zod inputs, clean duplicate
  409 responses, generic failed-login 401 responses and safe user DTOs without account IDs,
  password hashes, statuses or refresh credentials. Registration does not auto-login.
- Pinned Argon2 0.45.1, jose 6.2.12 and cookie 2.0.1. Argon2id uses a random salt,
  64 MiB memory, three iterations and one lane; plaintext passwords are never persisted.
- Required independent canonical base64url signing keys of at least 32 bytes. Local
  initialization generates 64 random bytes per missing key and preserves existing keys.
  Access defaults to 15 minutes; refresh sessions have a fixed seven-day lifetime.
- JWT verification pins HS256, issuer, separate audiences, purpose, required claims and
  expiry. JWTs contain an opaque session handle, not an account ID, email or role.
- Added `auth_sessions` and an additive fourth migration. Only the current SHA-256
  refresh digest is stored. Atomic conditional updates consume tokens once; replay or
  concurrent reuse commits whole-session revocation. Logout immediately invalidates that
  session's access and refresh tokens. Other independent login sessions remain active.
- Access authentication checks the session and current active account in PostgreSQL.
  Reusable authorization reads current FARMER/ADMIN roles rather than stale token roles.
  Farmer/admin-only routes used to verify authorization exist only as test fixtures.
- Refresh credentials use HttpOnly, SameSite=Strict cookies; production additionally
  requires Secure and a host-prefixed name. Refresh tokens are never JSON fields.
  POSTs require JSON and `X-Auth-Request: 1`; CORS uses exact credentialed origins.
  Auth responses are not cached. Logging redacts tokens, hashes, keys and Set-Cookie.
- Added credential and refresh/logout rate limits. Controlled admin provisioning reads
  credentials from stdin through a masked PowerShell prompt; no public ADMIN registration,
  automatic admin, default password or promotion of an existing account.

Available auth endpoints:

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET /api/v1/auth/me`

`GET /api/v1/health` and the existing response/error envelope remain available.

### Important files

Created:

- `backend/src/modules/auth/`: types, repository, password/token helpers, validators,
  cookie handling, service, controller and routes.
- `backend/src/middleware/authentication.ts`, `authorization.ts`
- `backend/src/cli/create-admin.ts`
- `backend/prisma/migrations/20261006000000_auth_sessions/migration.sql`
- `backend/tests/auth/`: helpers, service, HTTP and credential-log tests.
- `backend/tests/auth.database.integration.ts`
- `scripts/initialize-auth-env.ps1`, `scripts/create-admin.ps1`
- `docs/18-authentication.md`

Updated backend schema/package/lock/template, environment/logger/app/routes/error/types,
reusable rate limiter, shared database client, Biome coverage, existing foundation and
database tests/catalog expectations, development/repository scripts, README files,
database/API/security/setup/roadmap documentation, decisions and this state file.
No Flutter, Python, ML or deployment feature code was changed. Generated Prisma/build
output, one-off probes and private database/signing credentials remain ignored.

### Verification and commands

| Check | Result |
|---|---|
| `npm.cmd run format`, `format:check`, `lint` | Passed; no formatting/lint errors |
| `npm.cmd run typecheck`, `build` | Passed with strict TypeScript |
| `npm.cmd test` / `npm.cmd run check` | 36 passed: 21 foundation and 15 auth tests; dependency probe passes |
| `npm.cmd run test:auth:database` | 6 passed including suite parent: real Prisma/HTTP, digest storage, duplicate handling, rotation races, committed revocation and SQL guards |
| `npm.cmd run db:check` | Schema validation/generation/types plus all 13 domain/catalog regressions passed |
| `npm.cmd run db:format`, `db:validate`, `db:generate` | Passed; current client generated |
| `npm.cmd run db:migrate`, `db:status` | Fourth migration applied; all four applied and none pending |
| `npm.cmd run db:check:migrations` | All four migrations replayed in an isolated schema: 20 tables, 20 CHECKs, 35 custom triggers; temporary schema removed |
| `npm.cmd run db:diff` | No structural difference |
| Compiled application/server probe | Real database health, safe startup failure and graceful SIGTERM exit verified |
| Compiled admin CLI invalid-input probe | Rejects bad credentials/role injection safely without writing accounts or printing input |
| PowerShell syntax/repository/environment checks | Scripts parse; structure/templates/ignores pass; rerunning key initialization preserves credentials |
| Source review/credential scan/Markdown links/`git diff --check` | No authored `any`, redundant Prisma construction, leaked private credentials, unresolved local links or whitespace errors |

Coverage includes registration, duplicates, invalid inputs, login/wrong password,
missing/invalid/expired access, protected endpoint access, refresh/rotation/replay,
logout/revocation, FARMER/ADMIN permissions, CSRF/CORS, rate limits, production cookie
flags, safe DTOs/logging, live account status/roles and database constraints.

Resolved verification issues: the current Argon2 encoder orders PHC parameters
differently, so the test now compares parameter values without assuming order.
Two remote domain checks hit the five-second query timeout; development-only domain
test clients now allow 30 seconds. HTTP/runtime retains its five-second query bound.
Final reruns pass. Auth database fixtures remove only their own new UUID/email and
cascading sessions; domain/constraint probes roll back. No existing account/data was
overwritten, no automatic admin created and no database reset performed.
The compiled startup probe also caught pre-existing local signing values incompatible
with the new key format. Replaced those unused Phase 3 values with independent 64-byte
random keys in ignored `.env`, preserving every other setting. Startup/shutdown then
passed; rerunning the committed initializer preserves the valid keys.

Git handoff: the verified Phase 4 change is committed/pushed with a relevant message;
the commit identifier and push result are reported in the final response. Stop at Phase 4.

## Phase 5 Flutter foundation

### Changes and scope

- Read `AGENTS.md`, project state/decisions, Flutter/LLD/API architecture and the
  current mobile scaffold, dependencies and Android configuration before modification.
- Preserved Flutter 3.41.9/Dart 3.11.5 and Provider; locked compatible go_router
  17.5.0 and http 1.6.0. Created meaningful core/data/feature modules without empty
  files, speculative data or extra unused layers.
- Added centralized agricultural Material 3 light theme: forest scan accents,
  ivory/white surfaces, dark ink, wheat/amber tools and blue knowledge accents;
  explicit Roboto typography, spacing/radii and 48-point interaction minimums.
- Added five-area farmer shell, prominent Scan Leaf, nested/back-safe navigation,
  preserved feature state and scroll positions, safe unknown-route fallback and a
  reserved separate Admin boundary that reveals no privileged UI/data.
- Added honest foundation views for all requested feature areas. Mobile sign-in,
  camera/uploads, diagnoses, calculations, charts, assistant responses and dashboard
  operations are not simulated or implemented.
- Added API configuration through public Dart defines, optional offline shell,
  release HTTPS enforcement, origin-contained relative resource paths, redirect
  rejection, JSON/UTF-8/envelope handling, safe typed errors, 15-second request bound
  with supported transport abortion and 1 MiB response cap.
- Added optional access-token source contract for future secure-storage integration;
  no token persistence, mobile login/refresh implementation or secrets in Flutter.
  Main Android INTERNET permission is present; cleartext permission is debug-only.
- Home's scoped ChangeNotifier drives an explicit connection check through typed
  repository/datasource/API layers. It suppresses duplicate requests and handles
  error/retry/disposal safely. Shared dependencies are stateless app-level Providers;
  future screen state remains scoped. Widgets never call HTTP or use business setState.
- Added reusable loading/empty/error patterns, scalable safe scrolling pages, responsive
  card pairs, bottom bar/scrollable wide rail and constrained content. Large text,
  keyboard insets, long labels and small/landscape/tablet screens are verified.

### Important files

Created `mobile/lib/app.dart` and implementations under `core/{constants,theme,routes,
network,storage,exceptions,utils,widgets}`, `data/{models,datasources,repositories}`,
and all requested feature areas plus `shell` and `tools`. Every feature has a routed
view; only Home currently needs a ViewModel and concrete data workflow.

Added `mobile/test/core/api_client_test.dart`, `test/features/home_view_model_test.dart`,
`test/widgets/foundation_test.dart`, `test/integration/backend_connection_test.dart`
and `docs/19-flutter-foundation.md`. Updated existing entrypoint/scaffold test,
pubspec/lock, public template, Android manifests, mobile/root README, Flutter/setup/
roadmap/docs index, actual decisions, repository checker and this state file.
Backend application, Prisma schema/migrations, Python/ML and infrastructure code are
unchanged. Generated preview PNGs/test artifacts and one-off live helper stay ignored.

### Checks and outcomes

| Check | Result |
|---|---|
| `flutter --version`, `dart --version`, `flutter pub add go_router http` | Existing SDK preserved; compatible dependencies resolved and locked |
| `dart format lib test`; format with `--output=none --set-exit-if-changed` | Passed; 40 authored Dart files formatted |
| `flutter analyze --no-pub` | Passed; no issues |
| `flutter doctor -v` | SDK, network and connected emulator available; some Android licenses remain unaccepted |
| `flutter test --no-pub` | 37 passed: 17 API/repository, 4 ViewModel, 15 widget and one offline smoke test; optional live test skipped |
| Opt-in `backend_connection_test.dart` through local compiled Node server | Passed separately: full Flutter MVVM chain reaches actual Prisma/PostgreSQL-backed health; read-only, server/client stopped afterward |
| Responsive/navigation | Seven sizes: 320x568, 360x800, 412x915, 640x360, 768x1024, 1024x768 and 1024x360; primary small-phone action, 200% text, nested/back/state preservation, unknown/admin boundaries pass |
| State/accessibility | Loading/error/retry, safe keyboard/insets/long text, Android tap/label/contrast guidelines pass |
| Rendered visual review | Reviewed actual 320/360/1024 screenshots with SDK fonts; previews are ignored build artifacts |
| Repository/templates/PowerShell/Markdown/credential/whitespace checks | Passed; no actual secrets in source/commit candidates, no empty feature files or widget HTTP/business setState |

Initial checks caught brace-style lint issues, realistic font selection and semantics
handle cleanup in tests. Added SDK font loading and explicit theme typography,
ensured short rails scroll to every destination and corrected preview image capture
to run in real asynchronous execution. Final checks pass. No SDK license agreement
was accepted, Android device/APK validation or deployment performed.

Git handoff: the verified Phase 5 change is committed/pushed with a relevant message;
its identifier/result is reported in the final response. Stop after Phase 5.

## Current limitations and pending decisions

- Dependency audit reports four high-severity entries (`prisma`, `@prisma/config`,
  `deepmerge-ts` 7.1.5, and `mysql2` 3.15.3), including propagated reports from
  [recursive merging](https://github.com/advisories/GHSA-ggr8-5vv4-36mx),
  [MySQL authentication](https://github.com/advisories/GHSA-3f6p-5ww8-9rcr), and
  [MySQL decompression](https://github.com/advisories/GHSA-rgwj-5xj2-c3m3).
  Both vulnerable versions already existed in the Phase 2 lock. npm's suggested
  automatic remediation downgrades Prisma to 6.19.3, conflicting with the verified
  Prisma 7 architecture; no forced downgrade or unverified major transitive override.
  Audit also reports these with omit-dev due to the dependency/peer graph. The
  implemented PostgreSQL health/auth paths do not use MySQL or merge client-supplied
  object graphs, but dependency remediation remains a follow-up maintenance issue.
- Rate-limit counters are per-process/in-memory. Shared storage, proxy trust and
  least-privilege database roles must be chosen for an actual deployment. Default
  binding is loopback; LAN/container hosting needs explicit HOST/CORS configuration.
- Production auth requires HTTPS and same-site browser hosting for Strict cookies.
  Clients must serialize refresh calls; parallel/retried token reuse requires login again.
  Hashing throughput and native Argon2 deployment compatibility need deployment checks.
  Email verification, password recovery/change, MFA, security-event auditing, session
  management and expired-session cleanup remain future work. Future password/status
  management must revoke affected sessions; current access checks already reject inactive accounts.

- Mobile authentication/secure token persistence, session-aware admin navigation,
  localization, dark theme, camera/uploads and actual business workflows are future
  work. Only Android scaffolding exists; emulator/physical-device interaction and APK
  packaging remain unverified. Public API configuration is required for connection checks.
- Review outstanding Android SDK licenses locally before Android build verification;
  command-line tools are installed and instructions are in the development guide.
- Docker Engine/Desktop is not installed. Compose configuration passes validation;
  container startup is unverified. The complete schema and pgvector are verified on Neon.
- The preserved native Windows PostgreSQL installation lacks pgvector binaries;
  install the extension before applying Phase 2 migrations there, or use Neon/pgvector Compose.
- pg 8.23 can emit a query-queue deprecation warning during Prisma internal related
  queries; verified transactions pass. Keep the current lock until future adapter/pg compatibility is checked.
- CPU ML environment is the baseline; GPU/CUDA and model/experiment choices remain future work.
- Shared preprocessing package location, actual sourced agricultural data/rules, trained
  model artifacts, embedding model/dimensions/indexes, provider credentials, detailed
  business APIs and retention/Cloudinary deletion remain pending. The initial light
  design system is implemented; domain workflow designs remain future work.
- Seed data is intentionally empty. Database checks enforce structure/provenance presence;
  future services must validate full JSON contracts, agricultural sources, hashes, authorization,
  uploads, and deterministic formula semantics. Separate least-privilege runtime roles remain future work.

## Next step

Stop after Phase 5 Flutter foundation. Wait for the next explicit instruction and
reconcile its scope with the [roadmap](14-roadmap.md). Do not start mobile authentication,
complete disease/business APIs, AI/ML/RAG/calculators or admin functionality automatically.
