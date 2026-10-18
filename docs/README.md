# Documentation

Current Phase 25 work and executable operator commands:
[deployment and release engineering](phase-25-deployment-release-engineering.md).
Verification is ongoing; Docker execution/hosted release are not claimed. Entries
below retain historical phase handoffs.

**Phase24.6 current addendum (2026-10-17):** Current remediation, original requirements, component/vertical-slice changes and actual test evidence are in the Phase24.6 report and linked matrices. Phase24.5 remains a historical audit; no Phase25/26 starts.

See [remediation and current evidence](phase-24-6-pre-deployment-remediation.md). Historical phase details follow.

Current handoff: [Phase 24.5 master system audit](phase-24-5-master-system-audit.md)
and its [findings/remediation register](phase-24-5-findings.md). **NOT READY FOR PHASE 25**:
default AI startup configuration and original application/contract gaps require
targeted remediation. Full FYP status is partially complete; conditional external
content, policy and device gates remain. No deployment has started.

Previous handoff: [Phase 24 security hardening and verification](phase-24-security-hardening.md),
[Phase 23.7 original requirements matrix](phase-23-7-requirements-completion.md),
[profile/Admin accounts/audit contracts](41-profile-accounts-audit.md) and the
[calculator source/approval checklist](calculator-domain-input-checklist.md).
Phase 24 security work is complete with documented limitations; its readiness
statement is superseded by the broader Phase 24.5 audit. Licensed disease media and real
calculator content remain explicit limitations.

The original numbered files are architecture drafts preserved during Phase 0.
Database design and environment/operations guides now describe verified infrastructure.
Feature guides contain dated implementation contracts and explicit future boundaries.
Use the current completeness audit to distinguish working code from target designs.

