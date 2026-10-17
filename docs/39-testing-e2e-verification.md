# Phase 23 — application testing and E2E verification

**Current stabilization:** [Phase 24.7](phase-24-7-integration-stability.md) records
the latest root-cause investigation and acceptance runs. Counts and incomplete
feature descriptions below are historical Phase 23 evidence. The affected
Knowledge, Farmer library, Admin management and journey harnesses now stop HTTP
work and drain/close operational writers before fixture database teardown. Do not
disconnect Prisma while an owned writer can reconnect it. Current live checks
retain all required assertions and preserve each run's separate cleanup/result
proof; a union of successful categories is not an uninterrupted full-suite pass.

**Current Phase 23.7 evidence:** [requirements completion report](phase-23-7-requirements-completion.md)
records 309 backend, 369 Flutter (13 default opt-in skips), 346 AI (three opt-in SQL
skips), 42 isolated SQL tests, nine-migration replay and the enabled real host-widget
profile/Cloudinary/Admin journey. Run `scripts/check-e2e.py --only migrations database
original-requirements` with the AI environment. Production counts remain unchanged;
the owned schema/two cloud assets are cleaned. These are real service/form checks,
not physical-device or actual external-outage acceptance. Earlier dated evidence
and failed attempts below remain historical.

**Later remediation:** registration and farmer knowledge UI gaps recorded below are
addressed in Phase 23.6. Its [report](phase-23-6-remediation-report.md) records current
component checks and the real host-widget → Node → PostgreSQL/Google/pgvector proof.
This matrix retains Phase 23's original attempts, failures, skips and device limits.

Verification date: 2026-10-15. Scope ends at Phase 23. This phase adds test tooling,
fault checks and verification records, and fixes a verified existing model-health
transaction acquisition failure. It adds no business/UI feature, classifier change
or agronomic recommendation approval.

**Interpretation:** a passing API/MVVM contract is not a physical-device acceptance
test. Synthetic image inference is not a new accuracy measurement. Synthetic
calculator rates are arithmetic fixtures, not project-approved farmer recommendations.
Known incomplete product journeys are listed below rather than marked passed.

## Reproducible checks and isolation

Run component suites with `scripts/check-development.ps1 -Component` Backend, AI,
Flutter, Training, Preprocessing, Prisma and Docker; run Flutter formatting separately.
The comprehensive live command is:

```powershell
ai-service/.venv/Scripts/python.exe scripts/check-e2e.py
# A selected check, with the same isolation preflight and cleanup:
ai-service/.venv/Scripts/python.exe scripts/check-e2e.py --only journey
```

Prerequisites are the existing configured database/direct URL, Cloudinary,
pinned model/calibration artifacts, curated knowledge, Google embeddings/Gemini,
backend build and Flutter SDK. Credentials remain server-side. Each run writes a
new timestamped directory under ignored `.cache/phase23/`, containing one log per
check, structured `results.json`, and a connected journey proof when applicable.
Nonzero subprocess results, timeouts and detected skipped tests are explicit;
skipped live checks cannot yield PASS. Once a run is initialized, its identity,
baseline counts and each completed result are saved incrementally. Cleanup uses a
fresh control connection; a cleanup error leaves a failed report. Keep free disk
space for Flutter compilation; `flutter clean` removes generated build caches.

The runner generates a `phase23_<uuid>` schema, replays all eight committed
migrations, and copies existing source-backed knowledge/chunks and model registry
metadata. It copies no users, scans, private questions, calculator recommendations
or audits. Enum fields are explicitly cast into the replayed schema's own types.
The original source dataset, approved checkpoint and final-test partition are not
read for scoring, modified, retrained, retuned, promoted or redistributed.

