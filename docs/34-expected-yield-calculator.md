# Expected-yield calculator framework

Phase 18 adds a deterministic, versioned framework and Flutter UX. **Authoritative
agronomic configuration remains pending.** Inspection found no approved yield formula
or applicable rate data in project sources, seeds or PostgreSQL (`YIELD` count zero).
No source is silently approved, and no empirical yield formula, default rate, plant
population, historical harvest, soil or weather parameter is invented.

The implemented template is **dimensional area-rate projection**, not a validated
agronomic forecasting model: an explicitly reviewed expected mass per hectare can
be scaled by cultivated area only when a future approved source justifies that rate
and its stated applicability. Current production has no such configuration and
returns `PENDING_CONFIGURATION`. Synthetic test rates never become project data.

## Deterministic calculation contract

The sole template is `AREA_TIMES_REVIEWED_YIELD_RATE_V1`, formula version
`area-times-reviewed-yield-rate-v1`, engine `area-yield-v1`, crop `MAIZE`.
The engine performs `area in hectares × reviewed expected kg per hectare` without
inferring a rate, changing it through Gemini or applying unapproved loss/moisture
corrections. An eventual different agronomic formula requires an explicit source
review and a new implemented/versioned template, not arbitrary formula text or eval.

| Value | Admission |
|---|---|
| Cultivated area | Positive fixed decimal string, maximum 1000000 in entered unit, up to six fractional digits |
| Area unit | `HECTARE` or international `ACRE` |
| Expected kg/ha | Configuration-owned nonnegative decimal string up to 1000000, at most six decimal places; no public override |
| Result unit | `KG` or `TONNE` (metric tonne, symbol t) |
| Precision | Reviewed configuration pins zero to six decimal places and `HALF_UP` |
| Version | UUID configuration ID and positive 32-bit integer version from the catalogue |

The bounds are operational, not evidence of plausible crop yield. Zero area and
negative values are rejected; a deliberately reviewed zero rate is supported without
substituting a fallback. JSON numbers, signs, exponents, commas, leading-zero integers,
NaN, unsupported units and unknown input fields fail validation.

