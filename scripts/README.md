# Scripts

Phase 23.6 adds [check-farmer-remediation.mjs](check-farmer-remediation.mjs), invoked
only by the existing disposable-schema harness:

```powershell
ai-service/.venv/Scripts/python.exe scripts/check-e2e.py --only farmer-remediation
```

It drives real Flutter registration/login/knowledge widgets through the existing
Node/PostgreSQL and semantic-retrieval stack. Fixture account/hash/role/revocation
checks run only after schema isolation is verified. Flutter child environment is
allowlisted; no server credentials are forwarded. The parent drops the owned schema
and verifies unchanged production counts. This is host-widget verification, not
physical-device interaction. See [remediation evidence](../docs/phase-23-6-remediation-report.md).

Phase 23 adds [check-e2e.py](check-e2e.py), its connected Flutter
[journey helper](check-e2e.mjs), and a [test-only schema preloader](e2e-database-context.mjs).
Run the Python script with the AI environment from root, after backend build. It
requires existing direct DB/Cloudinary/model/Google/Gemini configuration and Flutter
on PATH. Each run creates an owned schema, copies sourced knowledge/model metadata,
runs explicit live checks and records separate logs/results under `.cache/phase23`.
`--only journey` or selected check names restrict the run; every run still verifies
raw SQL/Prisma schema isolation. Only generated accounts/images/owned assets and
synthetic calculator values are used. No source dataset or final-test rerun. See
the [test matrix](../docs/39-testing-e2e-verification.md).

Phase 22 adds [check-model-health.py](check-model-health.py) and its Node helper
[check-model-health.mjs](check-model-health.mjs). Run the Python script with the
AI virtual environment from root for a real pinned-model/Node/Flutter contract.
Registry access is enforced read-only; auth is ephemeral, images synthetic, and
RAG/generation disabled. No model promotion or final-test rerun. See
[model health](../docs/38-model-health-dashboard.md).

Phase 18 adds [check-yield.mjs](check-yield.mjs). After building the backend, run
`node --env-file=backend/.env scripts/check-yield.mjs` from root. It checks real
Node/Prisma/PostgreSQL reviewed-config publication/immutability/version/audit and
Flutter guest/farmer exact-unit contracts in one private rollback transaction.
No synthetic yield config or account/session/audit is committed. It requires the
current empty yield catalogue; no AI/Cloudinary/dataset access is used. See
[expected yield](../docs/34-expected-yield-calculator.md).

Phase 11 adds [serving parity verification](check-inference-parity.py). It uses
the configured approved model and `DATASET_PATH` loader, sends 16 frozen TRAIN
cases through the FastAPI app and compares exact tensor/logit hashes with saved
Phase 10.5 evidence. It records timing under a new ignored output path and never
reads TEST images or fits a model. See [inference verification](../docs/27-production-ml-inference.md).
The existing [start-ai.ps1](start-ai.ps1) now starts the model-backed internal
service; model files/settings and the server-only token must be configured.

Phase 10.5 adds [offline model compatibility](check-model-compatibility.py), restoring
the frozen candidate in training and AI environments on 16 TRAIN cases and measuring
local forward latency/memory. It adds no endpoint; choose a new ignored output.
The [fitness workflow](../docs/26-model-fitness-validation.md) documents deferred-test
fitting, validation diagnostics/freeze and the guarded single descriptive final test.
Use the corrected v2 manifest for new authorized experiments; v1 is historical.

Phase 10 adds configured [dataset preparation](../ml-training/dataset_preparation.py)
and [training](../ml-training/train.py). Use the committed immutable manifest for
future experiments; every smoke/full run has a new ignored output directory. Smoke
uses training/validation only. Full selection uses validation; the default workflow
evaluates test last. For fitness review, `--defer-test` leaves test evaluation to the
separate frozen-candidate evaluator after validation decisions are complete.
See [training/evaluation](../docs/25-ml-training-evaluation.md) for commands/artifacts.
Training checks cover all source/tests; preprocessing parity adds the pinned baseline
configuration for 12 synthetic cases across both Python environments.

Phase 9.5 adds the configured read-only
[dataset review command](../ml-training/dataset_review.py). It reads `DATASET_PATH`
through [the training loader](../ml-training/configuration.py), independent of cwd;
the local configuration value belongs in ignored `ml-training/.env` and the template
placeholder is blank. Future inventory, validation and training must reuse this loader.

From repository root, choose a new ignored directory for another review:

```powershell
ml-training/.venv/Scripts/python.exe ml-training/dataset_review.py --output .cache/dataset-review/local-review
```

The command inventories source files, compares both existing shared preprocessing
policies and writes development-only contact sheets/facts outside the dataset. It
refuses existing output, confirms source contents unchanged, and performs no training,
augmentation or permanent partitioning. The completed 8,040-file intake, 160 real-image
parity cases and remaining decisions are recorded in the
[Phase 9.5 readiness report](../docs/24-dataset-intake-preprocessing-review.md).
Training checks now include configuration/intake format/lint/types and fixture tests;
repository checks validate the blank dataset template and ignored local configuration.

Phase 9 adds [check-preprocessing-parity.py](check-preprocessing-parity.py).
`check-development.ps1 -Component Preprocessing` checks shared format/lint/types,
runs synthetic tests in both Python environments and verifies twelve identical
image/configuration cases through both installed consumer APIs. Training checks now
include Ruff/mypy. See [shared preprocessing](../docs/22-shared-preprocessing.md).

