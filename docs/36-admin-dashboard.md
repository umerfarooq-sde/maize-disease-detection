# Admin dashboard — Phase 20

The dashboard displays stored system activity through Flutter → Node → Prisma →
PostgreSQL. Counts describe account usage and model labels, not ground-truth
accuracy, agricultural prevalence or field health. No synthetic dashboard data is
seeded, no farmer history is downloaded for client aggregation, and no production
model is promoted by viewing the dashboard.

## API and authorization

`GET /api/v1/admin/dashboard` requires a live **ADMIN** bearer session. Missing,
invalid or revoked sessions receive 401; FARMER receives 403 before any dashboard
query. Public registration still creates FARMER accounts only. Existing trusted
operator provisioning remains the Admin creation mechanism. The route follows
controller → service → repository → Prisma/PostgreSQL, central errors, the existing
single response envelope and `Cache-Control: no-store`.

Optional paired `from`/`to` use actual inclusive `YYYY-MM-DD` UTC creation dates.
Default is the last 30 UTC days including today; range must be ordered, not future
and 1–366 days. Unknown fields, owner overrides, invalid/duplicate/partial dates
and limits/cursors are rejected with 400. The dashboard returns only the latest
ten scan activity entries and does not offer an individual-farmer inspection API.
Global limits and `ANALYTICS_RATE_LIMIT_MAX` (default 30/minute/IP, reused with an
independent dashboard limiter) protect this aggregate read.

The normal success `data` contains:

| Field | Source and scope |
|---|---|
| `range`, `asOf` | Validated UTC scan window and request start time |
| `farmers: {total,active,suspended,deactivated}` | Current all-time FARMER account rows by UserStatus; Admin accounts excluded |
| `ownership: {authenticated,anonymous}` | Selected-window scans with non-null versus null user ID; totals sum to scan count |
| `scans: {totals,uncertainty,distribution,daily}` | Same lifecycle/latest-prediction/zero-day contract as farmer analytics, across all system scans |
| `recent` | At most 10 selected-window scans, native timestamp/UUID descending; each includes creation time, lifecycle, anonymous/authenticated origin and nullable model label |
| `model` | Stored production registry state, nullable production version, configured inference version/enabled flag and explicit readiness `NOT_CHECKED` |
| `aiRequestStatistics` | `NOT_RECORDED`: the current assistant/generation flow does not persist request telemetry |

Farmer counts are deliberately **all-time current accounts**, while scan counts
use the selected window; the UI labels both scopes. Authenticated means a stored
non-null scan owner, not a count of currently signed-in users. Anonymous ownership
is not changed. The dashboard omits farmer emails, IDs, image URLs, Cloudinary IDs,
scan UUIDs, questions, tokens, provider URLs and artifact paths.

## Prediction and model semantics

Use one latest prediction per COMPLETED scan, ordered by prediction creation time
then UUID descending. Multiple model versions do not increase scan count. Missing
completed results, failed/pending/processing scans and unknown legacy labels stay
explicit. Distribution uses the four literal classifier classes plus `OTHER`.
Confidence flags are stored policy outcomes, never a measured correctness score.
Shared SQL/count validation and zero-filling preserve the Phase 19 contract; see
[farmer analytics](35-farmer-analytics.md).

Model registry state is `NOT_PROMOTED`, `SINGLE_PRODUCTION`, or
`MULTIPLE_PRODUCTION`. Only a single PRODUCTION database row yields a production
version; multiple rows are a visible conflict, never a guessed winner. The
configured research inference version is separate from promotion. A registered
version or configured origin does not prove the FastAPI process is loaded or
reachable. `readiness: NOT_CHECKED` makes this explicit. Detailed live ML health
remains the later model-health dashboard scope. Viewing this page makes no inference,
provider, Cloudinary or model-artifact request.

No AI request total or success rate is inferred from scan activity or empty
`ai_queries` tables. Request recording is not implemented in the current assistant
flow, so the UI says statistics are unavailable. Adding telemetry/retention would
require an explicit privacy and implementation decision.

## Query performance

One parameterized PostgreSQL statement combines scan aggregates, ownership, account
status counts, a bounded production registry projection and ten recent scans.
The shared scan aggregate filters dates and selects one latest prediction in the
database. PostgreSQL, not Flutter, counts rows and groups dates/classes. The
service fills missing bounded days/labels. Maximum response projection is 366 daily
buckets, five classes, ten recent entries and scalar summary fields.

The existing schema and indexes suffice for the observed local workload. The real
rollback fixture verifies **6,010 selected fixture scans** plus 1,000 older bulk
rows and boundary fixtures. Natural EXPLAIN ANALYZE reports **24.241 ms execution,
0.620 ms planning**, using the existing scan status/date index among its plan
operations. This is development query evidence, excludes network/UI time and is
not a production load benchmark. System-wide aggregates necessarily inspect the
selected system rows. Measure growth/concurrency before introducing extra date
indexes, caches or summary tables. No migration or dependency is added.

## Flutter and sessions

Profile → Administrator workspace opens `/admin` **outside the farmer navigation
shell**. Admin overview has its own sign-in, refresh and sign-out controls; returning
to the farmer app is explicit. It shares typography, spacing, responsive cards,
count bars and time-chart rendering with the project design system.

Admin and Farmer sessions have independent in-memory token stores, API clients,
refresh-cookie state and ViewModels. The common SessionRepository/SessionViewModel
reuse the previously tested expiry/rotation/revocation mechanics; role-specific
constructors/admission preserve Farmer-only behavior and require ADMIN in the
admin workspace. A wrong-role grant is logged out and discarded. Neither role's
refresh/access credentials are passed to the other client's requests. Both remain
volatile; restarting the app requires login and no secret is persisted in source
or preferences. These are native session flows; durable/browser auth remains a
separate project requirement.

AdminDashboardView → route-local ChangeNotifier ViewModel → repository → private
Admin ApiClient → Node. The dashboard provider is keyed by Admin session revision;
logout/account changes remove displayed data, and stale requests cannot restore
old counts. The repository validates the server schema and echoed date window.
The app offers 7/30/90-day presets, loading/retry/errors, empty-scan states with real
account/system information, responsive overview cards, distribution/time charts
and recent activity without identities/photos. It handles narrow screens, large
text, keyboard insets and long version strings.

## Verification

```powershell
# backend
npm run check
npm run db:validate
npm run db:status
# mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --no-pub
# root, after build, configured PostgreSQL and Flutter available
node --env-file=backend/.env scripts/check-analytics.mjs --admin
# existing farmer contract, after shared aggregation/session extraction
node --env-file=backend/.env scripts/check-analytics.mjs
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-repository.ps1
```

The shared synthetic harness uses a single private RepeatableRead rollback
transaction. Admin mode verifies baseline-relative real account/global/ownership/
prediction/status counts and recent bounds, a natural query plan, enabled Flutter
Admin sign-in/DTO transport, Farmer denial, invalid filters and logout. Every
fixture account/session/scan/prediction/model write rolls back; before/after row
counts must match. The original Farmer contract still verifies ownership and
microsecond cursor behavior. Neither reads raw dataset files or calls AI/cloud.

Backend tests cover every new endpoint for Farmer denial, authentication/revocation,
filters, rate limiting, internal failures, counts, model ambiguity and bounded
parameterized queries. Flutter tests cover session isolation/rotation, wrong-role
cleanup, wire validation, stale-state fencing, filters, loading/error/retry/empty
states, real routing and responsive layouts. Final totals are recorded in
[project state](PROJECT_STATE.md). Stop after Phase 20.
