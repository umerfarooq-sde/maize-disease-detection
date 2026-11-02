# R-07A — Independent FIELD INTELLIGENCE frontend audit

Audit date: 2026-11-02. Repository: `E:\MAIZEDOCTOR`. Branch: `main`.
Inspected HEAD: `657e1c8bbca6b6916a565da39ff36409ca36b069` plus the existing, uncommitted R-06D work.

## 1. Independent verdict and evidence limits

**Verdict: a coherent, substantially implemented redesign that needs targeted remediation and acceptance testing before frontend release sign-off. Independent score: 80/100. Ready to begin R-07B remediation; not an approval to release publicly.**

The application now has a recognizable agricultural identity, useful navigation, unusually careful scientific caveats, and substantial Farmer/Admin feature coverage. The strongest improvements are the persistent Assistant, prominent Scan destination, locally bundled typography, protected imagery, source-aware Knowledge, and separation of operational statistics from offline model evaluation. It has progressed beyond a generic CRUD interface.

Remaining weaknesses are concentrated in information hierarchy, form and modal lifecycle details, error specificity, and verification gaps. Some phone layouts prioritize explanatory material and filter controls over the user's next action or records. These need refinement rather than a navigation, state-management or design-system rewrite.

**No confirmed P0 was found. No P1 failure was independently reproduced at runtime.** R07-01 is a source-identified identity/lifecycle risk with P1 investigation priority, not a demonstrated permission bypass or proven cross-account disclosure. The other findings identify source-confirmed behavior, visible usability problems, or explicitly qualified execution risks.

### Evidence provenance

| Mark | Meaning | This audit's evidence |
|---|---|---|
| S | Current source inspected | Routes, screens, relevant ViewModels/repositories, shared components, validators, tests and installed Flutter/Dart SDK behavior |
| V | Existing render inspected | All 68 existing PNG golden artifacts were opened and reviewed; no baselines regenerated |
| D | Independent read-only diagnostic | Git inspection, file hashes, source searches, installed-SDK inspection, contrast calculations and ADB device enumeration |
| H | Historical/reported execution | R-06D reports 835 focused tests, 68 golden comparisons, clean analyze and Android debug/release builds; these were not rerun here |
| U | Unverified | Fresh application execution, physical Android/TalkBack, live services, profile-mode measurements and proposed regression scenarios |

The user permits changes to this report only. Fresh Flutter tests, analysis and builds were not invoked because they can write generated caches/artifacts. **New test-suite pass/fail/skip counts: not run, not zero failures.** Existing renders are host-test outputs with controlled fixtures, sometimes taller than a phone viewport. They are evidence of composition, not live backend content or physical performance. Source findings are not described as newly executed tests.

ADB reported no connected device. No fresh screenshots, physical interaction, camera permission checks, TalkBack results, FPS, frame timing or memory benchmarks are claimed. No backend/AI/provider calls, real mutations, model evaluation or database operations were performed.

Inputs included `AGENTS.md`, Flutter architecture, design-system and R-02 through R-06D implementation documentation, current project-state/known-issues documentation, actual UI and supporting code, and existing tests. Historical documentation was treated as evidence to reconcile, not authoritative proof of current execution.

## 2. Weighted score

These are independent design/engineering judgments, not benchmark measurements. Confidence is limited where execution or device evidence is absent.

| Category | Score | Strengths and evidence | Defects / improvement potential | Confidence |
|---|---:|---|---|---|
| Visual aesthetics | 12/15 | Cohesive forest/canvas palette, bundled Plus Jakarta Sans, restrained surfaces; all 68 renders reviewed | Long explanatory blocks, heavy record headers and repeated card hierarchy; R07-06–08 | High for represented states |
| Navigation and UX | 13/15 | Five persistent Farmer branches, central Scan, Home Profile entry, grouped Admin shell; router and navigation renders | Selected-photo exit guard; short-window discoverability; R07-02/07 | Medium-high |
| Scanning and results | 10/12 | Explicit upload confirmation, real progress, protected preview, honest unconfigured-threshold display | Next actions too deep; image failures generic; R07-04/06 | Medium-high; no live scan |
| AI Assistant | 8/10 | Persistent conversation/draft, pinned composer, citations, bounded local turns and guarded explanation handoff | Focus modal identity risk and large empty-state introduction; R07-01/07 | Medium |
| Knowledge and sources | 8/10 | Source-backed sections, reference rights, attribution, gallery/viewer and copyable references | Media date validation, image feedback, optional direct-source opening; R07-03/04/12 | Medium-high |
| Farmer tools/account | 8/10 | Explicit units, reviewed-rate semantics, pending states, private history, avatar reconciliation | Result handoff and photo-draft protection; R07-02/10 | Medium-high |
| Admin experience | 10/12 | Complete navigation, versioned content workflows, dirty guards, structured specifications, offline/runtime separation | Filter/technical density, eager CMS children, audit labels; R07-05/08/09 | Medium-high |
| Accessibility | 4/6 | Strong checked contrast, persistent field labels in most editors, textual chart summaries, semantic states | Audit-label truncation risk, one reduced-motion inconsistency, physical AT unverified; R07-05/11 | Medium |
| Responsiveness | 4/5 | Compact navigation and expanded sidebar; representative narrow/large-text renders | Short keyboard windows and incomplete cross-feature 1280dp/long-content closure; R07-05/07/08 | Medium |
| Performance / maintainability | 3/5 | Provider/MVVM retained, bounded chat/image concurrency, pagination, disposed controllers | CMS eager children and no device profiling; R07-09 | Medium-low for actual runtime cost |
| **Total** | **80/100** | | | |

## 3. Screen inventory and review coverage

