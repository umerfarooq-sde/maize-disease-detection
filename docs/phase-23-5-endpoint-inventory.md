# Phase 23.5 explicit Node endpoint inventory

**Historical consumers:** Phase 23.6 now connects registration and disease list/detail/
semantic search to production Flutter views. No endpoint was added or changed. See
[current handoff](40-farmer-registration-knowledge.md). The original master brief also
explicitly includes profile customization, Admin user management and audit viewing;
the scope-dependent wording below is corrected by the [remediation report](phase-23-6-remediation-report.md).

All 35 explicitly registered routes use `/api/v1`. Express may additionally answer
HEAD/OPTIONS through framework middleware; those are not extra business APIs.

Each row was traced through [route registration](../backend/src/routes/index.ts) and
[application dependency wiring](../backend/src/app.ts). `REAL VERIFIED (Phase 23)`
means retained successful real service contracts inspected during this audit; it
does not claim every mutation was replayed against user data today. Phase 23.5
fresh probes were read-only; earlier isolated-fixture results are identified.

All route groups additionally inherit JSON limits, CORS/security headers, request
IDs, global limits and centralized safe errors. Public image display can use a
Node-issued Cloudinary delivery URL; no client Cloudinary secret API is called.

| Method | Path | Module | Authentication/authorization | Validation | Controller -> service -> repository | Database interaction | Flutter consumer | Real integration |
|---|---|---|---|---|---|---|---|---|
| GET | /api/v1/health | health | Public | Empty request | health controller -> health service -> health repository | SELECT 1 | Home/connection card | REAL VERIFIED (fresh Flutter/Node/DB) |
| POST | /api/v1/auth/register | auth | Public FARMER enrollment | strict registrationCredentials; FARMER only | auth controller.register -> auth service -> auth repository | users | MISSING production registration UI; test consumer only | REAL VERIFIED (Phase 23) |
| POST | /api/v1/auth/login | auth | Credentials | strict loginCredentials + CSRF header | auth controller.login -> auth service -> auth repository | users/auth_sessions | Farmer and Admin SessionRepository | REAL VERIFIED (Phase 23) |
| POST | /api/v1/auth/refresh | auth | Refresh cookie | empty JSON + restricted refresh cookie | auth controller.refresh -> auth service -> auth repository | auth_sessions transactional rotation/replay | Shared serialized native session repository | REAL VERIFIED (Phase 23) |
| POST | /api/v1/auth/logout | auth | Refresh cookie | empty JSON + restricted refresh cookie | auth controller.logout -> auth service -> auth repository | auth_sessions revocation | Farmer/Admin sign-out | REAL VERIFIED (Phase 23) |
| GET | /api/v1/auth/me | auth | FARMER or ADMIN | empty request + live access session | auth controller.me -> auth service -> auth repository | auth_sessions/users | Test/extension consumer; identity from login/refresh grant | REAL VERIFIED (Phase 23) |
| POST | /api/v1/scans | scans | Guest or FARMER; ADMIN denied | Zod key/params/query + multipart + authoritative byte admission | createScanController -> scan service.create -> scan repository + storage/inference clients | scan_uploads/scans/scan_predictions/model_versions | Scan ViewModel/ScanRepository | REAL VERIFIED (Phase 23) |
| GET | /api/v1/scans | scans | FARMER owner | limit 1-50/UUID cursor | scanHistoryController -> scan service.history -> scan repository | Owned scan/prediction history | History/scan picker/analytics detail | REAL VERIFIED (Phase 23) |
| GET | /api/v1/scans/:scanId | scans | FARMER owner or guest original private key | UUID + strict empty query + capability key | readScanController -> scan service.read -> scan repository | Owned scan/prediction | Result/history repositories | REAL VERIFIED (Phase 23) |
| GET | /api/v1/diseases | knowledge | Public ACTIVE records | diseaseListRequest | knowledge controller.list -> knowledge service -> knowledge repository | diseases/active documents/sources | MISSING farmer catalogue UI | REAL VERIFIED (fresh catalogue HTTP; earlier live corpus contract) |
| GET | /api/v1/diseases/:slug | knowledge | Public ACTIVE records | diseaseDetailRequest | knowledge controller.detail -> knowledge service -> knowledge repository | diseases/active documents/sources | MISSING farmer knowledge detail UI | REAL VERIFIED (fresh catalogue HTTP; earlier live corpus contract) |
| POST | /api/v1/knowledge/search | knowledge | Public | knowledgeSearchRequest: bounded text/enums/topK | knowledge controller.search -> service -> AI client -> Python retrieval repository | pgvector/active source-backed chunks | MISSING browse/search UI; intentionally separate from assistant ask | REAL VERIFIED (Phase 23) |
| POST | /api/v1/knowledge/ask | generation | Public | askRequest: bounded question/literal filters | generation controller.ask -> generation service/client -> FastAPI retrieval/provider | pgvector SELECT only; no ai_queries write | AssistantDatasource/AssistantViewModel | REAL VERIFIED (fresh Node/FastAPI/Google/pgvector/Gemini) |
| POST | /api/v1/scans/:scanId/explanation | generation | FARMER owner or guest original key; ADMIN denied | explanationRequest UUID/empty body/key | generation controller.explain -> scan ownership service -> generation client | Read saved scan/prediction/model; pgvector SELECT | Authenticated Assistant scan picker/result action; guest UI does not expose context | REAL VERIFIED (Phase 23) |
| GET | /api/v1/calculators/fertilizer/rules | fertilizer | Public | fertilizer list request | fertilizer controller.list -> service -> repository | ACTIVE source-reviewed fertilizer_rules/calculator_configs/products | Calculator repository/ViewModel | REAL VERIFIED; current catalogue correctly PENDING |
| POST | /api/v1/calculators/fertilizer/calculate | fertilizer | Public | fertilizer calculate request: decimal strings/unit/version pins | fertilizer controller.calculate -> service -> repository + deterministic engine | Read immutable rule/config; no calculation history write | Calculator repository/ViewModel | REAL VERIFIED with SYNTHETIC rules only; real agronomy pending |
| GET | /api/v1/admin/calculators/fertilizer/rules | fertilizer | ADMIN | fertilizer list request | fertilizer controller.drafts -> service -> repository | Versioned draft/rule/config rows | AdminManagementRepository | REAL VERIFIED with isolated fixtures |
| POST | /api/v1/admin/calculators/fertilizer/rules | fertilizer | ADMIN | fertilizer reviewed strict draft schema | fertilizer controller.createDraft -> service -> repository | Immutable rule/config/product and audit_log transaction | AdminManagementRepository/editor form | REAL VERIFIED with isolated fixtures |
| PATCH | /api/v1/admin/calculators/fertilizer/rules/:ruleId/status | fertilizer | ADMIN | fertilizer strict UUID/status schema | fertilizer controller.changeStatus -> service -> repository | Atomic activation/retirement and audit | Admin management confirmed lifecycle | REAL VERIFIED with isolated fixtures |
| GET | /api/v1/calculators/yield/configurations | yield | Public | yield list request | yield controller.list -> service -> repository | ACTIVE source-reviewed YIELD calculator_configs | Calculator repository/ViewModel | REAL VERIFIED; current catalogue correctly PENDING |
| POST | /api/v1/calculators/yield/calculate | yield | Public | yield calculate request: decimal strings/unit/version pins | yield controller.calculate -> service -> repository + deterministic engine | Read immutable rule/config; no calculation history write | Calculator repository/ViewModel | REAL VERIFIED with SYNTHETIC rules only; real agronomy pending |
| GET | /api/v1/admin/calculators/yield/configurations | yield | ADMIN | yield list request | yield controller.drafts -> service -> repository | Versioned draft/rule/config rows | AdminManagementRepository | REAL VERIFIED with isolated fixtures |
| POST | /api/v1/admin/calculators/yield/configurations | yield | ADMIN | yield reviewed strict draft schema | yield controller.createDraft -> service -> repository | Immutable rule/config/product and audit_log transaction | AdminManagementRepository/editor form | REAL VERIFIED with isolated fixtures |
| PATCH | /api/v1/admin/calculators/yield/configurations/:configId/status | yield | ADMIN | yield strict UUID/status schema | yield controller.changeStatus -> service -> repository | Atomic activation/retirement and audit | Admin management confirmed lifecycle | REAL VERIFIED with isolated fixtures |
| GET | /api/v1/analytics/scans | analytics | FARMER owner only | analyticsQuery bounded paired UTC dates | analytics controller.summary -> service -> SQL repository | Owner-filtered scans/latest predictions | AnalyticsRepository/Field insights | REAL VERIFIED (Phase 23) |
| GET | /api/v1/analytics/scans/activity | analytics | FARMER owner only | activityQuery dates/UUID cursor/limit | analytics controller.activity -> service -> SQL repository | Owner-filtered scans/latest predictions | AnalyticsRepository/recent pages | REAL VERIFIED (Phase 23) |
| GET | /api/v1/admin/dashboard | dashboard | ADMIN | strict paired bounded dates | dashboard controller -> service -> SQL repository | System users/scans/predictions/model registry | AdminDashboardRepository | REAL VERIFIED (Phase 23) |
| GET | /api/v1/admin/knowledge/diseases | management | ADMIN | empty | managementController(diseases) -> management service -> management repository/AI indexer | Disease display metadata | AdminManagementRepository/forms; source fields edited with new version | REAL VERIFIED (Phase 23) |
| GET | /api/v1/admin/knowledge/documents | management | ADMIN | UUID cursor/empty body | managementController(documents) -> management service -> management repository/AI indexer | Versioned document/source summaries | AdminManagementRepository/forms; source fields edited with new version | REAL VERIFIED (Phase 23) |
| GET | /api/v1/admin/knowledge/documents/:id | management | ADMIN | UUID id | managementController(document) -> management service -> management repository/AI indexer | Immutable document/source/chunk lineage | AdminManagementRepository/forms; source fields edited with new version | REAL VERIFIED (Phase 23) |
| PATCH | /api/v1/admin/knowledge/diseases/:slug | management | ADMIN | fixed managed slug/display fields/revision | managementController(editDisease) -> management service -> management repository/AI indexer | Disease revision/status and audit | AdminManagementRepository/forms; source fields edited with new version | REAL VERIFIED (Phase 23) |
| POST | /api/v1/admin/knowledge/documents | management | ADMIN | strict reviewed source/content/version draft | managementController(createDraft) -> management service -> management repository/AI indexer | New document/source and audit | AdminManagementRepository/forms; source fields edited with new version | REAL VERIFIED (Phase 23) |
| POST | /api/v1/admin/knowledge/documents/:id/index | management | ADMIN | UUID id/empty JSON | managementController(index) -> management service -> management repository/AI indexer | Python canonical text/chunk/vector persistence; Node audit | AdminManagementRepository/forms; source fields edited with new version | REAL VERIFIED (Phase 23) |
| PATCH | /api/v1/admin/knowledge/documents/:id/status | management | ADMIN | UUID/expectedStatus/ACTIVE or ARCHIVED | managementController(status) -> management service -> management repository/AI indexer | Atomic current-policy activation/archive and audit | AdminManagementRepository/forms; source fields edited with new version | REAL VERIFIED (Phase 23) |
| GET | /api/v1/admin/model-health | model-health | ADMIN | strict empty body/params/query | model-health controller -> service -> registry repository + protected AI dashboard client | Read ModelVersion transaction; saved offline evidence remains artifact-owned | ModelHealthRepository/ViewModel | REAL VERIFIED after P2028 fix; Phase 23 final read-only contract |

