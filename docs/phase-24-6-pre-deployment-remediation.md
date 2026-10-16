# Phase 24.6 — pre-deployment remediation

Baseline: `main` at `18bd55e`, 2026-10-16. This is implementation and verification,
not authorization for Phase 25 or 26. The Phase 24.5 reports remain historical
snapshots. Current requirements, connections and evidence are maintained in the
[requirements matrix](phase-24-6-requirements-matrix.md),
[traceability](phase-24-6-traceability.md) and
[verification ledger](phase-24-6-verification.md).

Final verdict: **PARTIALLY COMPLETE**. Normal-config full run `20261016T204723Z-98b47879`
finishes **18 PASS / 3 FAIL / 0 selected skips**. Failed categories: **rag-database, knowledge, predeployment-remediation**.
The failed assertions remain intact. Owned assets and schema are cleaned, and all
22 public application table counts are unchanged. Actual default FastAPI startup
and the selected model work without confidence overrides; full integration
acceptance has **not** passed. Phase 25 readiness: **NOT READY**.

The engineering workflows below are implemented and have passing component and
targeted live evidence. That evidence does not replace failed full-run acceptance.
RAG/Knowledge failures include database-unavailable errors; earlier HTTP 500 and
cleanup failures are retained with unproven causes rather than attributed to a
provider without evidence. Scientific models, licensed content and release/privacy
approval also remain explicit gates. No Phase 25 or 26 work starts.

## Phase 24.5 finding dispositions

| ID | Previous severity | Action and evidence | Current disposition |
|---|---|---|---|
| AUD-01 | P1 | Corrected saved optional pair; actual configured startup/inference, strict paired/malformed/precedence/CLI tests | Engineering RESOLVED; no new confidence approval |
| AUD-02 | P1 | Real Node/AI/provider producers, minimal SQL events, ADMIN aggregates and Flutter; targeted live recording/rendering plus failure/RBAC tests | Engineering RESOLVED; best-effort losses/retention policy explicit |
| AUD-03 | P1 | Provenance/rights/review, secure upload, protected gallery, replacement/retirement/durable cleanup; real generated Cloudinary integration | Engineering implemented with focused live PASS; final Farmer detail/gallery verification OPEN; licensed real content OPEN |
| AUD-04 | P2 | Informational catalogue + sourced optional applicability/revisions/audit/Farmer detail; four model classes unchanged | Engineering implemented with focused live PASS; final Farmer detail verification OPEN; real sourced domain fields OPEN |
| AUD-05 | P1 | Independent product catalogue and immutable reviewed richer-model intake; existing exact area-rate engine preserved/tested | Source/review engineering complete; nutrient model/rates/selection/schedules and dependent numeric implementation OPEN pending actual model/data |
| AUD-06 | P1 | Dimensioned immutable min/expected/potential specification intake; existing conditional projection preserved/tested | Review engineering complete; approved forecast model/data and dependent numeric implementation OPEN |
| AUD-07 | P2 | Generated 59-operation OpenAPI 3.1 from runtime requests/shared validated responses; parser/drift/coverage gates and local viewer | RESOLVED |
| AUD-08 | P1 | Production privilege/TLS guards retained/regression tested; current research role not changed | OPEN deployment provisioning gate |
| AUD-09 | P2 | New media keeps protected Node delivery; generated fixtures only cleaned | OPEN owner legacy-asset inventory/invalidation decision |
| AUD-10 | P2 | Responsive/widget/host integration and ARM64 debug checks | OPEN named physical-device/hosted-browser release acceptance |
| AUD-11 | P2 | Retention unchanged as explicitly approved; minimal telemetry, no automatic erasure/deletion policy | OPEN retention/consent/provider-processing approval |
| AUD-12 | P2 | Fresh normalized OSV still identifies 2 Torch JIT/PT2 advisories; approved hash-bound weights_only state_dict path preserved | OPEN restricted-path release risk; no silent model/dependency replacement |
| AUD-13 | P3 | Registration/Knowledge legacy proof labels corrected; assertions and audit snapshots retained | RESOLVED |
| AUD-14 | P3 | Missing trustworthy training timestamp remains null; frozen artifacts untouched | OPEN historical metadata limitation; no fabricated date |
| AUD-15 | P2 | Existing per-process limits and tracked cleanup preserved; no deployment topology invented | OPEN shared quotas/proxy/network/scheduler infrastructure gate |
| AUD-16 | P2 | Committed projection returns before queued cleanup; lost-ack/client reconciliation and 16.5 s delay/regression/live photo tests | Engineering RESOLVED |