All paths below are frontend routes, not claims of live API availability. `V` identifies a representative existing render; it does not cover every state. Source/test inspection cannot establish that a screen has passed a fresh interactive journey.

### Farmer and Guest

| Route / presentation | Actual screen and responsibilities | Coverage and remaining gap |
|---|---|---|
| `/home` | `HomeView`: Guest/Farmer header, Profile, Scan hero, quick actions, recent authorized scans, connection status | S/V Guest light and Farmer dark; live history/retry U |
| `/knowledge` | `KnowledgeView`: library/search/filter and reviewed catalogue | S/V light/dark; live search U |
| `/knowledge/:slug` | `KnowledgeDetailView`: reviewed sections, optional metadata, citations and gallery | S/V detail/gallery; all inactive/empty/live-source combinations U |
| Reference gallery / viewer | Embedded protected gallery and fullscreen image viewer, not a new primary route | S/V gallery/viewer; genuine licensed assets and device zoom U |
| `/scan` | `ScanView`: ready, selected, upload, processing, failure, lost-picker recovery | S/V ready/selected/uploading; real camera, recovery, processing and network failures U |
| `/scan/result/:scanId` | `ScanResultView`: protected image, prediction, uncertainty, actions, scores and technical disclosure | S/V light/dark/details; live capability expiry U |
| `/assistant` | `AssistantView`: empty/conversation, draft/composer, citations, retry and bounded local turns | S/V empty/chat/keyboard; actual generation U |
| Assistant Focus sheet | Root-navigator modal with disease/topic controls | S; no modal identity-transition execution; R07-01 |
| Assistant scan picker | Root-navigator picker with session-aware history and selected-scan handoff | S and existing test inspection; no fresh sheet render or live ownership test |
| `/tools` | `ToolsView`: fertilizer/yield destinations | S/V |
| `/tools/fertilizer` | `FertilizerView`: area/unit/rule, source assumptions, pending/result | S/V pending/result; real approved rule availability U |
| `/tools/yield` | `YieldView`: reference-rate planning estimate and pending/result | S/V pending/result; real approved configuration U |
| `/profile` | `ProfileView`: Guest/account state, appearance, History, Insights and Admin entry | S/V Guest/Farmer; persisted appearance source inspected, not freshly executed |
| `/profile/sign-in` | `AuthIntroView`: Farmer authentication and Guest return | S/V sign-in; live login U |
| `/profile/register` | `RegistrationView`: local confirmation and current registration policy | S/V registration; live account creation not attempted |
| `/profile/edit` | `ProfileEditorView`: text profile and separate photo selection/upload/removal | S/V; selected-photo Back and ambiguity scenarios U |
| `/profile/data-deletion` | `PrivacyView`: request state, supported privacy wording and actions | S/V requested state; no real request made |
| `/profile/history` | `HistoryView`: authorized cursor history, retry/empty and protected thumbnails | S/V; live pagination U |
| `/profile/history/scans/:scanId` | Existing authorized result presentation reused for saved scan | S; representative result renders above, not a separately executed history journey |
| `/profile/analytics` | `AnalyticsView` / Field Insights: usage, distribution, dates and confidence context | S/V summary/distribution; no ground-truth accuracy claim |
| `/`, legacy route, unknown route | Root redirects Home; `/tools/assistant` redirects to `/assistant` preserving supported query context; not-found fallback | S; no fresh Back/deep-link execution |

`StatefulShellRoute.indexedStack` retains **Home / Learn / Scan / AI Assistant / Tools**. Profile is outside the bottom tab set and remains reachable through Home and account links. Admin has a separate shell. The redesign did not remove History or Field Insights access in the inspected router. Conditional/error states without their own golden are marked source-reviewed, not visually certified.

### Admin

| Route / management area | Current presentation and workflow | Coverage |
|---|---|---|
| Any guarded Admin entry | `AdminAccessView`: separate Admin sign-in, no public Admin registration | S/V dark sign-in and narrow large-text sign-in |
| Admin workspace shell | Grouped compact drawer / expanded labelled sidebar, current section, Farmer return and sign-out | S/V 320dp/2x drawer and expanded workspace |
| `/admin` | Overview with actual summaries, availability and AI Operations preview | S/V populated/empty, phone/tablet |
| `/admin/ai-operations` | Dedicated operational activity, outcomes, latency, periods and availability | S/V phone/chart/unavailable |
| `/admin/manage?area=diseases` | Disease metadata, immutable classifier relationship and reviewed optional facts | S/V catalogue/Healthy editor |
| `/admin/manage?area=knowledge` | Document draft, source/review, indexing and separate activation/version actions | S/V list/editor/sources |
| `/admin/reference-images` | Upload/review, provenance, rights, visibility/order and cleanup-related actions | S/V list/editor/empty; no real upload/publication |
| `/admin/manage?area=fertilizers` | Product catalogue/composition, frozen identity and copy/new workflow | S/V list/composition/frozen product |
| `/admin/manage?area=fertilizer` | Reviewed product kg/ha application rules and version/status | S/V rule list/editor |
| `/admin/manage?area=yieldRules` | Reviewed reference-yield configurations and planning limitations | S/V list; supporting editor/source code inspected |
| `/admin/manage?area=modelSpecifications` | Structured/Advanced JSON agronomic specifications, disabled/non-executable | S/V both modes; existing round-trip tests read, not rerun |
| `/admin/farmers` | Cursor-backed accounts, filters, status confirmation and conflict/error handling | S/V phone/tablet/confirmation |
| `/admin/audit` | Read-only immutable audit records, filters and expandable details | S/V list/detail; long-label risk remains |
| `/admin/model-health` | Production identity, readiness, offline evaluation evidence and runtime information | S/V overview/evidence/runtime/unavailable |

