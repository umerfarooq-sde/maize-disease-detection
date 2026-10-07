# Documentation

The original numbered files are architecture drafts preserved during Phase 0.
Database design and environment/operations guides now describe verified infrastructure.
The remaining feature documents describe intended behavior.

| Document | Scope |
|---|---|
| [Project state](PROJECT_STATE.md) | Verified repository status, checks, issues, and next step |
| [Engineering decisions](DECISIONS.md) | Existing database decisions, audit corrections, and later-phase choices |
| [Known issues](KNOWN_ISSUES.md) | Prioritized unresolved findings, external inputs and deployment requirements |
| [Pre-Phase-10 audit](23-pre-phase-10-audit.md) | Phase 0–9 compatibility, APIs, environments, security, tests and specific user prerequisites |
| [Dataset intake and real-image review](24-dataset-intake-preprocessing-review.md) | Phase 9.5 configured inventory, exact labels, recovered provenance/rights, duplicate conflicts, shared-policy comparison, real parity and training readiness |
| [ML training and evaluation](25-ml-training-evaluation.md) | Phase 10 research/exclusion policy, immutable grouped partitions, shared full-frame baseline, smoke, transfer learning, checkpoints and evaluation |
| [System overview](01-system-overview.md) | Purpose, users, boundaries, and primary flow |
| [HLA](02-hla.md) | Logical components and trust boundaries |
| [HLD](03-hld.md) | Runtime interactions and failures |
| [LLD](04-lld.md) | Layering and contract guidance |
| [Database design](05-database-design.md) | Implemented 21-table schema (19 domain plus auth/upload journals), ERD, ownership, constraints, versions, and vectors |
| [API design](06-api-design.md) | Implemented health/response contracts and future candidate routes |
| [Flutter architecture](07-flutter-architecture.md) | Implemented MVVM foundation and future farmer workflows |
| [AI architecture](08-ai-architecture.md) | Implemented service foundation and future Python inference/grounding ownership |
| [ML pipeline](09-ml-pipeline.md) | Shared preprocessing, dataset hygiene, and evaluation |
| [RAG architecture](10-rag-architecture.md) | Source-grounded retrieval and generation |
| [Security](11-security.md) | Identity, uploads, credentials, and access controls |
| [Testing](12-testing.md) | Planned component and integration checks |
| [Deployment](13-deployment.md) | Deployable units and operational decisions |
| [Roadmap](14-roadmap.md) | Phase boundaries and next implementation step |
| [Development environment](15-development-environment.md) | Phase 1 toolchains, setup, independent checks, and runtime limitations |
| [Database operations](16-database-operations.md) | Phase 2 Prisma configuration, migrations, seed, verification, and database prerequisites |
| [Backend foundation](17-backend-foundation.md) | Phase 3 layout, startup settings, middleware, health, response contracts and lifecycle |
| [Authentication](18-authentication.md) | Phase 4 endpoints, Argon2id, JWT/cookie/session flow, replay revocation, CSRF, RBAC and admin CLI |
| [Flutter foundation](19-flutter-foundation.md) | Phase 5 structure, Provider/MVVM, farmer routes, design system, API configuration and checks |
| [Scan uploads](20-scan-uploads.md) | Phase 7 gallery/camera/preview, multipart contract, validation, Cloudinary, pending scans, retries, compensation and cleanup |
| [AI service foundation](21-ai-service-foundation.md) | Phase 8 app structure, settings, health, lifecycle, safe logs/errors, internal access, local startup and tests |
| [Shared preprocessing](22-shared-preprocessing.md) | Phase 9 one package, conservative extraction/fallback, typed configuration, provenance, debug utilities, parity and Phase 9.5 real-image evidence |

The shared preprocessing location is implemented; finalize detailed business API
contracts, feature workflows and evaluated model compatibility in their phases. Do not treat
candidate designs as approved implementation details.
