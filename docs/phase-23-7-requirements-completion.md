# Phase 23.7 — original requirements completion

Verified 2026-10-15 (Asia/Karachi). Baseline: `3fe605c98b9eb28eb21a42bf1311a245d636c888`.
Read this report alongside [feature contracts](41-profile-accounts-audit.md) and
the separate [calculator input checklist](calculator-domain-input-checklist.md).

## 1. Phase 23.7 status

**COMPLETE for the authorized implementation and conditional content review.**
Private profile editing/photos, scoped Admin farmer management and read-only audit
history are implemented and verified end-to-end. The explicit fallback for unavailable
licensed disease media and agronomic rules is documented; these original product
requirements are **not** represented as complete recommendations or an image library.
Phase 24 and deployment have not started. This is not full original-product acceptance.

The original master development brief supplied by the user is the requirements
authority: §2 Farmer items 1–15/Admin items 1–14, §4 role capabilities, §Storage
(profile/leaf/reference images), and the detailed functional sections §9–20.
Later explicit phase instructions govern narrower supported behavior, particularly
fixed classifier labels, pending calculator content and bounded stateless chat.
The Phase 23.5/23.6 scope finding is corrected: profiles, farmer management,
audit viewing and disease images are approved original requirements.

## 2. Farmer profile customization

Flutter Profile → **Personalize your profile** → scoped ViewModel → repository →
authenticated Node API → controller/service/repository → existing Prisma profile.

| API under `/api/v1` | Request and result |
|---|---|
| `GET /profile` | FARMER only; `data.profile:null` before first save, otherwise the safe projection |
| `PATCH /profile` | JSON `{expectedRevision, displayName?, region?, countryCode?, fieldAreaHectares?}`; returns saved profile |
| `POST /profile/avatar` | Multipart `image` and `expectedRevision`; returns current profile after private Cloudinary upload |
| `DELETE /profile/avatar` | JSON `{expectedRevision}`; clears current association and attempts durable queued cleanup |

Projection: `displayName, region, countryCode, fieldAreaHectares, avatarUrl,
updatedAt, revision`. First save requires a name and null revision; later writes
require the current SHA-256 revision. Omitted PATCH fields remain unchanged;
explicit null clears optional values. Country is two-letter uppercase format,
not address verification. Area is an exact positive hectare decimal string with
up to eight integer/four fractional digits. Readable names/regions are bounded
to 120 Unicode code points. No unnecessary phone or localization field is collected.

The authenticated principal supplies ownership. User IDs, role, email, password,
token and provider fields cannot be edited through these strict schemas. Row locks
and revision checks prevent lost updates. Guests/Admin cannot use farmer profile APIs;
no-store responses and feature-local identity fences protect cached private UI state.
Forms cover loading, validation, saving, success, conflict/reload and network retry.

Original Storage requirements approve profile photos. Reuse the existing image
validator/Cloudinary adapter, with a separate typed `maizedoctor/profiles/<UUID>`
namespace, preview and explicit user upload/removal confirmation. Files must be
complete still JPEG/PNG/WebP with matching bytes/MIME/extension, at most 5 MiB and
16 MP and at least 16 pixels per side. Two active multipart uploads and rate limits
bound allocation. There is no ML, RAG or Gemini call for profile images.

A precommitted attempt and bounded cleanup queue in the **existing** profile row
cover failed upload, replacement, commit failure and interrupted compensation.
`npm.cmd run profiles:cleanup` retires attempts older than two minutes and attempts
up to 20 deletions across ten candidate profiles. Deletion can remain queued during
provider/DB outages; it is not an immediate worldwide invalidation guarantee.
Only three journal columns and one audit ordering index are added, in migration nine.

**Actual persistence proof:** a real PostgreSQL-backed Flutter host-widget test
saves/reads the profile, uploads/replaces two private Cloudinary photos, logs out
and in, reconstructs the app widget tree, signs in again, reloads persisted fields
and removes the photo. Native credentials remain intentionally volatile. This is
server persistence across a reconstructed app, not physical-phone/process acceptance.

