# Phase 24.7 final reliability closeout

Updated 2026-10-18 (Asia/Karachi). Continued from `6f7bb3cff64996cc157f14b6dfe7b39ae81efb22`.

**COMPLETE WITH DOCUMENTED RELIABILITY RISK — READY FOR PHASE 25 ENGINEERING.**
This verdict applies to current application engineering under the user's final
closeout criteria. Public release remains **NOT READY**. Phase 25/26 have not started.
The previous stricter historical-cause acceptance verdict is retained below as
historical evidence; missing old diagnostics no longer independently block
infrastructure engineering. No historical failed result is relabeled a pass.

## Accepted execution evidence

- Full normal configured run `20261017T213205Z-173ed748`: **21 PASS/0 FAIL/0 selected skips**.
- Independent repeat `20261017T215921Z-b412d414`: **4/0/0**, including preflight.
- Final independent reliability run `20261018T014159Z-55b5db42`: **4/0/0**, including preflight;
  real RAG SQL **4/0/0**, real Knowledge HTTP **1/0/0**, real Farmer/Admin
  remediation **1/0/0**. Actual exit0; assets/schema removed;22 public counts unchanged.
  It is a focused run, not a newly executed full21-category run.

Command: select project Node using `scripts/use-project-node.ps1`, then
`ai-service/.venv/Scripts/python.exe scripts/check-e2e.py --only rag-database knowledge predeployment-remediation`.
No confidence override, provider bypass or assertion/deadline relaxation.
The four supported labels and absent Healthy-topic abstention, source integrity,
reviewed synthetic metadata, gallery, real operational records/Admin UI and
owned cleanup are exercised. SQL RAG uses a synthetic embedder/real pgvector;
Knowledge uses actual configured Google embeddings. Host widgets are not phones.

No application source, dependencies, environment, database schema or model changed
in this closeout. Four test files gained eight cases: three Python operational,
one opt-in SQL recovery, two Node operational and two Flutter Knowledge cases.
Therefore the already passing complete suite remains applicable to the identical
runtime; a paid full-provider replay would add no change-specific coverage.

## Lifecycle investigation: observations versus hypotheses

| Stage | Retained failure evidence | Current bounded evidence / limit |
|---|---|---|
| DNS | No attributable historical DNS error | Both configured endpoints resolve3 IPv4 attempts. Resolver elapsed525–527ms. No endpoint/IP printed. |
| TCP | Node terminated/timeouts and Python generic CONNECT failures lack lower-stage proof | Authenticated query success necessarily traverses TCP; no claim of isolated historical TCP cause. |
| TLS | No retained certificate/handshake-specific failure | Actual Python client TLS true; Node existing verify-full configuration retained. Local synthetic SSL wait deliberately stalls. |
| PostgreSQL authentication | No proven historical credential/role rejection | Ten configured Python connections authenticate and perform real read-only SQL; Node actual Prisma adapter also queries. |
| Connection setup | Original generic context-entry error cannot distinguish connect/setup | Current real repository setup and scoped search_path pass; controlled setup failure remains safely mapped by existing unit tests. |
| Transaction initialization | Reproduced cold Node P2028 short-acquisition defect repaired previously | Aggregate is one parameterized statement/snapshot, no1s interactive acquisition. No new reproduction. |
| Query | Missing-schema42P01 and cancellation57014 are intentional controls | Real retrieval filters/versions, SELECT1, server cancellation, rollback and subsequent reads pass. These are expected faults, not outages. |
| Commit | Historical log classified COMMIT/CONNECTION_FAILURE at cumulative53023ms | Current read-only transactions commit; cumulative diagnostic duration is not an isolated53s COMMIT execution measurement. Ambiguous mutation commit must not be blindly replayed. |
| Shutdown | Historical best-effort worker deadline/storage warning during interruption | Owned Node writer drains before disconnect; Python3s join warns if incomplete. Controlled blocked worker is released/joined; all current fixtures cleaned. |