Final full-run acceptance, including actual external service failures, is reported
separately below/in the verification ledger. “Engineering resolved” is not a claim
that every live provider request succeeds or that the original agronomic product
requirements are fully delivered.

## Default FastAPI startup (AUD-01)

The ignored service-local dotenv had an optional policy digest without its path.
Both optional entries now remain empty, implementing the already approved null
policy. No threshold, calibration, key or model was changed. Other dotenv entries
were preserved. The saved private configuration is deliberately not committed.

`load_settings` checks the pair before model initialization and explains the exact
correction, including Windows PowerShell environment precedence. The executable
logs this **safe static ConfigurationError guidance** through the allowlisted
`configuration_hint`; it never serializes Pydantic rejected values. The lifespan
still independently rejects mismatched policy configuration. Paired empty/filled,
one-sided, malformed hashes, dotenv and process precedence have tests.

Normal startup and real synthetic-image inference pass using the actual project
settings, without a temporary confidence override. Run:

```powershell
ai-service/.venv/Scripts/python.exe scripts/check-ai-startup.py
powershell -File scripts/start-ai.ps1
```

The first command runs the actual application lifespan and model using TestClient;
the integration harness additionally serves it over real HTTP. The second is the
normal long-running executable. A new checkout still needs operator-supplied
private environment values. In PowerShell, removing an OS override reveals the
dotenv value; it does not clear it. Correct the file and remove both stale process
overrides together. Never copy credentials into a script or diagnostic.

Approved artifact identity, unchanged:

| Property | Value |
|---|---|
| Model | `mobilenet-v3-small-v2-20261009` |
| Checkpoint SHA256 | `e95a2e83262637fc1a08b919e6003bddb2fe70664b9c51418f059b7c8287dc66` |
| Metadata SHA256 | `a831116fe1ff8b915543991412f4ab6b334736e8eaca376fab8db3b57e5b263d` |
| Preprocessing | Shared `1.0.0`, approved full-frame policy, 224×224 RGB/NCHW |
| Class mapping | Common_Rust=0; Gray_Leaf_Spot=1; Healthy=2; Northern_Corn_Leaf_Blight=3 |
| Confidence | Threshold null; temperature 1; LOW_CONFIDENCE / THRESHOLD_UNCONFIGURED |

The shared package continues to own decoding, color conversion, resize,
normalization and tensor conversion. No dataset inventory, training, test-set
evaluation, model replacement or promotion occurred.

## Avatar commit, response and cleanup (AUD-16)

`profile-media.service.ts` returns the committed profile association projection
without awaiting obsolete Cloudinary deletion. The existing PostgreSQL journal
already contains cleanup work. The existing `profiles:cleanup` command owns the
tracked retry; there are no detached promises in the response path. Do not assume
cleanup runs automatically on an unscheduled local environment.

Replacement preserves the current asset and queues only obsolete identities.
Failed/ambiguous upload acknowledgements reread the journal; uncertain assets are
retained for reconciliation, not deleted. Removal with a lost database commit
acknowledgement rereads the serialized association. Current/pending asset fences,
cleanup leases, idempotent provider deletion and bounded attempts are retained.

Flutter reconciles an ambiguous removal through one GET instead of another DELETE.
The scoped Profile ViewModel also reloads after ambiguous network/timeout/server
outcomes, shows a review message and clears a stale selected image. A failed read
explicitly leaves the result uncertain. The default 15-second request deadline is
unchanged. The controlled 16.5-second deletion test proves the mutation returns
before deletion, then explicit journal cleanup finishes successfully.

The completed live remediation category additionally measures an actual Flutter
Profile ViewModel → repository → Node → PostgreSQL removal at **2,604 ms**, using
the unchanged 15-second transport deadline. No provider deletion starts on that
mutation. The separately awaited cleanup then observes an injected 16,500-ms delay
and deletes the real owned Cloudinary fixture; its journal finishes successfully.
This is controlled delay injection with real services, not a claimed provider outage.

Tests cover upload/replacement/removal, current-asset preservation, deletion
failure, lost commit acknowledgement, competing/pending updates, repeated removal,
interrupted cleanup/recovery, client timeout after commit and reconciliation.
Provider outages/delays are simulated; normal Cloudinary operations are also live.

## Admin AI operational monitoring (AUD-02)

