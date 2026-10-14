# Farmer analytics — Phase 19

Farmer analytics describes saved usage and model predictions, **not ground-truth
accuracy, disease prevalence, field health or measured model performance**. No
correctness labels are collected. The selected classifier and its uncertainty
policy are unchanged. In particular the current unconfigured threshold continues
to flag every new prediction LOW_CONFIDENCE.

## Access and API

Flutter → Node route → controller → service → repository → Prisma/PostgreSQL.
No FastAPI, Gemini, Cloudinary or raw dataset request is needed for statistics.

Both GET endpoints require a live FARMER access-token session:

- `/api/v1/analytics/scans`: summary, daily scan counts and prediction distribution.
- `/api/v1/analytics/scans/activity`: bounded recent activity with a UUID cursor.

There is no user-ID input. Every query uses the authenticated session's user ID.
Guests/invalid sessions receive 401, ADMIN receives 403. Foreign, anonymous,
missing or out-of-range cursors receive 404. Anonymous scans retain null ownership;
login never attaches them to a farmer. Responses/errors use the existing single
success/error envelope and `Cache-Control: no-store`. They omit owner IDs, image
URLs, Cloudinary IDs, provider/model paths and credentials. Activity scan IDs link
to the existing independently ownership-protected scan detail endpoint.

`from` and `to` must both be present or both omitted. They are actual `YYYY-MM-DD`
UTC calendar dates, inclusive at each end. Defaults select the most recent 30 UTC
days including today. A range must contain 1–366 days, be ordered and not extend
into the future. Filtering uses **scan creation time**, not inference completion
time. Internally the end becomes the exclusive following UTC midnight. Unknown
fields, arrays, impossible dates and invalid ranges return 400.

Activity accepts `limit` (default 10, maximum 50; positive integer text) and optional
UUID `cursor`. Its cursor must match the same owner and selected range. Ordering
is native PostgreSQL creation timestamp descending, then UUID descending; Prisma
uses the database cursor so microseconds are not lost through JavaScript dates.
The page returns `nextCursor: null` at the end. Refresh after new scans; multiple
HTTP requests are not a frozen snapshot when underlying scan statuses change.

`ANALYTICS_RATE_LIMIT_MAX` is server configuration (default 30 per minute per IP,
validated 1–1000), shared by these two endpoints alongside the existing global
limiter. Distributed production rate limiting remains an operational requirement.

## Counting and response semantics

Summary data has `range: {from,to,timeZone:"UTC",days}`, `asOf` (request-time UTC),
`totals`, `uncertainty`, `distribution`, and `daily`.

| Field | Meaning |
|---|---|
| `totalScans` | All owned scans created in the range |
| `completedScans`, `pendingScans`, `processingScans`, `failedScans` | Mutually exclusive current lifecycle counts, summing to total |
| `withPrediction` | Completed scans with a stored prediction |
| `completedWithoutPrediction` | Completed scans lacking a stored result, retained explicitly |
| `healthyPredictions` | Latest stored label is `Healthy` |
| `diseasePredictions` | Latest stored label is one of the three supported disease classes |
| `otherPredictions` | Unknown/legacy class, projected as `OTHER` |
| `uncertainty` | Counts of stored LOW_CONFIDENCE, CONFIDENT and null/legacy policy flags |

Only COMPLETED scans contribute predictions. Select one latest prediction per scan
using prediction creation timestamp descending, then UUID descending. Multiple
model versions do not multiply scan counts. The same deterministic tie rule now
applies to scan detail. Historical predictions on FAILED/PENDING/PROCESSING scans
do not contribute labels or uncertainty.

Distribution always returns five `{label,count}` entries: `Common_Rust`,
`Gray_Leaf_Spot`, `Healthy`, `Northern_Corn_Leaf_Blight`, `OTHER`. Daily returns
every UTC day, including zeroes, as `{date,count}`. Healthy+disease+other equals
withPrediction; confidence-policy counts and distribution also sum to that count.
Completed equals withPrediction+missing. Daily totals sum to totalScans. The
repository and Flutter wire parser validate nonnegative safe integer counts and
reconciliation. No average probability, percent correct, precision or recall is
inferred from user predictions. Flags from different model policies are not
claimed to be calibrated or directly comparable correctness measurements.

Activity returns `{range,items,nextCursor}`, each item containing only
`{id,status,createdAt,predictedClass}`. Label is null for non-completed/missing
results and `OTHER` for an unsupported historical label.

## Query bounds and performance

One parameterized aggregate statement filters owner/date before materializing
the selected scans, joins at most one latest prediction per scan, and calculates
counts/distribution/daily groups inside PostgreSQL. It never loads all scan rows
into Node. Output is bounded to one summary, 366 days and five labels. Activity
selects at most limit+1 minimal rows and performs an owner/range cursor check.
The existing `scans_user_id_created_at_idx` and prediction scan/model unique index
support this workload; no new table, migration, materialized view or cache is added.

The rollback contract inserted eight eligible scans and 7,000 additional bulk
other-owner/anonymous/out-of-window rows, plus individual boundary fixtures. Natural
EXPLAIN ANALYZE selected the existing owner/date index. Local
execution measured **0.268 ms**, planning **0.299 ms**. This is synthetic development
query evidence, excluding HTTP/network overhead; it is not a production throughput
benchmark. Very large per-farmer histories and concurrent load need measurement
before a more complex aggregate/index strategy is justified.

## Flutter

Profile → Field insights (`/profile/analytics`) uses a route-local Provider and
ChangeNotifier ViewModel → AnalyticsRepository → shared authenticated ApiClient.
No raw HTTP is in widgets. The repository validates wire schemas and echoed dates.
VM provides 7/30/90-day presets and custom bounded UTC dates, loading/retry/error,
paginated recent activity and empty-account/period states. Guests see a sign-in
gate. Account revisions hide old data immediately, recreate the feature Provider
and fence delayed requests; statistics are not persisted to disk.

Summary cards use existing responsive components/tokens. Horizontal label bars
show counts, and the time chart sums every daily count into at most six contiguous
periods without sampling days away. It scrolls horizontally on narrow screens and
provides count/date semantics and tooltips. Confidence wording states explicitly
that correctness has not been measured. Existing safe-area/scroll patterns handle
small phones, 200% text, keyboard insets and long labels.

## Verification

From the respective component directories:

```powershell
# backend
npm run check
npm run db:validate
npm run db:status
# mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --no-pub
```

From root, after backend build and with the existing local PostgreSQL available:

```powershell
node --env-file=backend/.env scripts/check-analytics.mjs
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-repository.ps1
```

The live contract opens one private RepeatableRead rollback transaction. Synthetic
farmers/admin, sessions, scans and model metadata never commit. It verifies owned
aggregates, latest multi-model tie handling, all statuses, missing/legacy results,
zero users, UTC boundaries, native microsecond pagination, foreign/anonymous
denials, real Flutter bearer-auth API contracts and natural query plans. Before/
after table counts must match. No real cloud upload, inference, dataset or model
artifact is used. Its Flutter test is opt-in and skipped in the isolated suite.

Backend unit/API tests cover filters, ownership/RBAC, conservation, empty results,
cursor handling, rate limits and safe failure. Flutter model/repository/ViewModel/
widget tests cover parsing, transport, session fencing, dates, grouped counts,
pagination, retry/empty/loading and narrow-screen accessibility. See
[project state](PROJECT_STATE.md) for final check totals. Stop after Phase 19.