Installed Psycopg3.3.6/binary libpq18.4 (`180004`) resolves hostname addresses before
its sequential attempt loop. Each `waiting.wait_conn` receives `connect_timeout=5`.
The synchronous DNS step is outside those per-attempt waits. Existing source:
`psycopg/connection.py`, `_conninfo_attempts.py`, `conninfo.py` in the locked environment.
A loopback-only SSL-request stall with synthetic credentials independently
observes **one attempt5065ms**, **three attempts15044ms**, with five seconds per
attempt. All sockets/worker closed. No actual DB authentication occurs in this
synthetic timeout control; it is not presented as a real SQL check.
This establishes a mechanism for roughly15s with three addresses. It does **not**
establish that historical attempts all stalled at TLS or prove their address count.

Node is separate: pg8.23.1/PrismaPg7.10.0 has a10s client-creation/checkout deadline,
pool max2/idle10s, query5s; pg-pool bounds pending checkout and new-client creation.
Its timer covers the client connection lifecycle rather than Psycopg's address loop.
No evidence proves that Python and Node interruptions share one underlying cause.
Server statement deadlines bound server execution, not every network wait or total
end-to-end wall clock. Production topology/deadline validation remains necessary.

**Historical cause cannot be established from retained evidence.** No provider
incident/authentication/maintenance record is available in this workspace/account
tooling, and the user does not have it. Later successful TLS/auth/SQL controls do
not reconstruct earlier failures. Neither provider outage, local resource pressure,
DNS failure nor exhaustion is asserted. Original Knowledge503 and Flutter heading
timeout remain historically unattributed; their current workflows pass.

## Current bounded reliability and recovery controls

Python actual configured AI and direct endpoints: **16/16 checks PASS**, including
two DNS observations,10 TLS-authenticated connections, read-only SQL/commit/close,
max2 concurrent readers, warm reads,12s idle reuse, fresh reconnect and actual
server cancellation57014 followed by rollback/recovery. Fresh authentication
1320–1982ms; normal successful connect/query/commit/close2427–3183ms; warm reads
952–971ms; idle reads918–973ms. These are development samples, not uptime/SLO proof.

Node actual reusable Prisma client: **8/8 controls PASS**. Cold SELECT1 1833ms,
warm228ms, concurrent2 readers1545ms, one-snapshot aggregate283ms, intentional
server cancellation/rollback1295ms, recovered read220ms, idle12s reconnect1528ms,
disconnect4ms. No global budget/pool changes, host overrides or automatic retry.

Retry classification: a failed read may be explicitly requested again; RAG does
not fabricate a fallback or indiscriminately reconnect. Commit acknowledgement
loss for a mutation is uncertain and needs its existing journal/idempotency
reconciliation. Node telemetry alone retries the same UUID once; SQL ON CONFLICT
prevents double counting. Python storage failure drops/logs its event without retry.

RAG fault injection raises at CONNECT against an otherwise real owned pgvector
fixture. It returns RETRIEVAL_UNAVAILABLE, no chunks; restoring connectivity
recovers the same current-version/source chunks, never archived version1.
Existing four-stage diagnostic tests redact dependency text. Actual server
cancellation checks rollback and connection reuse; cold/reconnect contexts close.

Flutter: failed catalogue clears loading with an error, rather than a false empty
success; explicit retry restores four entries. A delayed old search cannot
overwrite a newer completed search. Existing API503/DTO error, retry, reviewed
fields only when returned, long-text/disposal/session regressions pass.

## Operational telemetry and Admin recovery

The approved design is best effort, not a lossless billing/audit requirement.
Original Admin monitoring A04 requires observed operations; it does not require
every inference to wait for telemetry durability. Operational rows contain only
attempt identity/scope/type/outcome/duration/category/time. No prompts/accounts,
JWTs/images/provider credentials are recorded. Required audit trails are separate.

