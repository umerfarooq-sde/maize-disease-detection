# Scripts

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
runs synthetic tests in both Python environments and verifies eight identical
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

Run `./scripts/check-repository.ps1` from any working directory using PowerShell and Git.
It resolves the repository relative to the script, verifies foundation and development configuration files/directories,
checks that templates contain no credentials, and checks Git ignore behavior without
creating probe files. It exits nonzero on failure and does not modify the repository.

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

If Windows blocks script execution, use
`powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/check-repository.ps1`
from the repository root. This override applies only to that process.