These are 12 navigation destinations; the sign-in gate and modal editors are additional presentations. Shared confirmation, source, editor and gallery surfaces were inspected where artifacts existed. Not every dialog/permission state has a screenshot.

### Render inventory

All images under the following groups were opened: `test/widgets/goldens/` (3), `test/navigation/goldens/` (4), R-03 redesign images (8), R-04 (8), R-05 (12), R-06A (8), R-06B (8), R-06C (8), R-06D (9): **68 inspected artifacts**. This is an inspection count, not 68 newly passing comparisons.

Fixtures include synthetic leaves, users, rates and model metrics. They demonstrate rendering only. A fixture's 100% metric or sample rate is not a claim about the deployed model or a publishable agricultural recommendation. In-memory pixel inspection confirmed leaf pixels in both selected/uploading previews; apparent blankness in a preview tool was not recorded as an application defect. Similarly, the registration brand mark was not incorrectly classified as absent.

## 4. Scientific truth, feature parity and security observations

| Area | Source/render finding | Evidence boundary |
|---|---|---|
| Classifier identity | Four fixed mappings remain `Common_Rust`, `Gray_Leaf_Spot`, `Healthy`, `Northern_Corn_Leaf_Blight`; metadata editing does not retrain classes | Dart model/mapping and result/CMS code; no artifact promotion or inference executed |
| Confidence | Null threshold / `THRESHOLD_UNCONFIGURED` remains explicit. Raw probability is not certified accuracy; low-confidence wording is retained | Result summary and model-health presentation; no invented threshold/calibration |
| Healthy | Does not clear the entire field or imply absence of every disease | Result's Healthy-specific caution inspected |
| Knowledge | Reviewed/source content is distinguished from model output. Missing content stays missing | Detail/section/source presentation; no agricultural facts invented here |
| Fertilizer | Composition N/P2O5/K2O percentages are distinct from reviewed product kg/ha rates | R-06C cards/editor and Farmer result; calculations remain backend-authoritative |
| Yield/specifications | Area × reviewed reference yield is a conditional planning estimate. Saved richer specifications remain non-executable | Farmer yield and structured/JSON Admin presentation |
| Operations/model health | Offline evaluation, runtime outcomes, provider calls and availability remain separate. Event totals are not unique Farmer questions or model accuracy | Operations panels, metrics DTOs and offline/runtime sections |
| Sources/media | Source, attribution, rights/review and publication status remain visible; draft/index/activate stages are distinct | CMS/reference forms and repository contracts; no real content license independently authenticated |
| Sessions/ownership | Independent Farmer/Admin state, revision-scoped providers, repository authorization and Guest capability boundaries remain in source | No backend authorization re-test; Focus-sheet exception investigated in R07-01 |
| Private images | Protected Node transport, identity-sensitive keys, bounded requests, no new raw Cloudinary delivery path found | `PrivateImage`, image repository and consuming views; physical/cache instrumentation U |
| Assistant | At most 12 local turns; no transcript persistence/full-history request introduced; handoff and late-response revision checks remain | Router, ViewModel and existing navigation/Assistant tests read; root Focus modal remains a risk |
| Profile | Ambiguous successful photo mutations reconcile through a profile read; no automatic destructive replay introduced | Profile ViewModel/repository inspection; live provider timeout U |
| Admin | Dirty guards, frozen product restrictions, revision conflicts, account confirmations and read-only audit semantics are preserved | Source and representative rendered fixtures, not live mutations |

No plaintext credential or token presentation was found in the inspected UI paths. This is a scoped source observation, not a whole-repository secret-scan certification. No evidence justifies changing authentication, formulas, ML preprocessing, confidence policy, content rights or backend authorization as part of R-07B presentation work.

## 5. Prioritized finding matrix

Paths in findings are relative to `mobile/`; line numbers refer to the inspected working tree, including uncommitted work.

| ID | Priority / classification | Area | Evidence | Recommended order |
|---|---|---|---|---|
| R07-01 | **P1 investigation priority; runtime outcome unverified** | Assistant Focus modal / identity change | S: root modal retains old route-scoped ViewModel | Reproduce first; fix lifecycle only if confirmed |
| R07-02 | P2 source-confirmed guard omission | Profile photo draft | S: dirty guard covers text but not selected image | Early |
| R07-03 | P2 source/SDK-confirmed validation gap | Reference review date | S/D: `tryParse` normalizes impossible dates | Early |
| R07-04 | P2 source-confirmed feedback gap | Protected images | S/V: errors discarded, generic retry image | Early |
| R07-05 | P2 source-derived accessibility risk | Audit filter labels/options | S/V: legacy floating/default dropdown constraints | Reproduce long-content cases, then refine |
| R07-06 | P2 rendered hierarchy problem | Result next actions | V/S: repeated caution blocks precede actions | Core flow polish |
| R07-07 | P2 rendered short-window usability | Home, Assistant empty state, Admin sign-in | V: large text/keyboard leaves little actionable context | Core flow polish |
| R07-08 | P2 rendered density / hierarchy | Admin and Field Insights | V/S: controls/prose/full cards precede useful data | Adaptive presentation |
| R07-09 | P2 source-confirmed scalability risk; cost unmeasured | CMS accumulated lists | S: all visible cards in scrollable Column | Bounded performance refinement |
| R07-10 | P2 source-confirmed interaction omission | Calculator result handoff | S/V: appended result without visual focus/scroll handoff | Calculator presentation |
| R07-11 | P2 source-confirmed motion inconsistency | Protected image loading | S/SDK: unguarded indeterminate spinner | Shared component refinement |
| R07-12 | P3 optional convenience | Source references | V/S: copy supported, direct opening absent | Optional, after functional gates |

