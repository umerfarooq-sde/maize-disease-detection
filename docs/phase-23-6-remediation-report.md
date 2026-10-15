# Phase 23.6 — targeted implementation remediation

Verified 2026-10-15. Baseline `57902b79a9009f3d39875d621b0ea9baa25e1d01`.
Scope: the missing farmer registration and disease-knowledge Flutter handoffs only,
their integration/regressions, documentation and original-requirement review.

## 1. Remediation status

**COMPLETE** for both mandatory UI tasks. Real automated host-widget verification
passes through the existing services and isolated PostgreSQL. This does not certify
the entire original product brief or physical-device acceptance. Phase 24 was not
started. No new backend API, migration, dependency, source corpus or ML change.

## 2. Farmer registration

Complete: Login → Register → safe account-created confirmation → explicit Login →
authenticated FARMER. The view uses `RegistrationViewModel` and
`ApiRegistrationRepository` through the existing shared `ApiClient`.

- Only email/password are submitted; no role field or public ADMIN creation.
- Exact installed Zod email syntax/254-character limit, trim/lowercase email, and
  15–128 Unicode password code points without trimming/composition invention.
- Visibility control, busy/submission/success guards, editable failure retry,
  duplicate email, server validation, rate-limit, offline/timeout/server and malformed
  response handling. Errors retain no raw transport text or secrets.
- Success installs no token/cookie. Password field is cleared. Existing native
  volatile sign-in, serialized refresh, identity fencing and logout remain intact.
- The real form-created account is verified in the disposable database as FARMER
  with an Argon2id hash. Real login, refresh, logout/revocation and rejection of
  attempted ADMIN registration pass. Guest scans are not attached retroactively.

## 3. Knowledge library

Complete: real catalogue cards, explicit semantic search, detail/back navigation,
plain source references and current document versions. Four real catalogue entries
and **25 real source-backed sections** are verified: three diseases × seven topics,
Healthy × four. Healthy receives no invented treatment/cause headings.

Catalogue `GET diseases` has no query filter contract; browsing uses that endpoint
without attaching a search parameter. Explicit search uses `POST knowledge/search`
with bounded text and `topK:5`. Results are retrieved passages, not generated advice,
classification probabilities or an unrestricted chatbot. Detail uses
`GET diseases/:slug`. Names, descriptions, sections and citations come from Node;
no agricultural paragraphs, fake photo or new seed is introduced.

Loading, empty catalogue, no matches, missing/archived slug, network/server/timeout,
refresh and retry states are implemented/tested. The indexed shell retains only
screen-local public state; detail fetches on entry, with explicit refresh and no
disk/global active-document cache. Disposal/clear fences late results. Sources reuse
the assistant's existing strict parser and shared source card.

## 4. Files modified

Production changes are limited to `mobile/lib`: registration and knowledge models,
repositories, route-scoped ViewModels/views, knowledge cards and shared source card;
app/provider/router composition; sign-in registration link; bounded card previews;
keyboard-aware shell and one stale Home availability sentence. Existing assistant
source presentation delegates to the same shared component without changing answers.

Tests add two registration files, four knowledge files including fixtures, and the
opt-in real widget test. `scripts/check-farmer-remediation.mjs` uses the existing
`scripts/check-e2e.py` schema-isolation runner. Documentation updates current state,
known issues, README, architecture/auth/knowledge/testing guides, historical audit
correction notes and the new [feature guide](40-farmer-registration-knowledge.md).
The complete path inventory follows at the end of this report.

## 5. Commands and test results

Commands are relative to root unless a working directory is given. All final checks
below pass. The initial failed attempts are separately retained below.

