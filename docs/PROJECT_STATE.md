# Project state

Updated: 2026-10-09 (Asia/Karachi).

## Current phase

Phase 11 is complete. FastAPI serves the approved classifier through authenticated
internal prediction/model-health endpoints, validates pinned artifacts at startup
and loads one model per lifespan using the exact shared full-frame pipeline.
All 219 AI tests, Ruff and strict mypy pass; 16 real TRAIN tensor/logit hashes match
the frozen Phase 10.5 evidence exactly. Representative preprocessing-plus-inference
averages 17.75 ms on the local CPU. Read [inference contracts](27-production-ml-inference.md).

The Phase 10.5 candidate remains **FIT WITH DOCUMENTED LIMITATIONS** for a local FYP
research inference prototype. The original v1 scoring arithmetic is preserved, but
confirmed transformed-parent leakage invalidates its independent-evaluation claim.
The corrected v2 index and fresh model are verified; all 8,040 original files remain
unchanged. The new evaluation is descriptive on a previously inspected corpus,
without independent field/plant validation or commercial clearance.

Selected model version `mobilenet-v3-small-v2-20261009`, experiment
`mobilenet-v3-small-20261009-v2-01`, checkpoint `checkpoints/epoch-008.pt`,
SHA-256 `e95a2e83262637fc1a08b919e6003bddb2fe70664b9c51418f059b7c8287dc66`.
The completed run stops at epoch 11 under patience 3, out of 12 maximum. Validation:
**96.81% accuracy / 0.9589 macro F1**. One post-freeze final test: **95.83% / 0.9452**,
598 correct of 624. Test Gray Leaf Spot recall is **83.53%**, F1 **0.8659**. These are
internal benchmark scores, not measured farmer-field accuracy. Calibration remains
disabled (`T=1`): group cross-fitting worsens NLL/Brier/ECE. No confidence threshold
is locked; current serving explicitly returns `LOW_CONFIDENCE/THRESHOLD_UNCONFIGURED`
with a null threshold. Read [the fitness report](26-model-fitness-validation.md) and
[safe numerical/artifact evidence](../ml-training/reports/mobilenet-v3-small-20261009-v2-01-fitness/README.md).

The preceding Phase 0–9 audit verified 77 checked-in backend cases, a live farmer
WebP/auth lifecycle probe, five migration replay/checksum checks, 52 isolated Flutter
tests plus both live health/upload tests, and a debug Android APK. The AI suite has
50 passing tests, then five training tests, shared preprocessing 78 in each independent environment
and eight exact cross-environment parity cases. Actual FastAPI startup/shutdown and
six supplemental synthetic scenes pass. Real Cloudinary JPEG/PNG/WebP uploads and
nullable/actual farmer ownership are verified. Every audit-created row/asset was removed;
database counts/catalog/checksums match the pre-audit snapshot. Formatting/lint/types/
build/locked dependencies, repository/template/ignore/links and source-secret checks pass.

Both Python environments import the same `maizedoctor_preprocessing` 1.0.0 package.
Phase 9.5 runs both policies on all 8,040 images and verifies 160 real consumer parity
cases. Review of 81 filenames/78 contents found no obvious preprocessing-caused tissue
loss, without ground-truth lesion masks or classification accuracy. Conservative
extraction falls back for 8,021 of 8,029 accepted files; full-frame is approved for
the first baseline. Generic package defaults/version remain unchanged; Phase 10 pins
224×224/ImageNet settings in its artifact configuration. A reproduced Node/
shared image-admission mismatch, four existing high npm aggregate advisory entries,
native mobile refresh-cookie integration and deployment/platform limitations are recorded.
The recovered backend database client matches HEAD and works. Phase 6 remains explicitly
skipped. Phase 9.5 added configured read-only intake; the subsequent approved exclusions,
use restrictions, full-frame policy and Phase 10 baseline are recorded in DECISIONS.md.
Stop after Phase 11; Node/FastAPI orchestration, mobile sign-in,
disease/business APIs, calculators, admin functionality and RAG/Gemini remain deferred.

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
| Mobile | Flutter 3.41.9/Dart 3.11.5, Material 3 farmer shell, scoped Provider MVVM, go_router 17.5.0/http 1.6.0/image_picker 1.2.2, gallery/camera/preview/progress/retry/pending confirmation; 52 isolated tests, two optional live tests and separately verified real upload; debug Android APK builds |
| Backend | Express 5 health/auth/scans, strict TS/Zod, Argon2id, rotating/revocable JWT sessions/RBAC, upload signature/full decode validation, Cloudinary authenticated assets, durable scan-upload retry/cleanup; shared Prisma 7.10.0, 21 tables/five migrations, 77 passing tests across five suites |
| AI service | Python 3.11/FastAPI 0.142.2/Uvicorn 0.54.0; strict pinned model startup, once-per-lifespan CPU classifier, exact shared full-frame pipeline, authenticated predict/model health, bounded upload/concurrency and explicit uncertainty; 219 tests, Ruff and strict mypy pass; factory remains free of heavy imports |
| Shared preprocessing | One independently buildable typed package at `shared/preprocessing`, version 1.0.0, explicit JSON configuration, file/byte entrypoints, conservative extraction/fallback, optional unchanged CPU tensor and debug CLI; 78 tests pass in each consumer environment and 12 synthetic baseline parity cases pass |
| ML training | Corrected immutable v2: 4,162 contents/4,121 groups, 2,911/627/624 partitions, no confirmed leakage; fresh MobileNetV3 Small completed 11 epochs, best epoch 8; validation 96.81% accuracy/0.9589 macro F1, single descriptive test 95.83%/0.9452; raw probabilities, no threshold; 219 tests, Ruff over 32 files, mypy over 15 modules and 16 actual TRAIN cases with AI compatibility pass; limited FYP prototype |
| Infrastructure | Neon PostgreSQL 18.6 with pgvector 0.8.6 migrated; pgvector 0.8.7/PostgreSQL 18 Compose configuration; preserved native 18.4 cluster; private local settings ignored |
| Documentation | Architecture, database/operations, auth, Flutter foundation, scan uploads/recovery, FastAPI startup/contracts/network, shared preprocessing/configuration/versioning/limitations, decisions, roadmap and verification history |
| Scripts | Repository/environment/auth/admin/PostgreSQL/Python/development checks including shared preprocessing and actual cross-environment parity; configured FastAPI startup and 16-TRAIN serving parity/timing verifier; full live Flutter scan-upload harness and backend cleanup CLI |