### R07-01 — Root Assistant Focus sheet outlives its identity-scoped owner

- **Location:** `features/ai_assistant/views/assistant_view.dart:128–148`; `core/routes/app_router.dart:390–411`; `features/ai_assistant/view_models/assistant_view_model.dart:234–240`; `features/ai_assistant/widgets/assistant_focus_panel.dart:22–65`.
- **Evidence:** `_focus` places a modal on the root navigator and passes the current model with `ChangeNotifierProvider.value`. The route's provider is keyed by session revision. Disposing the old model clears turns and selected scan, but its disease/topic fields remain. No explicit Focus-sheet dismissal/rebinding on identity revision was found. The separate scan picker has session-aware guards and must not be conflated with this sheet.
- **Reproduction to execute:** Open Assistant, select a disease/topic or explain an owned scan, open Focus, then expire/revoke/change the Farmer identity while the modal remains open. Inspect sheet content, dismiss it, and reopen for the new identity. Exercise logout and Guest transitions too.
- **Impact:** A modal can retain an obsolete model/context or become inert; stale disease context could remain visible. Whether GoRouter transitions dismiss it in every affected path is **not established**. No cross-account backend access or leaked scan image/turn was demonstrated.
- **Suggested patch:** Scope the sheet to the Assistant/session lifecycle, or dismiss it explicitly when the captured revision becomes invalid. Never transfer old context to a new model. Preserve root-sheet layout and once-only scan handoff.
- **Regression risk:** Medium: navigator selection, tab retention and session teardown interact.
- **Acceptance:** Test actual session changes with Focus open; assert no obsolete context/VM notifications, no disposed-notifier errors, no additional explanation request, and unchanged normal tab/draft retention. Downgrade/close the risk if execution establishes safe dismissal already occurs.

### R07-02 — Staged profile photo is outside the existing dirty guard

- **Location:** `features/profile/widgets/profile_editor_form.dart:24–29,77–85`; `features/profile/views/profile_editor_view.dart:73–85`; `features/profile/widgets/profile_photo_editor.dart:82–112`.
- **Evidence:** Form dirtiness compares name/region/country/area only. The separate photo editor holds a newly selected candidate with Upload/Discard controls. A photo-only selection does not make the form's Back guard dirty.
- **Reproduction:** Open Edit Profile, choose a valid replacement without uploading, leave text unchanged, press app/system Back. Compare with editing text first. Source establishes the missing candidate predicate; this interaction was not executed here.
- **Impact:** Accidental loss of an unsaved local photo choice, not deletion of the current server avatar.
- **Suggested patch:** Coordinate text and selected-photo dirtiness at page level using existing state; one confirmation only. Preserve in-flight mutation reconciliation and current avatar until acknowledged.
- **Regression risk:** Medium: avoid blocking reconciled saves or double dialogs.
- **Acceptance:** Photo-only/text-only/combined drafts warn; Cancel preserves candidate/text; explicit Discard and completed upload remove only applicable dirtiness; session change clears private draft; no duplicate upload/removal.

### R07-03 — Reference-image date validation accepts normalized impossible dates

- **Location:** `features/admin/widgets/reference_editor.dart:145–188`, especially `180–184`; `data/repositories/reference_media_repository.dart:43–68`.
- **Evidence:** `retrievedAt` checks a date-shaped regex and `DateTime.tryParse`. Installed Dart SDK `lib/core/date_time.dart:304–306` documents normalization of out-of-range components. Thus date-shaped input such as `2026-02-30` passes this local calendar check. Repository serialization adds no strict calendar validation. Backend remains authoritative; no corrupt persisted date is claimed.
- **Reproduction:** Enter a complete source form with `2026-02-30`, then attempt validation/save against a test double. Also test leap years and day zero.
- **Impact:** Misleading local acceptance and avoidable server rejection; inconsistent review-date quality.
- **Suggested patch:** Validate parsed year/month/day against the literal components, preserving the existing date-only wire format and limits. Do not invent a new backend date contract.
- **Regression risk:** Low.
- **Acceptance:** Reject invalid calendar days/months; accept valid leap-day and ordinary dates; preserve exact submitted string; no real media mutation required.

### R07-04 — Protected-image failures lose their actionable meaning

- **Location:** `core/widgets/private_image_view_model.dart:13–29`; `core/widgets/private_image.dart:42–69`; consumers include result, history, avatar and gallery.
- **Evidence:** The ViewModel catches every failure without keeping an error category. Missing bytes/decode failure renders a broken-image retry control, regardless of network failure, expired authorization or unavailable image. Existing renders/test fixtures demonstrate success states, not differentiated failure feedback.
- **Reproduction:** Use repository doubles for timeout, no-network, access expiry, forbidden, missing image and malformed bytes. Read resulting UI and semantics.
- **Impact:** Users cannot tell whether to retry, sign in again or accept missing media. An icon/tooltip alone gives little context.
- **Suggested patch:** Keep a safe typed presentation state and concise inline text/retry or account action where applicable. Preserve protected transport, identity fencing and concurrency limits. Never expose raw URLs, tokens or provider exceptions.
- **Regression risk:** Medium because it is shared.
- **Acceptance:** Each supported safe category has appropriate wording/action and semantics; retry does not exceed queue bounds; old identity bytes never replace current image; decode errors remain recoverable.

### R07-05 — Audit filters retain legacy floating labels and default-height options