`ai_operations` stores one immutable identity per observed attempt, with only:
UUID, scope, operation, outcome, bounded duration, safe category and timestamp.
There are no user/scan IDs, prompts, transcripts, private image paths, model input,
provider messages, JWTs or API keys. Existing `ai_queries`/`ai_responses` are not
misused to store fabricated prompt content merely to obtain counters.

| Scope | Actual producer | Operations |
|---|---|---|
| NODE | Validated AI clients wrapped in the application composition | INFERENCE, RETRIEVAL, GENERATION, EXPLANATION |
| AI_SERVICE | Measured service operations | INFERENCE, RETRIEVAL, GENERATION, EXPLANATION |
| PROVIDER | Official Google embedding/Gemini adapters | EMBEDDING, GEMINI |

SUCCESS follows successful downstream validation, not merely HTTP 200. Unsupported,
insufficient and conflicting-evidence results are ABSTAINED. Actual provider/timeouts
and invalid responses are FAILED with safe categories. Separate scopes must not be
summed as unique farmer requests; explicit retries are distinct attempts, while
storage retries retain the event UUID and cannot create duplicate rows.

Node owns one writer with 128 queued events plus one active write, one same-identity
retry, explicit flush/close and startup/shutdown ownership. Responses do not await
telemetry storage. FastAPI owns a bounded 128-event worker initialized and closed
by lifespan; provider context uses ContextVar, not private payload capture. SQL
writes have timeouts. This is **best-effort operational monitoring**, not a lossless
audit/billing ledger: queue overflow, storage failure, abrupt termination or an
exhausted shutdown deadline can lose events. Node exposes local pending/dropped
counts; AI logs storage/capacity/shutdown loss conditions. Historical pre-producer
requests and lost events cannot be reconstructed as zero. These process-local
diagnostics are not global cluster counters.

Retention remains unchanged by the user's approval: no automatic deletion or new
account erasure policy. The timestamp index supports later approved retention work;
minimal persistent events still need an approved retention/processing policy before
public use. Durable SQL rows survive restarts; in-memory pending queues do not.

ADMIN-only `GET /api/v1/admin/ai-operations` accepts the existing bounded UTC
`from`/`to` date-range contract. SQL computes scoped request/success/failure/abstention
counts, average/p50/p95 latency and UTC daily counts. An unavailable database returns
UNAVAILABLE with null values; a successful empty aggregate is a real observed zero,
with the historical collection limitation displayed. The existing Admin dashboard
repository/ViewModel renders scoped cards and request bars, warnings, loading,
error and empty states. Offline model metrics stay on the separate model dashboard.

Tests cover ADMIN/FARMER/guest access, invalid dates, outcome and idempotent storage,
concurrency/overflow, failed providers/storage, private-field exclusion, parsing and
rendering. A controlled real generation produces Node and Google-provider rows,
then the actual Flutter dashboard reads and renders them through Node.

## Disease catalogue and sourced applicability (AUD-04)

The four classifier labels/slugs remain immutable. ADMIN can create an additional
**informational knowledge entry**, and edit name/scientific name/description/status
plus optional reviewed growth-stage/severity text. A new entry is never represented
as a newly trained class. Existing RAG class filters still admit the approved four
contexts; catalogue creation does not silently expand classifier or RAG scope.

Optional `catalogueMetadata` records reviewed arrays, a full source snapshot,
review note and approval. Nonempty applicability requires a valid attributable
source. No agricultural levels or growth claims are seeded or defaulted. Revisions
include metadata, updates reject stale revisions and audits retain prior values.
Farmer detail projects only reviewed metadata, distinguishes informational entries
and retains intentional Healthy behavior. Inactive catalogue entries and their
media are hidden; existing immutable document/chunk history is preserved.

Flows: Admin management → Diseases → new informational entry or revision-pinned
edit → service/repository/audit → Farmer Knowledge detail. Tests cover sourced and
empty metadata, reserved-class rejection, stale revisions, permissions, Healthy,
public projection, unchanged model class mapping and existing indexing behavior.

## Disease reference-image lifecycle (AUD-03)

Admin → reference-media form → single strict validated multipart upload → reserved
database intent → authenticated sanitized Cloudinary object → READY draft. Source
identity, license, contributor, attribution, alt text, rights confirmation, order
and content kind are required. Publication is a separate explicit reviewed action.
Production composition rejects SYNTHETIC_TEST publication; only the disposable
technical integration fixture injects permission for visibly labeled generated
rectangles after proving its owned schema. No dataset photograph is republished.

