# Documentation

The original numbered files are architecture drafts preserved during Phase 0.
Database design and environment/operations guides now describe verified infrastructure.
The remaining feature documents describe intended behavior.

| Document | Scope |
|---|---|
| [Project state](PROJECT_STATE.md) | Verified repository status, checks, issues, and next step |
| [Engineering decisions](DECISIONS.md) | Existing database decisions, audit corrections, and later-phase choices |
| [System overview](01-system-overview.md) | Purpose, users, boundaries, and primary flow |
| [HLA](02-hla.md) | Logical components and trust boundaries |
| [HLD](03-hld.md) | Runtime interactions and failures |
| [LLD](04-lld.md) | Layering and contract guidance |
| [Database design](05-database-design.md) | Implemented 19-table schema, ERD, ownership, constraints, versions, and vectors |
| [API design](06-api-design.md) | Implemented health/response contracts and future candidate routes |
| [Flutter architecture](07-flutter-architecture.md) | Implemented MVVM foundation and future farmer workflows |
| [AI architecture](08-ai-architecture.md) | Python ownership, inference, and grounding |
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

Finalize detailed business API contracts, feature screen workflows, and preprocessing package
location in the appropriate phases. Do not treat
candidate designs as approved implementation details.