Python tests prove one failed sink cannot alter a controlled model inference:
two successful predictions, one genuinely stored event and one diagnosed loss.
This is not reported as two persisted rows. Queue saturation retains128 pending
plus1 active, drops4 of133 attempts visibly, and then drains129. A blocked sink
exceeds the existing3s join, logs shutdown_incomplete and is released/joined by the
fixture. At actual process exit unpersisted work can be lost; no lossless guarantee.
The loss counter is process-local, Python loss diagnostics are logs, not an Admin
global delivery counter. Production alert collection is a Phase25 responsibility.

Node retains128 queued+1 active and at most one same-identity storage retry.
Controlled lost commit acknowledgement yields two writes with one ID/one logical
record; close drains the owned writer before disconnect. Storage/overflow losses
are observable. Admin unavailable has null totals/daily; recovery to COLLECTED
with empty arrays means no **recorded** events, not proof that zero operations
occurred. UI explicitly warns about best-effort omissions and historical coverage.
Actual recorded operations/aggregates and Admin/Farmer/guest permissions pass live.

## Closeout checks and preservation

| Current check | PASS / FAIL / SKIP |
|---|---|
| Focused normal E2E `20261018T014159Z-55b5db42` |4/0/0 categories; SQL4/0/0 + Knowledge1/0/0 + remediation1/0/0 |
| Node operations/repository/safe diagnostics |15/0/0 |
| AI operations/database diagnostics/inference |61/0/0; existing Starlette warning retained |
| Flutter Knowledge repositories/VM/widgets |30/0/0 |
| Flutter Admin predeployment DTO/VM/widgets |8/0/0 |
| Node format/lint/strict types/OpenAPI |PASS,59 operations |
| AI Ruff lint/format/mypy |PASS,73 formatted files checked/47 typed source files |
| Flutter format/analyze |PASS, no analyzer issues |
| Local stalled-driver timing |2 expected-timeout controls PASS,0 unexpected failures |
| Configured Python read-only lifecycle |16/0/0 checks |
| Configured Node adapter lifecycle |8/0/0 checks |

Counts overlap; they are not summed. Historical full component counts356+2 Node,
371 AI/3 default SQL skips,391 Flutter/14 default live skips remain dated evidence
at6f7bb3c, not newly rerun totals. The added SQL recovery test is opt-in like the
other3; this focused live invocation enables all4 with zero skips. Android build,
Prisma14/no drift and shared78-per-environment/12 parity evidence remain applicable
because their source/locks/schema/artifacts are unchanged. No new build or final
test-set evaluation is claimed. Raw safe diagnostics are in ignored
`.cache/phase247closeout/`; original run results/logs are retained unchanged.

Final read-only catalog and frozen/hash checks verify all22 public counts unchanged,
zero owned temporary schemas,14 finished migrations,34 checks/28 foreign keys/
38 custom triggers/87 indexes, registry VALIDATED,171 frozen files unchanged.
Model `mobilenet-v3-small-v2-20261009`, full-frame1.0.0/224 RGB/NCHW, class mapping
Common_Rust0/Gray_Leaf_Spot1/Healthy2/Northern_Corn_Leaf_Blight3, T1/null threshold
are untouched. Checkpoint and metadata hashes remain as recorded below.
No real user/assets deleted, DB reset, raw dataset read, retraining, split change,
final rescoring, privilege weakening, TLS relaxation or secret/config mutation.

## Final readiness distinction

No unresolved reproducible P0/P1 application blocker remains in the checked scope.
No new P2 functionality defect was reproduced. Intermittent connectivity is a
documented operational reliability risk; old unobservable causes are uncertainties,
not automatically new application defects. Existing dependency restricted-path
risk and P3 deprecation notices remain. This is not a guarantee of defect absence.

**Phase25 engineering: READY WITH DOCUMENTED RISKS. Public release: NOT READY.**
Production least-privilege identities, private FastAPI/database topology, verified
TLS/HTTPS, shared limits, cleanup scheduling, backups/recovery, monitoring and
alerts, CI/CD/signing must be implemented/verified in separately authorized Phase25.
Retention/privacy/provider-processing approval, physical devices/browser, real
licensed media/sourced metadata, agronomic inputs/mathematical models and exact
model-dependent richer calculator engine/UI, confidence/field claims and research/
commercial dataset limits still constrain release/full-product acceptance.
No confidence threshold, agronomic value or content approval is fabricated.