## Tests and implementation locations per group

| Group (every route above) | Source and tests |
|---|---|
| health | [routes](../backend/src/modules/health/health.routes.ts); [HTTP/service checks](../backend/tests/foundation/http.test.ts); corresponding controller/service/repository in the same module |
| auth | [routes](../backend/src/modules/auth/auth.routes.ts); [HTTP/service checks](../backend/tests/auth/http.test.ts); corresponding controller/service/repository in the same module |
| scans | [routes](../backend/src/modules/scans/scan.routes.ts); [HTTP/service checks](../backend/tests/scans/http.test.ts); corresponding controller/service/repository in the same module |
| knowledge | [routes](../backend/src/modules/knowledge/knowledge.routes.ts); [HTTP/service checks](../backend/tests/knowledge/http.test.ts); corresponding controller/service/repository in the same module |
| generation | [routes](../backend/src/modules/generation/generation.routes.ts); [HTTP/service checks](../backend/tests/generation/http.test.ts); corresponding controller/service/repository in the same module |
| fertilizer | [routes](../backend/src/modules/fertilizer/fertilizer.routes.ts); [HTTP/service checks](../backend/tests/fertilizer/http.test.ts); corresponding controller/service/repository in the same module |
| yield | [routes](../backend/src/modules/yield/yield.routes.ts); [HTTP/service checks](../backend/tests/yield/http.test.ts); corresponding controller/service/repository in the same module |
| analytics | [routes](../backend/src/modules/analytics/analytics.routes.ts); [HTTP/service checks](../backend/tests/analytics/http.test.ts); corresponding controller/service/repository in the same module |
| dashboard | [routes](../backend/src/modules/admin/dashboard.routes.ts); [HTTP/service checks](../backend/tests/admin/http.test.ts); corresponding controller/service/repository in the same module |
| management | [routes](../backend/src/modules/admin/management.routes.ts); [HTTP/service checks](../backend/tests/admin/management.test.ts); corresponding controller/service/repository in the same module |
| model-health | [routes](../backend/src/modules/admin/model-health.routes.ts); [HTTP/service checks](../backend/tests/admin/model-health.test.ts); corresponding controller/service/repository in the same module |