## 3. Admin user management

**Required and implemented**, scoped to existing FARMER accounts.

- `GET /api/v1/admin/farmers`: server-side native timestamp/UUID cursor pagination,
  limit 1–50/default 20, optional account status and exact normalized email.
- `PATCH /api/v1/admin/farmers/:id/status`: confirmed, revision-pinned
  `ACTIVE`, `SUSPENDED` or `DEACTIVATED` transition.

Lists return only account ID/email/status/display name/creation date/revision.
There is no password, session secret, profile private-field dump, Admin listing,
role editor, public Admin creation or arbitrary account deletion. Deactivation
preserves profile/scans and is reversible access control, not personal-data erasure.

A single transaction locks the target FARMER, changes status, revokes all unrevoked
sessions and appends an immutable audit event. Audit failure rolls back everything.
Reactivation requires fresh login; previous sessions remain revoked. Existing live
authentication prevents suspended/deactivated access and refresh. Flutter has an
independent Admin route/session, filters, pagination, validation, confirmation and
loading/error/retry states. Every new Admin endpoint denies FARMER access.

## 4. Admin audit viewer

**Required and implemented:** `GET /api/v1/admin/audit-logs`, exposed through the
Admin overview → **View audit history**. Read-only pagination supports action,
known entity type, actor UUID and paired inclusive UTC dates spanning at most
366 days. The new `(created_at DESC,id DESC)` index supports the bounded order.

Entries show UTC timestamp, action, affected entity/UUID, retained actor UUID/current
role or null, and allowlisted metadata. Only recognized statuses, bounded version/
session counts and known changed-field names survive projection. Arbitrary `changes`,
text, source/review payloads, tokens, private markers and unnecessary PII are omitted.
Actor role reflects the current account, not a historical role snapshot. Existing
SQL audit immutability remains unchanged; there is no audit update/delete API.

## 5. Disease-image management

**Required, pending approved resources and subsequent integration.** Real database
inspection finds zero `disease_images`; no repository-approved licensed disease
library assets are available. The existing model supports disease relation, URL,
Cloudinary ID, alternative text and ordering. Cloudinary storage works, but that
does not establish image ownership, redistribution rights or publication approval.

Needed resources/decisions:

1. Approved maize reference photos with literal disease context, owner/source,
   credit, documented permission/license for hosting and display, and useful alt text.
2. An explicit image provenance/publication contract: current image rows do not
   fully retain image-specific rights/source/review status. Add only necessary
   metadata after the media and intended delivery policy are established.
3. Controlled Admin upload/review/activate/deactivate/reorder workflow, audited
   changes, cleanup and appropriate private/public delivery policy.
4. Farmer Knowledge cards/details/gallery integration and accessible attribution,
   including empty/loading/failure behavior and licensed-image fixtures.

The existing text Knowledge library remains usable with honest icons. No placeholder
is called a real disease photo. No web image is scraped or fabricated, and no raw
training dataset photo is redistributed. User-owned profile photos do not approve
a reusable disease reference library.

## 6. Calculator domain data

Both real public catalogues remain pending: fertilizer **`PENDING_RULES`**, yield
**`PENDING_CONFIGURATION`**. Full regression tests and this phase's real API probe
verify that missing configuration never yields invented recommendations.

The [separate checklist](calculator-domain-input-checklist.md) states exactly what
to supply/approve: authoritative product composition and product kg/ha rate with
maize applicability/assumptions/precautions; an authoritative applicable yield model
and kg/ha scenario; source/publisher/URL/section/dates/reuse rights; reviewer approval,
precision and immutable publication version. A source document/link and applicability
approval suffice for Codex to prepare a reviewable draft in separately authorized work;
the user need not write JSON. No new provider key or dataset metadata is required.