No credentials/provider logs/manual dataset labels are required to close this
assessment. User action: authorize Phase25 separately if desired, and arrange
documented content/policy/device/release approvals before public use.

MAIZEDOCTOR's current application engineering is sufficiently verified to begin Phase 25 — Deployment, Production Infrastructure and Release Engineering. Historical connection interruptions remain documented for operational validation; this is not public-release approval.

## Earlier stabilization handoff (historical; superseded above)

# Phase 24.7 — integration stability and acceptance

Updated 2026-10-18 (Asia/Karachi). Baseline `7c0332a`, branch `main`.
**PARTIALLY COMPLETE. Phase 25: NOT READY. Phase 25/26 have not started.**

The repaired code passes one uninterrupted normal configured full run **21 PASS /
0 FAIL / 0 selected skips**, followed by an independent original-boundary repeat
**4 PASS / 0 FAIL / 0 selected skips**. All owned fixtures are cleaned and public
counts unchanged. Three confirmed defects are repaired: cold operational
aggregation, gallery account-revision state and affected harness writer teardown.
Strict acceptance remains partial: the original three causes were not recorded
precisely enough to reconstruct, and an intermittent connection interruption was
observed again. Later passes do not prove historical cause or continuous uptime.

## Original three failures

| Original failure | Proven evidence and action | Current result / cause status |
|---|---|---|
| rag-database | Original `20261016T204723Z-98b47879`: 1 passed/2 failed entering repository context, before the application query body, with generic UNAVAILABLE. Added CONNECT/TRANSACTION_SETUP/QUERY/COMMIT, safe category/SQLSTATE/duration/correlation. Missing-schema oracle now requires actual QUERY/42P01, not a transport outage. | Final full and repeat each pass all 3 SQL cases. Historical connection/setup subtype and responsible component remain unproven. |
| knowledge | Original HTTP 503 with the same generic database log. Added safe diagnostics and repaired writer shutdown; live contract requires five Node retrieval events persisted before disconnect. | All four labels, source projection and absent Healthy-topic abstention pass full/repeat. No proof the original 503 shared another failure's cause. |
| predeployment-remediation | Original reviewed-growth-stage heading absent at the unchanged 90-second deadline, before gallery assertions; terminal ViewModel state was not recorded. Added safe view/loading/error/data/count diagnostic; slow/API/DTO/retry/long-text widget regressions. | Reviewed synthetic metadata/gallery render through real backend in full/repeat. Which original case A–G occurred cannot be reconstructed. The separate gallery bug is not claimed as its cause. |

Original run remains 18/3/0. All earlier Phase 24.6 evidence remains in the
[historical ledger](phase-24-6-verification.md); no failed result or Phase 24.5
audit file was rewritten.

## Confirmed defects, fixes and controls

**Cold aggregate acquisition:** independent repeat `20261017T212006Z-62ca6a4f`
failed before Knowledge, because Admin operations returned UNAVAILABLE. Its
service swallowed the lower exception while returning that truthful state.
Read-only actual-database controls then independently proved a repository defect:
the two-query read transaction's `maxWait=1000` failed cold with P2028/acquisition
timeout at 1,074 ms, repeated at 1,077 ms; the same warmed client passed at
1,519 ms. The failed HTTP response did not retain its exception, so that specific
response is not retroactively assigned an unrecorded code.

Totals and daily projections now use **one parameterized SQL statement and one
snapshot**. This removes the unnecessary interactive acquisition deadline and
two read-committed snapshots. Shared pool acquisition (10 s), query (5 s), TLS,
production-role guards and writer limits are unchanged. No prewarming, retry or
global timeout/pool increase was introduced. Missing query output fails instead
of fabricating empty statistics. After repair, cold succeeds at 1,848 ms and
warm at 250 ms. These probes only read public data; no accounts/events were
created. Repository/service/diagnostic focused tests: 13 PASS/0 FAIL/0 SKIP.
Live metrics also require totals/daily request and failure sums to agree.

