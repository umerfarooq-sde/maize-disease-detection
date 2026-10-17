# Phase 24.6 — current connections and phase status

Current stabilization is [Phase 24.7](phase-24-7-integration-stability.md). The
Phase 24.6 execution verdict below remains historical; it is not replaced by
combining later focused passes. API/architecture boundaries are unchanged.

Updated 2026-10-17 (Asia/Karachi). The [Phase 24.5 component inventory](phase-24-5-components.md)
and [vertical slices](phase-24-5-vertical-slices.md) are preserved historical
baselines. This addendum records changed producers/consumers and their verification.
The [remediation report](phase-24-6-pre-deployment-remediation.md) defines contracts,
loss conditions, source gates and new APIs. Exact executions belong to the
[verification ledger](phase-24-6-verification.md).

## Component connections and affected vertical slices

| Slice | Connected implementation | Persistence / returned state | Verification |
|---|---|---|---|
| Normal AI startup | Actual service-local config → safe preflight → lifespan → artifact loader → shared full-frame pipeline → selected checkpoint | Strict hashes/config/class mapping; null threshold and truthful low confidence | Actual configured lifespan/inference smoke and normal HTTP integration; no temporary policy override |
| Profile/avatar | Profile views → scoped ProfileViewModel → ApiProfileRepository → existing Node controller/media service/repository | Atomic association + existing durable journal → prompt projection; cleanup CLI later deletes only obsolete assets | Unit/API/VM/repository lost-ack/timeout/replacement/current-image fences, 16.5 s delay; normal real Cloudinary/profile journey |
| Operational recording | Node validated AI-client observers; FastAPI service decorators/Google adapters → owned bounded writers → repositories | Minimal ai_operations attempts; idempotent same-event storage retry; explicit best-effort loss | Real generation/provider rows; failure/privacy/overflow/concurrency/UTC/idempotency tests |
| Admin monitoring | Separate Admin navigation → dashboard repository/ViewModel → ADMIN ai-operations controller/service → SQL aggregates | Scoped volume/outcomes/mean/p50/p95/daily; unavailable is null, collected empty is zero with historical warning | Guest/Farmer denial, actual Flutter/Admin/DB test; offline model evaluation stays separate |
| Disease catalogue | Admin management editor → repository → Node management controller/service → revision-locked repository/audit | Existing four classifier slugs remain fixed; informational creation + reviewed optional metadata | Reserved labels rejected, source/revision/permissions/Healthy/inactive tests and real DB/Farmer detail |
| Farmer knowledge detail | Existing Knowledge VM/repository → disease detail DTO + scoped ReferenceGalleryViewModel/repository | Optional sourced applicability; explicit informational label; publication-only image cards | Widget/error/empty/long-text and real public informational/gallery fixture |
| Reference media | Admin ReferenceManagementView → Gallery VM/media repository → Node media controller/service/repository → Cloudinary | Reserved durable intent → READY DRAFT → explicit review/publication; metadata/audit retained | Strict image/license/source/rights/RBAC/Cloudinary failure tests; real generated upload/protected bytes/replacement/retirement/cleanup |
| Image delivery | Farmer public library or Admin draft repository → exact Node-relative path → Cloudinary private reader | Metadata-free bytes with no-store; no Cloudinary URL leakage | Real controlled byte read, draft/role/inactive tests; private profile/scan authorization unchanged |
| Product catalogue | Admin management form/VM/repository → product controller/service/repository | Immutable sourced metadata documents; shared product/rule lock, revision conflicts, freeze referenced content, cursor pagination | Unit/RBAC/schema/serialization/widget tests; real source-intake version/edit/status/frozen-product contract |
| Richer model review | Admin source-intake form → specification repository/API → service/repository | Immutable CalculatorConfig with explicit dimensions/source/assumptions; DISABLED/PENDING_DOMAIN_APPROVAL | Missing scientific contract/units/version/conflict/audit/activation denial; no arbitrary evaluator |
| OpenAPI | Runtime mounted routes + actual Zod validators + shared response schemas → generator → parser/drift gate | OpenAPI 3.1 JSON with all 59 business operations; local-only JSON viewer | Coverage/operation/method/path/request/response checks in npm check |