Current engines implement reviewed area-rate scaling with exact units/rounding,
not soil N/P/K need assessment or minimum/expected/potential field forecasting.
Those broader original outputs need approved domain models and, where necessary,
separate versioned engine work. Gemini does not calculate or change quantities.
Optional future AI calculator explanations are not implemented or claimed enabled.

## 7. Original functional requirements matrix

“Implemented” denotes source/test evidence, not fresh live retesting of every earlier
provider journey in this phase. Existing comprehensive real-provider evidence remains
in [Phase 23](39-testing-e2e-verification.md) and [Phase 23.6](phase-23-6-remediation-report.md).
The new live proof is restricted to this phase's changes and content-state checks.

| Original requirement | Status and implementation evidence |
|---|---|
| Farmer account creation/login/refresh/logout; no public Admin enrollment (§4) | Implemented: `backend/src/modules/auth`, `mobile/lib/features/auth`; Phase 23.6 registration; auth/backend and Flutter regression suites |
| Anonymous leaf detection (§2 F1, §4, §10) | Implemented: scan upload/inference modules and scoped Flutter detection; [flow](29-farmer-detection-history.md); nullable owner and no later history attachment |
| Authenticated detection and private records (§2 F1, §4) | Implemented: authenticated scan ownership, validated Node→FastAPI transport; [integration](28-node-fastapi-integration.md) |
| ML prediction/confidence/status/image and uncertainty (§2 F2, §11) | Implemented: typed prediction projection/result ViewModel/widgets; [inference](27-production-ml-inference.md). Current unapproved confidence cutoff retains LOW_CONFIDENCE; no guaranteed diagnosis |
| AI disease explanation and next-step context (§2 F3, F12, §11) | Implemented: ownership-checked scan explanation, immutable classifier context and cited reviewed evidence; [grounded generation](31-grounded-generation.md), [assistant](32-farmer-ai-assistant.md). Missing evidence abstains |
| View symptoms (§2 F4) | Implemented with sourced SYMPTOMS documents in real knowledge detail/search; `backend/src/modules/knowledge`, `mobile/lib/features/disease_knowledge` |
| View treatment/management (§2 F5) | Implemented with reviewed MANAGEMENT evidence, not a universal or fabricated treatment prescription; [knowledge](30-knowledge-retrieval.md) |
| View precautions/prevention (§2 F6) | Implemented with sourced PREVENTION sections and grounded assistant evidence |
| View overview, causes, favorable conditions, scientific name and references (§2 F7, §12) | Implemented where sourced: four fixed contexts, 25 real documents, optional scientific name, typed source metadata. Healthy has only four appropriate sections. Absent facts are not fabricated |
| Knowledge search/browse/categories/cards/details (§2 F8, §12) | Implemented: real catalogue, explicit disease/topic filters, semantic passage search and versioned source details; [Flutter handoff](40-farmer-registration-knowledge.md) |
| Agricultural RAG assistant (§2 F9, §13) | Implemented: domain limits, bounded local conversation, reviewed retrieval, verified citations, abstention/errors; [assistant](32-farmer-ai-assistant.md) |
| Fertilizer quantity calculator (§2 F10, §14) | Framework/UI/Admin rules implemented; real recommendation content PENDING. Current product-area-rate model does not independently infer N/P/K needs/timing; [calculator](33-fertilizer-calculator.md) and checklist |
| Expected yield (§2 F11, §15) | Framework/UI/versioned configs implemented; authoritative model/rate PENDING. Conditional area-rate projection does not implement the original min/expected/potential forecast range; [yield](34-expected-yield-calculator.md) |
| Grounded AI guidance generally (§2 F12) | Implemented for reviewed knowledge/scan explanations. Optional calculator-specific AI explanations remain disabled; numerical engines remain deterministic |
| Customizable farmer profile (§2 F13, §4, Storage) | Implemented now, including approved profile photos; four metadata/photo APIs, MVVM and real persistence proof; [contracts](41-profile-accounts-audit.md) |
| Authenticated scan history/detail (§2 F14) | Implemented, private cursor pagination/detail/image/date/prediction; [history](29-farmer-detection-history.md) |
| Personal visual statistics (§2 F15, §16) | Implemented owner-filtered SQL aggregates/cards/time periods/label distribution; [analytics](35-farmer-analytics.md). Usage is not ground-truth accuracy |
| Prominent scan/quick actions, guest/signed-in shell (§9–10) | Implemented in Home/farmer navigation. Greeting/personal totals/recent scans are suggested Home layout, not separately mandatory duplicate widgets; personal records/stats remain available from Profile |
| Admin authentication and ADMIN-only workspace (§4) | Implemented independent volatile Admin session/routes; controlled existing CLI enrollment; no new real Admin is silently provisioned by tests |
| Manage farmers/users (§2 A1, §4) | Implemented now: paginated FARMER listing and audited confirmed access-status changes; new accounts repository/ViewModels/tests |
| Manage diseases (§2 A2, §18) | Implemented fixed-context display/scientific name/description and active/inactive editing; [Admin management](37-admin-management.md). Arbitrary classifier class creation/rename/delete is intentionally forbidden by Phase 21, requiring a new model version |
| Manage disease information/knowledge (§2 A3, §18) | Implemented immutable sourced topic documents/review/index/publish/archive. No dedicated severity/growth-stage fields or complete source-backed coverage guarantee exists; extend reviewed content/schema only if approved evidence justifies it |
| Manage fertilizer information (§2 A4, §19) | Reviewed immutable product snapshots/rule drafts/publication framework implemented; real product/rate content PENDING. Changed snapshots require a new slug/version, not unsafe mutation of historical rules |
| Manage calculator parameters (§2 A5, §20) | Implemented versioned reviewed source/unit/configuration forms and publication transactions; no arbitrary formula evaluator; real values pending |
| Manage agricultural knowledge (§2 A6) | Implemented within the supported maize domain through reviewed document/source lifecycle; unsupported unrestricted corpus ingestion is not enabled |
| User statistics (§2 A7) | Implemented server-aggregated farmer/status counts in [Admin dashboard](36-admin-dashboard.md) |
| Scan statistics and scans over time (§2 A8, §17) | Implemented aggregate scans/status/owner type and date periods/recent activity; `backend/src/modules/admin` |
| Disease/healthy prediction distribution (§2 A9, §17) | Implemented aggregates/charts, explicitly model-label usage rather than verified field prevalence |
| Model health (§2 A10, §17) | Implemented protected live readiness/runtime health plus actual registry metadata; [model health](38-model-health-dashboard.md) |
| ML metrics and model versions (§2 A11, §4, §17) | Implemented pinned offline test/per-class/confusion matrix evidence and registry/deployment distinction; no production-scan “accuracy” or model promotion |
| Monitor AI services/AI request statistics (§2 A12, §17) | Partial original ambition: model readiness/failures/latency are available; durable assistant/Gemini request totals remain NOT_RECORDED and dashboard readiness is NOT_CHECKED until the dedicated probe. No invented zero totals or full service-monitoring dashboard |
| Maintain knowledge-base versions (§2 A13, §33) | Implemented immutable document/chunk/source/embedding lineage and explicit rebuild/publication/archive; archived/stale evidence excluded |
| Maintain/view audit logs (§2 A14, §4) | Implemented immutable mutation audits plus this phase's filtered paginated read-only Admin viewer. General farmer profile edits are not claimed as Admin audit events |
| Disease reference image management/display (§4, §12, §18, Storage) | Required but PENDING licensed media/provenance/delivery/workflow and Farmer rendering, as detailed above; existing unused table alone is not implementation |
| Grounded image/knowledge outputs in result (§11) | Image/status/prediction/confidence are direct result fields; source-backed guidance is available through explicit explanation/assistant/library navigation. Every topic is not automatically generated into each result |