- **Location:** `features/admin/views/audit_log_view.dart:97–181`; compare persistent wrapping fields elsewhere and installed Flutter `input_decorator.dart:2403`.
- **Evidence:** Action/affected-record dropdowns use floating labels and default dropdown geometry; Actor/from/through fields use `labelText`. The SDK label is ellipsized. Existing narrow renders and tests do not establish full long-option readability at 200% text. This is a source-derived clipping/truncation risk, **not a newly observed RenderFlex exception**.
- **Reproduction:** At 320dp/200%, expand filters, select longest valid action/resource labels, open menus and focus all date/actor fields with keyboard visible.
- **Impact:** Truncated labels and constrained selected values reduce accessibility and filter confidence.
- **Suggested patch:** Use existing persistent wrapping field presentation and adaptive dropdown item/selected-value height. Keep values, UTC boundary semantics and apply/reset behavior unchanged.
- **Regression risk:** Low-medium.
- **Acceptance:** Full label/value remains accessible and readable; assert glyph/semantics visibility, not just absence of framework exceptions; tab traversal and date validation unchanged.

### R07-06 — Repeated uncertainty prose separates the result from its next actions

- **Location:** `features/disease_detection/widgets/prediction_summary.dart:98–125,156–210,270–292`; `features/disease_detection/widgets/scan_result_card.dart:37–66`; `features/disease_detection/views/result_view.dart:111–175`.
- **Evidence:** `result-uncertain-light.png`, dark and details renders: image/status/category are followed by probability caveats, threshold explanation and next-step caution before the action group. In the tall light fixture actions sit beyond an ordinary initial phone viewport. A tall golden does not make the whole composition initially visible on a phone.
- **Reproduction:** Open a completed null-threshold result on 360×800 and 320dp/200%; measure scrolling needed to reach Learn/Explain/Scan Another, retaining image and lead category.
- **Impact:** Good scientific caution becomes repetitive and delays the intended next step.
- **Suggested patch:** Keep one clear visible uncertainty summary and Healthy-specific boundary; bring primary actions directly after it. Put the fuller softmax/policy explanation in an accessible disclosure with the existing technical details. Do not change model status, values or certainty.
- **Regression risk:** Medium: preserve mandatory warnings, all scores and authorized handoff.
- **Acceptance:** Null threshold and no-diagnosis claim remain explicit before action; Learn mapping and once-only Explain work; all existing information remains available; shorter phone composition without clipped text.

### R07-07 — Short-height and keyboard layouts spend too much space on introduction

- **Location:** `features/home/widgets/home_scan_hero.dart:13–61`; `features/ai_assistant/widgets/assistant_empty_state.dart:22–75`; `features/admin/views/admin_sign_in_view.dart:37–52` and its shared `core/widgets/auth_header.dart` presentation. `AdminAccessView` mounts that sign-in screen; it does not draw the authentication heading itself.
- **Evidence:** `navigation-light-320-2x.png`, `r04-assistant-keyboard-2x.png`, `r06a-sign-in-light-320-2x.png`: long hero/introduction treatment pushes primary body actions down; keyboard Assistant shows mostly introduction; narrow Admin heading wraps awkwardly. The persistent Scan tab and pinned composer remain available. This is inefficiency, not proof of an inaccessible app.
- **Reproduction:** Compare no-keyboard and keyboard-open layouts at 320dp with 200% text, then landscape short height. Use real focus traversal, not a tall image alone.
- **Impact:** More scrolling, reduced conversation space, lower visual polish outdoors/on small phones.
- **Suggested patch:** Adapt nonessential padding/illustration and empty-state copy to available height/keyboard. Retain heading identity, useful guidance and all destinations. Never clamp system text or hide navigation labels.
- **Regression risk:** Low-medium.
- **Acceptance:** Primary controls and composer remain discoverable; input is not obscured; 100/150/200% scaling and reduced motion retain semantic order; large displays keep balanced composition.

### R07-08 — Management and Insights prioritize filters/provenance over records

- **Location:** `features/admin/widgets/admin_content_management.dart:73–91,177–220`; `features/admin/views/farmer_management_view.dart:96–191`; `features/admin/widgets/admin_calculator_card.dart:107–112`; `features/admin/widgets/ai_operations_panel.dart:42–113`; `features/analytics/widgets/analytics_cards.dart:13–40`.
- **Evidence:** R-06B/C list renders begin with area controls/filter explanations and long record metadata. `r06d-accounts-dark-tablet.png` keeps a predominantly single-column card treatment despite expanded width. Operations places several scope paragraphs before values. `r05-insights-dark.png` uses four full-width summary cards before the chart. Full revision hashes consume reading space in product cards.
- **Reproduction:** At phone height, count meaningful records/metrics visible before scrolling. At 1280dp, compare available content width to card density; expand controls/details rather than deleting them.
- **Impact:** Slower scanning and unnecessary travel between filters, counts, records and management actions.
- **Suggested patch:** Concise persistent scope summary, collapsible filters/provenance, compact selectable revision disclosure, adaptive two-column metrics/list-detail only where widths permit. Keep search explicitly limited to loaded records, source access, actual statuses and all mutation actions.
- **Regression risk:** Medium: preserve query synchronization, status filters and dirty guards.
- **Acceptance:** One clear heading/scope, useful data near the top, full details reachable; zero/unavailable remain distinct; expanded widths improve density without shrinking text; long names/URLs and all guarded navigation remain usable.

### R07-09 — CMS cards are eagerly mounted as the loaded set grows