Mobile authentication workflows, disease-result APIs, Node inference orchestration, RAG, calculator
execution, notification delivery and the admin dashboard remain future work. Flutter
feature introduction/empty screens are foundation UI; FastAPI now exposes internal
prediction/model health alongside process health, without retrieval/generation endpoints.

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

## Phase 7 implementation and verification (2026-10-06)

Scope: secure maize leaf image storage and scan-record foundation only. The workspace
started clean at e5f1949 (Phase 5). AGENTS.md, project state/decisions, relevant
architecture, schema/migrations, auth/backend layers and mobile foundation were read
before edits. The explicit Phase 7 request does not authorize Phase 6 or inference.

- Added the layered scans module, strict multipart/header/Zod validation, optional
  session auth and FARMER ownership. Invalid supplied credentials return 401; ADMIN
  returns 403; request-supplied ownership/provider fields are rejected.
- Accepted still JPEG/PNG/WebP with matching MIME/signature/extension, at most 5 MiB
  and 16 million pixels. Security decoding validates full content with five-second
  processing timeout; original bytes are uploaded unchanged. Python's future shared
  ML preprocessing remains untouched. Two concurrent upload slots and additional
  rate limits protect parsing/decoding/storage work.
- Integrated server-only Cloudinary SDK, authenticated assets, generated IDs,
  overwrite protection and signed HTTPS delivery. Required partial provider
  configuration is rejected; all blank cleanly disables uploads. No provider secrets
  or internal journal/owner fields are returned or included in mobile source.
- Added fifth migration 20261006010000_scan_uploads: one necessary durable upload
  journal and immutable uploaded_at timestamp. Preserve all prior migrations;
  backfill existing scans under the atomic migration lock. Database: 21 application
  tables, 21 CHECK constraints, 37 custom triggers and unchanged partial indexes.
- Added exact-payload, owner-scoped retry identity; atomic scan/journal completion,
  confirmed-upload compensation, lost-commit protection, delayed unknown-outcome and
  crash recovery. `scans:cleanup` processes bounded stale attempts and prunes cleaned
  FAILED journals after 24 hours, preserving all completed scans.
- Added image_picker datasource, typed scan/photo models, repository/datasource,
  route-scoped Scan ViewModel, preview component and upload UI. Gallery/camera
  cancellation, native permission errors, Android lost picker data, upload progress,
  saving state, errors/retry/new selection/disposal are handled. Selected original
  bytes and retry key remain in memory, without plaintext token persistence.
- Added maintained locked backend provider/parser/decoder packages. image_picker
  1.2.3 archive download stalled; compatible cached 1.2.2 resolved and is locked.
  Native Kotlin compilation reported its cross-drive incremental-cache error;
  project kotlin.incremental=false fixed it. Rebuild passed without that error in 32.5s.
- Final camera-style EXIF regression found that Cloudinary reports portrait JPEG
  dimensions after orientation while Sharp reports original dimensions. Fixed the
  provider consistency check to accept the EXIF-authorized swap without modifying
  bytes. Unit and real-provider JPEG/PNG upload regression pass; original bytes remain intact.

New API: POST /api/v1/scans, 201 new PENDING scan, 200 same-key replay.
Existing health/auth endpoints remain available; no inference/read/history API added.

| Check | Result |
|---|---|
| Backend `npm run check` | Formatting, Biome lint, strict typecheck, build, 50 isolated tests and compiled dependency probe pass |
| Image/security/service/HTTP tests | Format signatures/decoding/EXIF portrait metadata, MIME/extension spoofing, size/pixel/animation/multipart bounds, farmer/guest/admin behavior, limits, disconnected-client slot retention, safe replies and idempotency pass |
| Recovery tests | Database failure deletion, uncertain provider outcome, lost commit, failed cleanup, crashed upload, completed-scan protection, retry and failed-journal pruning pass |
| Original database regression `db:check` | 13 catalog/domain/constraint/relationship/ownership/vector/version/timestamp tests pass; synthetic writes roll back |
| Auth database regression | Six tests pass, including real HTTP auth and refresh locking/revocation |
| Scan database integration | Seven tests pass for metadata, null/owned scans, parallel claims, transaction rollback, cleanup exclusion and immutable/state SQL invariants |
| Real Cloudinary integration | One test passes: Node multipart PNG and portrait EXIF JPEG -> authenticated Cloudinary -> PostgreSQL, replay, signed delivery and unsigned denial; exact fixture assets/journals/scans removed |
| Prisma | Format/validation/client generation pass; all five SQL migrations replay in a temporary schema; fifth migration deployed; status up to date; diff has no changes |
| PostgreSQL probe | Real authenticated PG 18.6 temporary-table round trip passes and rolls back |
| Flutter formatting/analyzer | Pass, no issues |
| Flutter isolated tests | 52 pass; both live tests skipped by default |
| Flutter live upload harness | Scan ViewModel -> repository -> datasource -> ApiClient -> real Node/Cloudinary/PostgreSQL passes; only own synthetic asset/SQL rows removed |
| Android APK | `flutter build apk --debug --no-pub` passes with gallery/camera plugin after cross-drive Kotlin cache fix; generated APK ignored |
| Android emulator | APK installation/activity launch succeed on emulator-5554; interactive picker/capture could not be verified because Android System UI repeatedly reports not responding |
| Cleanup command | Ran successfully: zero stale assets/failures/expired journals; no unrelated assets enumerated |

Commands/checks performed from appropriate component directories:

- npm view/install locked Cloudinary 2.11.0, Multer 2.4.0, Sharp 0.35.5 and
  @types/multer 2.3.0; npm audit confirmed the four already-known Prisma graph findings.
- `npm run format`, `npm run check`, `npm run db:format`, `db:validate`, `db:generate`,
  `db:check:migrations`, `db:migrate`, `db:status`, `db:diff`, `db:check`,
  `test:auth:database`, `test:scans:database`, `check:database`, `test:scans:live`
  with explicit live opt-in, `test:scans:mobile`, and `scans:cleanup`.