| Exact command | Result |
|---|---|
| `dart format lib test` (mobile) | Formatted the added code |
| `dart format --output=none --set-exit-if-changed lib test` (mobile) | 193 files, zero pending changes |
| `flutter analyze` and final `flutter analyze --no-pub` (mobile) | No issues |
| `flutter test --no-pub test/auth/registration_test.dart test/auth/registration_widget_test.dart test/knowledge` (mobile) | **42 passed**, zero skips |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Flutter` | **338 passed**, **12 opt-in live skips**; includes analyzer and full `flutter test` |
| `flutter test --no-pub test/widgets/foundation_test.dart test/farmer_flow_test.dart` (mobile) | **18 passed** after the final Home-copy change |
| `flutter build apk --debug --no-pub --target-platform android-arm64` (mobile) | PASS, Gradle 40.4 s; ignored `mobile/build/app/outputs/flutter-apk/app-debug.apk` |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Backend` | Format/lint/strict TypeScript/build/import checks and **299 tests passed**, zero skips |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component AI` | Ruff format/lint, mypy (46 source files), **346 tests passed**, **three opt-in SQL skips** |
| `npm.cmd run db:validate` (backend) | Prisma schema valid; no schema/migration modifications |
| `ai-service/.venv/Scripts/python.exe scripts/check-e2e.py --only farmer-remediation` | PASS: schema preflight + **one live host-widget E2E test**, zero skips; actual Node/PostgreSQL/Google/pgvector |

Final repository/diff/link/privacy and frozen-artifact checks also pass, as recorded
below. Tests exercise source metadata, all four catalogue slugs,
matching/malformed DTOs, safe error mappings, Unicode bounds, submission suppression,
loading/empty/retry/disposal/clear fences, guest/farmer navigation, back behavior,
small/landscape/tablet layouts and 200% text. Backend regressions cover all existing
auth/scan/history/assistant/calculator/analytics/Admin/model-health modules. AI
regressions cover retrieval/embedding/generation/inference/auth/lifecycle foundations.

### Real evidence and retained failures

Passing run: `.cache/phase23/20261015T155340Z-ae2d48e8/`. The live widget test drives
the actual `MainApp` views through production ViewModels/repositories/HTTP clients.
The helper subsequently reads the actual FARMER row/hash and revoked session records.
Public knowledge uses existing documents, sources and ready vectors copied into the
owned schema; semantic search calls the actual Google embedding provider and pgvector.
The parent verifies **schemaRemoved=true**, **productionCountsUnchanged=true** across
21 application tables and **passed=true**. No Cloudinary upload or model prediction
is required by this new UI proof. Starting the existing private AI service loads its
pinned classifier; no training, final-test scoring or model promotion occurs.

Initial run `.cache/phase23/20261015T155046Z-e61177ef/` failed after registration,
login and detail verification because the test's search-button tap missed after
scroll/focus repositioning. The corrected helper unfocuses, centers and verifies a
hit-testable target; the full real flow passes afterward. Both runs removed their
owned schema and confirmed unchanged production counts. Initial analyzer style
findings and three long-card widget failures were fixed: explicit braces, bounded
description previews and keyboard-space handling. No failed run is counted as PASS.

Local logs/results: `.cache/phase236/` (`backend`, `ai`, `flutter`, `mobile-final`,
`prisma`, `live`, `live-attempt-2`); the first live result intentionally remains failed.
Default opt-in skips are not hidden or relabeled as live coverage. Historical Phase
23 real Cloudinary/model/assistant/Admin evidence is preserved in the
[existing matrix](39-testing-e2e-verification.md), rather than claimed freshly replayed.

No physical Android device or emulator was used. The APK is a build artifact and the
live test runs host widgets with real HTTP. Camera/permissions/IME/platform behavior,
release networking/signing and actual phone acceptance remain unverified.

## 6. Backend/API compatibility

No endpoint or response envelope changes. Registration uses existing `201 data.user`;
public disease list uses `data.items`; detail/search use their existing projections.
No FastAPI, Gemini or Cloudinary credential enters Flutter. Search has its own bounded
25-second deadline; ordinary requests retain the existing deadline. There is no
arbitrary image/URL transport, new fetch origin or UI-to-provider call.

## 7. Flutter architecture compliance

`View → ChangeNotifier ViewModel → Repository → ApiClient → Node` throughout both
features. Root providers supply dependencies; registration, library and detail state
are route-scoped. Controllers retain form fields; local `setState` only toggles password
visibility. No raw HTTP/business calculations in widgets. Existing design tokens,
safe areas, scrolling, state patterns and farmer/Admin navigation are retained.
Final review found no new credential logging, TypeScript `any`, dead parallel API
client, copied retrieval algorithm or unnecessary generic framework.

## 8. Remaining issues, P0–P3

- **P0:** none found by the executed targeted and regression checks; this is not a
  comprehensive production-security certification.
- **P1 before final FYP acceptance:** original profile customization and Admin
  farmer/user management, audit viewing and disease-media functionality remain absent.
  They require separately scoped implementation, not new credentials for these two UIs.
- **P2:** approved calculator agronomic content, source freshness/local applicability,
  native-device acceptance, volatile-session limitation, provider outages, and the
  existing Phase 24/25 security/deployment/retention tasks remain. Source/candidate
  evidence is not field certainty. See [known issues](KNOWN_ISSUES.md).
- **P3:** original Swagger/OpenAPI generation is missing; manual route inventory and
  runtime schemas exist. Suggested personalized Home statistics/recent-scan layout
  is not implemented on Home; corresponding private analytics/history features exist.

## 9. Original requirements still missing

This review re-read the initial user-pasted **MAIZEDOCTOR master development prompt**,
not just later architecture drafts. Its §2 item 13 explicitly says **“Maintain a
customizable farmer profile.”** §4 FARMER repeats “Maintain profile,” and §35 lists
`/api/v1/profile`. The Phase 23.5 statement that original editing scope was not
established is therefore corrected.

Current Profile shows email/guest/session status, sign-out and history/analytics/Admin
links. The optional `FarmerProfile` schema has display name, phone, region, country,
area, avatar metadata and language, but no profile read/update workflow or Flutter
editor. Registration creates the account, not a filled profile. Additional work:
bounded owner-only Zod read/update contracts, service/repository persistence, explicit
editable-field/privacy policy, Flutter typed repository/ViewModel/form and ownership,
validation/loading/retry tests. Avatar customization additionally needs validated
upload/replacement/deletion compensation and source/metadata privacy handling.
Reuse existing schema/auth/storage; do not casually change email/password/roles.
**Schedule a dedicated profile phase before final demo/acceptance.** It was not
implemented here because this request explicitly limits mandatory remediation.

Other original gaps are independently established:

| Original brief | Actual as-built gap / extra work |
|---|---|
| §2 Admin item 1; §4 “Manage users” | Existing aggregate dashboard is not account management. Add controlled paginated farmer administration, guarded status changes/audits/session revocation, and ADMIN forms/RBAC tests. No casual destructive account deletion. |
| §4 “View audit logs” | Management writes real audit rows but has no audit-list API/UI. Add bounded ADMIN-only read projection/filters/redaction/pagination and privacy tests. |
| §4 “Manage disease images”; §12 images | No curated disease images or Admin media CRUD. Add reviewed source/rights-backed media metadata and safe upload/cleanup workflow; current honest icons are appropriate. |
| §40 “Generate Swagger/OpenAPI documentation” | No generated specification/viewer; runtime Zod/Pydantic contracts and manual endpoint inventory do exist. Separate documentation task. |
| §§14–15 real fertilizer/yield outputs | Real source-approved rules/formula/applicability remain pending under the later explicitly approved framework fallback. Never substitute synthetic values to call these complete. |

Generalized notification/chat/calculation history tables do not establish an agreed
delivery/history feature; chat/stateless calculator behavior follows later explicit
decisions. The Home arrangement is explicitly a suggested structure (§9), so its
missing embedded stats/greeting is distinguished from missing core capabilities.
Original segmentation ambitions are superseded by the explicitly approved shared
full-frame model policy. No retraining or preprocessing rewrite is justified here.

## 10. User actions required

**None to complete these two UI features.** Existing credentials, source corpus and
APIs suffice and were used successfully. No dataset metadata or extra agricultural
content is requested for registration/knowledge.

Before the final demo, the user must participate in real Android acceptance and
provide/approve the intended named Admin enrollment identity. If calculators are to
show real recommendations, an authorized domain reviewer must approve source-backed
rules/applicability. Codex can prepare code or candidate source research in separately
authorized work; the user need not implement missing profile/Admin code manually.
Do not provision personal accounts or publish agronomic rules without that intent.

## 11. Updated phase status

Phase 4 backend remains complete; its later **mobile registration handoff is resolved**.
Phase 6's **farmer browse/search/detail/source UI gap is resolved** using Phase 14's
existing real foundation. Phase 23.6 is complete for its authorized two features.
The historical Phase 23/23.5 audit is annotated and preserved. Original broader
product scope remains partial as listed above. No Phase 24/25/26 work starts here.

## 12. Phase 24 readiness

**READY WITH NON-BLOCKING LIMITATIONS.** The two audit blockers are implemented and
connected to real services; independent component checks, real UI/API/database/search
proof, unchanged production data and Android packaging pass. Remaining original
profile/Admin requirements need explicit pre-demo scheduling and must not be called
implemented. They do not require weakening auth, rebuilding RAG or delaying an
independently authorized security review. Device/domain/production readiness is not
claimed. Stop after Phase 23.6.

## Final review and preservation

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-repository.ps1`:
  PASS (structure/templates/ignore rules).