Both calculators now import one Node exact-decimal/unit primitive: BigInt
coefficients/scales preserve the exact international acre (`0.40468564224` ha) and
metric tonne (`1000` kg). See [NIST Handbook 44 (2026), Appendix C](https://www.nist.gov/system/files/documents/2025/12/30/appc-26-HB44-20251222.pdf).
Only the final quantity is rounded in the selected output unit. Exact unrounded
quantity is returned, and a tiny positive amount rounded to zero carries a warning.
Phase 17's fertilizer API, kg/gram behavior and engine version remain unchanged.

## Public endpoints

All paths are relative to `/api/v1`; standard success/error/request-ID envelopes,
no-store responses, centralized errors and configured per-process calculator rate
limits are reused. Yield has one shared limiter across its public/admin routes,
using existing `CALCULATOR_RATE_LIMIT_MAX` (default 30/minute/IP) plus global limits.
Fertilizer and yield counters are independent. No new environment variable is needed.

| Endpoint | Behavior |
|---|---|
| `GET /calculators/yield/configurations` | `{status, message, engineVersion, items}`; only admitted ACTIVE configs for `maize-area-yield`, bounded to 100 |
| `POST /calculators/yield/calculate` | JSON with exactly `{area, areaUnit, outputUnit, configId, configVersion}` |

A successful result contains validated input, normalized hectares, expected yield
`{value, unit, unroundedValue}`, public configuration/source/version, formula/engine
versions, rounding, assumptions, deterministic explanation and unit reference.
Every amount stays a decimal string. It explicitly describes a conditional planning
estimate; actual harvest may differ. No probability, disease-loss coefficient or
false forecast certainty is attached.

Missing/invalid input returns 400, wrong media type 415, stale/retired/missing selected
configuration 409 `YIELD_CONFIGURATION_CHANGED`, incompatible stored configuration
503 `YIELD_CONFIGURATION_INVALID`, and database errors the existing safe 500.
An empty catalogue returns 200 with `PENDING_CONFIGURATION` and no values. Guests
and farmers use the same stateless public calculation; no credentials, account
association, `history` record or personal calculation retention is added.

## Controlled configuration and source review

Reuse the existing `CalculatorConfig` with kind `YIELD`, key `maize-area-yield`,
unit `kg/ha`, immutable version/payload/source/creator identity and one-active SQL
guard. No new table, schema change, migration or dependency is required.

| ADMIN endpoint | Behavior |
|---|---|
| `GET /admin/calculators/yield/configurations` | Bounded status/activation-eligibility summaries |
| `POST /admin/calculators/yield/configurations` | Create a new immutable DRAFT version; 201 |
| `PATCH /admin/calculators/yield/configurations/:configId/status` | `{status: ACTIVE\|INACTIVE}` |

Existing live-session JWT and ADMIN RBAC protect all management: guests/invalid
tokens get 401, FARMER 403. Use the existing [controlled administrator CLI](18-authentication.md).
Draft input includes version/title, expected kg/ha rate, applicability, one to eight
assumptions, source `{title,publisher,url,citation}`, quantity decimal places and
a review note of at least 20 characters. The administrator must intentionally review
the source and justify the model/rate/conditions before publication. A nonempty URL
or review note does not independently verify agronomic truth.

The server fixes template/engine/formula/crop/rounding and stamps review actor/time.
Public output omits review/account IDs and internal parameters. Reusing a version
returns 409; parameters/source cannot be changed in place. Activation validates
the full approved contract and atomically retires the prior active config. A short
10-second acquisition/15-second metadata transaction and advisory lock serialize
these writes; CREATE/ACTIVATE/DEACTIVATE audits retain request/actor/version lineage.
An administrator can deliberately reactivate a compatible historical version.
An in-flight calculation can finish with the immutable version it read; no new rate
is silently substituted. Invalid legacy JSON, changed formula/engine/unit/source or
absent review metadata fails closed. No source URL is fetched automatically.

## Flutter architecture and UX

Tools → Yield follows `View → route-local ChangeNotifier ViewModel → repository →
shared API client → Node → service → repository → Prisma`. Dependency providers
are app-level, form/result state is feature-local. There are no widget HTTP calls,
frontend yield calculations or Flutter Gemini credentials.

The area/unit form, decimal admission, source model and strict wire-parsing helpers
are shared with Phase 17. The public fertilizer input/type names remain compatible.
Yield exposes only cultivated area, hectares/international acres, kg/metric tonnes
and a reviewed scenario choice. Pending configuration is explicit and calculation
disabled, while inputs remain editable. Source, applicability and assumptions are
visible before submission; results disclose versions, source, precision and limits.

Loading prevents duplicate submit. Input edits/reloads/disposal fence delayed results;
retrying a stale configuration refreshes choices and requires a new explicit
calculation. Network/timeout/server errors offer retry; invalid input stays editable.
Sources are validated HTTPS references displayed as plain/selectable text. Safe
areas, scrolling, keyboard, 320px phones, large text and long references are tested.

## Verification

```powershell
Set-Location backend
npm.cmd run check
npm.cmd run db:validate
npm.cmd run db:status
Set-Location ../mobile
dart format lib test
flutter analyze
flutter test --no-pub
Set-Location ..
# Backend must be built. Requires configured empty yield recommendation database.
node --env-file=backend/.env scripts/check-yield.mjs
# Verify the preceding calculator after shared-unit extraction:
node --env-file=backend/.env scripts/check-fertilizer.mjs
```

The yield live check uses the real Node/Prisma/PostgreSQL stack within one private
rollback transaction. Synthetic ADMIN/farmer accounts, configurations, sessions and
audits are never committed or visible to other clients. It verifies draft/review/
source retention, activation, PostgreSQL immutable-payload and one-active guards,
version replacement/stale rejection, retirement, audit and unchanged before/after
counts. Enabled Flutter repository calls verify guest/farmer exact acre/kg/tonne
results and farmer denial on ADMIN routes. Only tooling and throwaway credentials
go to Flutter; database/JWT/provider secrets remain in Node. The check requires an
initial empty yield catalogue and never accesses AI, Cloudinary or raw dataset data.

See [project state](PROJECT_STATE.md) for final results. Real use still requires an
authoritative project-approved formula/rate, applicable region/crop/conditions and
local agronomic review. No scientific accuracy or harvest guarantee is established
by synthetic arithmetic or contract tests. Stop after Phase 18.
