# R-07B — Final frontend remediation and release verification

Date: 2026-11-02. Branch `main`; starting HEAD `657e1c8bbca6b6916a565da39ff36409ca36b069`.

## Verdict and boundaries

The independent R-07A score was **80/100**. This is a targeted implementation release, not a new independent scoring exercise. No replacement score is claimed.

**Verdict: IMPLEMENTATION COMPLETE — AUTOMATED FRONTEND VERIFIED; RELEASE CONDITIONAL.** Final verification is **882 passed / 0 failed / 14 opt-in live skips**, including **68 passing golden comparisons** and **18 passing R-07B tests**. Both Android ARM64 staging compilation gates passed.

Public-release approval remains separate from implementation completion. Physical-device/TalkBack acceptance, live integration, approved content and signed production distribution are not established by widget tests or unsigned staging compilation.

Scope remained Flutter presentation, session-owned UI lifetime, local validation, components, tests, goldens and this mobile report. No backend/FastAPI/database/API DTO, authentication rule, calculator formula, agricultural recommendation, model, preprocessing, source publication policy or deployment file was changed. No provider call, real account/content mutation, retraining, migration, commit or push was performed.

The 33 incoming R-06D paths and `R07_INDEPENDENT_AUDIT.md` were preserved. R-07B deliberately builds on the existing Audit view, metric-grid wrapper and R-06D sign-in assertion where integration requires it; it does not revert their prior behavior. The independent audit was not rewritten.

## Audit disposition

| Finding | Classification and outcome | Evidence / preserved behavior |
|---|---|---|
| R07-01 — Assistant Focus lifecycle | **CONFIRMED — fixed** | Before the fix, new widget tests showed the root Focus sheet remaining open across Guest login and Farmer logout. It now observes its captured session revision and closes its exact owned route after invalidation/owner disposal; stale content is removed before rebinding. Late answers do not enter the new identity. No backend permission bypass was demonstrated. |
| R07-02 — Photo-only draft | **CONFIRMED — fixed** | A new Back test initially exited without confirmation. Selected local photo now participates in the existing text form's dirty predicate. Cancel retains it; confirmed discard clears local selection without upload/removal. System and app-bar Back and acknowledged-upload cleanup are tested. |
| R07-03 — Impossible source date | **CONFIRMED — fixed** | The original validator accepted `2026-02-30`. Reference review dates now reuse the existing strict management date validator. Leap years, century boundaries, invalid days/months, malformed input, retained input and blocked save are tested. No future-date prohibition or wire-format change was introduced. |
| R07-04 — Generic protected-image errors | **CONFIRMED — fixed** | Tests first failed because supported safe messages were absent. Only `AppErrorKind` is retained; known network/timeout/auth/access/not-found cases get actionable messages, unknown causes remain generic. Decode failures have a safe fallback. Small images use accessible feedback without expanding their layout; larger slots show text/retry. |
| R07-05 — Audit labels/options | **CONFIRMED presentation inconsistency — fixed; prior overflow NOT REPRODUCED** | Audit controls now use existing persistent wrapping labels and adaptive dropdown height. A 320dp/200% test verifies long selected action text spans more than 48dp without line truncation and the complete through-date label remains readable. No historical RenderFlex exception is claimed. |
| R07-06 — Result actions | **CONFIRMED — fixed** | Reviewed renders showed repeated caution before actions. Primary actions now immediately follow the visible threshold caution, ahead of supporting next-step prose. Raw score semantics, uncertainty, Healthy field-wide limitation, class scores and technical disclosures remain intact. |
| R07-07 — Constrained introductions | **CONFIRMED — fixed with physical acceptance pending** | Compact Home hero typography/padding removes nonessential decoration on narrow local widths. Short Assistant content windows use a smaller empty-state treatment. Admin sign-in has a shorter heading/introduction. System text scaling is preserved. Both keyboard/large-text golden review and existing responsive matrices remain applicable. |
| R07-08 — Admin/Insights density | **CONFIRMED — targeted improvements implemented** | CMS workflow prose, product revision hash and detailed telemetry coverage use disclosures; read-only classifier and disabled-engine warnings remain visible. Farmer summary cards reuse the shared adaptive metric grid. Scope, loss counters, provenance, source access, actual values and mutation controls remain. Further expanded-account table/list-density experimentation is deferred optional polish; it is not a reproduced broken workflow. |
| R07-09 — Eager CMS cards | **CONFIRMED — fixed** | A valid 100-record fixture mounted all 100 cards before the fix. CMS lists now reuse `AdminRecordPage`/`SliverList.builder`; regression asserts fewer than 20 mounted cards and successfully scrolls to a filtered late record. Editors remain bounded scrollable forms. Cursor/load-more, local-search scope and dirty guards are preserved. No measured FPS/memory improvement is claimed. |
| R07-10 — Calculation result visibility | **CONFIRMED — fixed** | Button-submitted fertilizer output was initially not hit-testable in a 320dp/200% window. Shared result presentation reveals the acknowledged quantity once per response identity, dismisses input focus and respects reduced motion/offstage state. Fertilizer and Yield tests verify visible output and no subsequent rebuild scroll jump. Math/rounding/requests are unchanged. |
| R07-11 — Reduced-motion image loading | **CONFIRMED — fixed** | Original pending-image test still found an animated spinner under disabled animations. It now uses a static hourglass with loading semantics under that preference. Normal loading remains animated. This is product preference compliance, not a claim that all functional progress animation violates WCAG. |
| R07-12 — Direct source opening | **CONFIRMED — deferred optional convenience** | Current source copying/selectable references remain functional. No approved external launcher utility/dependency exists in this app. Adding a new integration for nonblocking convenience is unnecessary for this remediation. No link is falsely labelled broken. |

