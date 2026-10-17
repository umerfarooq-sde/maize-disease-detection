# Phase 24.6 — verification ledger

> Current Phase 24.7 evidence: see [integration stabilization](phase-24-7-integration-stability.md).
> The following Phase 24.6 results are preserved; they are not a claim of
> uninterrupted Phase 24.7 acceptance.

Updated 2026-10-17 (Asia/Karachi). Baseline `18bd55e`. Executions use the real
configured development services and disposable generated fixtures where marked
live. No raw dataset access, model fit, immutable split modification, production
model replacement or final test-set evaluation occurs. Full test logs/private
fixture proofs remain ignored under `.cache/phase246` and `.cache/phase23/<run>`;
this report contains sanitized results, not credentials or private content.

## Component verification

| Check / command | Result | Exact counts / practical boundary |
|---|---|---|
| `check-development.ps1 -Component Backend` | PASS |349 backend tests + 2 actual subprocess isolation tests;0 failures/0 skips. Formatting, lint, strict TypeScript, build and environment check pass. Lint includes non-failing style/non-null fixture notices. |
| `npm --prefix backend run openapi:check` | PASS | OpenAPI 3.1 parser validates59 unique registered operations, route/method/request/shared-response coverage and generated drift. Included in backend gate. |
| `check-development.ps1 -Component AI` | PASS |363 passed, 3 opt-in SQL tests skipped,1 existing Starlette/httpx deprecation warning. Ruff format/lint and mypy 47 source files pass. |
| `check-development.ps1 -Component Training` | PASS |219 fixture/tooling tests; no training or final evaluation. Ruff/mypy pass. |
| `check-development.ps1 -Component Preprocessing` | PASS |78 tests in each of 2 locked Python environments, plus 12 exact synthetic cross-environment parity cases. |
| Flutter format/analyze/full `run-flutter.mjs test` | PASS |385 passed,14 live opt-in skips,0 failures; analyzer reports no issues. Live cases are reported independently below. |
| Flutter `build apk --debug --target-platform android-arm64` | PASS | Debug APK built; not a signed release or physical-device acceptance test. |
| `check-development.ps1 -Component Prisma` | PASS | Validation/client generation/types,14 reported SQL catalog/rollback tests,14 applied migrations up to date. |
| `npm --prefix backend run db:diff` | PASS | No difference detected. CLI informational stderr was rerun with PowerShell Continue so it did not masquerade as a failure. |
| Isolated migration replay | PASS |14 atomic migrations replayed; owned temporary schema removed. Original9 migration bytes remain unchanged. |
| `check-development.ps1 -Component Database` | PASS | Actual authenticated PostgreSQL18.6 temporary-table SQL round trip. |
| `check-development.ps1 -Component Docker` | PASS | Compose config validation only; no running container daemon/deployment claim. |
| `check-repository.ps1` | PASS | Required structure/templates/blank secrets/ignore rules. |
| `check-image-admission-contract.py` | PASS |56 synthetic cases:21 accepted/35 rejected, Node/shared agree;5 MiB/16 MP/min-side16. |
| Actual configured `check-ai-startup.py` | PASS | Actual saved policy/config, selected checkpoint+metadata hashes, class mapping, shared preprocessing, null threshold and model inference. No confidence override. |
| Windows PowerShell environment preflight | PASS |5 isolated preflight cases: empty/paired valid, path-only/digest-only/malformed digest rejected. No policy JSON or threshold created; no real config edited. This fixture-only check is separate from actual startup/E2E evidence and does not supply its success claim. |
| Read-only frozen/preservation proof | PASS |171 frozen files + approved checkpoint; original 9 migrations identical; pre-existing user files and other private environment files unchanged. |

The standard AI SQL skips are all 3 `test_rag_database.py` opt-in tests, activated
and reported by the live RAG category. The 14 standard Flutter skips require live
services/flags; default component success does not claim those cases ran. The live
suite records their actually selected executions. Failure scenarios use controlled
mocks/faults unless explicitly described as normal live provider operations.

## Targeted live remediation

Run `20261016T142822Z-7f0c843c`: preflight + targeted remediation category both PASS,
zero selected skips. Actual generation/provider telemetry → PostgreSQL → ADMIN
API → Flutter dashboard; real generated Cloudinary reference upload → review →
protected Node gallery; informational/source applicability; replacement/conflict/
retirement cleanup and versioned disabled model review pass. Owned assets and
schema cleaned; public counts unchanged. Earlier targeted failures remain recorded.

