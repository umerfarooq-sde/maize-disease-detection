# R-06A — Admin shell, Overview and AI Operations

Frontend-only release based on clean `main` at
`07f3f302b8a0ca8c74df4912e94f0e23dce93e58`. The older uncommitted-state
description in the brief no longer applied. R-01 through R-05 are retained.
No backend, AI-service, database, API contract, domain ViewModel, repository,
authentication, model, telemetry producer or deployment configuration changes.

## Navigation and existing features

`ShellRoute` wraps the existing Admin destinations outside the Farmer five-tab
shell. The selected location determines a labelled, grouped navigation item.
Phones have a drawer; widths of at least 840dp have a 264dp sidebar. Both lists
scroll, wrap long labels and keep all destinations available at large text sizes.

| Group | Destination | URL |
| --- | --- | --- |
| Overview | System Overview | `/admin` |
| Content Management | Diseases | `/admin/manage?area=diseases` |
| Content Management | Knowledge Documents | `/admin/manage?area=knowledge` |
| Content Management | Reference Images | `/admin/reference-images` |
| Calculator Management | Fertilizer Catalogue | `/admin/manage?area=fertilizers` |
| Calculator Management | Fertilizer Rules | `/admin/manage?area=fertilizer` |
| Calculator Management | Yield Rules | `/admin/manage?area=yieldRules` |
| Calculator Management | Agronomic Model Review | `/admin/manage?area=modelSpecifications` |
| People | Farmer Accounts | `/admin/farmers` |
| Operations | AI Operations | `/admin/ai-operations` (new frontend route) |
| Operations | Model Health | `/admin/model-health` |
| Operations | Audit History | `/admin/audit` |

Existing URLs remain supported. `/admin/manage` opens Knowledge as before;
unrecognized area query values fall back to Knowledge. Query values are local
navigation state and never become new backend parameters. A small optional
callback on the existing management view keeps its area chips and URL selection
in sync. Management/editor fields, validation, mutations and workflows are unchanged.

The header identifies MAIZEDOCTOR Admin and the current section. Workspace
actions show the actual account email when available, Return to Farmer App and
Admin Sign Out. The drawer/sidebar also includes both actions. Return switches
workspace without signing out either session. Android Back closes an open drawer
first, returns a direct child URL to Overview, then returns to Farmer. A pushed
Admin workspace can return to its originating Profile route.

## Authorization and reporting lifetime

`AdminAccessView` still gates on the independent, role-checked Admin session.
The private route Navigator is not mounted for guests or Farmer credentials.
The report provider is keyed by Admin session revision and disposed on logout
or identity change; existing repositories and ViewModels retain their revision
and late-response guards. Farmer credentials, private-image handling and all
Farmer navigation branches are unchanged.

Overview and AI Operations share one existing `AdminDashboardViewModel` for the
active Admin workspace. The model is created lazily, and the first visible report
page loads only if no report, request or error already exists. Opening management
directly does not fetch dashboard data. Switching reports during a pending request
does not start another request; switching after completion reuses the selected
date window. Refresh/retry and 7/30/90-day selection remain explicit. There is no
background polling or provider call for decoration.

The existing `AdminDashboardRepository` already bundles `GET admin/ai-operations`
and `GET admin/dashboard` with the same `from`/`to` window. This remains the data
source for both presentations. A required dashboard failure is a report error;
unavailable/malformed optional operations data preserves valid dashboard counts.
No new endpoint, repository adapter or network filter is introduced.

## Overview and metric meanings

The primary grid shows actual registered Farmer accounts, selected-period saved
scans, Healthy model labels and disease model labels. Supporting counts show
account states, scan ownership and completed/pending/processing/failed scans.
Account counts are labelled all-time; scan counts use the selected UTC creation
window. Update timestamps explicitly use local display time.

A compact, bounded AI preview links to the dedicated page. Management shortcuts
use real destinations. Registry/configured-version information explicitly says
that live readiness has not been checked. Trends, label distribution, confidence
flags and at most ten anonymous/authenticated recent records remain accessible
in disclosures, keeping the initial dashboard focused. No Farmer identity/photo
is added to recent activity. No unsupported Knowledge totals are invented.

Null metrics use the shared Unavailable state; true zero remains zero. Initial
loading, required-report errors, retry, absent report, empty scan periods and
optional telemetry unavailability remain distinct. Runtime predictions do not
measure model correctness, field prevalence, disease severity or formal drift.

## AI Operations

- Show only returned operation categories: inference, retrieval, grounded
  generation, scan explanation, Gemini and embedding. Scopes remain `NODE`,
  `AI_SERVICE` and `PROVIDER`; unlike scopes are never added into a unique-request
  count. A Farmer action may emit several events.
- Scope disclosures retain actual attempts, successes, failures and abstentions.
  Failure percentage is the displayed failed-attempt fraction, not model accuracy.
- Mean/p50/p95 are the returned latency measurements, formatted consistently in
  milliseconds. Zero-sample rows say latency unavailable instead of implying a
  measured zero. No additional percentiles or error categories are fabricated.