- **Location:** `features/admin/widgets/admin_content_management.dart:40–73,240–259`; scrolling comes through `core/widgets/app_page.dart`. Existing reusable contrast: `features/admin/widgets/admin_record_page.dart:33–61` uses `SliverList.builder`.
- **Evidence:** Loaded items are filtered into a list and inserted with `for (final item in visible)` inside the page's Column. Product/knowledge pagination can increase that set; text changes rebuild the filtered tree. Farmer/Audit record pages already use lazy children. Latest-rule/spec responses are bounded, so those are not described as unbounded APIs.
- **Reproduction:** With local test doubles, append several pages of long product/knowledge records, type filters and inspect built-child count. Profile on a device before assigning a frame-time impact.
- **Impact:** Unnecessary widget/layout work and memory growth with accumulated pages; no measured jank or leak is claimed.
- **Suggested patch:** Reuse the existing lazy Admin record/sliver approach for the list state. Keep editor, cursor/load-more semantics, loaded-record search scope and draft guard unchanged.
- **Regression risk:** Medium: preserve scroll position and record identity.
- **Acceptance:** Offscreen children are not all mounted; cursor boundaries and filters work; opening/editing/returning restores expected list state; measure before/after on a device. Do not make unsupported claims about other `ListView` delegates or the intentionally bounded 12-turn chat.

### R07-10 — Successful calculation has no visual result handoff

- **Location:** `features/fertilizer_calculator/views/fertilizer_view.dart:131–158`; `features/yield_calculator/views/yield_view.dart:157–188`; `features/tools/widgets/planning_result_summary.dart:46–58`; `test/redesign/r05_layout_test.dart:50–65`.
- **Evidence:** The authoritative response is appended below Calculate without an explicit scroll/focus handoff. The result quantity already has `liveRegion: true`; an assertion that it lacks any accessibility announcement would be incorrect. Layout tests programmatically calculate/find text rather than proving visibility after a keyboard-open tap.
- **Reproduction:** On a short phone at 200%, focus area, enter valid input, calculate via button/keyboard with a delayed success. Verify whether result is visible without exploratory scrolling. Repeat error/retry.
- **Impact:** A visually successful operation can appear unchanged when the response is below the viewport.
- **Suggested patch:** After the acknowledged result, dismiss input focus and make the result heading visible using a bounded presentation-only scroll/focus action, respecting reduced motion. Do not change quantities, rounding, rules or requests.
- **Regression risk:** Low-medium: guard against jumping repeatedly on rebuilds or old responses.
- **Acceptance:** One handoff per successful calculation, no movement on mere rebuild, clear errors, keyboard-safe 320dp/200% and unchanged numerical/source/version output.

### R07-11 — Shared protected-image loading bypasses reduced-motion presentation

- **Location:** `core/widgets/private_image.dart:51–56`; contrast `core/widgets/app_states.dart:16–22` and the scan processing presentation.
- **Evidence:** Image loading directly constructs an indeterminate `CircularProgressIndicator`, while shared loading states explicitly provide a static alternative under disabled animations. Installed SDK implementation repeats the indeterminate controller; no corresponding image-level adaptation exists.
- **Reproduction:** Force a pending protected-image request with `MediaQuery.disableAnimations = true`; inspect scheduled animation and semantics. Repeat with normal preference.
- **Impact:** Inconsistent product reduced-motion behavior. Functional progress animation is not automatically a WCAG violation; this audit does not certify such a violation.
- **Suggested patch:** Reuse the existing reduced-motion-aware loading treatment, with appropriate image-loading semantics.
- **Regression risk:** Low.
- **Acceptance:** Static, announced loading under reduced motion; normal progress otherwise; no loss of retry/image identity protection.

### R07-12 — Source URLs are copyable but lack an explicit open action

- **Location:** `core/widgets/source_reference_card.dart:30–85`.
- **Evidence:** References preserve title/provenance and selectable/copyable URL; copy actions work by design. There is no direct external-source action. This is optional convenience, not a dead-link defect.
- **Reproduction:** Open a citation and try to follow its reference without copying to a browser.
- **Impact:** Extra effort when checking evidence during a demonstration.
- **Suggested patch:** If desired, add an explicit user-initiated safe HTTPS source action using the project's approved link handling. Retain copy and provenance; never fetch arbitrary content automatically or bypass URI validation.
- **Regression risk:** Low-medium because external-app behavior and accessibility need verification.
- **Acceptance:** Valid public HTTPS opens only on user action; unsupported/malformed links cannot execute; copy remains; failed browser launch gives safe feedback. Defer if it requires widening scope or a new dependency without benefit.

## 6. Visual design assessment

The forest/leaf/lime identity works in both themes. Plus Jakarta Sans is locally bundled with its license; no runtime font fetching was found. The central Scan mark and native branding are materially better than the previous default identity. Most statuses use semantic labels/icons rather than color alone. Cards, persistent field labels and spacing are consistent across Farmer and Admin.

The largest visual problem is **hierarchy, not palette**. Results repeat uncertainty, management pages repeat explanatory/technical content, and metric sections use more vertical space than their information requires. Patches should simplify visible structure while preserving disclosure, sources and scientific boundaries. New gradients, extra illustrations or a replacement component library would not address these problems.

Golden examples demonstrating strengths: `home-guest-light.png`, `scan-selected-dark.png`, `r04-library-light.png`, `r04-gallery-light.png`, `r06a-overview-dark-tablet.png`, `r06c-composition-editor-light.png`, `r06d-model-evidence-dark.png`. Examples requiring hierarchy refinement: result uncertainty renders, Assistant keyboard empty state, R-06B/C list headers, R-06D wide account list and R-05 Insights summary.

## 7. Accessibility and responsive assessment

### Independently checked contrast

A read-only contrast calculation evaluated **50 text/background token pairs** from the current light/dark semantic palette. Minimum checked ratio: **5.20:1**; **0 checked pairs below 4.5:1**. This supports the selected semantic text roles; it is not exhaustive pixel-level certification of every screen, image, disabled state, focus outline or chart.

