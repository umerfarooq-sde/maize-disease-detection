# MAIZEDOCTOR

AI-powered maize disease detection and agricultural decision support for farmers,
with administrative tools for maintaining knowledge and monitoring the system.

## Current status

Phase 5 adds the Flutter farmer shell, reusable design system, responsive navigation,
MVVM/Provider structure and a typed API client with a real backend health check.
The Phase 4 authentication backend and Phase 2 PostgreSQL + Prisma persistence remain
available. Mobile sign-in, scanning, disease/calculator APIs, AI services, trained
models and the admin dashboard remain future work; feature foundation screens show
their availability honestly.
See [project state](docs/PROJECT_STATE.md) for verified progress and outstanding decisions.
Use the [development setup guide](docs/15-development-environment.md) for commands and limitations.
Use [database operations](docs/16-database-operations.md) for migration and verification commands.
Use [backend foundation](docs/17-backend-foundation.md) for server setup and HTTP contracts.
Use [authentication](docs/18-authentication.md) for credentials, cookies, endpoints and admin provisioning.
Use [Flutter foundation](docs/19-flutter-foundation.md) for mobile setup, design tokens, routes and tests.

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

Stop after Phase 5 Flutter foundation. Wait for an explicit instruction before
implementing business features. See the [roadmap](docs/14-roadmap.md).