- Daily scope counts have explicit UTC dates, numeric values, a labelled scale
  and semantic descriptions. Pagination renders at most nine entries at once
  from the existing bounded response; page changes make no network requests.
  All-zero series produce zero-length bars without division by zero.
- Local Node pending events are not persisted counts. Local dropped events are
  not successfully stored records or a global loss measurement. Collection is
  labelled bounded best effort; abrupt process loss and provider-writer failures
  may omit events. No raw prompt, transcript, token or private image is added.
- The UI is read-only. It provides no retraining, promotion, threshold-change,
  event-deletion or reset controls. Offline model metrics stay in Model Health.

## Components and accessibility

New presentation components: `AdminWorkspaceShell`, `AdminWorkspaceHeader`,
`AdminNavigation`/`AdminNavigationLink` with `AdminDestination`, `AdminReportPage`,
`AdminMetricGrid`/`AdminMetricCard`, `AiOperationsView`, `AiOperationChart`.
Existing Overview, `AdminSystemSummary` and `AiOperationsPanel` are refined.

Reuse FIELD INTELLIGENCE `AppPage`, metric/status/loading/error/empty components,
responsive tokens, brand mark, analytics charts, fonts and native Material controls.
The shared metric card gains an optional decorative icon; existing callers retain
their previous rendering. There are no new packages, colors, fonts or assets.

Navigation has explicit labels, selected/button semantics and minimum 48dp targets.
A semantic boundary around the nested Navigator prevents its route from hiding
the sibling sidebar. Large-text headers wrap; keyboard-constrained layouts use
a compact header while retaining the full semantic title. Reduced-motion settings
resolve disclosure animation through the existing motion tokens. Text scaling
is not globally disabled or clamped.

## Verification — 2026-11-02

- Combined focused regression: **648 passed / 0 failed / 0 skipped**. This includes
  the retained R-01–R-05 selection, all local Admin tests and 51 new R-06A tests.
- **43 golden comparisons passed**: eight new R-06A captures and the existing
  35. The Admin sign-in baseline alone was updated for its new workspace frame;
  the Farmer and shared-component baselines are retained. All eight new images
  and the changed Admin baseline were visually inspected; fixtures are synthetic.
- Responsive matrix: 320/360/412/480/600/840/1024/1280dp, 100/150/200% text,
  both themes, long account/section labels, very large numbers, expanded data,
  reduced motion, portrait and landscape keyboard layouts. Missed taps fail the
  new layout tests. Android/labeled tap-target and selected-sidebar semantics pass.
- Navigation tests exercise all twelve destinations on phone and expanded layouts,
  legacy management URLs, area selection, Back, session isolation, actual Header
  account context, Farmer return and Admin sign-out. Pending/late report tests
  verify no duplicate fetch or private-state restoration after logout.
- Formatter and Flutter analyzer: clean. Git whitespace check: passes.
- ARM64 staging debug compilation: **passed**, 98.4 seconds.
- ARM64 staging release compilation: **passed**, 189.2 seconds, using the existing
  `-PallowUnsignedVerification=true` gate. This is unsigned compilation evidence,
  not a distributable signed release. Existing nonfatal CupertinoIcons warning remains.
- Two affected opt-in live UI harnesses were updated to use the new destinations.
  Their default execution compiled successfully and reported **0 passed / 0 failed /
  2 skipped** because live flags were off. No live E2E/provider acceptance is claimed.
- ADB reports no device. Physical Android/TalkBack acceptance is **NOT VERIFIED**.
  No real accounts, assets, DB data, Gemini requests or other provider work were used.

Commands from `mobile/`, using the existing environment-isolating wrapper:

```powershell
$node = '..\.cache\node\node-v24.22.0-win-x64\node.exe'
$runner = '..\scripts\run-flutter.mjs'
& $node $runner analyze
& $node $runner test --no-pub test/redesign test/features/home_view_model_test.dart test/scans test/history test/knowledge test/security/private_image_test.dart test/navigation test/assistant test/auth test/farmer_flow_test.dart test/theme test/widgets test/responsive test/profile test/admin test/fertilizer test/yield test/analytics
& $node $runner test --no-pub test/integration/requirements_test.dart test/integration/predeployment_remediation_test.dart
& $node $runner build apk --debug --flavor staging --target-platform android-arm64 --no-pub
& $node $runner build apk --release --flavor staging --target-platform android-arm64 --no-pub -PallowUnsignedVerification=true
```

## Scope and remaining acceptance

33 related paths: 15 library files, eight test/helper files, nine golden images
and this guide. The only management-screen change is navigation coordination;
forms and data workflows were not redesigned. All repository/domain ViewModel,
backend/AI/database/model sources are unchanged. No commit or push is authorized
as part of this release. R-06B/C/D and R-07 have not begun.

R-06A engineering verification is complete. Physical-device acceptance and live
provider verification remain separate. Future API capabilities, including optional
Knowledge counts or an operational error-category breakdown, are not simulated.