**Gallery state:** before-fix regression 1 PASS/1 FAIL reproduced permanent busy
state after an account revision changed during a read. Completion now clears
busy/stale selections and reports identity invalidation. Explicit fresh reads
can rebind; stale Admin mutations never rebind/retry. Three regressions pass,
including disposal and zero stale publication requests.

**Harness ownership:** affected Node owners stop the server, close/drain their
operational writer, then clean fixtures/disconnect clients. Assistant/scan-upload
also disconnect shared clients. A gated writer regression proves close waits and
prevents post-close writes. Knowledge live proof requires all five retrieval
events persisted. This defect is not claimed to explain the Python outage.

Shared safe Prisma diagnostics classify acquisition versus expiry for centralized
errors and degraded aggregate logs. Static categories/codes only; no raw SQL,
exception text, credentials, prompts, images or private URLs. Live failure proofs
bound aggregate diagnostics to 20 entries. Public errors and API schemas remain
unchanged. Three extra Knowledge widget cases cover slow responses, API failure,
malformed DTO/retry and long text at 320×640/text scale 2. Content is test-only.

## Connection stability and remaining attribution gap

Earlier affected run `20261017T114333Z-4204cff5` captured a 53,023 ms COMMIT
connection failure and subsequent CONNECT timeouts around 15 seconds, alongside
Node connection termination/timeouts. It finished 2 PASS/5 FAIL/0 selected skips.
The exact network/backend/authentication cause remains unestablished. TLS-edge
success did not authenticate or prove PostgreSQL query availability.

The final post-fix full run logged **1 Python telemetry storage warning(s)**,
including CONNECT/CONNECTION_TIMEOUT at 15,020 ms. Guest inference and Farmer
scan/history still passed: best-effort telemetry failure did not replace the
successful Farmer response. An immediate later bounded control reached
AUTHENTICATED_READY with verified client TLS on all six resolved IPv4 endpoint/
address combinations (roughly 1.64–1.89 s). It executed no SQL and does not prove
what failed earlier. Later resource samples showed 2,284–3,155 MB available RAM,
2–15% CPU and zero sampled TCP retransmits; not the failure instant, so not a
causal explanation. Provider-side logs are unavailable in the workspace; an
optional sanitized-log question was sent, without pausing independent work.

Existing Python per-operation connections retain 5 s connect, transaction-local
search_path, 5 s statement and 15 s idle-transaction settings. Node pool max 2,
10 s acquisition/idle and 5 s query limits are retained. Other affected Knowledge/
profile repositories have no analogous one-second acquisition limit. Earlier
read-only probes passed 16/16 at concurrency 4 and after 422 seconds idle;
3–6 observed backends versus max_connections=901 are snapshots, not proof about
historical peaks, provider autosuspension or exhaustion. No provider is blamed
and no unlimited recovery retry was added. Metadata delivery remains explicitly
bounded best effort; storage/queue/abrupt-shutdown losses are possible.

## Actual run ledger

PASS/FAIL/selected skips are per invocation, never combined into a fictional run.