- `git diff --check`: PASS. New Node helper syntax, Biome formatting and lint pass.
  Formatting command: `backend/node_modules/.bin/biome.cmd format --indent-style=space --indent-width=2 --line-width=100 --javascript-formatter-quote-style=single scripts/check-farmer-remediation.mjs`;
  lint: `backend/node_modules/.bin/biome.cmd lint scripts/check-farmer-remediation.mjs`;
  syntax: `node --check scripts/check-farmer-remediation.mjs`.
- Read-only `.cache/phase236/check-review.py`: PASS, **469 local Markdown links**,
  no broken links, matching private environment-value leaks or machine-specific
  dataset/source paths in authored changes.
- Read-only `.cache/phase236/verify-frozen.py`: PASS, **171 frozen files**, approved
  checkpoint hash, all **eight unchanged migrations**, protected source/corpus/shared
  scopes and original user-file hashes. No raw dataset is read by that check.
- The original `.gitignore`, ML README/dataset scaffolding and eight-line historical
  PROJECT_STATE workspace section are preserved outside the remediation commit.
  Generated logs, temporary fixtures and APK outputs remain ignored. The report's
  file inventory is the reviewed commit scope; no unrelated user changes are staged.

## Complete file inventory

47 related files (new and modified); generated proof/build outputs remain ignored.