| Document | Scope |
|---|---|
| [Project state](PROJECT_STATE.md) | Verified repository status, checks, issues, and next step |
| [Master system audit](phase-24-5-master-system-audit.md) | Current Phase 24.5 verdict, actual architecture, original completeness and exact next action |
| [All phase statuses](phase-24-5-phase-matrix.md) | Every requested phase, including decimal audits/remediations, current source/test evidence and limitations |
| [Original requirements](phase-24-5-requirements-matrix.md) | Farmer/Admin/ML/RAG/nonfunctional traceability and mandatory versus approved-limited/optional scope |
| [Component connections](phase-24-5-components.md) | As-built diagram, producers/consumers, failures/configuration and reserved versus incomplete structures |
| [Current API contracts](phase-24-5-api-contracts.md) | All 44 Node and 10 AI operations, schemas/auth/DTOs/Flutter/downstream/tests; not a generated OpenAPI replacement |
| [Vertical slices](phase-24-5-vertical-slices.md) | Nineteen UI-to-provider-to-returned-state journeys and cross-layer identity bindings |
| [Database ownership](phase-24-5-database-ownership.md) | Actual 21 tables/nine migrations, writers/readers, ownership and SQL invariants |
| [Fresh verification](phase-24-5-verification-matrix.md) | Commands, counts/skips, failed default startup, explicit test configuration, live versus mock and cleanup evidence |
| [Findings](phase-24-5-findings.md) | P0–P3 priority, exact locations, remediation and Phase 25/FYP gates |
| [User/manual gates](phase-24-5-manual-gates.md) | Required content/approval/device inputs and legitimate future infrastructure scope |
| [Phase 24 security report](phase-24-security-hardening.md) | Threat model, genuine fixes, image privacy, dependency advisories, test results, unchanged retention and release gates |
| [Phase 23.6 remediation](phase-23-6-remediation-report.md) | Registration and real farmer knowledge UI, live verification, original-requirement corrections and readiness |
| [Farmer registration and knowledge](40-farmer-registration-knowledge.md) | Current Flutter MVVM routes, auth/catalogue/search contracts, source display and test commands |
| [Phase 23.5 completeness audit](phase-23-5-completeness-audit.md) | Phase 0–23 verdict/matrix, actual feature wiring, real/mock evidence, user inputs/manual actions and deferred work |
| [Endpoint inventory](phase-23-5-endpoint-inventory.md) | All 35 Node routes: validation, roles, controller/service/repository, consumers and real evidence |
| [Configuration inventory](phase-23-5-configuration-inventory.md) | All 70 runtime template entries and test/tooling inputs, presence only, no secret values |
| [Engineering decisions](DECISIONS.md) | Existing database decisions, audit corrections, and later-phase choices |
| [Model health dashboard](38-model-health-dashboard.md) | Phase 22 registry/readiness, pinned offline metrics and process-local operational signals |
| [Testing and E2E verification](39-testing-e2e-verification.md) | Phase 23 component/live/failure/E2E matrix, isolation, skipped tests and product/device gaps |
| [Known issues](KNOWN_ISSUES.md) | Prioritized unresolved findings, external inputs and deployment requirements |
| [Pre-Phase-10 audit](23-pre-phase-10-audit.md) | Phase 0–9 compatibility, APIs, environments, security, tests and specific user prerequisites |
| [Dataset intake and real-image review](24-dataset-intake-preprocessing-review.md) | Phase 9.5 configured inventory, exact labels, recovered provenance/rights, duplicate conflicts, shared-policy comparison, real parity and training readiness |
| [ML training and evaluation](25-ml-training-evaluation.md) | Phase 10 research/exclusion policy, immutable grouped partitions, shared full-frame baseline, smoke, transfer learning, checkpoints and evaluation |
| [Model fitness and generalization audit](26-model-fitness-validation.md) | Phase 10.5 transformed-photo leakage investigation, immutable grouped repair, fresh training, validation-only calibration/robustness and frozen descriptive final evaluation |
| [Production ML inference](27-production-ml-inference.md) | Phase 11 pinned artifact startup, exact shared full-frame serving, internal prediction/model-health contracts, image admission, uncertainty and parity/timing verification |
| [Node/FastAPI integration](28-node-fastapi-integration.md) | Phase 12 compatible admission, unchanged-byte internal client, durable scan lifecycle/predictions, owned reads, recovery and Flutter response compatibility |
| [Farmer detection and history](29-farmer-detection-history.md) | Phase 13 complete scan/results, honest uncertainty, volatile farmer sessions, private paginated history, scoped MVVM and integration checks |
| [Knowledge and retrieval](30-knowledge-retrieval.md) | Phase 14 sourced catalogue, immutable ingestion/chunks, Google embeddings, pgvector, public/internal contracts and real retrieval evaluation |
| [Grounded generation](31-grounded-generation.md) | Phase 15 bounded reviewed context, official Gemini SDK, verified excerpts/citations, immutable scan explanations, abstention, access controls and server-only setup |
| [Farmer AI assistant](32-farmer-ai-assistant.md) | Phase 16 scoped Flutter conversation, MVVM/repositories, visible sources, private farmer scan explanations, bounded follow-ups, volatile privacy boundaries and tests |
| [Fertilizer calculator](33-fertilizer-calculator.md) | Phase 17 exact decimal quantities/units, reviewed immutable rules/configurations, ADMIN publication, Flutter MVVM and pending real recommendation content |
| [Expected-yield calculator](34-expected-yield-calculator.md) | Phase 18 deterministic dimensional framework, exact units, immutable reviewed configuration, Flutter planning UX and pending authoritative agronomic model/rates |
| [Farmer analytics](35-farmer-analytics.md) | Phase 19 owner-filtered usage/prediction aggregates, bounded UTC dates, recent activity, private Flutter charts and rollback/query-plan verification |
| [Admin dashboard](36-admin-dashboard.md) | Phase 20 ADMIN-only system aggregates, distinct native sign-in/navigation, account/scan charts, honest model/telemetry state and rollback contracts |
| [Admin management](37-admin-management.md) | Phase 21 reviewed disease/knowledge/source/version forms, explicit RAG rebuild/publication, immutable calculator management and audit controls |
| [System overview](01-system-overview.md) | Purpose, users, boundaries, and primary flow |
| [HLA](02-hla.md) | Logical components and trust boundaries |
| [HLD](03-hld.md) | Runtime interactions and failures |
| [LLD](04-lld.md) | Layering and contract guidance |
| [Database design](05-database-design.md) | Implemented 21-table schema (19 domain plus auth/upload journals), ERD, ownership, constraints, versions, and vectors |
| [API design](06-api-design.md) | Implemented health/response contracts and future candidate routes |
| [Flutter architecture](07-flutter-architecture.md) | Implemented MVVM foundation and future farmer workflows |
| [AI architecture](08-ai-architecture.md) | FastAPI classifier, retrieval/generation ownership and architectural boundaries |
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
contracts and feature workflows in their phases. Approved model compatibility and
internal serving are verified in Phase 11. Do not treat
candidate designs as approved implementation details.