The first broad run's new category additionally verifies independent fertilizer
product creation/edit/version-conflict/status/frozen-rule snapshot and non-indexed
source documents. It passes using real PostgreSQL/generated fixtures. Its synthetic
images are deliberately marked and never published by normal application composition.

The 16.5-second avatar-delete test is a deterministic delay fixture, not a live
Cloudinary outage. It proves response/cleanup separation without extending Flutter
timeouts; actual profile upload/replacement/removal/protected delivery is exercised
by the normal original-requirements live category. ViewModel/repository tests also
cover server acknowledgement/network timeout after a committed update.

## Normal-environment full integration attempts

Every attempt below invokes `python scripts/check-e2e.py` using corrected saved
configuration, existing database/token/schema isolation, all 19 historical categories
+ the new remediation category and preflight. **No process-only confidence-policy
override is used.** The test harness includes the new category as source code;
“normal/unmodified” refers to the actual command/configuration, not a claim that
the feature-verification script has no Phase 24.6 changes.

| Run | Result | Failure / cleanup evidence |
|---|---|---|
| `20261016T143446Z-9fdf0914` |18 PASS /3 FAIL /0 selected skips | Generation, assistant and management fail. Genuine Gemini timeout/unavailable and indexing failures recorded. Journey, all original-requirements and the new remediation category pass. Owned assets/schema removed;22 public table counts unchanged. |
| `20261016T145938Z-12fef8f0` |16 PASS /5 FAIL /0 selected skips | Database fixture expired before SQL assertions; corrected its explicit test transaction budget only. Assistant/management/journey/remediation also fail; real504/timeout and one500 are not relabeled passes. Generation passes. Conservative parent retained schema after failed journey despite successful asset proof. Separate recovery independently reconciled4 recorded generated assets, removed only this owned schema, and verified22 public counts unchanged. Original failed results remain unchanged. |
| `20261016T192859Z-8787b9b4` |20 PASS /1 FAIL /0 selected skips | Protected image GET in upload-api returns503; its assertion is retained. All other categories, including knowledge indexing, journey, media/product/model intake and actual Flutter avatar timing pass. Committed response 2604 ms; tracked cleanup injects16500 ms then deletes the owned fixture. Conservative parent retains schema; independent recovery confirms7 recorded assets reconciled, no untracked real asset IDs, owned schema removed and 22 public counts unchanged. Original failed evidence remains. |
| `20261016T200543Z-20a0a413` |20 PASS /1 FAIL /0 selected skips | All19 historical categories + preflight pass. The new category reports1 failed reference-cleanup attempt; its strict first-attempt assertion fails. Actual Flutter avatar response 2582 ms and separate delayed profile cleanup pass. Final owned asset deletion succeeds; schema removed and 22 public counts unchanged. This failure remains recorded. |
| `20261016T204723Z-98b47879` |18 PASS / 3 FAIL / 0 selected skips | Failed: rag-database, knowledge, predeployment-remediation. Saved normal configuration, no confidence override. Assets/schema cleaned;22 public counts unchanged. This run does not satisfy full integration acceptance. |

The new live reference check was subsequently strengthened to exercise one bounded
retry through the existing durable cleanup service, verify pending records remain
retired/inactive (or a lost clear acknowledgement is already reconciled), and require
**both** reference records to finish RETIRED/INACTIVE with null image URL and no
cleanupPending flag. A persistent second failure still fails the test. The former
first-attempt-only assertion could not verify recovery and did not check all final
journal rows. Original failed runs are preserved; recovery is explicitly recorded,
not treated as a successful first attempt or a waived cleanup failure.

Follow-up `20261016T203628Z-9ebda62f` fails during replacement with HTTP500 before
the strengthened cleanup assertions. The cause is not proven from that historical
projection and is not labeled a Cloudinary outage. Its generated assets/schema are
cleaned and public counts unchanged. Reference repository diagnostics were added
with only an allowlisted Prisma code (never queries, messages, URLs or credentials),
plus narrower live stages. The diagnostic/privacy unit test passes.

Focused `20261016T204205Z-3588d3c1` then passes preflight and the entire strengthened
remediation category, zero selected skips. Both reference journals are acknowledged
cleared; first cleanup removed 2/failed 0, no retry needed. Actual Flutter avatar
response 1909 ms; separate16500 ms cleanup passes. Fixtures/schema removed;22 public
counts unchanged. All previous failed assertions remain recorded.