### Reproduction boundaries and false-positive avoidance

- The Focus defect is a stale modal lifetime problem. Tests do not establish stolen credentials, cross-account server access or disclosure of another account's saved scan.
- Date tests demonstrate local rejection/normalization behavior; no invalid database mutation was attempted.
- Profile tests discard a staged local selection, never the current saved asset.
- Unknown image failures never infer an unavailable cause or display request IDs, URLs, tokens, raw exceptions or internal paths.
- A test-only tab-retention timeout was traced to using the real picker dependency in a mocked navigation harness. Supplying the existing fake Scan repository resolved that harness issue without application/plugin changes.
- Existing source-copying, deliberately bounded chat, unavailable metrics and pending agronomic configurations were not replaced with fabricated content or speculative rewrites.

## Implementation details

### Assistant and account state

The permanent GoRouter branch and Provider/MVVM ownership remain. The Focus modal captures a session revision, listens for revision changes, suppresses invalid content and removes only its own route. Owner disposal schedules safe cleanup outside widget-tree mutation. A second Focus presentation is guarded while the first is open. Ordinary tab changes retain one live Assistant model, draft, selected focus and conversation; a regression walks all five branches and confirms only one question request.

The existing 12-turn bound, no transcript persistence, no full-history payload, once-only saved-scan explanation handoff and late-response fences are unchanged. Existing navigation/session tests are part of final verification.

The profile form accepts `pendingPhoto` and a local-discard callback. Text and photo dirtiness share one existing confirmation. Completed uploads clear the candidate through the existing ViewModel; they do not cause a second upload or an unnecessary unsaved-photo warning. Existing ambiguous mutation read-reconciliation is untouched.

### Images, forms and scientific information

Protected images still use the existing repository, Node transport, revision-scoped keys, two-active/32-waiting bound and in-memory decode policy. Presentation stores only a safe error kind. Retry and decode fallback do not bypass authorization or expose a Cloudinary URL.

Reference dates reuse `validateManagementField('source.retrievedAt', value)` rather than another date implementation. Existing management publication/review dates already use strict calendar validation. Source/review/rights/activation requirements remain backend-authoritative.

Results retain all four fixed classes, null-threshold behavior, `LOW_CONFIDENCE` semantics, raw-softmax caveats and no field-wide Healthy clearance. Actions move earlier without changing Knowledge mapping, authorized Explain or Scan Another behavior. No threshold, score or severity was invented.

### Management, responsiveness and performance

CMS list state uses the existing lazy Admin record page; editor state still uses the existing width-constrained `AppPage`. Record keys, editor keys, pagination and local filter semantics remain. Tests now scroll to named disease/record controls instead of assuming every lazy child is mounted. Assertions about all four classes, archived versions and publication are retained.