Testing uses the existing `DIRECT_DATABASE_URL`, not a guessed endpoint. The
test-only [database context preloader](../scripts/e2e-database-context.mjs) sets and
checks the generated schema on each direct pg pool connection before it is used;
production modules/query implementations and results are not replaced. The runner
uses the TypeScript loader directly so test workers inherit this setup. Both Prisma
and unqualified SQL must pass the same schema preflight before fixture writes.
Session settings are unsuitable for transaction-pooled isolation; see
[Neon's connection-pooling documentation](https://neon.com/docs/connect/connection-pooling).
Public production connection configuration remains unchanged.

Live accounts and synthetic calculator publications exist only in the owned schema.
Cloud uploads use the application's guarded UUID public IDs; only owned assets are
removed. The connected helper records cleanup status. Unknown journey cleanup,
a failed asset-producing check or a timed-out subprocess retains the schema for
investigation rather than discarding its
compensation records. Successful cleanup drops only the verified generated schema
and compares all 21 production application-table counts before/after.

## Component matrix

| Area | Coverage and evidence | Result |
|---|---|---|
| Node/TypeScript | Auth/passwords, refresh replay/logout, every role boundary, catalogue, uploads/admission, inference/recovery, history, retrieval/generation clients, calculators, farmer/Admin analytics, management and model health | 299 pass, zero skipped; format/lint/strict types/build/import checks pass |
| FastAPI | Settings/service token, malformed requests, logging/errors, model missing/corrupt/incompatible startup, lifespan shutdown, inference/concurrency/uncertainty, RAG/chunking/embedding/provider errors, grounded Gemini with official SDK mocks | 346 pass; three SQL tests default-skip and are separately enabled live |
| Shared preprocessing | Invalid/gray/alpha/orientation/format/dimension/lesion-preservation cases in both consumer environments, exact implementation/mask/CHW/tensor/provenance parity | 78 pass in each environment; 12 synthetic parity cases pass |
| ML tooling | Configuration, inventory/grouping/partition integrity, immutable mapping/artifacts, training/evaluation/calibration/visual tooling using fixtures | 219 pass; no real model training or final-test rerun |
| Flutter | Repositories, ViewModels, navigation/session privacy, scan/result/history/assistant/calculators/analytics/Admin forms and health, loading/error/empty states and responsive widgets | 296 pass; 11 default opt-in skips, separately run below; analyzer and formatting pass |
| Database | Prisma schema/client/type checks, SQL constraints/FKs/immutability, transactional auth/refresh, ownership, prediction/lease persistence, catalogue/version constraints and migration replay | 42 live integration tests pass; 13 Prisma checks pass; all eight migrations current and fresh replay passes; three opt-in Python SQL tests pass |
| Packaging | Android debug APK, native Dart/Flutter analysis and formatting | APK build passes; no Android device/emulator connected |
| Infrastructure | Repository/templates/ignores; Compose configuration | Pass; running container deployment is not verified by Compose config |
| Node/shared admission | Generated JPEG/PNG/WebP/invalid/animated/corrupt/dimension/metadata cases | 56 cases pass: 21 admitted, 35 rejected |

## Required E2E scenario matrix

The connected [Flutter journey](../mobile/test/integration/e2e_test.dart) uses the
real public/admin API clients, repositories and Scan ViewModel. The independent
live scripts additionally verify detailed negative, pagination and version cases.
Widget/navigation tests use controlled data; this is not a tap-through device suite.

| # | Scenario | Verification | Product limit |
|---|---|---|---|
| 1 | Farmer registration | Real Flutter API-client POST → Node → PostgreSQL, duplicate/invalid/role controls also covered by auth suites | Farmer registration screen is absent; API registration is verified |
| 2 | Login | Farmer and separate Admin native session repositories; Argon2 verification and real DB sessions | Credentials remain volatile |
| 3 | Select/scan image | Synthetic gallery datasource → Scan ViewModel → Node → real Cloudinary → real FastAPI/shared preprocessing/model | Camera hardware/permission/cancel behavior is not device-tested |
| 4 | Receive prediction | Literal class, probabilities/confidence, pinned model/preprocessing, completion and LOW_CONFIDENCE behavior | No agronomic correctness/field validation is inferred |
| 5 | Save scan to history | Same authenticated scan persisted under farmer; real paginated history, other-owner denial and anonymous separation | No retroactive anonymous ownership |
| 6 | View result | Real result-detail repository matches saved image/time/prediction; result widgets and retry/uncertainty tested separately | No manual/device tap-through claim |
| 7 | Ask AI about result | Real explicit owned scan context preserves classifier; sourced general Common_Rust question uses Google/Gemini; insufficient evidence may abstain | Classifier context is not rewritten as certainty |
| 8 | View knowledge | All four sourced disease API records and source-retaining sections; retrieval covers available reviewed topics | **Farmer Knowledge tab is still a placeholder** |
| 9 | Use calculator | Flutter → Node exact deterministic fertilizer/yield fixtures, version pins, units, invalid input and server errors; standalone rollback contracts | **Real recommendation/formula content remains pending approved sources** |
| 10 | Farmer statistics | Connected farmer's saved scan plus real SQL aggregates/UTC/pagination/empty/ownership/query-plan contracts | Usage/prediction statistics, not measured accuracy |
| 11 | Admin login | Controlled Admin creation and independent Admin login; public registration cannot choose ADMIN | No public Admin enrollment |
| 12 | Admin dashboard | Real server aggregates/current model registry and Farmer denial; Flutter repository and responsive widget coverage | Current production model remains unpromoted |
| 13 | Admin knowledge edit | New reviewed immutable versions, status validation, timestamps, audit identity, forms/confirmation widgets | Human source/legal/agronomic review remains necessary |
| 14 | RAG refresh/index | Real Google vectors persisted READY, v1 retired/v2 active, source lineage retained, old retrieval excluded and real grounded v2 generation in management contract | Provider outages never auto-publish a draft |
| 15 | Model-health view | Real loaded checkpoint, saved 624-content report and separate runtime counts; Admin API/repository/UI states | Process-local counters; no ground-truth feedback or formal drift |
| 16 | Refresh/logout | Connected client-expiry forces actual cookie refresh; real DB refresh replay/races and logout revoke access | Server-expiry boundaries use controlled clock/token/session fixtures |

## Failure matrix

| Failure | Test evidence | Method / expected behavior |
|---|---|---|
| DB unavailable | [dependency failures](../backend/tests/foundation/dependency-failures.test.ts), foundation health/lifecycle, scan persistence/recovery suites | Actual closed loopback DB connection returns 503/degraded without diagnostics; commit-loss/compensation paths use injected failures |
| FastAPI unavailable | Dependency-failure and inference-client/service/health tests | Actual connection refusal maps INFERENCE_UNAVAILABLE; injected scan failure preserves durable FAILED outcome/retry |
| Cloudinary unavailable | Backend scan upload/storage compensation tests and Flutter upload error tests | Injected provider failure/timeout and failed cleanup, not a deliberate outage of the configured real account |
| Gemini unavailable | AI generation/SDK/provider tests, Node generation-client tests, assistant retry widgets | Mocked timeout/503/malformed output maps safe errors, never fabricated successful guidance |
| Invalid token / wrong role | Auth, every protected route group, live auth/Admin contracts | 401/403 before protected work; no user-selectable Admin role |
| Expired session / replay | Auth service/token tests plus real DB auth rotation/expiry constraints and connected refresh | Expired/revoked grants rejected; replay revokes session; successful rotation/logout verified |
| Network timeout | Native stalled HTTP test, bounded inference/retrieval/generation clients and Flutter client/repository/ViewModel tests | Whole-call deadline, safe timeout UI and retry; configured providers are not sabotaged |
| Corrupt image | Node admission + FastAPI API/shared decoding suites, generated contract cases | Authoritative decode/dimension/format checks; no invalid image reaches inference/storage as success |
| Unsupported image | Same contract, including format mismatch, SVG, animation and bad metadata | Appropriate safe 4xx response; FastAPI policy is not weakened |
| Low confidence | Real pinned-model scan plus controlled threshold-boundary Python/Node/Flutter cases | Current unconfigured policy remains LOW_CONFIDENCE; honest warning even for a high numerical score |
| Invalid calculator input | Both exact engines/validators/API/widget suites, connected negative-area API input | Negative/zero/oversized/missing/stale input rejected; no Gemini arithmetic |

## Skips, failures and final run evidence

Default Flutter tests intentionally skip the ten existing opt-in contracts and the
new connected journey. These are enabled separately by the live runner: backend
connection, guest upload/inference, farmer scan/history, assistant, fertilizer, yield,
farmer analytics, Admin analytics, management, model health and the connected journey.
The guest upload test is run twice, with and without inference. The three default
AI SQL skips are enabled with RUN_RAG_DATABASE_TESTS=1. Default Node `npm test` does
not collect standalone database/provider integration files; the runner collects and
enables them explicitly. Skips are not counted as passing tests.

Early harness attempts failed enum copying/schema search-path isolation, pooled
session settings, Windows import-URL handling and CLI preload propagation. These
were test-tooling corrections, not changes to application/model behavior. A missing
opt-in flag initially skipped the two upload API checks; the final runner sets both
flags and rejects skipped live tasks. A later preflight encountered a real database
connection timeout; that failed attempt is retained. Failed-attempt reports and
cleanup proofs remain under `.cache/phase23/`, separate from successful runs.

The broad live run `20261015T094831Z-10991b2b` passed database/migrations, all three
Python SQL cases, real retrieval, both explicitly enabled upload API checks, guest
upload/inference, farmer history, assistant, both calculators and farmer analytics.
Generation failed a Healthy question (safe abstention instead of expected grounded
evidence). Admin analytics timed out, and management/model-health Flutter
compilation failed when drive E: ran out of space. These are retained as failures.
The original idle control connection also expired before final cleanup/reporting;
its results were recovered from the original log, not relabeled as a successful run.

After verifying no scan/upload asset references remained, the two abandoned
generated schemas were removed. `recovery-proof.json` records unchanged production
counts during recovery; the original broad run's final count comparison is
unavailable. The runner now saves partial results and terminates its owned Windows
subprocess tree on timeout. Flutter's standard clean recovered about 4 GB.

The independent connected journey `20261015T095107Z-f4a8650c` passed both Flutter
tests in 220.92 seconds with all 16 API/MVVM steps, real cloud/model/provider calls,
successful owned-asset cleanup, dropped schema and unchanged production counts.
The generation-only recheck `20261015T095657Z-9c32f04d` passed all nine tests, including
all four classes and scan explanations, with no skips and verified cleanup. The
earlier Healthy abstention remains an intermittent grounding limitation.

The post-cleanup Admin analytics check passed in 66.55 seconds, including 7,000
synthetic scans, one aggregate SQL statement, query-plan/index evidence and the
real Flutter Admin contract. Its transaction rolled back all fixture writes.
The next management attempt returned `503 KNOWLEDGE_UNAVAILABLE` during a visibility
search; its schema was removed and counts verified unchanged. This upstream failure
is retained even when a later attempt succeeds.

Repeated standalone model-health checks localized a real `P2028` registry
transaction acquisition failure after an idle connection/Flutter compilation.
The repository used Prisma's default two-second acquisition bound while the pool
and existing analytics checks allowed ten seconds. The fix sets only this
transaction's `maxWait` to 10,000 ms, retaining RepeatableRead and the existing query/
transaction execution deadlines. The actual read-only registry + pinned model +
Flutter repository/ViewModel contract then passed. Full backend checks were rerun:
299 pass. Temporary diagnostic instrumentation reported only bounded Prisma codes
and was removed; no query/result substitute is part of the final verification.

Complete management recheck `20261015T122903Z-77aa6aeb` passed in 337.20 seconds,
including real Google/Gemini, visibility, immutable versions, audit lineage,
calculator management and Flutter forms' repository contract. That run retains
its separate pre-fix model-health failure and therefore has `passed: false`.
Final model-health run `20261015T123435Z-5233c9e0` passed in 55.69 seconds after the
fix, with no skipped cases or diagnostic transaction wrapper. Both runs removed
their owned schemas and verified all 21 production counts unchanged. Each check
category has passing evidence; the combined earlier failed runs remain failed.
Final independent cleanup inspection found zero remaining generated Phase 21/23
schemas and all 21 production counts matching the final run's baseline.

**Outcome:** verification completed with explicit acceptance gaps. The repository
is not being declared feature-complete or deployment/field-ready. Retained
provider 503/grounding variability and all unverified device/UI/content requirements
remain visible in this matrix and Known Issues.

Final measured command totals, run IDs, remaining failures and cleanup evidence are
recorded in [project state](PROJECT_STATE.md). Do not interpret this verification as
completion of the missing registration/knowledge UI, real agronomic calculator
content, physical camera/permissions, browser/durable sessions, deployment/load,
independent field testing or commercial licensing. Stop after Phase 23.

## Phase 24.7 final execution override — 2026-10-18

Repaired-code normal run `20261017T213205Z-173ed748`: **21 PASS/0 FAIL/0 selected skips**,
uninterrupted/no confidence override; independent `--only rag-database knowledge
predeployment-remediation` run `20261017T215921Z-b412d414`: **4/0/0** including preflight.
Both clean owned assets/schema and preserve all22 public counts. Backend356+2,
AI371/0/3 default skips, Flutter391/0/14 default skips, OpenAPI59, ARM64 debug,
78 preprocessing cases per environment+12 parity, Prisma14 SQL/applied migrations
and captured drift exit0 pass. Existing warnings remain visible. One best-effort
metadata CONNECT failure occurred in the full run; later authenticated controls
passed, without proving cause. Historical original-three cause closure is still
open: Phase24.7 PARTIALLY COMPLETE; Phase25 NOT READY. All prior failed reports
above are historical and unchanged. Full scope/limits and controls:
[Phase24.7 report](phase-24-7-integration-stability.md).
