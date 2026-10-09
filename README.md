# MAIZEDOCTOR

AI-powered maize disease detection and agricultural decision support for farmers,
with administrative tools for maintaining knowledge and monitoring the system.

## Current status

Phase 10.5 is complete: **FIT WITH DOCUMENTED LIMITATIONS** for a local research/FYP
inference prototype. The audit found transformed-photo leakage in the original v1
partitions; its independence claim is invalid. The corrected immutable v2 contains
**4,162 unique contents / 4,121 groups**, split **2,911 train / 627 validation / 624
test**, with no confirmed group leakage. Raw source files remain unchanged/external.

Fresh MobileNetV3 Small fits successfully for 11 epochs (patience 3, best epoch 8), scoring
**96.81% validation accuracy / 0.9589 macro F1** and **95.83% final descriptive test
accuracy / 0.9452 macro F1**. This reused public corpus is not an independent field
holdout. Gray Leaf Spot, source-domain and confident-error limitations are explicit;
raw probabilities are retained and no confidence threshold is locked. See
[model fitness](docs/26-model-fitness-validation.md). Use remains non-commercial
academic/FYP research without raw redistribution or commercial clearance. Shared
preprocessing, existing FastAPI/Flutter/backend/database features are preserved;
production inference and application integration remain future work.
See [project state](docs/PROJECT_STATE.md) for verified progress and outstanding decisions.
Use the [development setup guide](docs/15-development-environment.md) for commands and limitations.
Use [database operations](docs/16-database-operations.md) for migration and verification commands.
Use [backend foundation](docs/17-backend-foundation.md) for server setup and HTTP contracts.
Use [authentication](docs/18-authentication.md) for credentials, cookies, endpoints and admin provisioning.
Use [Flutter foundation](docs/19-flutter-foundation.md) for mobile setup, design tokens, routes and tests.
Use [scan uploads](docs/20-scan-uploads.md) for request contracts, validation, privacy and cleanup operations.
Use [AI service foundation](docs/21-ai-service-foundation.md) for Python startup, health, internal access and checks.
Use [shared preprocessing](docs/22-shared-preprocessing.md) for the single training/serving pipeline and its limitations.
Use the [pre-Phase-10 audit](docs/23-pre-phase-10-audit.md) and [known issues](docs/KNOWN_ISSUES.md)
for environment results and compatibility findings. Use the
[dataset intake and preprocessing review](docs/24-dataset-intake-preprocessing-review.md)
for historical dataset findings, visual artifacts and provenance.

## Planned architecture

```text
Flutter -> Node.js / TypeScript REST API -> PostgreSQL (Prisma)
                         |
                         +-> Cloudinary
                         +-> Python FastAPI -> shared preprocessing -> PyTorch
                                           -> RAG -> Gemini
```

- Flutter uses MVVM, Provider/ChangeNotifier, and repositories.
- The backend uses routes, controllers, services, and repositories with `/api/v1` APIs.
- Python owns image processing, inference, retrieval, and Gemini interaction.
- Training and inference must import one preprocessing implementation.
- Agricultural knowledge must be grounded in curated sources; calculator arithmetic is deterministic.
- Planned roles are `FARMER` and `ADMIN`. Anonymous scans have a nullable user reference;
  authenticated scans belong to the farmer.

## Repository

| Directory | Purpose |
|---|---|
| [mobile/](mobile/README.md) | Flutter application |
| [backend/](backend/README.md) | Node.js + TypeScript API and Prisma persistence |
| [ai-service/](ai-service/README.md) | Python + FastAPI AI service |
| [ml-training/](ml-training/README.md) | Dataset validation, training, evaluation, and experiment tracking |
| [docs/](docs/README.md) | Architecture and technical documentation |
| [scripts/](scripts/README.md) | Development and repository automation |
| [infrastructure/](infrastructure/README.md) | Local PostgreSQL Compose and native development configuration |
| [shared/preprocessing/](shared/preprocessing/README.md) | One reusable Python preprocessing package for training and serving |

Read [AGENTS.md](AGENTS.md) before changing the project. Architecture drafts are
design guidance, not evidence that features exist.

## Environment configuration

Templates contain server-only settings or public mobile configuration. Generate ignored
local database settings without printing passwords:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/initialize-dev-env.ps1
```

Populate secrets locally or through deployment secret management. Templates leave all
credentials blank. Backend and AI database access will need separate least-privilege
credentials in later phases. Prisma and database checks read backend `.env`; cloud
transaction poolers need a separate `DIRECT_DATABASE_URL` for migration sessions.
Mobile configuration contains only a public API URL and may later be
supplied through Flutter build configuration; never supply server secrets to Flutter.
No provider account, dataset, or model artifact is needed for environment smoke checks.

Dataset intake reads `DATASET_PATH` from ignored `ml-training/.env`, independent of
the working directory. The supplied local value is configured; the committed
`ml-training/.env.example` placeholder remains blank. An explicitly set OS variable
takes precedence. Future inventory, preprocessing validation and training must call
`load_dataset_path()` from the training configuration module rather than hardcode a
machine path. See [ML configuration and commands](ml-training/README.md).

## Repository checks

From the repository root, using PowerShell and Git:

```powershell
./scripts/check-repository.ps1
git diff --check
git status --short --branch
```

The [development setup guide](docs/15-development-environment.md) describes TypeScript
compilation, Python environment tests, Flutter analysis/tests, and PostgreSQL/Compose checks.

If Windows blocks script execution, run the check with a process-only policy override:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/check-repository.ps1
```

This does not change the machine's persistent execution policy.

## Next step

Stop after Phase 10.5. Phase 11 may begin for a separately authorized FYP prototype
using the frozen v2 candidate and its documented limitations; no Phase 11 functionality
is implemented here. See [fitness audit](docs/26-model-fitness-validation.md) and
[roadmap](docs/14-roadmap.md).