Safe metadata from the first full run separates operations:7 model inferences
succeeded (mean 29 ms/max 88 ms);15 retrievals succeeded (mean 4121 ms/max 6121 ms);
6 Gemini calls succeeded (mean 7353 ms/max 11828 ms),2 timed out at approximately12 s
and 1 was unavailable. These are development samples, not latency SLOs. The results
do not justify altering the approved classifier or fabricating successful provider
responses. Earlier failed formatting/import/cwd/tool invocations are retained in
private logs; the passing final component runs are reported separately.

## Security and remaining external verification

Auth/JWT rotation/revocation, Argon2 bounds, RBAC/ownership, private image and
metadata removal, service authentication, TLS/production-role rejection, model hash,
source integrity/injection/citation and subprocess environment regressions pass
the component/live categories actually marked PASS. Default synthetic publication
is denied; new ADMIN routes reject Farmer and guest access. Database checks test
invalid telemetry fields, source-less publication (including SQL NULL bypass),
nullable preupload URL state and replacement lineage FK.

Current dependency checks report zero npm vulnerabilities, zero affected packages
among 47 hosted Flutter packages queried against OSV, and zero reported findings
in the generic AI/training pip scans. Those scans skip local CPU wheels: a separate
normalized OSV check still reports Torch PYSEC-2025-194 and PYSEC-2026-139. The approved
hash-bound state_dict/weights_only loader does not use the affected JIT/PT2 entry
paths; pins/model remain unchanged. This is a documented restricted-path risk,
not blanket package clearance. No security test is
disabled to obtain a passing result. Native camera/device/restart/slow-network and
hosted browser acceptance, production role/network topology, distributed quotas,
cleanup scheduling, backups/CI/signing, retention/erasure/provider consent, legacy
asset review, real reference rights and agronomic/field/commercial approval remain
unverified external/release gates. No deployment has occurred.

## Final uninterrupted normal-config run

Command: `ai-service/.venv/Scripts/python.exe scripts/check-e2e.py` with the project Node runtime. No confidence-policy override; all selected categories attempted.

| Category | Result | Seconds | Selected skips |
|---|---|---:|---:|
| schema-preflight | PASS | 3.23 | 0 |
| database | PASS | 84.05 | 0 |
| migrations | PASS | 11.2 | 0 |
| rag-database | FAIL | 58.03 | 0 |
| knowledge | FAIL | 59.95 | 0 |
| generation | PASS | 131.94 | 0 |
| upload-api | PASS | 81.0 | 0 |
| guest-upload | PASS | 25.92 | 0 |
| guest-inference | PASS | 23.66 | 0 |
| farmer-scan | PASS | 52.2 | 0 |
| assistant | PASS | 69.67 | 0 |
| fertilizer | PASS | 50.39 | 0 |
| yield | PASS | 41.44 | 0 |
| farmer-analytics | PASS | 50.03 | 0 |
| admin-analytics | PASS | 53.27 | 0 |
| management | PASS | 265.3 | 0 |
| model-health | PASS | 23.16 | 0 |
| farmer-remediation | PASS | 32.14 | 0 |
| original-requirements | PASS | 127.2 | 0 |
| journey | PASS | 137.33 | 0 |
| predeployment-remediation | FAIL | 154.09 | 0 |

**18 PASS / 3 FAIL / 0 selected skips; full integration acceptance FAILED.** Owned Cloudinary cleanup/schema removal and unchanged public counts are verified. Original result JSON/logs are retained. No failed assertion is suppressed or changed into a pass.

The final RAG SQL category reports **1 passed / 2 failed / 0 skipped**; the Knowledge live contract reports **0 passed / 1 failed / 0 skipped**, with an actual HTTP 503 and safe `retrieval_database_failed:UNAVAILABLE` diagnostics. These errors establish unavailability at that boundary, not its precise transport or application cause. The later generation/assistant and other successful categories do not erase them.

The final remediation Flutter test reports **0 passed / 1 failed / 0 skipped**. It passed avatar removal in **1,984 ms**, Admin sign-in and the operational dashboard assertions, then timed out waiting for the Knowledge detail and reviewed growth-stage heading (test line 135). Its precise cause is unproven; this is not described as a provider outage or waived. The later delayed-cleanup, replacement and product/model checks in that category were not reached. Separate focused run `20261016T204205Z-3588d3c1` passed those checks with a 1,909 ms avatar response and tracked 16,500 ms cleanup; that does not change this failed full-run result.

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