| Run | Scope | Counts | Cleanup/data |
|---|---|---|---|
| `20261017T111632Z-ac9d4341` | Initial focused, before subsequent repairs | 4/0/0 | Owned schema/assets clean; public counts unchanged |
| `20261017T113727Z-09c332d4` | Focused after gallery/teardown repairs | 4/0/0 | Owned schema/assets clean; public counts unchanged |
| `20261017T114333Z-4204cff5` | Affected flows; connection interruption | 2/5/0 | Separate owned recovery; original failed result unchanged |
| `20261017T204440Z-a6bfd1c2` | Affected-flow recovery | 6/0/0 | Owned schema/assets clean; public counts unchanged |
| `20261017T205623Z-d379fdd4` | Earlier full, before aggregate repair | 21/0/0 | Owned schema/assets clean; public counts unchanged |
| `20261017T212006Z-62ca6a4f` | Earlier independent repeat; Admin UNAVAILABLE | 3/1/0 | Owned schema/assets clean; public counts unchanged |
| `20261017T212855Z-bdb508b9` | Post-aggregate-repair focused | 2/0/0 | Owned schema/assets clean; public counts unchanged |
| `20261017T213205Z-173ed748` | Final full on repaired code | 21/0/0 | Owned schema/assets clean; public counts unchanged |
| `20261017T215921Z-b412d414` | Final independent original-boundary repeat | 4/0/0 | Owned schema/assets clean; public counts unchanged |

The retained interrupted schema was recovered separately after connectivity
returned: exact recorded schema, one matching generated assistant account/scan/
journal with example.invalid fixture image, zero actual Cloudinary uploads,
avatars or reference media. Only that owned schema was dropped, all 22 public
counts verified unchanged. Its failed JSON remains unchanged; independent proof
is `.cache/phase247/retained-recovery.json`. No real asset/account was deleted.

## Final uninterrupted normal configured full run

Run `20261017T213205Z-173ed748`. Command: `ai-service/.venv/Scripts/python.exe
scripts/check-e2e.py`, after selecting project Node with
`scripts/use-project-node.ps1`. Actual process exit 0. No confidence override,
temporary bypass, altered order, disabled assertion or selected skip. The normal
harness isolates its schema/local ports/internal token and generated fixtures;
configured providers and approved model remain real.

| Category | Result | Seconds | Selected skips |
|---|---|---:|---:|
| schema-preflight | PASS | 3.66 | 0 |
| database | PASS | 84.50 | 0 |
| migrations | PASS | 7.52 | 0 |
| rag-database | PASS | 95.61 | 0 |
| knowledge | PASS | 30.62 | 0 |
| generation | PASS | 95.03 | 0 |
| upload-api | PASS | 79.69 | 0 |
| guest-upload | PASS | 44.53 | 0 |
| guest-inference | PASS | 69.27 | 0 |
| farmer-scan | PASS | 38.44 | 0 |
| assistant | PASS | 66.75 | 0 |
| fertilizer | PASS | 47.42 | 0 |
| yield | PASS | 32.19 | 0 |
| farmer-analytics | PASS | 45.20 | 0 |
| admin-analytics | PASS | 45.28 | 0 |
| management | PASS | 251.80 | 0 |
| model-health | PASS | 22.45 | 0 |
| farmer-remediation | PASS | 31.14 | 0 |
| original-requirements | PASS | 117.52 | 0 |
| journey | PASS | 149.81 | 0 |
| predeployment-remediation | PASS | 194.41 | 0 |

All 19 historical integration categories, preflight and remediation pass in this
single run. Its schemaRemoved/cloudCleanupComplete/productionCountsUnchanged/
passed flags are true. Independent repeat `20261017T215921Z-b412d414` uses `--only rag-database
knowledge predeployment-remediation`, 4/0/0 with the same cleanup/data guarantees.
Earlier full `20261017T205623Z-d379fdd4` was before the aggregate repair and is not substituted for
the final repaired-code evidence. Failures were inspected between bounded runs;
paid calls were not repeatedly rerun to obtain a random pass.

## Complete component evidence

