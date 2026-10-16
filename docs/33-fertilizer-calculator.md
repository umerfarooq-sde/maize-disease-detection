# Deterministic fertilizer calculator

**Phase24.6 current addendum (2026-10-17):** Independent source-reviewed product CRUD and immutable disabled nutrient-model intake are implemented. AREA_RATE_V1 still scales product mass only. No N/P/K demand/selection/schedule formula or dosage is invented; the mathematical model and real source data remain required.

See [remediation and current evidence](phase-24-6-pre-deployment-remediation.md). Historical phase details follow.

**Content handoff:** Phase 23.7 re-verifies the real catalogue's pending state.
Use the separate [source/data/approval checklist](calculator-domain-input-checklist.md)
before preparing and explicitly publishing a real configuration. Synthetic tests
do not supply approved agronomic recommendations.

Phase 17 adds a Node-owned exact area-rate engine, source-reviewed versioned rule
publication and a Flutter calculator using the existing MVVM/design system.
**Real maize fertilizer recommendations are pending.** The configured database has
no fertilizer products, rules or fertilizer configurations; seed groups remain empty.
Only isolated tests contain synthetic arithmetic rates. No dosage, soil requirement,
fertilizer choice or source approval is inferred by the application.

## Calculation and units

The supported algorithm `AREA_RATE_V1`, engine `area-rate-v1`, scales an explicitly
reviewed **fertilizer product mass rate**: `area in hectares × product kg per hectare`.
It does not convert nutrient percentages into product recommendations or decide
agronomic suitability. Each published rule must state its applicability, assumptions,
source reference and administrator review. Product N/P2O5/K2O percentages retain
the existing database label semantics; they are not used in this calculation.

Area and rate are decimal **strings**, with at most six fractional digits and no
exponents, commas, signs, leading-zero integers, NaN or coercion from JSON numbers.
Area must be positive and at most `1000000` in the entered unit. Rates may be zero
and must not exceed `1000000` kg/ha. These bounds are operational limits, not dose
recommendations. Area units are `HECTARE` and `ACRE`; output units are `KG` and `G`.