Technical requirements supporting these functions remain in the existing architecture,
schema, ML and test guides. One shared approved full-frame preprocessing package,
fixed class mapping, frozen research model, pgvector/Google embeddings and official
server-only Gemini SDK remain unchanged. No new ML fitting/evaluation was performed.
Swagger/OpenAPI documentation requested by §3/§40 is still absent (P3 technical
documentation debt); phase-specific Markdown/API contracts do not replace it.
Source-backed growth-stage/severity coverage, broad agronomic forecasts, full service
telemetry and disease media are recorded as limitations, not silently completed.
Notifications/generic history schema capacity does not establish an extra mandatory
feature; later explicit stateless chat/calculation decisions remain authoritative.

## 8. Actual checks and results

| Command/check | Result and boundary |
|---|---|
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Backend` | PASS: formatting, lint, strict TypeScript, build, compiled imports and **309 tests**, zero skips (10 new profile/accounts/media tests). Two existing Biome informational suggestions remain |
| Same script `-Component Flutter` | PASS: analyzer and **369 tests**, **13 explicitly opt-in live skips** (31 new targeted unit/repository/ViewModel/widget tests) |
| Same script `-Component AI` | PASS: Ruff formatting/lint, mypy 46 source files, **346 tests**, **3 opt-in PostgreSQL skips**, one existing TestClient warning. AI production source unchanged |
| `dart format --output=none --set-exit-if-changed lib test` in mobile | PASS, no formatting drift |
| `flutter build apk --debug --no-pub --target-platform android-arm64` in mobile | PASS, local debug APK `mobile/build/app/outputs/flutter-apk/app-debug.apk`; no emulator/physical-device acceptance |
| `ai-service/.venv/Scripts/python.exe scripts/check-e2e.py --only migrations database original-requirements` | PASS: actual migration replay, **42 isolated PostgreSQL tests**, **one enabled real Flutter host-widget E2E**, zero skips in the selected live checks |
| `npm.cmd run db:migrate` in backend, after disposable replay | PASS: applies only the additive ninth migration to configured development DB; no reset, deployment hosting or seed replacement |
| `npm.cmd run db:check` in backend | PASS: Prisma schema validation/client generation/strict DB TypeScript/**13 rollback DB tests** |
| `npm.cmd run db:status` and `npm.cmd run db:diff` in backend | PASS: **nine migrations applied**, **no schema difference** |
| `prisma format` / targeted backend and Flutter checks during implementation | PASS after fixing a narrow test UUID type annotation, formatter findings and a legitimate 64-character multipart revision limit boundary |

Live run: `.cache/phase23/20261015T181137Z-dae1d43f/results.json` and
`requirements-proof.json`; component commands/logs: `.cache/phase237/`.
The owned schema was removed; all **21 production table counts** are unchanged;
both generated Cloudinary assets were confirmed cleaned. Real tests cover cross-farmer
denial, safe DTOs, Admin-only access, cursor pagination, audit redaction/immutability,
actual transaction rollback on injected audit-write failure, status/session revocation,
app-tree profile persistence, Cloudinary replacement/removal and pending catalogues.
Controlled synthetic images use no raw dataset content. Gallery acquisition uses a
fixture datasource; HTTP, PostgreSQL, Flutter forms and Cloudinary are real.

Unit tests additionally inject upload/finalization/compensation/cleanup failures,
provider/DB errors, stale revisions, malformed image/security fields, missing or wrong
role sessions and delayed/disposed identity results. These fault branches are mocked;
they do not claim an actual external-provider outage. Layout tests cover narrow phone,
landscape, tablet and large text. An initial test compile error and multipart boundary
failure were fixed before the passing full runs; no failed check is hidden as a skip.

Final read-only repository checks pass. All **528 local Markdown links** resolve;
source scanning finds no private configured secret, machine-specific dataset path,
embedded private key or prohibited Admin TypeScript `any`. The **171 frozen files**,
approved checkpoint SHA-256 and original eight migration byte hashes match their
recorded baselines; three unrelated protected working files match their original
hashes. The ninth migration is the only added migration. No raw dataset is read.
`node --check scripts/check-requirements.mjs`, explicit Biome helper checks and
`git diff --check` pass. The helper initially needed import ordering/formatting;
those nonsemantic fixes were applied and the checks rerun successfully. A first
attempt used unsupported Biome flag spelling; the local CLI help supplied the
correct flags. Existing real-DB tests emit a pg overlapping-query deprecation
warning; all checks pass, but this remains future compatibility debt.

The link/frozen checks are read-only ignored evidence tooling under `.cache/phase237`;
they are not product features or a substitute for the real service tests above.
Training and final-test scoring are not rerun. Reviewed staging excludes all
pre-existing unrelated user changes, including the original project-state paragraph.

## 9. Files modified

Important groups: existing backend wiring/storage plus new profile and Admin accounts
modules; one additive migration and DB invariants; Flutter profile/photo/Admin models,
repositories, scoped ViewModels/forms/routes; fault/layout/authz tests; isolated live
requirements harness; source-backed handoff documentation. No dependency is added.

The complete related file inventory is appended below. Pre-existing `.gitignore`,
`ml-training/README.md`, `ml-training/dataset/README.md` and the unrelated ML workspace
paragraph in `PROJECT_STATE.md` remain preserved outside the commit.

## 10. Remaining issues by priority

- **P0:** none found in this phase's implemented scope.
- **P1 — original-product acceptance:** disease reference media/integration needs
  licensed approved resources; fertilizer/yield real recommendations and broader
  original agronomic outputs need authoritative reviewed data/models. These are
  explicit conditional prerequisites, not blockers to completed profile functionality.
- **P2 — acceptance/operations:** physical Android picker/permissions/process-restart
  QA is still pending. Native sessions remain volatile. Photo originals may retain
  metadata; authenticated Cloudinary URLs are bearer capabilities. Provider failures
  can leave durable cleanup intents; scheduling cleanup and production retention/
  least-privilege/shared rate limits belong to separately authorized deployment/security
  work. Existing older live helpers still forward broader server environments to their
  test children; this new runner uses an allowlist. AI telemetry is process-local or
  unrecorded, model confidence policy/field generalization and source freshness remain
  existing documented limitations. No new commercial/field-use clearance is claimed.
- **P3:** Swagger/OpenAPI remains absent; typed Markdown contracts exist. Dedicated
  optional Home personalization and broader structured severity/growth-stage coverage
  remain outside this targeted remediation. Actor role in audit entries is current,
  not a newly invented historical snapshot.

## 11. User actions

**Required before claiming the full original product/demo complete:** approve/supply
licensed disease-library media and its source/rights; approve authoritative fertilizer
and yield content/model/applicability using the checklist; enroll the intended named
Admin through the existing controlled masked-input CLI; perform physical-device QA.
Test fixtures provision no lasting user/Admin account. Profile/account/audit code
completion needs no additional credentials, dataset metadata or manual JSON from you.

**Optional/separate authorization:** request candidate agronomic-source preparation,
broader calculator models, sustained AI telemetry, enriched knowledge fields or a
different Home layout. Commercial use requires independent dataset/content licensing,
field validation and replacement where necessary. Approval of this phase does not
authorize those changes, deployment or Phase 24.

## 12. Phase 24 readiness

**READY WITH DOCUMENTED LIMITATIONS** for separately authorized security hardening.
The missing profile/account/audit implementations are now real verified flows. The
request explicitly allows unavailable media/content to remain documented and does
not make them a blocker to profiles. Licensed disease media, real agronomic content,
full original-product acceptance and physical-device testing remain incomplete.
Security hardening is not started automatically. Stop after Phase 23.7.

## Complete file inventory

80 related files, including this report:

```text
README.md
backend/README.md
backend/biome.json
backend/package.json
backend/prisma/migrations/20261015000000_profile_media_journal/migration.sql
backend/prisma/schema.prisma
backend/src/app.ts
backend/src/cli/cleanup-profile-images.ts
backend/src/modules/admin/accounts.controller.ts
backend/src/modules/admin/accounts.repository.ts
backend/src/modules/admin/accounts.routes.ts
backend/src/modules/admin/accounts.service.ts
backend/src/modules/admin/accounts.types.ts
backend/src/modules/profile/profile-media.controller.ts
backend/src/modules/profile/profile-media.repository.ts
backend/src/modules/profile/profile-media.routes.ts
backend/src/modules/profile/profile-media.service.ts
backend/src/modules/profile/profile.controller.ts
backend/src/modules/profile/profile.repository.ts
backend/src/modules/profile/profile.routes.ts
backend/src/modules/profile/profile.service.ts
backend/src/modules/profile/profile.types.ts
backend/src/modules/scans/scan.storage.ts
backend/src/routes/index.ts
backend/src/types/express.d.ts
backend/tests/database.integration.test.ts
backend/tests/migration-replay.ts
backend/tests/profile/foundation.test.ts
docs/07-flutter-architecture.md
docs/14-roadmap.md
docs/16-database-operations.md
docs/18-authentication.md
docs/19-flutter-foundation.md
docs/33-fertilizer-calculator.md
docs/34-expected-yield-calculator.md
docs/37-admin-management.md
docs/39-testing-e2e-verification.md
docs/41-profile-accounts-audit.md
docs/DECISIONS.md
docs/KNOWN_ISSUES.md
docs/PROJECT_STATE.md
docs/README.md
docs/calculator-domain-input-checklist.md
docs/phase-23-5-completeness-audit.md
docs/phase-23-6-remediation-report.md
docs/phase-23-7-requirements-completion.md
mobile/README.md
mobile/lib/app.dart
mobile/lib/core/network/api_client.dart
mobile/lib/core/routes/app_router.dart
mobile/lib/core/routes/app_routes.dart
mobile/lib/core/utils/request_key.dart
mobile/lib/data/models/admin_accounts.dart
mobile/lib/data/models/farmer_profile.dart
mobile/lib/data/repositories/admin_accounts_repository.dart
mobile/lib/data/repositories/profile_repository.dart
mobile/lib/features/admin/view_models/audit_log_view_model.dart
mobile/lib/features/admin/view_models/farmer_management_view_model.dart
mobile/lib/features/admin/views/admin_access_view.dart
mobile/lib/features/admin/views/admin_dashboard_view.dart
mobile/lib/features/admin/views/audit_log_view.dart
mobile/lib/features/admin/views/farmer_management_view.dart
mobile/lib/features/admin/widgets/audit_entry_card.dart
mobile/lib/features/disease_detection/view_models/scan_view_model.dart
mobile/lib/features/profile/view_models/profile_view_model.dart
mobile/lib/features/profile/views/profile_editor_view.dart
mobile/lib/features/profile/views/profile_view.dart
mobile/lib/features/profile/widgets/profile_editor_form.dart
mobile/lib/features/profile/widgets/profile_photo_editor.dart
mobile/test/admin/accounts_helpers.dart
mobile/test/admin/accounts_test.dart
mobile/test/admin/accounts_widget_test.dart
mobile/test/integration/requirements_test.dart
mobile/test/profile/helpers.dart
mobile/test/profile/model_repository_test.dart
mobile/test/profile/view_model_test.dart
mobile/test/profile/widget_test.dart
scripts/README.md
scripts/check-e2e.py
scripts/check-requirements.mjs
```