| Check | Result and practical limit |
|---|---|
| Backend format/lint/strict types/build/full tests | 356 PASS/0 FAIL/0 SKIP |
| Actual frontend subprocess environment isolation | 2 PASS/0 FAIL/0 SKIP |
| Generated OpenAPI validation/route/request/response drift | PASS, 59 operations |
| AI Ruff format/lint, mypy 47 files, full pytest | 371 PASS/0 FAIL/3 default SQL skips |
| Flutter format/analyze/full tests | 391 PASS/0 FAIL/14 default live skips; 231 files, 0 formatting changes |
| Android ARM64 debug packaging | PASS; not a signed release or installed-device acceptance |
| Shared preprocessing, both locked environments | 78 PASS in each, 0 failures/skips |
| Exact cross-environment synthetic parity | 12 PASS/0 FAIL/0 SKIP |
| Prisma validate/generate/types/catalog/rollback/status | PASS, 14 SQL checks and 14 applied migrations |
| Captured Prisma drift subprocess | Exit 0, no difference detected |
| Full-run live database cases | 43 PASS/0 FAIL/0 SKIP |
| Final full/repeat live SQL RAG | 3 PASS/0 FAIL/0 SKIP each |
| Full live generation/upload API cases | 9/0/0 and 2/0/0 |
| Node/shared image-admission contract | 56 synthetic cases PASS: 21 accepted/35 correctly rejected; no dataset access |
| Repository structure/templates/ignore checks | PASS |

Counts overlap and are not summed into inflated unique totals. Default SQL/live
skips are disclosed separately from zero-skip live runs. SQL RAG uses a
deterministic synthetic embedder with real PostgreSQL/pgvector; Knowledge and
management independently call actual Google embeddings. Controlled faults/mocks
are not called real provider outages. Flutter live checks are host-widget/API
tests, not physical-device/browser acceptance. Existing Starlette/httpx and
non-failing pg/lint notices remain visible; no dependency/security test was removed.

## Connected features and security

| Flow | Verified boundary |
|---|---|
| Actual saved FastAPI startup → model | Normal python -m app.server: health/model-health 200, ready approved artifact without confidence overrides |
| Node → private FastAPI → shared model → DB → Flutter | JPEG/PNG/WebP; anonymous/Farmer ownership, result/history, low-confidence preservation |
| RAG/Google → Node/Flutter | Four labels, READY vectors/source lineage, archived exclusion, absent Healthy-topic abstention, grounded explanation |
| Knowledge metadata → Farmer widgets | Reviewed synthetic applicability/source/severity through actual Node/DB; long/empty/error/retry/disposal/session tests; no real facts invented |
| Profile/avatar → durable cleanup | Final avatar committed response 1,802 ms with separate 16.5 s cleanup delay; actual Cloudinary persistence/replacement/removal; lost-ack/reconciliation regressions |
| AI events → DB → Admin API/UI | Real generation/provider records, aggregate counts/percentiles/daily consistency, metadata-only privacy, guest/Farmer denial |
| Admin media → protected Farmer gallery | Generated upload, rights/review/publication, delivery, ordering/revision/replacement, both retired records and acknowledged cleanup |
| Product/rule/model intake | Reviewed versions/freeze/audit; richer numerical models stay disabled; no recommendation values fabricated |

Auth/refresh/logout/revocation, Argon2id bounds, RBAC/ownership/capabilities,
protected metadata-free images, TLS/production-role guards, environment
allowlists, provider bounds, injection/citation validation and cleanup fences
remain enabled/passing. No security test was disabled. Representative classifier
mean was 28.80 ms for four generated fixtures in the final upload check;
excludes upload/network time, is not accuracy or a production SLO.

## Preservation and remaining requirements

171 frozen files, checkpoint/metadata and all migration files unchanged. No raw
dataset access, training, immutable split change, final test rescore or registry
promotion. Selected model mobilenet-v3-small-v2-20261009 remains VALIDATED;
preprocessing 1.0.0/full-frame 224 RGB/NCHW, temperature 1/null threshold remain.
All outputs remain LOW_CONFIDENCE/THRESHOLD_UNCONFIGURED. Mapping:
Common_Rust=0, Gray_Leaf_Spot=1, Healthy=2, Northern_Corn_Leaf_Blight=3.

- Checkpoint: `e95a2e83262637fc1a08b919e6003bddb2fe70664b9c51418f059b7c8287dc66`.
- Metadata: `a831116fe1ff8b915543991412f4ab6b334736e8eaca376fab8db3b57e5b263d`.
- All 22 public counts unchanged: diseases 4/sources 4/documents 25/chunks 25/
  model 1; other inventoried tables retain original zero counts.