Farmer Knowledge detail → scoped Gallery ViewModel → media repository → Node list
and protected byte endpoint. Published source-backed library images are public
library content through the controlled Node delivery path; draft bytes require
ADMIN. This does not relax private scan/profile ownership or guest capabilities.
No Cloudinary URL/public ID is returned. Both paths use `private, no-store` and
metadata-free display bytes; no incompatible persistent public image cache is added.
UI provides source/license/credit, alt text, responsive cards and empty/error states.

Reordering and edits are revision-pinned/audited; provenance edits unpublish.
Replacement keeps the previous publication until the new draft is explicitly
published, then atomically retires/queues the old asset. Competing replacements
cannot publish against an already retired parent. Removal retires without waiting
for provider cleanup. `references:cleanup` safely claims only retired/stale reserved
assets, preserves uncertain/current objects and retries idempotently. Replacements
have a self-referential FK; immutable lineage/audits survive asset cleanup.

**No real approved reference image exists.** Technical upload/review/publication/
delivery/replacement/deletion/cleanup works with isolated generated fixtures, all
removed afterward. Empty real galleries are deliberate, not fake content. Real
publication requires an authorized reviewer to verify rights and disease identity.

## Generated Node OpenAPI (AUD-07)

`backend/openapi.json` is OpenAPI 3.1 covering all **59** registered business
operations. Runtime Zod request validators register their actual schemas; the
generator reconciles the mounted router and method/path/operation identity.
Shared response schemas are also checked by `sendSuccess`, including legacy
endpoints. Complex historical JSON snapshots retain module-specific validation;
the specification does not pretend to infer every JSON subfield automatically.

The spec includes bearer authentication, refresh cookie and CSRF/header semantics,
anonymous scan capabilities, roles, request/body/path/query schemas, multipart,
binary delivery, errors, pagination and enums. It contains no private values or
privileged live data. Automatic Express HEAD uses GET response validation.

```powershell
. ./scripts/use-project-node.ps1
npm --prefix backend run openapi:generate
npm --prefix backend run openapi:check
npm --prefix backend run openapi:serve
```

The last command serves only the JSON viewer at
`http://127.0.0.1:9090/openapi.json`, without remote references, scripts/CDNs or a
public application route. `npm run check` now validates the spec with the pinned
Swagger parser and checks generated drift. Tests reject missing request/response
contracts, unregistered documentation, duplicate operations and method/path drift.
Final contract review also tests FARMER-only bearer requirements for both analytics
routes and exact intent-header differences between profile/avatar/explanation/auth
operations. Future CI must invoke the existing `npm run check` gate, including OpenAPI.

## Calculator engineering and honest remaining domain gates

The existing deterministic `AREA_RATE_V1` product-mass calculator and
`AREA_TIMES_REVIEWED_YIELD_RATE_V1` conditional planning projection remain unchanged.
Exact decimal units, immutable rules/configs and source/version output remain.

Independent ADMIN fertilizer catalogue CRUD now supports sourced product
composition, optional type/stage/conditions/application reference text, review,
visibility, pagination and audit. Supplementary source metadata is stored as
immutable versioned KnowledgeDocuments marked PRODUCT_INFORMATION_ONLY; these
draft/archived documents are never indexed into disease RAG. Referenced product
content is frozen under the same advisory lock as rule creation; copy to a new
slug to revise it. Unreferenced edits require revision/source validation. No hard
delete can orphan historical rules. A text rate reference never enables a dose.

ADMIN agronomic-model intake stores immutable `model-intake.*` CalculatorConfigs
with an explicit source, applicability, assumptions, mathematical definition,
dimensioned input/output definitions and sourced coefficient definitions. Yield
contracts require minimum/expected/potential outputs; nutrient contracts require
nitrogen/phosphorus/potassium outputs. There is no arbitrary code/formula evaluator.
Every intake is DRAFT, PENDING_DOMAIN_APPROVAL and DISABLED, with no activation
endpoint; neither executable engine accepts its payload. Units and duplicate field
identities are validated. Fresh source review/version conflicts/audit are tested.

This completes source-intake/review/versioning engineering without guessing a
model. Actual N/P/K demand, soil-based selection, application schedules and
minimum/expected/potential yield forecasting are **not implemented numerical
outputs**. They require approved mathematical models, coefficients, applicability
and worked examples; exact model-dependent engine/UI implementation must follow
that approval. Merely activating one kg/ha rate cannot satisfy those requirements.
No synthetic catalogue/rule/model is enabled as a recommendation.