```text
README.md
docs/07-flutter-architecture.md
docs/18-authentication.md
docs/19-flutter-foundation.md
docs/30-knowledge-retrieval.md
docs/39-testing-e2e-verification.md
docs/40-farmer-registration-knowledge.md
docs/KNOWN_ISSUES.md
docs/PROJECT_STATE.md
docs/README.md
docs/phase-23-5-completeness-audit.md
docs/phase-23-5-configuration-inventory.md
docs/phase-23-5-endpoint-inventory.md
docs/phase-23-6-remediation-report.md
mobile/README.md
mobile/lib/app.dart
mobile/lib/core/routes/app_router.dart
mobile/lib/core/routes/app_routes.dart
mobile/lib/core/widgets/feature_card.dart
mobile/lib/core/widgets/source_reference_card.dart
mobile/lib/data/models/assistant_answer.dart
mobile/lib/data/models/knowledge.dart
mobile/lib/data/models/registration_credentials.dart
mobile/lib/data/repositories/knowledge_repository.dart
mobile/lib/data/repositories/registration_repository.dart
mobile/lib/features/ai_assistant/widgets/assistant_source_card.dart
mobile/lib/features/auth/view_models/registration_view_model.dart
mobile/lib/features/auth/views/auth_intro_view.dart
mobile/lib/features/auth/views/registration_view.dart
mobile/lib/features/disease_knowledge/view_models/knowledge_detail_view_model.dart
mobile/lib/features/disease_knowledge/view_models/knowledge_view_model.dart
mobile/lib/features/disease_knowledge/views/knowledge_detail_view.dart
mobile/lib/features/disease_knowledge/views/knowledge_view.dart
mobile/lib/features/disease_knowledge/widgets/knowledge_match_card.dart
mobile/lib/features/disease_knowledge/widgets/knowledge_section_card.dart
mobile/lib/features/home/views/home_view.dart
mobile/lib/features/shell/views/farmer_shell.dart
mobile/test/auth/registration_test.dart
mobile/test/auth/registration_widget_test.dart
mobile/test/integration/farmer_remediation_test.dart
mobile/test/knowledge/helpers.dart
mobile/test/knowledge/repository_test.dart
mobile/test/knowledge/view_model_test.dart
mobile/test/knowledge/widget_test.dart
scripts/README.md
scripts/check-e2e.py
scripts/check-farmer-remediation.mjs
```
