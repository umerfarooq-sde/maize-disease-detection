# Phase 24.5 — phase completeness matrix

Audit baseline: `840f7fdbd26a6a68797af86934145297aeda7eaa`, 2026-10-16.
Statuses describe the current implementation, including later repairs. They do not
retroactively make the original v1 ML split independent or erase historical failures.
See the [requirements matrix](phase-24-5-requirements-matrix.md) for original-product
requirements exceeding the narrower completed phase scopes. Checks are recorded in
the [fresh verification ledger](phase-24-5-verification-matrix.md).

| Phase | Current status | Source / persistence / transport / consumer | Verification and limit |
|---|---|---|---|
| 0 | COMPLETE AND VERIFIED | Root directories, AGENTS, README, docs, ignore files and environment templates | Repository check; no initialized project was rebuilt |
| 1 | COMPLETE WITH VERIFIED LIMITATIONS | Locked Flutter/Node/Python environments; scripts; local PostgreSQL Compose | All development checks and Android packaging; Compose validation does not prove a running container daemon |
| 2 | COMPLETE AND VERIFIED | Prisma schema, SQL checks/triggers, seed structure, shared database client | Live catalog, client generation, migration status, rollback tests and drift check |
| 3 | COMPLETE WITH VERIFIED LIMITATIONS | `backend/src/app.ts`, `application.ts`, config/middleware/errors/modules | Strict types, build, foundation tests, health; original generated Node OpenAPI requirement remains missing |
| 4 | COMPLETE AND VERIFIED | Auth route/controller/service/repository; `users`, `auth_sessions`; mobile session repositories | Registration/login/rotation/revocation/RBAC tests and live journeys; volatile mobile sessions are an explicit later decision |
| 5 | COMPLETE WITH VERIFIED LIMITATIONS | `mobile/lib/core`, `app.dart`, route-local Providers, typed data repositories, farmer shell | Analyzer, format, ViewModel/repository/widget/navigation tests; physical-device acceptance absent |
| 6 | COMPLETE WITH VERIFIED LIMITATIONS | Disease catalogue/detail/search; sourced documents and chunks; Knowledge ViewModels/views | Four real classes, 25 sourced sections; missing media and broader metadata/CRUD are original-product gaps, not fictitious completed features |
| 7 | COMPLETE AND VERIFIED | Scan image picker/upload/preview; scan service/storage/repository; Cloudinary; upload journal | Live guest/farmer upload and protected-image tests; original inference bytes preserved by Phase 24 |
| 8 | COMPLETE AND VERIFIED | FastAPI app factory/lifespan, config, logging, schemas, errors, internal authentication | Foundation/startup/shutdown/health tests and live service startup |
| 9 | COMPLETE AND VERIFIED | `shared/preprocessing/src/maizedoctor_preprocessing` imported by training and serving | 78 tests in each environment and 12 exact synthetic parity cases; approved full-frame baseline intentionally disables extraction |
| 9.5 | COMPLETE WITH VERIFIED LIMITATIONS | Intake/review reports, reusable `configuration.py`/DATASET_PATH, manifests | Frozen review evidence inspected; raw source images are not re-inventoried during this audit; research license limitations persist |
| 10 | COMPLETE WITH VERIFIED LIMITATIONS | `ml-training` dataset/training/evaluation tools and versioned artifacts | Fixture/tooling tests; original v1 independence claim invalidated and repaired by 10.5; no fit or final-test rescore here |
| 10.5 | COMPLETE WITH VERIFIED LIMITATIONS | v2 manifests, lineage/exclusions, selected checkpoint and fitness reports | Independently checked 4, 162 unique contents / 4, 121 groups, zero known-group leakage and pinned hashes; no independent field validation |
| 11 | BROKEN / REGRESSION | FastAPI artifact loader/service is implemented, but current local optional confidence hash/path settings disagree | Unmodified configured service refuses startup (correct guard, AUD-01). Explicit approved null-policy override permits actual pinned-model verification; artifacts/cutoff are not changed |
| 12 | IMPLEMENTED BUT INTEGRATION INCOMPLETE | Node inference client, admission contract, scan lifecycle and transactional predictions | Contracts and explicit-policy live Node → FastAPI → checkpoint → PostgreSQL checks pass; default combined service remains blocked by AUD-01 |
| 13 | COMPLETE WITH VERIFIED LIMITATIONS | Scan/result/history ViewModels, repositories and views | Real integrated host-widget/API flows, owner pagination and error tests; guidance is a separate assistant/library journey, not inline result sections |
| 14 | COMPLETE WITH VERIFIED LIMITATIONS | AI chunking, Google embedding provider, pgvector repository/retrieval, sourced corpus | Real provider/SQL retrieval and isolated indexing tests; bounded four-context corpus, no unapproved web scraping |
| 15 | COMPLETE WITH VERIFIED LIMITATIONS | Central prompts/context, official Google SDK, structured evidence selection and server-rendered excerpts | Real grounded generation plus deterministic injection/conflict/failure tests; deliberate conservative excerpt policy, no unchecked factual paraphrases |
| 16 | COMPLETE WITH VERIFIED LIMITATIONS | Assistant ViewModel/repository/datasource; Node generation; owned scan context | Live bounded chat/scan explanation/citations, scope and ownership tests; route-local 12-turn history, no persisted conversations |
| 17 | BLOCKED BY APPROVED EXTERNAL INPUT | Exact-unit fertilizer engine, versioned reviewed rule publication and Flutter UX | Framework passes synthetic arithmetic/live fixture tests; actual catalogue PENDING_RULES; nutrient recommendation functionality also requires a justified model |
| 18 | BLOCKED BY APPROVED EXTERNAL INPUT | Exact-unit yield projection, immutable configuration and Flutter UX | Framework passes synthetic calculations; actual catalogue PENDING_CONFIGURATION; min/expected/potential forecasting is not implemented |
| 19 | COMPLETE AND VERIFIED | Farmer owner/date-filtered SQL aggregates, activity pagination, charts | Actual DB/repository/Flutter checks; these are usage/prediction statistics, never ground-truth model accuracy |
| 20 | PARTIALLY IMPLEMENTED | Admin aggregates, separate Admin session/navigation, overview cards | Actual account/scan statistics verified; original AI operational monitoring is NOT_RECORDED, with no request metrics producer/UI |
| 21 | PARTIALLY IMPLEMENTED | Reviewed knowledge draft/index/publish/archive, display metadata, calculator management | RBAC/version/audit/index/invalidation verified; richer disease management/media and complete original fertilizer-management scope remain partial |
| 22 | COMPLETE WITH VERIFIED LIMITATIONS | Admin model health → Node registry/client → AI pinned development snapshot and runtime counters | Actual model/dashboard contract; offline metrics separate from process-local runtime; no trainedAt timestamp, durable cluster monitoring or formal drift |
| 23 | COMPLETE WITH VERIFIED LIMITATIONS | Component suites, isolated DB/provider/E2E harness and failure simulations | Current unmodified full harness fails AUD-01; explicit approved-policy configuration is separately verified. Host-widget/provider integration is not physical-phone or public-release acceptance |
| 23.5 | COMPLETE WITH VERIFIED LIMITATIONS | Historical completeness audit and inventories | Historical registration/Knowledge bugs are resolved by 23.6; broader original scope was corrected by 23.7; old claims are not current verdicts |
| 23.6 | COMPLETE AND VERIFIED | Registration form/ViewModel/repository and real Knowledge catalogue/search/detail | Current source and fresh farmer-remediation live gate; old placeholder wording in the legacy journey is stale evidence metadata |
| 23.7 | COMPLETE WITH VERIFIED LIMITATIONS | Profile/photo journal, Admin farmers/status/revocation/audit viewer; ninth migration | Current live persistence/rollback/ownership tests; new AUD-16 delayed-cleanup response issue remains; licensed media and calculator fallback explicitly permitted, not full product completion |
| 24 | COMPLETE WITH VERIFIED LIMITATIONS | Protected private images, metadata-free display copies, bounded Argon2, TLS/privilege guards, dependency/runtime and subprocess isolation | Fresh security regressions plus dependency checks; production roles/network/privacy/device gates remain; no protection was relaxed |

The previous security verdict concerns hardening of implemented paths. It does not
certify the original product's missing Admin/content/calculation capabilities.