White on the Earth accent is approximately **3.58:1** and must not be used for ordinary body text. Its inspected role is decorative; no current white-body-on-Earth failure was established. Disabled controls should not be misclassified as ordinary active text for contrast scoring.

### Source strengths and limitations

- Shared controls generally use 48dp targets and responsive button geometry; navigation labels remain visible, including narrow `AI` with a full accessible Assistant label.
- Headings, textual status explanations, chart summaries and result live regions improve nonvisual understanding.
- AppPage/scrolling forms and the pinned composer account for keyboard/safe areas; that does not prove every nested modal's physical focus behavior.
- Persistent labels elsewhere make the remaining Audit floating-label approach stand out. R07-05 needs long-text selected-value tests rather than only overflow checks.
- Reduced-motion handling exists broadly, with R07-11 a specific inconsistency.
- No physical TalkBack, switch-access, focus restoration, native permission-dialog or outdoor readability acceptance was possible. No universal WCAG compliance claim is made.

### Responsive coverage table

| Scenario | Existing evidence reviewed | Closure still needed |
|---|---|---|
| 320/360/412/480dp | R-03–R-06 layout test source and representative renders | Fresh execution, long translated/technical labels, real keyboard/insets |
| 600/840/1024dp | Farmer/Admin responsive tests; tablet artifacts | Real split-screen/landscape interaction and modal focus |
| 1280dp | Admin layout test source and expanded goldens | Farmer R-03/R-04/R-05 matrices stop at 1024; extend representative tests rather than imply full coverage |
| 100/150/200% text | Existing matrix tests and selected 2x renders | Audit long selected values, after-calculation visibility, short-height Assistant and auth |
| Light/dark | Both represented across all release groups | Not every state has both themes; fresh comparison after targeted fixes |
| Reduced motion | Source guards and tests | Pending-image exception and actual interaction transitions |

No new RenderFlex overflow was reproduced by executing tests in this audit. A clipping risk, excessive scrolling and inconvenient hierarchy are not interchangeable with a proven framework layout exception.

## 8. Performance and maintainability

Positive source findings include stable selected-image subtrees during progress, explicit upload actions, bounded local Assistant history, near-bottom-aware conversation scrolling, session-revision fences, disposed controllers, cursor-backed History/accounts/audit, image decode sizing, and a private-image repository bounded to two active requests plus a 32-entry waiting queue. Reference gallery presentation bounds visible work. These are useful engineering safeguards, not measured performance claims.

R07-09 is the clearest remaining list-construction concern. It can be fixed by reusing the lazy record infrastructure rather than inventing another abstraction. The intentionally short chat does not need a speculative virtualization rewrite that could break anchors or draft retention.

No device startup latency, frame budget, peak RSS, image-cache lifetime, sustained memory trend or battery measurement was collected. APK compilation does not establish smoothness. Recommended measurement: a profile-mode representative phone run of Home → history paging → protected result → tab-retained Assistant → large Admin catalogue, with frame/memory observations and session change. Keep fixture/provider costs bounded and distinguish debug overhead from release/profile behavior.

## 9. Exact recommended patch boundaries

These are recommendations only; **none were implemented**.

| Patch | Existing code to change | Preserve / avoid |
|---|---|---|
| A — Modal lifecycle | Assistant Focus sheet owner and identity-aware dismissal; regression test first | Preserve permanent branch, Guest questions, draft retention and one explanation per handoff; no API change |
| B — Unified local draft boundary | Profile edit page/form/photo integration | Current avatar, acknowledged persistence and GET reconciliation; no destructive replay |
| C — Calendar validation | Reference editor's date-only validator, reuse a suitable existing helper if present | Literal wire format and backend authority; no source/date fabrication |
| D — Safe image presentation | Private-image ViewModel/widget and focused tests | Protected endpoint, revision keys, bounded concurrency and no token/URL disclosure |
| E — Action hierarchy | Result summary/actions and compact Home/Assistant empty layouts | Visible uncertainty, Healthy boundary, all actual scores/details and feature reachability |
| F — Admin density | Existing list headers/cards/filter disclosures and adaptive metric grouping | Exact fields, filter semantics, revision/conflict state, all navigation/draft guards |
| G — Lazy CMS list | Existing CMS list branch using Admin lazy record/sliver infrastructure | Cursor behavior, list restoration and loaded-record search scope |
| H — Calculation handoff | Fertilizer/Yield presentation scroll/focus coordination only | Deterministic results, source/version, units and unchanged repositories/payloads |
| I — Motion and labels | Existing image loading component and Audit presentation controls | Current accessible semantics, UTC filters and normal loading behavior |
| J — Optional source opening | Existing source card and approved external link utility | Copy, citations and user-controlled safe navigation |

Do not use R-07B to rewrite Provider, GoRouter, repositories, auth, calculator engines or model contracts. Review current line numbers/diffs again before implementation because this audit includes uncommitted R-06D work.

## 10. Required regression tests and acceptance plan

### First: close the lifecycle and validation uncertainties

1. Reproduce R07-01 with Focus open through Farmer expiry, logout, account switch, Guest transition and widget teardown. Assert no stale disease/topic/context or disposed-model usage; keep ordinary tab retention.
2. Test photo-only/text-only/combined profile drafts, one confirmation, Cancel preservation, explicit discard, ambiguous photo mutation reconciliation and identity clearing.
3. Test strict reference dates, including leap/non-leap February, invalid month/day, valid dates and unchanged serialization.
4. Test safe protected-image states, expired authorization, malformed bytes, retries, queue bounds, revision changes and reduced motion.