Phase 8 adds [start-ai.ps1](start-ai.ps1) for the configured FastAPI entrypoint.
`check-development.ps1 -Component AI` now runs Ruff format/lint, strict mypy and
service/dependency tests. See [AI foundation](../docs/21-ai-service-foundation.md).

Phase 7 adds [check-scan-upload.mjs](check-scan-upload.mjs), invoked from backend
with `npm.cmd run test:scans:mobile`. It starts a private ephemeral Node test server,
runs the opt-in Flutter upload ViewModel against real Cloudinary/PostgreSQL, and
removes only its synthetic asset/journal/scan. Requires Flutter on PATH and backend
server-only environment configuration. It does not deploy a server or print secrets.

Phase 12 extends that owned-fixture harness with `npm.cmd run test:inference:mobile`
(`--inference`): an already-running configured FastAPI classifier and a registered
approved model are required. It verifies Flutter -> Node -> FastAPI -> PostgreSQL ->
Flutter with actual Cloudinary and removes only its synthetic records/asset.
[check-image-admission-contract.py](check-image-admission-contract.py) and its Node
helper compare 56 generated cases against authoritative shared preprocessing without
dataset/model/network access. Run from root with the AI environment's Python.

Phase 13 adds `--inference --farmer` to the same upload harness. From `backend`,
run `node ../scripts/check-scan-upload.mjs --inference --farmer` after build.
It creates two throwaway farmers, supplies only generated credentials through the
Flutter child environment, verifies real native login/scan/history/detail/ownership/
logout, and removes its own asset/rows/users. The guest check remains unchanged.
See [farmer detection/history](../docs/29-farmer-detection-history.md).

Run `./scripts/check-repository.ps1` from any working directory using PowerShell and Git.
It resolves the repository relative to the script, verifies foundation and development configuration files/directories,
checks that templates contain no credentials, and checks Git ignore behavior without
creating probe files. It exits nonzero on failure and does not modify the repository.

Phase 19 adds [check-analytics.mjs](check-analytics.mjs). After backend build, run
`node --env-file=backend/.env scripts/check-analytics.mjs` from root. It verifies
real SQL aggregates, UTC/microsecond boundaries, multi-model counting, ownership,
empty users, date/cursor validation, natural query plans and the enabled Flutter
analytics contract. Synthetic accounts/sessions/scans/predictions/model metadata
remain in one private rollback transaction; before/after table counts must match.
Requires the configured PostgreSQL and Flutter on PATH; no AI/cloud/raw-dataset
request or production recommendation change occurs. Read
[farmer analytics](../docs/35-farmer-analytics.md).

Phase 20 extends that harness with `--admin`:
`node --env-file=backend/.env scripts/check-analytics.mjs --admin` from root.
The same private rollback fixture verifies system-wide aggregate/account/ownership
counts, bounded recent entries, the natural global query plan and enabled Flutter
Admin authentication/transport/Farmer-denial contract. It records only synthetic
plan metadata under ignored `.cache/phase20`; no model promotion or live provider
call occurs. The original no-flag Farmer checks remain supported. See
[Admin dashboard](../docs/36-admin-dashboard.md).

Phase 17 adds [check-fertilizer.mjs](check-fertilizer.mjs). Build the backend, then run
`node --env-file=backend/.env scripts/check-fertilizer.mjs` from root. With the current
empty recommendation catalogue it verifies actual ADMIN draft/publication/audit and
version/source behavior plus Flutter guest/farmer exact-unit contracts. All synthetic
accounts/rules/configurations/audits are visible only inside one private rolled-back
PostgreSQL transaction; no recommendation, cloud asset or AI call is committed.
See [fertilizer calculator](../docs/33-fertilizer-calculator.md) for prerequisites.

Phase 1 adds these scripts, invoked from the repository root:

| Script | Purpose |
|---|---|
| `initialize-dev-env.ps1` | Generate ignored local database credentials and component `.env` files without overwriting existing files |
| `initialize-auth-env.ps1` | Fill only missing/blank local JWT keys without printing secrets; also invoked by dev initialization |
| `create-admin.ps1` | Trusted operator prompt for a new ADMIN; masked password sent as UTF-8 stdin, no default account |
| `postgres-local.ps1 -Action Start/Check/Stop` | Operate an isolated native Windows development cluster using PostgreSQL 18 tools |
| `setup-python.ps1 -Component ai-service/ml-training/All` | Install locked dependencies into separate component virtual environments |
| `check-development.ps1 -Component Backend/AI/Training/Preprocessing/Flutter/Database/Prisma/Docker/All` | Run checks independently; aggregate failures when checking all |

Example:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Backend
```

`Docker` validates Compose configuration; it does not verify a running engine.
Database checks require a running development database. Flutter checks require
write access to the installed SDK cache. See [development setup](../docs/15-development-environment.md).
`Prisma` verifies an already migrated pgvector database; it does not apply migrations.
See [database operations](../docs/16-database-operations.md) for migration/replay/seed commands.

Phase 21 adds [check-admin-management.py](check-admin-management.py) and its Node
[contract helper](check-admin-management.mjs). From root, after backend build, run
`ai-service/.venv/Scripts/python.exe scripts/check-admin-management.py`. It requires
the existing server-side Google/Gemini and database configuration, creates a
generated disposable schema, starts private services and verifies actual reviewed
version/index/publication/retirement/source/audit and Flutter management flows.
Synthetic calculator values are confined to that schema. Cleanup drops only the
verified owned schema and checks unchanged production counts. No model training,
classifier promotion or raw dataset use occurs. Read
[Admin management](../docs/37-admin-management.md).

If Windows blocks script execution, use
`powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/check-repository.ps1`
from the repository root. This override applies only to that process.