Workflow/source limitations remain in disclosures with critical fixed-class/disabled-specification warnings visible outside them. Unique PageStorage keys distinguish disclosure booleans from scroll-position values; regression caught and corrected a transient collision introduced during implementation. Rule/source values remain selectable and full provenance remains reachable.

The existing Admin intrinsic metric layout was extracted into shared `AppMetricGrid`; the Admin wrapper delegates to it, preserving existing callers. Farmer Insights uses that same width/text-aware layout. No fixed card height or global text-scale limit was introduced. Broader account table redesign is not required to repair a current correctness issue.

Farmer R-03/R-04/R-05 responsive matrices now include **1280dp** in addition to 320/360/412/480/600/840/1024. Existing Admin matrices already include these widths. Tests cover 100/150/200% text, both themes, long content, keyboard/landscape, reduced motion and empty/error states. These are automated layout checks, not physical usability certification.

## Changed paths

Paths are relative to `mobile/`. The list below describes R-07B work, not every incoming R-06D change shown by Git.

### Production Dart

```text
lib/core/widgets/app_cards.dart
lib/core/widgets/private_image.dart
lib/core/widgets/private_image_view_model.dart
lib/features/admin/views/admin_sign_in_view.dart
lib/features/admin/views/audit_log_view.dart
lib/features/admin/widgets/admin_calculator_card.dart
lib/features/admin/widgets/admin_content_management.dart
lib/features/admin/widgets/admin_metric_grid.dart
lib/features/admin/widgets/ai_operations_panel.dart
lib/features/admin/widgets/reference_editor.dart
lib/features/ai_assistant/views/assistant_view.dart
lib/features/ai_assistant/widgets/assistant_empty_state.dart
lib/features/analytics/widgets/analytics_cards.dart
lib/features/disease_detection/widgets/prediction_summary.dart
lib/features/fertilizer_calculator/widgets/fertilizer_result_card.dart
lib/features/home/widgets/home_scan_hero.dart
lib/features/profile/views/profile_editor_view.dart
lib/features/profile/widgets/profile_editor_form.dart
lib/features/tools/widgets/planning_result_summary.dart
lib/features/yield_calculator/widgets/yield_details.dart
```

### Tests and evidence

New: `test/redesign/r07_lifecycle_test.dart`, `r07_media_test.dart`, `r07_presentation_test.dart` — **18 focused tests**.

Updated: `test/admin/management_widget_test.dart`, `test/admin/widget_test.dart`, `test/assistant/widget_test.dart`, `test/environment_test.dart`, `test/widgets/foundation_test.dart`, R-03/R-04/R-05 layout tests, `r06a_fixtures.dart`, R-06A navigation/operations tests, R-06B fixtures/content/layout/golden tests, R-06C management tests and the existing R-06D accounts/audit test. Updates preserve checks while supporting lazy children, disclosure access, 1280dp and the shorter verified sign-in heading. Compact Assistant assertions use the compact heading; an additional roomy-viewport test explicitly preserves the full heading and Guest boundary. The obsolete pre-redesign `Scan Leaf` assertion now checks the current `Scan a maize leaf` action.

**19 reviewed golden baselines changed; 49 untouched.** Affected groups: two navigation renders; Home Guest and three result renders; Assistant keyboard; two Insights renders; Admin Operations/sign-in; four disease/knowledge CMS renders; four product/rule/yield list renders. All actual changed images were opened before the selected update. No baseline was regenerated to suppress a functional failure.

New report: `R07_FINAL_FRONTEND_RELEASE.md`. Historical `R07_INDEPENDENT_AUDIT.md` remains unchanged.

## Verification record

Commands use the existing environment-isolating frontend launcher from `mobile/`:

```powershell
node ../scripts/run-flutter.mjs analyze
node ../scripts/run-flutter.mjs test --no-pub --reporter json
node ../scripts/run-flutter.mjs build apk --debug --flavor staging --target-platform android-arm64 --no-pub
node ../scripts/run-flutter.mjs build apk --release --flavor staging --target-platform android-arm64 --no-pub -PallowUnsignedVerification=true
```

Formatting is checked with `dart format --output=none --set-exit-if-changed` on changed/untracked Dart paths. `git diff --check` is run separately. No dependency was added.