- `flutter pub get --offline`, `dart fix --apply` for new braces/import issues,
  `dart format lib test`, final format check, `flutter analyze --no-pub`,
  `flutter test --no-pub --reporter expanded`, targeted new/widget tests and
  `flutter build apk --debug --no-pub`.
- Repository structure/template/ignore checks, local Markdown links, actual-secret
  scan, whitespace/source review and Git diff/status checks are recorded at handoff.

Important new files: backend/src/modules/scans/{routes,controller,service,repository,
storage,validation,types} (scan.*.ts), cleanup-scan-uploads CLI, fifth migration,
scan isolated/database/live tests; mobile upload request, image/scan datasources and
models, scan repository/ViewModel/preview, scan unit/widget/live tests;
scripts/check-scan-upload.mjs and docs/20-scan-uploads.md. Configuration/app/routes,
dependency locks, native Android settings, existing catalog counts and docs updated.

Git handoff: verified Phase 7 work is committed/pushed with a relevant message;
its identifier/result is reported in the final response. Stop after Phase 7.

## Phase 8 implementation and verification (2026-10-07)

Read AGENTS.md, project state, AI/RAG/security architecture, decisions, existing Python
manifests/locks/tests, environment template and setup/check scripts before changes.
Workspace started clean on main at 7a7ec71. Two agents independently implemented
foundation tests and reviewed application security/architecture; root implemented
the application, configuration/tooling and documentation. No Phase 9 work was started.

- Added app factory/lifespan and configured Uvicorn entrypoint. Startup loads/validates
  settings before listening, does not import torch/image libraries or load models,
  and creates no database/provider connections. Lifespan marks start/stop explicitly.
- Added Pydantic typed health/query/error/metadata contracts. GET /health reports
  process status, uptime, service version, unimplemented capabilities and unloaded
  model with null model version. It accepts no query fields; 200 follows startup,
  503 is a safe pre-start report. No fake diagnosis/model readiness or business API.
  Final inspection corrected OpenAPI's default validation/error schema to match the
  actual envelope; the generated-contract regression assertion passes.
- Added fixed application/HTTP/validation/unexpected error handling, server-generated
  UUID correlation and no-store/nosniff headers. Validation exposes bounded source/code
  pairs only, without raw input/field names/context. Unknown failures contain no trace.
- Added allowlisted JSON stdout events for lifecycle, request status/route template/
  latency and errors. No raw request URL/query, headers/body, dynamic path values,
  exception/library messages or tracebacks are logged. Uvicorn access logging disabled.
- Settings load from service-local ignored .env with OS precedence; ENVIRONMENT,
  HOST, PORT, LOG_LEVEL and AI_SERVICE_TOKEN are validated. Loopback defaults and no
  browser CORS preserve Flutter -> Node -> private FastAPI. Production/non-loopback
  requires a random base64url shared server token; a reusable bearer dependency compares
  credentials in constant time and future operations fail closed if unconfigured.
  Health requires no token. No Node integration or deployment/firewall changes.
- Added meaningful boundary READMEs for future preprocessing, inference, RAG and model
  management, without placeholder processors/clients/loaders. Shared preprocessing
  implementation/package location remains future work, identical for training/inference.
- Preserved all original locked dependencies; added Pydantic settings 2.15.0/
  python-dotenv 1.2.4 and dev Ruff 0.16.10/mypy 1.20.2 plus their required transitives.
  Python 3.11, FastAPI 0.142.2, Uvicorn 0.54.0, PyTorch/torchvision/image versions remain.
  Lock diff adds seven packages without upgrading existing entries. No global installs.
- Added scripts/start-ai.ps1 and expanded only the AI development-check branch with
  format/lint/types before pytest. Repository checks include the new structure/template
  keys. Documented startup/API/network/logging boundaries and recorded actual decisions.

| Check | Result |
|---|---|
| AI aggregate check | Ruff format (27 files), lint, strict mypy (17 application modules) and 49 pytest cases pass |
| Foundation tests | 46 pass: actual lifecycle/health/correlation, capabilities absent, no heavy imports/external calls, docs/CORS boundaries, query/body/path validation, safe errors/logging, auth dependency and settings |
| Preserved dependency tests | Three pass: isolated Python, in-memory dependency route, image libraries and compiled CPU torch/torchvision operators |
| Live CLI/socket check | Actual python -m app.server on an ephemeral loopback port returns safe health, 404 and validation responses, no CORS/server header; JSON logs omit synthetic sensitive path/query values; only own child stopped |
| Invalid CLI settings | Production startup with invalid synthetic token exits 1, fixed configuration_invalid JSON event, no rejected value |
| uv lock/sync | Lock resolves and sync --locked installs seven additions; lock --check passes |
| uv pip check | All 42 installed packages compatible |
| Compilation | compileall app/tests passes |
| Independent source review | No blocking defect: config/auth, lifespan, safe errors/logs, no heavy imports and phase boundaries verified |
| Repository checks | Required structure/templates/blank secrets/ignore behavior pass; final local links, private-secret and whitespace checks recorded at Git handoff |

Commands performed: component uv lock, sync --locked, lock --check, pip check;
`.venv/Scripts/python.exe -m ruff format app`, `ruff check app`, `mypy`, `pytest`,
`compileall -q app tests`; `scripts/check-development.ps1 -Component AI`,
`scripts/check-repository.ps1`; an ignored temporary actual-CLI HTTP/error/log check;
Git/source/Markdown/credential checks. No external AI provider, database or model is
called by these tests or application startup. Temporary live server was stopped.

Important new files: app/main.py, app/server.py, api middleware/security/health route,
config/settings.py, schemas/common.py/health.py/errors.py, utils/errors.py/logging.py,
four future-boundary READMEs and package markers; tests/conftest.py, test_health.py,
test_settings.py, test_errors_and_logging.py, test_service_authentication.py;
scripts/start-ai.ps1 and docs/21-ai-service-foundation.md. Updated manifest/lock,
environment example, AI/architecture/development/root documentation, decisions and checks.
Original dependency tests and all backend/mobile/ML/database feature files are preserved.

Git handoff: Phase 8 is committed/pushed with a relevant message; identifier/result
reported in the final response. Stop after Phase 8.

## Phase 9 implementation and verification (2026-10-07)