## API changes

All routes have the `/api/v1` prefix. Existing routes remain covered by OpenAPI.

| Method / path | Access / contract |
|---|---|
| GET `/admin/ai-operations` | ADMIN; UTC dates; metadata-only aggregates |
| POST `/admin/knowledge/diseases` | ADMIN; sourced informational catalogue creation |
| PATCH `/admin/knowledge/diseases/:slug` | Existing ADMIN edit, expanded optional reviewed metadata |
| GET `/diseases/:slug` | Existing public detail, added safe catalogue/applicability projection |
| GET `/diseases/:slug/images` | Public published reference metadata only |
| GET `/disease-images/:id/image` | Published reference bytes via Node; no provider redirect |
| GET `/admin/disease-images/:slug/items` | ADMIN draft/active/inactive metadata |
| GET `/admin/disease-images/:id/image` | ADMIN draft/reference bytes |
| POST `/admin/disease-images` | ADMIN multipart image + bounded JSON `metadata` |
| PATCH `/admin/disease-images/:id` | ADMIN reviewed metadata/order, expectedRevision |
| PATCH `/admin/disease-images/:id/status` | ADMIN reviewed publish/hide/retire, expectedRevision |
| GET/POST `/admin/calculators/model-specifications` | ADMIN non-executable versioned review intake |
| GET/POST `/admin/fertilizers` | ADMIN cursor-paginated source-backed product list/create |
| PATCH `/admin/fertilizers/:id` | ADMIN unreferenced product edit, expectedRevision |
| PATCH `/admin/fertilizers/:id/status` | ADMIN reviewed visibility, expectedRevision |

There are 15 added operations (44 → 59). Profile routes retain their wire shape;
their committed-response/cleanup semantics are corrected. No Flutter→FastAPI or
Flutter→Google shortcut exists.

## Database, security and preserved work

Five additive migrations extend the original nine: operational events, optional
catalogue metadata, reference lifecycle, a follow-up SQL NULL publication guard,
and reference replacement FK. Applied migrations are not rewritten. There are now
14 migrations, 22 application tables, 34 checks, 28 FKs and 38 custom triggers.
Schema/client, replay, rollback and drift checks are in the verification ledger.
No database reset, production role change, raw data deletion or destructive asset
operation occurred. The original nine migration bytes remain identical.

Argon2 bounds, JWT rotation/revocation, role/owner/capability checks, protected
delivery, metadata removal, TLS verification, production privilege rejection,
internal service auth, model hashes, RAG source integrity/injection/citation
checks and Flutter subprocess environment allowlists remain in force. New routes
use the same layers and safe errors. Monitoring failures cannot replace successful
farmer results. Retention is unchanged; cleanup applies only to obsolete owned
assets under existing/new durable journals.

The pre-existing `.gitignore`, ML README, dataset documentation and eight-line
PROJECT_STATE user addition remain intact and outside the remediation commit.
The shared state file is staged with only the Phase 24.6 prefix over committed
history. Actual private paths/credentials and the corrected ignored AI dotenv are
not staged. Model/manifest hashes are independently checked.

## Release boundary

Real licensed imagery, sourced stage/severity content, real calculator rates and
agronomic forecast models, confidence/field/calibration approval, commercial data
clearance, legacy asset decisions and privacy/retention acceptance remain external
gates. Production least-privilege roles, private networking/TLS, shared budgets,
cleanup scheduling/backups/CI/signing and device/browser release acceptance remain
separate deployment/release work. These are not proof that public deployment was
performed. Phase 25 and Phase 26 have not started.

## Final acceptance and exact next action

Phase 24.6 has not met the required uninterrupted normal-environment full-suite
acceptance. Diagnose the failed categories using safe connection/provider metadata,
resolve any confirmed application defect, and rerun the unchanged assertions in
`python scripts/check-e2e.py` after dependencies are stable. A focused pass or
union of passing categories from different runs cannot substitute for that gate.
Do not deploy or start Phase 25/26 on the basis of this handoff.

Separately obtain approved nutrient/forecast mathematical contracts and worked
cases before implementing their missing numerical engines/UI; verify licensed
reference content and reviewed applicability before publishing it. The review
framework does not itself deliver those agronomic outputs. All exact component,
live failure/skip and fixture cleanup results are in the verification ledger.
