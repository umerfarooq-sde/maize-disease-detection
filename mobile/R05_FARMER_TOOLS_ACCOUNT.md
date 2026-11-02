# R-05 — Farmer tools and account

Frontend release on top of FIELD INTELLIGENCE R-01–R-04. No backend, AI,
database, model, authentication contract or calculator engine changes.

## Screens and navigation

| Screen | Presentation | Existing route |
| --- | --- | --- |
| Tools | Two purpose-led planning cards; configuration availability is checked inside each tool | `/tools` |
| Fertilizer | Labelled area/unit inputs, reviewed rule selection, exact result summary, evidence disclosures | `/tools/fertilizer` |
| Yield | Matching inputs, reviewed scenario, conditional planning result, source/assumptions disclosure | `/tools/yield` |
| History | Local-date headings, protected scan cards, explicit model/status wording, lazy cursor list | `/profile/history` |
| Field insights | Real aggregate cards, readable activity bars, textual label counts, UTC date filters | `/profile/analytics` |
| Account center | Real name/email/protected avatar; account, activity, appearance, privacy and separate Admin entry | `/profile` |
| Profile editor | Persistent labels, optional-field indications, private photo controls, unsaved-text Back confirmation | `/profile/edit` |
| Privacy | Actual deletion-request status and review explanation; confirmation before submission | `/profile/data-deletion` |

The five Farmer branches, Assistant lifecycle, Home Profile action, existing
result/history links and separate Admin workspace remain unchanged. Editing
returns to the account center and refreshes its projection once for the same
session. The editor's app-bar Back uses `Navigator.maybePop` so the local
`PopScope` also protects unsaved text when leaving through that button.

## Shared presentation

New small widgets: `PlanningHeader`, `PlanningDisclosure`,
`PlanningResultSummary`, `AccountAction`, `ProfileAccountHeader`.

Reuse: `AppPage`, `AppField`, `FeatureCard`, `AppMetricCard`, status/loading/
empty/error components, `PrivateImage`, confirmation dialog, responsive pair,
theme tokens, source widgets and existing calculator input widgets.
The appearance selector uses wrapping choices at narrow widths with large text,
retaining the existing persisted theme controller.

## Calculator contracts and scientific limits

- Fertilizer still uses the server's `AREA_RATE_V1` area × reviewed product
  mass-rate calculation. Product composition is not a dosage recommendation.
- Yield still uses `AREA_TIMES_REVIEWED_YIELD_RATE_V1`: area × reviewed reference
  yield. This is a conditional planning estimate, not a field forecast or
  guaranteed harvest. No minimum/potential forecast is introduced.
- Inputs remain decimal strings; hectare/international-acre and output-unit
  selection, validation, request versions, HALF_UP precision and stale-rule
  handling remain in the existing models/ViewModels/repositories/backend.
- Summary quantities, input area, normalized area, unrounded values, rule/config
  versions, assumptions, explanations and source references are displayed from
  typed responses. Flutter performs no replacement arithmetic or re-rounding.
- Rules/configuration pending and unavailable/error states remain distinct.
  No production recommendations or synthetic defaults are added.
- Evidence disclosures have separate page-storage keys for expansion and child
  text scrolling. Reopening after scrolling is regression-tested.

## History, insights and privacy

History uses the original `SliverList.builder` and cursor requests. Headings
compare adjacent records using local calendar dates, including across loaded
page boundaries. They do not sort, regroup or download all records. Refresh,
load-more retry, empty/error states and owner isolation remain intact. Protected
thumbnails retain the existing bounded transport and session handling. The
compact tile used by Home and the Assistant picker retains its layout.

Field insights shows saved/completed scans, actual healthy/disease model-label
counts, pending/processing/failed counts, per-period totals, distribution and
available confidence flags. Bars have visible numeric values and semantic date/
count descriptions. Filters and aggregate day boundaries use UTC; record and
update timestamps identify local display time. No production predictions are
represented as accuracy, ground truth, disease severity or formal drift.
Unknown/unavailable, error and a genuinely empty account have separate states.

The account-center profile is loaded once on visibility per session scope,
rather than during uncontrolled rebuilds or underneath direct child routes.
Guests do not request private profiles/history/analytics. Private state remains
scoped by the existing session revision; returning from Edit refreshes only if
the same identity is still active.