- Fourteen migrations, 34 CHECKs, 28 FKs, 38 custom triggers and 87 indexes
  unchanged. Final verification finds zero temporary schemas.
- Ignored environment files and original user .gitignore/ML README/dataset
  scaffolding/eight-line PROJECT_STATE addition are preserved outside this commit.

Current overrides to the [65 original requirements](phase-24-6-requirements-matrix.md)
separate verified workflows from content and strict system acceptance. Metadata/
media technical workflows pass; real licensed photos and sourced agronomic fields
remain absent. RAG works, but connection cause/stability closure remains open.
Full automated execution now passes; historical root-cause diagnosis is a separate
unfulfilled acceptance criterion. No original failed report is relabeled a pass.

No uncorrected P0/P1 code cause is identified. **P1 acceptance investigations**:
original database/503 subtype, original heading-timeout case, and attribution of
observed intermittent CONNECT/COMMIT interruptions. Related confirmed code defects
are fixed. No additional P2 feature defect is established; existing deprecation
notices are non-failing maintenance risks. Do not infer provider/local blame from
later probes. Green functional runs do not close these causal/stability gaps.

External gates: approved licensed reference photos, real stage/severity content,
fertilizer rates/nutrient-demand/selection/timing models, yield forecast equations/
data, confidence policy, device/browser acceptance, privacy/provider-processing/
retention/release approval and commercial dataset clearance/replacement. Richer
N/P/K/schedule and min/expected/potential forecast outputs are absent: their exact
engine/UI extensions require the approved mathematical specification. Disabled
intake is not claimed to be those numerical features. No new credentials or manual
dataset labels are requested. Retention remains unchanged.

Next: use the new safe diagnostics and available provider/network evidence to
establish the responsible component on recurrence, then add its matching
regression. Do not brute-force paid tests, speculate, or start Phase 25/26.
Phase 24.7 remains PARTIALLY COMPLETE and Phase 25 NOT READY under the requested
strict cause-closure criterion.

## Changed files

No routes, database schema, dependencies or configuration values changed.
DECISIONS is unchanged: no architectural decision was introduced.

- `README.md`
- `ai-service/app/api/middleware.py`
- `ai-service/app/rag/repository.py`
- `ai-service/app/utils/logging.py`
- `ai-service/tests/test_database_diagnostics.py`
- `ai-service/tests/test_rag_database.py`
- `backend/src/middleware/error-handler.ts`
- `backend/src/modules/admin/operations.repository.ts`
- `backend/src/modules/admin/operations.service.ts`
- `backend/src/utils/database-diagnostics.ts`
- `backend/tests/admin/operations.repository.test.ts`
- `backend/tests/admin/operations.test.ts`
- `backend/tests/foundation/database-diagnostics.test.ts`
- `backend/tests/knowledge.live.integration.ts`
- `docs/30-knowledge-retrieval.md`
- `docs/39-testing-e2e-verification.md`
- `docs/KNOWN_ISSUES.md`
- `docs/PROJECT_STATE.md`
- `docs/phase-24-6-requirements-matrix.md`
- `docs/phase-24-6-traceability.md`
- `docs/phase-24-6-verification.md`
- `docs/phase-24-7-integration-stability.md`
- `mobile/lib/features/disease_knowledge/view_models/reference_gallery_view_model.dart`
- `mobile/test/integration/predeployment_remediation_test.dart`
- `mobile/test/knowledge/metadata_widget_test.dart`
- `mobile/test/knowledge/reference_lifecycle_test.dart`
- `scripts/check-admin-management.mjs`
- `scripts/check-assistant.mjs`
- `scripts/check-e2e.mjs`
- `scripts/check-farmer-remediation.mjs`
- `scripts/check-predeployment-remediation.mjs`
- `scripts/check-requirements.mjs`
- `scripts/check-scan-upload.mjs`