| Check | Result |
|---|---|
| Initial full regression | **847 passed / 31 failed / 14 opt-in live skips**; retained in `build/r07-suite-first.jsonl`. Failures were reviewed, including changed goldens, lazy-list assumptions and stale pre-redesign wording. This run is not concealed or combined with other runs. |
| Focused reproduction/fix tests | Fail-before/pass-after evidence for modal lifetime, photo-only Back, impossible dates, safe image messaging, reduced motion, eager lists and offscreen results; later targeted regressions also passed. Counts are not added to final full-suite totals. |
| Intermediate full regression | **878 passed / 3 failed / 14 opt-in live skips**, retained in `build/r07-suite-final.jsonl`. All three failures expected the old full Assistant introduction in a now-compact window. Assertions were updated to the deliberate compact wording and a roomy-state assertion was added; all 16 Assistant widget tests then passed. No application code or golden changed after this run. |
| Final full suite | **882 passed / 0 failed / 14 opt-in live skips**; `build/r07-suite-accepted.jsonl`, command exit 0, runner success true, 269.665 seconds. This single complete run is authoritative. |
| All 68 golden comparisons | **68 passed / 0 failed / 0 skipped**, included in the final suite; 19 baselines updated selectively after visual review, 49 unchanged |
| Analyze | **Passed**, no issues; `build/r07-analyze.log` |
| Formatting | Passed; 60 current changed/untracked Dart files checked, zero formatting changes needed at final check |
| Android ARM64 staging debug | **Passed**, Gradle 85.8 seconds; `build/app/outputs/flutter-apk/app-staging-debug.apk` |
| Android ARM64 staging release | **Passed**, Gradle 158.6 seconds, 19.0 MB; existing unsigned-verification gate; `build/app/outputs/flutter-apk/app-staging-release.apk` |
| APK inspection | ARM64 Flutter engine in debug/release; ARM64 application library in release; both locally bundled Plus Jakarta Sans assets present in both APKs. Some dependency libraries also contain other ABIs; no claim that every packaged dependency is ARM64-only. |
| Git whitespace/scope | `git diff --check` passed. All working-tree paths remain under `mobile/`; final status is `main` at unchanged `657e1c8`, 91 modified/untracked paths including preserved incoming work, zero staged. |
| Physical Android | **NOT VERIFIED** — configured SDK ADB reports no connected device |
| TalkBack / device performance | **NOT VERIFIED / NOT MEASURED** |
| Live backend/AI integration | **NOT RUN** — outside this frontend/mock-only release verification |
| Signed production distribution | **NOT VERIFIED** — an unsigned staging build is not release signing approval |

Ignored `build/r07-*` logs retain local run evidence; no private data or provider responses are part of these test fixtures. Generated golden failures were moved, not deleted, from the new test failure folders into `build/r07-golden-failures/navigation/` (8 images) and `build/r07-golden-failures/redesign/` (68 images). Source and user assets were not moved. This preserves before/after/diff evidence without leaving generated failure folders among source changes.

The 14 opt-in skips are live integration checks intentionally not enabled; they are not counted as passes. Full-suite totals include the golden and focused R-07B tests; those subsets must not be added again. The release build retains the previously documented nonfatal CupertinoIcons font-family warning; no dependency was introduced merely to silence it.

## Remaining acceptance gates

1. Physical Android: native launch, five tabs, Focus/account changes, camera/gallery/lost-picker behavior, protected images, avatar confirmation, keyboard/system Back, large text and Admin forms.
2. TalkBack: spoken order, focus restoration, modal dismissal, retry announcements and charts on an actual supported device.
3. Profile-mode frame/memory observation with long local catalogues and protected image/history journeys. A mounted-child assertion does not establish FPS or peak memory.
4. Current authorized live Node/DB/FastAPI/model/RAG flow acceptance, reconciled against existing project-level known issues. This release neither reruns providers nor supersedes historical integration failures with Flutter test passes.
5. Reviewed agronomic data/model specifications and licensed reference images where required. Pending screens remain honest; no data was seeded or approved by this UI release.
6. Production signing, distribution, privacy/retention and infrastructure/release gates remain independent. Existing staging release compilation does not close them.

No confirmed P0 or reproduced unresolved P1 frontend defect is being concealed. No new backend-security claim, WCAG certification, commercial dataset clearance or field-accuracy claim is made. Optional direct source opening and further account-table density are deferred polish, not an excuse to disable existing functionality.

No commit or push is authorized by R-07B. Stop after documenting final verification.