Profile/avatar repositories and ViewModels are unchanged. Preview is not
upload; upload/removal require explicit actions and existing revision checks.
Removal requires confirmation. Transport ambiguity retains the existing
read/reconcile path and reload/conflict feedback; the UI neither claims an
unconfirmed success nor automatically repeats a destructive mutation. The
unsaved-change dialog guards edited text, not a server mutation or staged photo.

Deletion requests are not immediate erasure. The UI displays the authoritative
request status, review explanation, original refresh/error behavior and existing
confirmation. It does not promise automatic deletion or change retention policy.

## Verification

Final combined focused regression: **563 passed / 0 failed / 0 skipped**,
including **35 golden comparisons** (12 new R-05, 23 retained regressions).
The preceding combined run had 561 passes and two outdated Profile-request
expectations; their mocks/assertions now explicitly cover the new functional
account projection without weakening login or Home request-count checks. The
final result is one complete run, not combined counts from separate attempts.

```powershell
# From mobile/; uses the existing repository Flutter wrapper.
$node = '..\.cache\node\node-v24.22.0-win-x64\node.exe'
& $node '..\scripts\run-flutter.mjs' analyze
& $node '..\scripts\run-flutter.mjs' test --no-pub `
  test/redesign test/features/home_view_model_test.dart test/scans test/history `
  test/knowledge test/security/private_image_test.dart test/navigation `
  test/assistant test/auth test/farmer_flow_test.dart test/theme test/widgets `
  test/responsive test/profile test/admin/widget_test.dart `
  test/admin/accounts_widget_test.dart test/fertilizer test/yield test/analytics
& $node '..\scripts\run-flutter.mjs' build apk --debug --flavor staging `
  --target-platform android-arm64 --no-pub
& $node '..\scripts\run-flutter.mjs' build apk --release --flavor staging `
  --target-platform android-arm64 --no-pub -PallowUnsignedVerification=true
```

- Formatter: 32 related Dart files, zero changes on final check.
- Analyzer: no issues.
- Responsive matrix: seven widths (320/360/412/480/600/840/1024), three text
  scales (1/1.5/2), both themes across all eight screens, keyboard, reduced
  motion, long email/source text and large exact decimal fixtures. Missed taps
  fail the R-05 layout tests.
- Twelve new golden baselines visually inspected: Tools, fertilizer pending/
  result, yield pending/result, History, Insights summary/distribution, guest/
  Farmer Profile, editor, requested privacy state. Previous release goldens
  remain intact. Visual fixtures are explicitly synthetic and never published
  or sent to a live backend.
- Debug ARM64 staging build: passed (56.7 seconds).
- Release ARM64 staging compilation: passed (156.5 seconds), using the existing
  unsigned verification gate; this is not a production-signed release.
- Existing nonfatal CupertinoIcons font warning remains outside R-05 scope.
- ADB reports no connected device: physical Android/TalkBack acceptance is
  **NOT VERIFIED**. Automated semantics/layout checks are not device acceptance.
- Tests use local mocks and in-memory fixtures. No paid-provider, backend, AI,
  database, live-account mutation or deployment tests were run.

## Scope and limitations

R-05 touches 45 related paths: 23 library files, nine test/helper files, twelve
golden images and this guide. Earlier R-03/R-04 work is retained; additive overlap
is limited to the router, history tile and authentication regression test (which
now accounts for the functional Profile read after login/opening Profile).
The Home initials action still makes no decorative profile/avatar request.

No commit or push. R-06A is a separate release and has not begun. Real calculator
availability still depends on reviewed, active server configurations; this
redesign supplies no agronomic rates or coefficients.

Final Git check: branch `main`, HEAD
`6cf1cbff9a8d927baacaf105f5c99883723dcecf`, zero staged paths, 113 total
changed/untracked frontend paths including the prior work. All 71 original
working-tree paths remain present: 68 retain their initial SHA-256 fingerprint;
the three intentional additive overlaps are listed above. No changed path is
outside `mobile/`. `git diff --check` passes. R-05 implementation and automated
verification are complete; physical-device acceptance remains outstanding.