### Then: verify targeted visual changes

5. Result: all four labels, Healthy wording, null threshold/low-confidence status, Learn mapping, authorized once-only Explain, class scores and model details. At phone height verify actions are reachable with concise caution still visible.
6. Home/Assistant/auth: short landscape and keyboard windows at 320/360dp/200%; Guest private-history requests remain absent; main navigation/composer not obscured.
7. Admin: long Audit labels/options at all target scales, date boundaries, scope/zero/unavailable semantics, collapsed/expanded filters, query synchronization and guarded route transitions.
8. CMS: locally paginated large fixture set, lazy mounted-child count, filtering/load-more/restored position, editor identity and all publication/revision protections.
9. Calculators: actual button/keyboard submission with delayed success, error and retry; ensure visible result handoff once; preserve existing live-region output and all deterministic fixtures.

### Run only after implementation is separately authorized

Use existing repository tooling: format affected Dart files, `flutter analyze`, the named feature/widget/ViewModel and session/router regressions, relevant R-01 foundation tests, and targeted golden comparisons. Inspect new renders before updating only affected baselines. Run Android ARM64 staging debug/release gates using the existing documented build configuration; do not substitute an unverified release command or bypass signing/environment checks.

Do not blindly run provider-backed suites, mutate real Admin records or regenerate all goldens. Retain exact command/run identities and pass/fail/skip counts. R-06D's historical 835 tests and 68 comparisons remain historical evidence until independently executed again.

## 11. Device, live-service and release gates

| Gate | Status in this audit | Required closure |
|---|---|---|
| G01 — Physical Android / accessibility | **NOT VERIFIED; no ADB device** | Camera/gallery permissions, lost-picker return, navigation/Back, keyboard/insets, TalkBack/focus, account changes and safe protected-image behavior |
| G02 — Profile-mode performance | **NOT MEASURED** | Frame/memory observations on a representative phone, especially loaded CMS lists and image/history journeys |
| G03 — Fresh static/widget/golden/build checks | **NOT RUN in report-only scope** | Execute after scoped R-07B changes; include long content, short windows and Farmer 1280dp closure |
| G04 — Configured live application journey | **NOT VERIFIED by this audit** | Controlled, authorized real Node/FastAPI/DB flow with real ownership, RAG source availability and supported calculators; no synthetic production data |
| G05 — Content and public-release approvals | **Not an audit approval** | Licensed reference photographs, reviewed calculator/domain data, appropriate model claims, privacy/retention and production security/infrastructure gates |

Current `README.md`, `docs/PROJECT_STATE.md` and `docs/KNOWN_ISSUES.md` still describe Phase 25 as partially complete and retain a configured full E2E result `20261018T173013Z-6deb0e3f` of **19 PASS / 2 FAIL / 0 selected skips**. These are historical application-integration records, not newly reproduced frontend defects or proof that today's services are down. This report neither overwrites them with Flutter unit passes nor fabricates their root cause. Public readiness requires a separate reconciliation using current configured evidence.

Missing approved agronomic rates, richer forecast specifications or redistributable media are content/domain gates; they are not solved by visual polish. A pending screen can be technically correct while the corresponding demonstration output remains unavailable. Saved specifications do not make a richer engine executable.

## 12. Final acceptance decision

**R-07B readiness: READY FOR TARGETED REMEDIATION, not frontend-release sign-off.** Begin with R07-01 reproduction and the small confirmed form/error-state fixes. Then improve hierarchy and adaptive density without reducing scientific disclosures or changing workflows. Optional source-opening polish should follow the required work.

Before closing R-07B: resolve or evidence-close the lifecycle risk; fix the confirmed guard/date/error/motion issues; demonstrate revised result and keyboard layouts; verify long-label and calculator handoff behavior; address or measure CMS scaling; pass scoped regressions and reviewed comparisons; record device/live gaps honestly. No unsupported score target or subjective requirement to make every screen more decorative is imposed.

The design system and existing architecture should be retained. No backend, AI, data, model, auth, licensing or calculator-policy change is justified by this frontend audit. No P0 was established and historical uncertainty is not manufactured into a security exploit. Equally, reported tests and attractive goldens are not accepted as substitutes for unperformed lifecycle/device/live verification.

## 13. Execution and integrity record

- Read-only operations: Git branch/HEAD/status/diffs, file/source searches and reads, installed-SDK inspection, ADB enumeration, all 68 existing PNG views, in-memory image checks, 50-pair contrast calculation and file hashing.
- No Flutter execution, APK compilation, live service request, paid provider call, seed, database migration, account mutation, model modification, commit or push was performed.
- Initial working tree contained **33 existing modified/untracked frontend paths, zero staged**. They belong to prior R-06D work and were preserved.
- Pre-report integrity baseline: **448 existing nonignored mobile files**, SHA-256 aggregate `10CFD3EB4A9C647B9940519799B6086805ED3990DF1963B472E2DCB1745C46F4`. Paths sorted uniquely; aggregate is SHA-256 of newline-joined `path:fileSHA256` records, excluding this report.
- After writing the report, the same **448-file aggregate matched exactly**. Git still showed the original 33 paths plus this report, zero staged files and unchanged HEAD. `git diff --check` found no whitespace errors; Git emitted line-ending conversion notices for existing R-06D paths, without altering their content. The report's own trailing-whitespace check was also performed separately because it is untracked.
- The only output of R-07A is `mobile/R07_INDEPENDENT_AUDIT.md`. Ignored runtime caches are outside this tracked/nonignored content-hash assertion; none were intentionally created or modified.

**No fixes implemented. R-07B and later releases not started.**