`ACRE` means the **international acre**, exactly `0.40468564224` hectares, as specified
in [NIST Handbook 44 (2026), Appendix C](https://www.nist.gov/system/files/documents/2025/12/30/appc-26-HB44-20251222.pdf).
It does not mean the former US survey acre or an unspecified local land unit.
One kilogram is exactly 1000 grams. The engine represents decimal values with
BigInt coefficients and scales, preserving every conversion digit. It rounds **once**
after conversion to the selected output unit, using the configuration's `HALF_UP`
policy and zero to six decimal places. Both rounded and unrounded quantities are
returned; a positive amount displayed as zero carries an explicit precision warning.
No floating-point fertilizer arithmetic or Gemini/provider call is involved.

## Public API

All paths begin with `/api/v1`, reuse the single standard success/error envelope,
carry a request ID and return `Cache-Control: no-store`. No account or calculation
history is persisted. Guest and signed-in farmer calculations use the same public
API; Flutter intentionally sends no account credentials on these requests.

| Method/path | Contract |
|---|---|
| `GET /calculators/fertilizer/rules` | `{status: READY\|PENDING_RULES, message, engineVersion, items}`; at most 100 active, admitted rules |
| `POST /calculators/fertilizer/calculate` | JSON containing exactly the six fields below; returns one deterministic result |

Request fields:

| Field | Type/meaning |
|---|---|
| `area` | Positive fixed decimal string |
| `areaUnit` | `HECTARE` or `ACRE` |
| `outputUnit` | `KG` or `G` |
| `ruleId` | UUID from the catalogue |
| `ruleVersion` | Positive 32-bit integer from that rule |
| `configVersion` | Positive 32-bit integer from that rule's bound configuration |

The response includes the validated input, exact `normalizedArea` in hectares,
`quantity: {value, unit, unroundedValue}`, rounding policy, public rule/source/config
snapshot, engine version, deterministic calculation explanation, assumptions and
the NIST unit reference. Decimal quantities stay strings in Flutter. Public rules
include product slug/name, applicability, product rate, source title/publisher/HTTPS
URL/citation and explicit versions; reviewer/account IDs and internal parameters
are omitted. Empty catalogues return 200 with `PENDING_RULES`, not fabricated values.

Unknown fields, client-supplied rates/formulas, missing or impossible input and
unsupported units fail with 400; wrong media type fails with 415. Stale/missing
rule or configuration pins fail with 409 `FERTILIZER_CONFIGURATION_CHANGED`.
An incompatible stored rule/config/product fails closed with 503
`FERTILIZER_CONFIGURATION_INVALID`. Database failures use the existing safe 500
contract. A default shared calculator limit of 30 requests per minute per IP is
configured by server-only `CALCULATOR_RATE_LIMIT_MAX` (1–1000), in addition to the
existing global limiter. Production distributed rate-limit infrastructure remains
a separate deployment requirement.

## Controlled rules and versioning

Existing `Fertilizer`, `FertilizerRule`, `CalculatorConfig` and `AuditLog` tables are
sufficient. No table, migration or dependency is added. Existing SQL guards make
rule/config identities and payloads immutable, while partial unique indexes permit
one active version per identity. Status changes preserve historical payloads.

| ADMIN endpoint | Purpose |
|---|---|
| `GET /admin/calculators/fertilizer/rules` | Up to 100 recent draft/status summaries, with activation eligibility |
| `POST /admin/calculators/fertilizer/rules` | Create immutable reviewed DRAFT rule and create/reuse matching product/config; 201 |
| `PATCH /admin/calculators/fertilizer/rules/:ruleId/status` | `{status: ACTIVE\|INACTIVE}`; activate or retire an existing version |

All ADMIN routes use existing live-session authentication and reusable ADMIN RBAC;
guests receive 401 and FARMER accounts 403. Controlled admin provisioning remains
the [existing CLI](18-authentication.md). This phase adds rule-management API support,
not an admin dashboard, arbitrary formulas or editable historical payloads.

A draft request contains three strict objects:

- `product`: slug, name, description, decimal N/P2O5/K2O label percentages, nullable
  application method, precautions and HTTPS product source reference.
- `rule`: rule key/version/title, `rateKgPerHectare`, applicability, one to eight
  assumptions, source `{title,publisher,url,citation}` and a review note of at least
  20 characters. This review is an attestation by an authorized administrator who
  has intentionally approved the project source/rate, not proof from a URL.
- `config`: immutable version and `quantityDecimalPlaces`. The server fixes MAIZE,
  algorithm, engine, HALF_UP rounding, units and the NIST unit source.

The server stamps review actor/time and freezes the entire product snapshot in the
rule parameters. Reusing a product/config identity requires an identical payload;
reusing a rule version returns 409. Changes require a new version (and a new product
slug if the product payload changes), rather than rewriting history. Review/source
fields and unknown algorithms/configurations are validated again on publication,
catalogue reads and calculation. Out-of-band product changes hide/refuse the bound
rule until a compatible reviewed version is published.

Publication uses a short transaction and calculator-wide advisory lock, retiring
the previous active rule for the same product/key and the previous active
`maize-area-rate` configuration before activating the new versions. Reads use one
repeatable-read snapshot. The global active configuration means publishing a new
config can hide other rules bound to the previous version; publish matching reviewed
rule versions deliberately. Administrators can deliberately reactivate a compatible
historical version; immutable version numbers do not imply automatic newest-version
promotion. CREATE/ACTIVATE/DEACTIVATE audit records retain actor, request ID and
version metadata without logging calculation inputs or private provider content.

No source URL is fetched, no recommendation seed is generated and no AI explanation
is enabled. A future grounded explanation must preserve these exact numeric results.

## Flutter flow

Tools → Fertilizer uses a route-scoped `FertilizerViewModel` ChangeNotifier:
`View → ViewModel → repository → datasource → shared API client → Node → repository
→ Prisma → PostgreSQL`. App-level providers supply reusable repository dependencies,
not feature business state. Widgets contain presentation and ephemeral text editing.

The form exposes explicit area/output units, available rules, applicability/source
and assumptions. It shows the server's unchanged decimal result, versions and
rounding information. Editing any input invalidates the old result; generation
fences ignore delayed/disposed requests. Loading, errors/retry and honest pending
content use the existing design system. A stale-rule retry refreshes the catalogue
and requires an explicit new calculation, never silently substituting a new dose.
Sources render as plain selectable HTTPS references, without HTML or fetching.

## Verification and local commands

Synthetic fixtures are arithmetic/contract checks only, never agronomic evidence.
Run the standard checks and the explicitly opt-in PostgreSQL/live contracts:

```powershell
Set-Location backend
npm.cmd run check
npm.cmd run test:fertilizer:database
npm.cmd run db:validate
npm.cmd run db:status
Set-Location ../mobile
dart format lib test
flutter analyze
flutter test
Set-Location ..
# Build backend first. Requires the configured empty recommendation database.
node --env-file=backend/.env scripts/check-fertilizer.mjs
```

The live script binds a temporary loopback Node server to one private PostgreSQL
rollback transaction. It verifies real ADMIN creation/login, draft/publish/deactivate,
source/reviewer/audit retention, immutable replacement, stale pins and product drift,
then runs Flutter repository calls for guest/farmer exact acre/kg/gram results and
FARMER denial on admin reads. Every synthetic rule, configuration, account/session
and audit is rolled back; other clients never see a recommendation. The script
requires an empty initial fertilizer catalogue and passes only tooling plus its own
throwaway fixture credentials to Flutter, never database/JWT/provider secrets.

See [project state](PROJECT_STATE.md) for final check results. Remaining prerequisites
are authoritative project-approved product/rate sources with explicit applicable
crop/region/conditions, agronomic review and deliberate versioned publication.
No production recommendation is available until that work is done. Stop after
Phase 17; yield calculations and subsequent phases require a new instruction.