Read AGENTS.md, project state/decisions, ML/AI/RAG architecture, existing Python
configuration/tests, and local scaffold before implementation. Phase 8 was already
committed at 2605164. Existing dataset ignore rules, documentation-only ML scaffold
and its README/state additions were preserved. The unrelated deletion of the backend
database client was also preserved; none of these changes belongs to the Phase 9 commit.
Two agents supplied independent pipeline review and synthetic unit tests while the
root agent implemented the shared package, consumer wiring and verification tooling.

- Added one editable local package, `shared/preprocessing`, imported identically by
  AI and training. Their local modules re-export the actual shared functions without
  additional transforms. No API endpoint, model loader or training loop was added.
- Configuration explicitly pins preprocessing version 1.0.0, dimensions, normalization,
  segmentation thresholds/fallback, input limits, crop padding and resize behavior.
  Immutable validated settings reject invalid/nonfinite/extra fields; canonical JSON
  SHA-256 distinguishes configuration changes. Defaults are foundation values, not
  evaluated classifier hyperparameters.
- Validate bounded JPEG/PNG/WebP bytes, signatures, optional MIME/extensions, full
  decoding, dimensions, animation and containers. Apply EXIF orientation, grayscale/
  palette handling, valid ICC-to-sRGB conversion and configured alpha compositing.
  Unsigned 16-bit grayscale uses fixed-range rounding instead of saturated conversion;
  the regression preserves gradations from dark through white.
- Foreground extraction accepts an oriented supplied mask or non-opaque alpha; otherwise
  it uses full Lab color and removes only uniform-background components connected to
  the perimeter. Enclosed brown/yellow/gray/rust/dead/background-colored lesions remain
  selected. Coverage, border variation, boundary contact and significant component
  gates preserve the full frame when uncertain; strict rejection is configurable.
  There is no green-only threshold, random augmentation, semantic maize detector or
  measured segmentation accuracy. All outputs warn that leaf identity is unverified.
- Use outward-only mask margin, background replacement, padded crop, aspect-preserving
  letterbox, explicit normalization and read-only contiguous RGB CHW float32 arrays.
  Optional PyTorch conversion copies unchanged values. Metadata records image/config/
  supplied-mask hashes, bounds, warnings, extraction status and library versions.
  Supplied masks must follow the same provenance/policy in training and serving.
- Independent review led to fixed-range 16-bit conversion, supplied-mask hashing,
  explicit minimum crop padding and bounded crop coordinate allocations. Strict type
  checks caught and resolved literal/nullable-library typing without adding `Any`.
- Added safe errors and an opt-in debug CLI producing standardized/mask/prepared images,
  a contact sheet and metadata in a new output directory. It refuses overwrite and
  does not copy source EXIF/location metadata. Inspected a generated synthetic contact
  sheet under ignored `.cache/phase9-debug-synthetic-current/`; internal lesion patches
  and leaf silhouette were retained. These artifacts are not real maize validation.
- AI health now truthfully reports preprocessing `library_available`; startup still
  imports no heavy image/ML libraries and loads no model. Existing factory/security/
  logging behavior is preserved. Both locks install the same local package with
  existing scientific/AI dependency versions preserved; training gains matching dev tools.
- Workspace image/data inventory found only launcher/UI graphics and documentation-only
  dataset scaffold. No actual dataset paths, photos, model weights or downloads were
  invented. Representative maize-leaf validation remains pending.

| Check | Result |
|---|---|
| Shared package tests | 78 pass in the AI environment and the same 78 pass in the training environment |
| Input/security coverage | Invalid/truncated/animated files, signature/MIME/extension, byte/pixel limits, orientation/ICC, grayscale 8/16-bit, alpha/palette and safe errors pass |
| Extraction/output coverage | Diseased non-green regions, enclosed background-colored lesions, supplied masks/provenance, ambiguous-frame fallback/strict errors, crop/letterbox/math/layout/read-only outputs and repeated/concurrent determinism pass |
| Tensor/debug coverage | Exact unchanged CPU tensor with independent storage, safe local inspection artifacts and no overwrite pass |
| Cross-environment parity | Eight synthetic scene/configuration cases produce identical implementation identity, masks, array/tensor bytes, dtype/shape and metadata through the two consumer modules |
| AI aggregate | Ruff format/lint (29 files), strict mypy (18 application modules) and 50 pytest tests pass; original foundation/dependency tests preserved |
| Training aggregate | Ruff format/lint (three files), strict mypy (one consumer module) and five pytest tests pass; four original dependency probes preserved |
| Shared source/tooling | Ruff format/lint (16 package files plus parity script) and strict mypy (nine source modules) pass |
| Dependency configuration | Both `uv sync --locked`, `uv lock --check` and `uv pip check` pass; all 43 AI / 34 training installed packages compatible |
| Distributable package | `uv build` successfully creates source archive and wheel under ignored `.cache/phase9-package-artifacts/` |
| Compilation | Shared source and both consumer wrappers compile successfully |
| Repository source safety | Git whitespace checks pass; 261 source/configuration candidates inspected without actual private credentials; intended artifacts remain ignored |
| Documentation links | 138 of 139 local links resolve; the single pre-existing unresolved link targets the unrelated deleted backend database client; Phase 9 links resolve |
| Full repository structure | Blocked by the unrelated local deletion of `backend/src/database/client.ts`; Phase 9 required files/configuration/typing/docs/tooling are present |
| Real maize images | Not available; field validation pending |

Commands/checks performed from the repository or appropriate component directories:

- `uv lock`, `uv sync --locked`, `uv lock --check`, `uv pip check` for both consumers.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1`
  with `-Component AI`, `-Component Training`, and `-Component Preprocessing`.
- Shared Ruff format/lint, `mypy --config-file shared/preprocessing/pyproject.toml`
  against shared source and pytest against shared tests using both environment executables.
- `python scripts/check-preprocessing-parity.py`, synthetic debug generation/contact-sheet
  inspection, and module compilation via the consumer environments.
- `uv build shared/preprocessing --out-dir .cache/phase9-package-artifacts`, repository
  structure/template/ignore checks, local Markdown links, credential/source inspection,
  and `git diff --check`.

Important created files: `shared/preprocessing/pyproject.toml`, `README.md`,
`configs/default.json`, `src/maizedoctor_preprocessing/{config,decoding,segmentation,
pipeline,types,errors,debug,__init__,__main__}.py`, `py.typed`, five shared test files;
`ai-service/app/preprocessing/__init__.py`, `ai-service/tests/test_preprocessing.py`,
`ml-training/preprocessing.py`, `ml-training/tests/test_preprocessing.py`,
`scripts/check-preprocessing-parity.py`, and `docs/22-shared-preprocessing.md`.
Updated Python manifests/locks, AI health contract/test, development/repository checks,
root/component READMEs, relevant architecture/development docs, decisions and this file.
No backend/mobile/schema changes, external provider calls, training, inference or
dataset operations were performed by this phase.

Git handoff: verified Phase 9 work is committed/pushed with a relevant message;
its identifier/result is reported in the final response. Unrelated local changes
remain outside the commit. Stop after Phase 9.

## Post-Phase 9 database client recovery (2026-10-07)

The user authorized recovery of the locally deleted `backend/src/database/client.ts`
if necessary. Inspection confirmed that backend startup, repositories, maintenance
commands, seed and database tests still import its shared-client/factory exports.
An independent read-only review confirmed that restoring the committed implementation
was the appropriate minimal fix.

Restored only this file with `git restore --source=HEAD --worktree`. Git's Windows
checkout produced CRLF line endings rejected by Biome; formatting only the restored
file returned it to the expected LF format. Its Git blob hash matches HEAD exactly,
so no backend implementation change remains. Other existing ignore/ML scaffold/README
changes were preserved and excluded from this documentation commit.

| Check | Result |
|---|---|
| Repository foundation | Required structure, documentation, environment templates and Git ignore/source visibility checks pass |
| Local documentation links | All 139 resolve; the previously missing database-client link is restored |
| Backend aggregate | Formatting, lint, strict typecheck, build, all 50 isolated foundation/auth/upload tests and compiled dependency probe pass |
| Prisma validation | Existing schema is valid; no migration/schema changes |
| Source integrity | Restored client matches HEAD; Git whitespace checks pass |

Commands: `git show HEAD:backend/src/database/client.ts`, import inspection with `rg`,
`git restore --source=HEAD --worktree -- backend/src/database/client.ts`, local Biome
formatting of that file, `scripts/check-repository.ps1`, `npm run check`,
`npm run db:validate`, local Markdown link verification and Git content/diff checks.
The Phase 9 repository/link failure is resolved. No later phase was started.

## Pre-Phase-10 audit (2026-10-07)

Read the whole authored project across backend/database, mobile/native and Python/shared/
training, including all configurations, environment templates, parsed dependency locks,
SQL migrations and tests. Traced actual layering/contracts, not only file presence.
The [full audit](23-pre-phase-10-audit.md) contains the required 18-section report,
all seven Node APIs plus FastAPI health, complete environment-variable inventory,
installed/required dependency matrix, coverage matrix and concrete user prerequisites.

| Phase | Fresh audit status |
|---|---|
| 0 | PASS — required roots/docs/templates/ignore rules |
| 1 | PASS WITH WARNINGS — environments work; optional Docker runtime absent and licenses/Python patch maintenance pending |
| 2 | PASS — schema/client/five migrations/catalog/invariants/live queries |
| 3 | PASS — strict backend architecture/health/errors/lifecycle |
| 4 | PASS WITH WARNINGS — backend auth/RBAC/session checks; native Flutter sessions deferred |
| 5 | PASS WITH WARNINGS — MVVM/design/routes/tests/debug APK; physical/iOS/release checks pending |
| 6 | NOT FULLY TESTABLE — explicitly skipped, no disease knowledge APIs/reviewed seeds |
| 7 | PASS WITH WARNINGS — live guest/farmer upload/replay/compensation; physical capture/scheduled cleanup pending |
| 8 | PASS — FastAPI process foundation, no model/Node orchestration implied |
| 9 | PASS WITH WARNINGS — shared source/parity/synthetic tests; field validation needs real data |

| Check | Fresh result |
|---|---|
| Backend aggregate | Format/lint/strict types/build/dependency probe; 50 isolated tests pass |
| Live backend database suites | 13 domain/catalog, six auth/session, seven scan/journal tests pass |
| Prisma and SQL | Format no diff, validation/client generation pass; five applied checksum-matching migrations, no structural drift; all five replay in only an owned temporary schema |
| Provider/Flutter integration | One checked-in live PNG/oriented-JPEG test, live Flutter upload and live Flutter health pass; additional farmer WebP ownership/replay/auth/logout probe passes |
| Backend count | 77 checked-in cases; supplemental audit probes counted separately |
| Database integrity | Neon PostgreSQL 18.6/vector0.8.6, 21 application tables, 21 checks/37 triggers/four partial indexes; before/after snapshots identical, all counts zero, no temporary schema |
| Flutter | Locked offline dependencies, format54 files/no change, analyzer no issues; 52 isolated and two separately executed live tests pass; debug APK builds |
| Python and shared | AI50/training5/shared78 in each venv/eight parity cases pass; Ruff/strict mypy/locked sync+checks+pip check/package build/compileall pass |
| FastAPI live/synthetic stress | Safe actual test/production startup/health/errors/shutdown; six deterministic synthetic scene/gate probes pass |
| Docker | Compose validation passes; Engine absent, no container runtime claim |
| Security | No configured private values/pattern matches across source candidates or 501 unique historical text blobs; no committed non-template .env; fresh npm audits still report four high aggregate findings |
| Repository/docs | Structure/templates/ignore/local links/Git whitespace pass after minimal documentation corrections |

The live checks used the already configured **development** Neon/Cloudinary account,
not production. Cleanup targeted only freshly generated fixtures/assets; no database
reset, deployment, seed, broad provider cleanup, training or model download occurred.
Remaining original workspace ignore/ML README/scaffold/state changes are preserved
outside the audit commit. No dependency/package/source/schema/migration changes.

Documentation corrections: current Flutter scanning, implemented provider/security
controls and shared preprocessing, backend timeout60/10/5 seconds, testing scope and
development debug packaging. Created this audit report and KNOWN_ISSUES.md; updated
root/AI READMEs and documentation index. DECISIONS.md stays unchanged because no actual
architecture/product decision was made.

Readiness categories:

- **Code:** no new P0/P1 defect; before inference define the reproduced Node/shared
  1×1/trailing-PNG admission/failure contract. The native mobile cookie/session client
  and Node→AI adapter remain deliberately unimplemented later work.
- **Configuration/credentials:** current DB/JWT/Cloudinary settings are configured and
  verified. Regular connected mobile builds still need public API_BASE_URL; no new
  secret, Gemini key, model path or internal service token is needed for local CPU training.
- **External data/files:** supply an actual raw original JPEG/PNG/WebP path, exact labels,
  source/license, available official split/group/augmentation-parent metadata and real
  representative images. Empty scaffold directories are not a dataset.
- **User decisions:** approve actual taxonomy/ambiguous-label policy, independent grouping/
  split provenance, CPU versus identified alternate target, and empirical shared mask
  policy after real-image review. No class count/split ratio/model choice was fabricated.
- **Manual/operational:** real-device camera/gallery checks and relevant Android licenses,
  cleanup scheduler for persistent API use, least-privilege/deployment/privacy choices
  at their proper phases. Docker/GPU/iOS are optional targets, not local CPU blockers.

The training environment and shared implementation are stable, but model training cannot
be justified until those data/empirical prerequisites are met. Training-only splitting,
augmentation/seed/class-map/checkpoint/metrics/plots/run manifests are future Phase 10
implementation, not completed files. Stop after this audit.

## Phase 9.5 dataset intake and real-image verification (2026-10-07)

- Configured the supplied absolute dataset path in ignored `ml-training/.env`.
  Added blank `DATASET_PATH` in `.env.example` and a cwd-independent loader with
  explicit OS precedence, no interpolation/global mutation, and directory validation.
  Future intake, validation and training read this same configuration.
- Added read-only `dataset_inventory.py` and `dataset_review.py`. Reports/debug images
  stay in ignored `.cache/dataset-review/phase95-20261007/`; output cannot overwrite
  existing files or sit inside the source dataset. All 8,040 source hashes/file stats
  were checked again after review and are unchanged.
- Exact classes/counts: Common_Rust 2,498; Gray_Leaf_Spot 1,087; Healthy 2,324;
  Northern_Corn_Leaf_Blight 2,131. All folders are flat; no official split exists.
  Inventory finds 3,854 excess exact copies, ten near-content pairs and three
  contradictory families covering seven filenames/five byte contents. No class was
  merged, relabeled, finalized or assigned a partition.
- Both canonical shared policies accept 8,029/reject 11. Conservative mode extracts
  only eight Rust files/four distinct contents and otherwise preserves the full frame.
  All 80 purposive comparisons plus the fourth extracted family were viewed. No obvious
  tissue/lesion deletion was observed in this sample; most clutter remains and small
  lesions soften through resize. Full-frame is recommended, with approval pending.
- Recovered both local source archives and matched every current byte hash. The
  PlantVillage color contribution duplicates the Corn collection. Original-image
  filenames/UUIDs and confirmed derivatives support grouping; sparse EXIF IDs/timestamps
  do not establish independent plants/sessions. Mixed license/individual rights notices
  leave intended-use eligibility unresolved. Private metadata stays ignored.
- Checks passed: training Ruff format/lint, strict mypy on four sources, 29 tests,
  locked environment/pip compatibility, 160 real-image/two-policy exact cross-environment
  parity cases, repository/template/ignore checks, local links, whitespace and private
  path/credential checks. New tests cover configuration, literal labels, duplicate
  conflicts, corrupt input, source immutability and safe output destinations.
- Updated current documentation and added the complete
  [Phase 9.5 report](24-dataset-intake-preprocessing-review.md). No source image,
  canonical preprocessing code/config/version, model, augmentation or permanent split
  was created/changed. The Phase 0–9 audit remains historical evidence.

## Phase 10 dataset preparation, training and evaluation (2026-10-07)

Historical v1 record: confirmed transformed-parent leakage found in Phase 10.5
invalidates independent-evaluation claims below. Preserve its artifacts; use v2 for
current fitness.

- Approved dataset policy is persisted in `ml-training/configs/research-policy.json`
  and hash-pinned family/invalid/confirmed-relative evidence in `group-evidence.json`.
  Exclude 18 filenames/16 unique contents: eleven shared-rejected inputs plus all seven
  members of three contradictory families. Collapse 3,852 remaining duplicate aliases.
  No original image is converted, relabeled, renamed, deleted or written.
- New `dataset_preparation.py` writes/verifies immutable eligibility, exclusions,
  literal class mapping, provenance, grouped stratified partitions and integrity hashes.
  Committed safe index: `ml-training/manifests/maize-research-20261007-v1/manifest.json`,
  semantic fingerprint `e1abe6c4bba09080371345365ab92067f1f08bfba9f927f66cbc9e58af6b5e98`.
  Future experiments reuse it and resolve source bytes only through `DATASET_PATH`.
- Fixed class counts (eligible/train/validation/test): Common_Rust 1301/910/196/195;
  Gray_Leaf_Spot 568/397/86/85; Healthy 1162/813/175/174;
  Northern_Corn_Leaf_Blight 1139/797/171/171. Seed 20261007; target 70/15/15;
  nine eligible confirmed-relative links stay together. All pairwise group/content
  intersections are empty; all 8,040 original names/bytes/sizes/mtimes match Phase 9.5.
- Shared preprocessing remains package **1.0.0**, with artifact-pinned disabled extraction,
  full-frame RGB/224 letterbox/CHW float32 and centrally configured ImageNet normalization.
  Fingerprint `b142e59f458d27a2d3fddbfc86c2f2f802670ab4909f1275babbef92de9cb5c8`.
  Generic defaults are preserved. Training-only mild flip/affine occurs after shared
  preprocessing; validation/test never use augmentation. Twelve synthetic and sixteen
  real TRAIN-image cases show exact training/AI wrapper parity with this configuration.
- New `model.py`, `training_data.py`, `train.py` and `evaluation.py` implement checked
  official MobileNetV3 Small weights, deterministic CPU transfer learning, AdamW/scheduler/
  validation-only checkpoint selection/early-stopping infrastructure, unique epoch files,
  strict restore parity, guarded final test and typed metrics/standalone plots. Matplotlib
  and its locked dependencies are added; 43 installed distributions pass compatibility.
- Actual `smoke-20261007-01`: 32 train/16 validation, one finite epoch, safe save/reload,
  exact fresh-model outputs, no test evaluation. Actual original run
  `mobilenet-v3-small-20261007-01`: ten completed epochs, then external terminal
  interruption during epoch 11. Its directory/checkpoints remain byte-identical.
  `mobilenet-v3-small-20261007-01-recovery` locks the unchanged epoch-10 validation
  winner before test, strictly restores it and completes evaluation without more fitting.
- Selected unaugmented train/validation/test accuracy: 99.5886%/95.7006%/95.2000%; macro
  F1: 0.9948/0.9411/0.9396. Test has 595 correct of 625, macro precision/recall
  0.9375/0.9421, weighted F1 0.9522 and macro OVR ROC-AUC 0.9946. Per-class P/R/F1,
  specificity, AUC, confusion, curves and fitting analysis are preserved. No test
  result determines hyperparameters, thresholds or selection; test is evaluated once.
- Best local model: `.cache/phase10/experiments/mobilenet-v3-small-20261007-01-recovery/checkpoints/epoch-010.pt`,
  SHA-256 `a7a08eb88510fd8f58c7a30f174935bf9d6a7bfe941a0eec876ff01d32154c6d`.
  [Committed aggregate report](../ml-training/reports/mobilenet-v3-small-20261007-01-recovery/README.md)
  retains 24 hash-verified numerical/code/provenance files plus integrity.json. Full local
  experiment retains immutable model and prediction CSVs. No raw source image is published.
- Checks: **92 tests**, Ruff format/lint on 19 files, strict mypy on nine source files,
  lock/pip compatibility, repository/templates/ignore, links, whitespace, credentials and
  private-path scans pass. An independent auditor recomputes every numerical metric from
  CSVs and validates parent/recovery/config/class/source/environment/checkpoint hashes;
  two zero-input strict restores agree. It performs no additional test-image inference.
- Fixed a pre-commit Windows Git newline-conversion issue that changed report byte
  hashes. Scoped `.gitattributes` retains frozen manifest/report bytes and LF training
  sources. All 34 hash-bound Git index files match their recorded SHA-256 identities.
- Reports/documentation/decisions/testing/development checks are updated. Backend,
  mobile, database, AI service and shared package source remain unchanged. No production
  model promotion or application inference occurs; stop after Phase 10.

## Phase 10.5 completion and verification

- Expanded transformed-photo review confirms 36 additional parent relations,
  including 22 crossings of the v1 partitions. V1 independent-evaluation claims
  are invalid; the original experiments and reported arithmetic remain preserved.
- New immutable `maize-research-20261008-v2` applies the existing contradictory-family
  policy to four newly confirmed families, groups all known relatives and retains
  the original splitter/seed. It contains 4,162 unique eligible contents in 4,121
  groups, split 2,911/627/624; all 8,040 raw files remain unchanged.
- A real 32/16 smoke passes before a fresh bounded classifier fit. Epoch 8 is selected
  by validation macro F1; patience 3 ends the run at epoch 11. Validation diagnostics,
  group-fold calibration, errors/CAM, TRAIN augmentation, source membership and ten
  fixed perturbation probes are reviewed before the candidate freeze.
- All 48 pre-test candidate references and 13 final artifact references validate.
  One post-freeze test scores 598/624 correct; no post-test model/policy change occurs.
  Critical-field rejection checks, independent saved-CSV arithmetic and exact 16-case
  TRAIN model compatibility across training/AI environments pass.
- Checks pass: 219 ML tests, 50 AI tests, 78 shared tests in each environment,
  12 synthetic preprocessing parity cases, Ruff formatting/lint and strict mypy.
  The safe aggregate export contains 98 files, including 93 byte-identical copies
  and 16 numerical plots; raw images and weights stay local/ignored.
- Updated the fitness report, project/ML documentation, known issues, roadmap and
  finalized decisions. No Phase 11 API or application integration is implemented.
  Read [model fitness](26-model-fitness-validation.md) for exact class counts, metrics,
  commands, artifact hashes and remaining limits.

## Phase 11 implementation and verification (2026-10-09)

- Added strict runtime validation for the approved checkpoint, SHA-pinned metadata
  and adjacent calibration sidecar, literal class mapping, model version, explicit
  full-frame preprocessing/normalization configuration, runtime dependencies and
  finite state keys/shapes/dtypes/output. Missing/incompatible artifacts fail startup
  with safe codes; the model is loaded once, frozen/eval and cleared on shutdown.
- Added authenticated `POST /api/v1/predict?top_k=4` with unchanged raw JPEG/PNG/WebP
  bytes and `GET /api/v1/model-health`. Existing public `/health` reports basic readiness.
  Startup requires the server-only token even on loopback. Settings/templates are
  explicit; paths resolve relative to the service and credentials remain ignored.
- Uses the exact shared 1.0.0 full-frame pipeline and tensor conversion. Admission
  enforces 5 MiB, ≥16-pixel sides, ≤16 million pixels, MIME/signature/container/full
  decode agreement and still images. Capacity is reserved before buffering; direct
  CPU callers are bounded too. Uploads have a default 10-second deadline.
- Returns class, confidence/top probabilities, model/preprocessing versions, duration
  and explicit uncertainty. With no approved threshold, all current predictions are
  `LOW_CONFIDENCE/THRESHOLD_UNCONFIGURED`. An optional separately pinned policy must
  declare validation-only provenance and bind the checkpoint/validation CSV; no real
  numerical policy is chosen, recalibration performed or TEST images revisited.
- Checks pass: **219 AI tests**, Ruff format/lint over 40 AI files, strict mypy over
  24 app files, **78 shared tests in each environment**, 12 exact synthetic parity
  cases, script lint/compilation, valid uv lock and 43 compatible installed packages.
  One existing Starlette/HTTPX warning remains; dependencies are unchanged.
- Serving exactly matches saved Phase 10.5 tensor/logit SHA values for **16 actual
  TRAIN samples**, four per literal class, via configured `DATASET_PATH`. Mean
  preprocessing/inference **17.75 ms**, median **15.94 ms**, range **11.20–51.40 ms**
  at batch one/two CPU threads, excluding transfer/response serialization; not an SLA.
- Actual loopback Uvicorn passes JPEG/PNG/WebP, auth, malformed/MIME/size cases,
  model readiness, Node-mismatch rejection and six simultaneous requests (one 200,
  five busy 503). Owned process shutdown exits 0; actual missing-checkpoint startup
  exits 3 with a safe error and no rejected path/secret. Final approved-model startup
  also passes after the strict dtype guard. Local measurements/logs remain ignored.
- Frozen Phase 10.5 source/model/report/index identities are preserved. No Node or
  Flutter feature changes, retraining, repeated TEST evaluation or raw dataset edits.
  Updated architecture/startup/API documentation and actual lifecycle decisions.
  See [production ML inference](27-production-ml-inference.md) for exact commands,
  request/response/error contracts, artifact hashes and remaining deployment limits.
- Final repository/template/ignore and whitespace checks pass; 235 local Markdown
  links resolve, 452 source candidates contain no private credentials/dataset path,
  and 171 frozen Phase 10.5 files match working/committed byte hashes. Existing
  unrelated workspace changes are preserved outside the Phase 11 commit.

## Current limitations and pending decisions

- V1 transformed-parent leakage invalidates historical independence claims; original
  run/recovery/artifacts remain immutable. Corrected v2 repairs all confirmed families
  and excludes four newly contradictory families without raw edits. Unresolved pair 24
  may relate TRAIN/VAL Healthy images; physical plant/session identity remains unavailable.
- Fresh v2 fits successfully with patience 3, stopping at epoch 11 with epoch 8 selected;
  mild internal overfitting (unaugmented accuracy gap 2.57 percentage points), no
  significant task underfitting. Test GLS recall 83.53%/F1 0.8659; Corn-only VAL GLS
  recall 2/9 and source accuracy 77.08% show domain weakness. Confident wrong
  predictions persist (three test errors above 0.99). Calibration cross-fitting does
  not improve diagnostics; calibration is disabled, T=1, and no threshold is locked.
- The corpus was previously inspected/its v1 test consumed. V2's single final test is
  descriptive; it is not fresh external/field validation. Classifier seed stability,
  plant/field independence, OOD/maize rejection and clinical/agronomic validity remain
  unestablished. Commercial clearance and deployment uncertainty policy remain open.

- Starlette TestClient emits one upstream deprecation warning recommending httpx2.
  Existing HTTPX remains locked and tests pass; a test-client migration is maintenance
  work rather than an unverified change to this phase's dependency baseline.
- Shared preprocessing has dataset-wide mechanical checks and sampled real-image
  visual review, without annotated lesion ground truth or independent field accuracy.
  Perimeter-camouflaged leaf edges can still be removed before uncertainty gates detect
  them; outward padding does not guarantee recovery. Resize can lose tiny lesions.
  Extraction retains background for almost all current images and does not identify
  maize. The user approved full-frame policy, invalid/conflicting-family exclusions and
  academic/FYP use. Commercial licensing or source replacement remains required. Future
  deployment needs worst-case memory/time profiling and target-platform codec parity;
  representative local latency and bounded six-request concurrency are now verified.
- Node security decoding accepts valid 1×1 PNG and PNG trailing bytes that the shared
  minimum-dimension/container policy rejects. Actual Phase 11 FastAPI rejects both;
  its exact contract is documented. Align Node eligibility or explicitly handle
  accepted-scan processing failure in Phase 12 without duplicating ML transforms.
- FastAPI provides classifier readiness, validated startup and internal predictions;
  retrieval/generation and Node orchestration remain future work. Deployment
  requires private networking, TLS, coordinated token rotation and deployment-specific
  limits. Generic library/server log events intentionally omit diagnostic messages
  to protect secrets. Python 3.11.0 remains the workstation baseline; provision a
  maintained 3.11 patch release for a new/production environment.

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
  localization, dark theme and remaining business workflows are future work. Upload
  supports guest mode and an injected farmer token source; no mobile login is invented.
  Android debug APK builds; physical devices, iOS scaffolding/permissions and release
  packaging/signing remain unverified. Public API configuration is required for upload.
- Interactive Android gallery/capture needs a responsive emulator or physical device;
  a previously recorded emulator-5554 System UI ANR blocked historical checks and was
  not reproduced or cleared by this audit. APK/plugin compilation, picker
  routing/error tests and complete live Flutter upload through a synthetic image source pass.
- Schedule `npm run scans:cleanup` from backend every five minutes for crash/unknown
  outcome recovery. No OS task/deployment worker was installed. Recovery depends on
  database/provider availability; completed-scan retention and deletion are deferred.
- Signed Cloudinary URLs are persistent bearer capabilities; avoid publishing/logging
  them. Original photos can retain EXIF/location data. Future owner-checked delivery
  policy and successful-scan retention require an explicit later decision.
- Docker Engine/Desktop is not installed. Compose configuration passes validation;
  container startup is unverified. The complete schema and pgvector are verified on Neon.
- The preserved native Windows PostgreSQL installation lacks pgvector binaries;
  install the extension before applying Phase 2 migrations there, or use Neon/pgvector Compose.
- pg 8.23 can emit a query-queue deprecation warning during Prisma internal related
  queries; verified transactions pass. Keep the current lock until future adapter/pg compatibility is checked.
- CPU ML environment and the first transfer-learning baseline are implemented;
  GPU/CUDA, further validation-only experiments and model promotion remain future work.
- Production hosting/promotion, actual sourced agricultural data/rules,
  embedding model/dimensions/indexes, AI provider credentials, detailed
  business APIs and completed-scan retention/Cloudinary deletion remain pending. The initial light
  design system is implemented; domain workflow designs remain future work.
- Seed data is intentionally empty. Database checks enforce structure/provenance presence;
  future services must validate full JSON contracts, agricultural sources, hashes, authorization,
  uploads, and deterministic formula semantics. Separate least-privilege runtime roles remain future work.

## Next step

Stop after Phase 11. Phase 12 Node/Python integration requires the next explicit
instruction and must use the documented admission/uncertainty contract. Independent
field validation and commercial
licensing/source replacement remain requirements before real farmer/commercial use.
Read [inference contracts](27-production-ml-inference.md), [model fitness](26-model-fitness-validation.md) and reconcile the next instruction
with the [roadmap](14-roadmap.md).