There is no Flutter→FastAPI/Google shortcut, controller Prisma access, invented
numerical recommendation or duplicated preprocessing. Existing source chunks and
immutable model identities retain their owners. Disease images now have a writer,
review/delivery/consumer; ai_queries/responses remain intentionally reserved because
operational counts do not justify storing conversations. Model_metrics/history/
notifications retain their previously documented reserved status; they are not
claimed as new implemented functionality.

## Phase status changes from the audit

| Phase | Current implementation status | Remaining boundary |
|---|---|---|
| 0–2 | COMPLETE AND VERIFIED | Five additive migrations extend original nine; no reset |
| 3 | COMPLETE AND VERIFIED | Generated Node contracts now implemented and checked |
| 4–5 | COMPLETE AND VERIFIED at software level | Native device/browser release acceptance pending |
| 6 | PARTIALLY IMPLEMENTED | Catalogue/metadata/reference lifecycle connected and focused live pass; final full-run Farmer detail UI fails. Cause remains open; actual sourced fields/photos also pending |
| 7–9 | COMPLETE AND VERIFIED | Existing security/shared pipeline unchanged |
| 9.5–10.5 | COMPLETE within approved research evidence | No new data inventory/training/final test; unknown field independence/licensing remains |
| 11–12 | COMPLETE AND VERIFIED engineering | Default null-policy startup repaired; external service failures are separately reported |
| 13–16 | COMPLETE engineering within bounded domain | Current real provider outcomes in ledger; field/physical-device acceptance separate |
| 17 | COMPLETE framework/review engineering; richer output BLOCKED BY ACTUAL EXTERNAL INPUT | Actual approved rates absent; nutrient demand/selection/schedules require a mathematical model and model-dependent implementation |
| 18 | COMPLETE framework/review engineering; forecast BLOCKED BY ACTUAL EXTERNAL INPUT | Conditional area-rate projection exists; min/expected/potential outputs require approved formula/data and exact engine/UI extension |
| 19 | COMPLETE AND VERIFIED | Usage/prediction statistics, never ground-truth accuracy |
| 20 | COMPLETE AND VERIFIED engineering | Real best-effort AI operational API/UI added; distributed durability/retention policy explicit |
| 21 | PARTIALLY IMPLEMENTED | Admin catalogue/media/product/source review connected and targeted verified; final Farmer detail/gallery acceptance remains open, alongside real domain approval |
| 22 | COMPLETE within existing model-health boundary | Missing trustworthy training date not fabricated; no formal ground-truth drift |
| 23–23.7 | Current regressions and new remediation rechecked | See exact final integration failures/skips; no claim that all historical runs passed |
| 24 | Security controls retained and regression-tested | Production roles, infrastructure and policy acceptance pending |
| 24.5 | Historical audit COMPLETE, original verdict preserved | Current remediation is a separate phase |
| 24.6 | PARTIALLY COMPLETE | Engineering implemented; normal configured full run 18 PASS / 3 FAIL / 0 selected skips; failed rag-database, knowledge, predeployment-remediation. Phase 25 NOT READY. Exact evidence/gates in report/ledger |
| 24.7 | PARTIALLY COMPLETE | Repaired full `20261017T213205Z-173ed748`21/0/0 + independent `20261017T215921Z-b412d414`4/0/0; cold aggregate/gallery/teardown repaired. Mandatory original cause/connection stability attribution remains open. Phase25 NOT READY. |
| 25–26 | NOT STARTED | No deployment or release engineering authorization exercised |

## Phase24.7 current connection override

All connected slices above are exercised by the final full/repeat runs in the
[current report](phase-24-7-integration-stability.md). Operational aggregation
now returns both projections from one SQL snapshot, eliminating the reproduced
short cold-acquisition defect. Gallery revision state/affected writer ownership
are repaired. No API/schema/dependency/model/global timeout change. These
execution outcomes supersede current verification claims, not historical
failures. Original causes and observed intermittent connection attribution remain
open; metadata/media domain approval and richer mathematical models/engine/UI,
device/privacy/commercial/release gates remain. No Phase25/26 has started.