Real test evidence includes `auth.database.integration.ts`, `scans.database.integration.ts`,
`scans.inference.integration.ts`, `scans/history.database.integration.ts`, the two opt-in
Cloudinary/inference API files, knowledge/generation live files, and existing
`scripts/check-*.mjs` calculator/analytics/Admin/assistant contracts. Their collection
and proof paths are recorded in the [Phase 23 matrix](39-testing-e2e-verification.md).

## Disconnects and deliberately absent APIs

- POST auth/register exists but has no production Flutter registration form/repository method.
- Disease list/detail and semantic search have no farmer Knowledge repository/ViewModel/view.
  The assistant uses knowledge/ask; that is not a library screen.
- No profile-edit API/UI, notification delivery API, account-management CRUD, public Admin
  enrollment, audit-browser API or chat/calculator history API exists. These are not newly
  invented requirements; profile editing/user administration/audit browsing remain scope-
  dependent target-design ideas, while stateless chat/calculators are explicit decisions.
- GET auth/me also currently has only test/extension consumers; production native
  identity comes from validated login/refresh grants. This is not a broken account screen.
- No duplicate explicitly registered route or Flutter request for a nonexistent implemented
  endpoint was found. Empty pending catalogues are real data states, not static demo results.
- Node has no generated OpenAPI document. Zod/runtime contracts, tests and these reference
  tables exist; automatic contract publication remains a documentation/maintenance gap.
- Python vector access uses its documented parameterized repository rather than Prisma;
  services invoking storage/AI clients do not violate the backend orchestration boundary.
