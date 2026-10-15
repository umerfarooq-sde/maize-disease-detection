# Project state

Updated: 2026-10-15 (Asia/Karachi).

## Current phase

Phase 23.6 targeted remediation is complete for the two authorized farmer UI gaps.
Registration now follows form → route-scoped ViewModel → repository → existing Node
API → PostgreSQL, with FARMER-only enrollment, matching input checks, visibility,
safe retry and explicit sign-in after success. Existing session/refresh/logout
semantics are unchanged. Knowledge now browses the real four-entry catalogue,
performs explicit semantic passage search, and opens current versioned, sourced
details. Healthy renders only its four supported sections; other entries have seven.

Verification: 42 new targeted Flutter tests and the full 338-test Flutter suite pass;
12 default live checks are explicitly skipped, with the new live widget check enabled
and passing separately. All 299 backend tests and formatting/lint/strict types/build
pass; AI format/Ruff/mypy and 346 tests pass (three opt-in SQL skips). Prisma schema
validation passes. Android ARM64 debug packaging and 18 final Home/navigation tests
pass; repository/link/privacy checks and 171 frozen-file hashes pass. Evidence is in
the [Phase 23.6 report](phase-23-6-remediation-report.md).

Real widget proof `20261015T155340Z-ae2d48e8` drives registration/login, all four
details/25 source-backed documents, actual Google/pgvector semantic search, guest
access, refresh/logout, duplicate and ADMIN-injection rejection. The owned schema
was removed and all 21 production table counts are unchanged. An initial harness
tap/scroll failure is retained, followed by the passing corrected run. No physical
Android/emulator acceptance is claimed. Shared source presentation is reused by
assistant/library; shell keyboard space and bounded card previews pass layout tests.
The stale Home claim that disease analysis was unavailable is corrected.

**READY WITH NON-BLOCKING LIMITATIONS for separately authorized Phase 24.** The Phase
4 mobile registration handoff and missing Phase 6 farmer library are resolved, not
rebuilds of their working services. Phase 23.5 incorrectly left profile scope
unestablished: the original master brief explicitly asks for a customizable farmer
profile, Admin user management, audit viewing and disease-image management. Those
remain separately scheduled product gaps; do not mark all original requirements
complete or silently implement them here. Recommend profile customization and the
agreed Admin gaps before final FYP acceptance. Real calculator content, named Admin
enrollment and device QA also remain pre-demo work. See the report for source
evidence, extra implementation needed, priorities and Phase 24/25/26 boundaries.

No dataset, split, class mapping, preprocessing implementation/policy, checkpoint,
model registry, corpus, dependency, schema or migration is changed. No raw dataset
is opened, training/test scoring repeated, model promoted or user data reset.
Pre-existing user workspace edits are preserved and excluded from the commit.
Stop after Phase 23.6; Phase 24 has not started.

## Historical Phase 23.5 checkpoint (superseded above)

Phase 23.5 completeness audit is complete. **NOT READY FOR PHASE 24.** Actual code
still lacks farmer registration UI and the farmer disease-knowledge library; the
corresponding APIs and real knowledge already exist. Complete these earlier-phase
Flutter handoffs in a separately requested remediation scope before security hardening.
Do not treat green test suites as complete user-facing features.

Fresh verification passes 299 backend, 346 AI (three opt-in SQL skips), 296 Flutter
(11 default live skips), 219 ML fixture and 78 shared tests in each Python environment,
plus 12 synthetic parity cases, Prisma/client/13 DB checks/eight applied migrations
and no schema diff. Android ARM64 debug APK builds. Readonly live probes confirm
PostgreSQL/pgvector, all four sourced class retrievals, actual grounded Gemini,
Cloudinary credentials, the pinned model and actual Node/FastAPI/Gemini plus native
Flutter health. No Android emulator/phone acceptance is claimed.

All 8,040 source files freshly match original byte hashes/sizes/mtimes; v2 content/
group split intersections are zero. The selected research model is unchanged and
unpromoted. No real classifier fitting or final-test evaluation was repeated.
The audit fixes only cwd-dependent harness import sorting, stale Tools copy and
stale current architecture language. AI checks and affected Flutter checks pass.

Fertilizer/yield frameworks are connected but contain no real approved rates/model
configuration. This authorized pending-content fallback does not itself block
security work after coding remediation; it does block complete recommendation
claims at the FYP demo. No additional user resource is needed to implement the two
missing UIs. Real domain approval, named Admin provisioning and physical-device
acceptance are separate pre-demo actions; security/deployment/QA work remains in
Phases 24/25/26. No Phase 24 begins automatically. Read the
[complete audit](phase-23-5-completeness-audit.md),
[35-endpoint inventory](phase-23-5-endpoint-inventory.md) and
[70-entry configuration inventory](phase-23-5-configuration-inventory.md).

The preceding Phase 23 record follows.

Phase 23 verification is complete, with the acceptance limits below. Component checks pass:
299 backend tests, 346 AI tests (three default opt-in SQL skips), 296 Flutter tests
(eleven default opt-in skips), 219 ML-tooling fixture tests and 78 shared preprocessing
tests in each Python environment. Twelve synthetic preprocessing parity cases and
all 56 Node/shared image-admission cases pass. Android debug APK packaging, Prisma
schema/client checks and migration status, repository and Compose validation pass.

A new connected Flutter/API/MVVM farmer/Admin journey passes registration, login,
real Cloudinary upload and pinned-model inference, private history/detail, source-
grounded AI, synthetic fertilizer/yield calculations, farmer/Admin statistics,
immutable knowledge version edits with real Google indexing, model health, cookie
refresh and logout. The test uses a disposable schema, generated accounts/images,
and existing source-backed knowledge. Its owned cloud asset was removed, its schema
dropped, and all 21 production application-table counts are unchanged.

Verification is not a claim that every planned product screen is implemented:
farmer registration has an API but no registration screen; the farmer Knowledge tab
is still a placeholder; real agronomic calculator content awaits approved sources.
No Android device/emulator is connected, so camera/permissions and physical device
acceptance remain unverified. Synthetic scans measure integration, not accuracy.
Read the [Phase 23 test matrix](39-testing-e2e-verification.md).

Early harness/schema/preload failures and a database connection timeout are recorded.
One live generation check abstained on a Healthy scouting question where the test
expected GROUNDED; that failure is retained and all nine focused generation tests
passed on recheck. A later management search returned 503; a separate complete
management/Flutter recheck passed. Provider/grounding variability remains a risk.
Disk exhaustion caused Flutter compilation failures and an Admin analytics timeout;
generated outputs were cleaned and the affected checks rerun. Recovery removed
only verified abandoned test schemas; the original broad run's final count
comparison is unavailable, while recovery and successful runs verify unchanged counts.
Verification found and fixed a real model-health P2028 transaction-start failure:
its acquisition wait now matches the existing ten-second pool/analytics bound.
Both the actual read-only model/Flutter contract and full backend checks pass.
No model, preprocessing, schema, source corpus, provider setting or business feature
is changed. No real classifier training, final-test rerun or promotion.
Stop after Phase 23.

The preceding Phase 22 is complete and verified for the Admin ML model-health dashboard.
`/admin/model-health` shows safe registry promotion/status separately from actual
loaded-model readiness, pinned offline test/per-class/confusion-matrix evidence,
and process-local runtime requests/failures/latency/uncertainty/output counts.
No production model is promoted. The configured research classifier remains
`mobilenet-v3-small-v2-20261009`; saved final-test accuracy is 95.8333% on 624 unique
contents, with the existing inspected-corpus/field-independence limitations.
Training time is absent from the artifact and is explicitly not recorded;
registration time is not relabeled as training time.

The internal protected FastAPI dashboard projects already SHA-verified metadata
once at startup. No offline metric is recalculated from user scans or a new test
pass. The same shared preprocessing/model/class mapping remains intact. Runtime
counters are fixed-size, thread-safe and lifespan-local: restart resets them,
auth/query rejection is excluded, and no cluster-wide/durable history is claimed.
No validation-approved confidence threshold exists, so the UI explains all outputs
being LOW_CONFIDENCE. There is no ground-truth feedback or formal drift detection.
Read [model health](38-model-health-dashboard.md).

Verification: 296 backend tests and 296 Flutter tests pass (ten live contracts
are default-skipped). 346 AI tests pass (three opt-in database checks default-skip). Formatting,
lint, strict TypeScript/build, analyzer, Ruff/mypy and Prisma checks pass; eight
migrations remain current. The enabled read-only registry ? real pinned FastAPI
model ? Node ? Flutter contract passes. Only synthetic image bytes are inferred;
no raw dataset, model/metric/account/scan write, training, test rerun or promotion.
Existing unrelated workspace changes are preserved. Stop after Phase 22.

The preceding Phase 21 is complete and verified for Admin management. `/admin/manage` provides
validated disease display/visibility edits, source-backed immutable knowledge
versions, explicit indexing and confirmed activation/archive, plus fertilizer/yield
rule forms through the existing versioned calculator services. All management
routes require ADMIN; Farmer/guest/revoked access is denied. Model class labels,
slugs, artifacts and calculator algorithms remain fixed. Read
[Admin management](37-admin-management.md).

New knowledge drafts use the shared Python canonical text/chunker/Google embedder.
Provider failure cannot publish a draft. Activation rechecks current index policy,
then atomically retires the prior active document/source and records audit lineage.
Historical chunks/citations remain immutable and archived vectors are excluded.
Generation admits current explicitly reviewed Admin versions through the same
content/hash/source/offset/coverage checks, retaining pinned original identities.

Checks pass 292 backend tests, 291 Flutter tests (nine live checks default-skip)
and 336 AI tests (three opt-in database checks default-skip), plus formatting/lint,
strict types/build, Flutter analysis, Ruff/mypy and Prisma validation. The enabled
real Flutter → Node → FastAPI → Google/pgvector/Gemini management contract passes
versions, rebuild/publication/retirement, visibility/CAS, audits and calculator
management in a disposable schema. Cleanup verifies production counts unchanged.
All eight migrations remain current; no schema/dependency/ML/shared-preprocessing
or classifier artifact change occurs. Stop after Phase 21.

The preceding Phase 20 is complete and verified for the Admin dashboard. ADMIN-only
`GET /api/v1/admin/dashboard` returns real PostgreSQL account/status/ownership/
latest-prediction/time/distribution aggregates and ten minimal recent scan entries.
Flutter `/admin` sits outside farmer navigation with independent volatile Admin
sign-in/cookies/tokens, shared tested refresh/revocation mechanics, scoped MVVM,
responsive cards/charts and loading/retry/empty states. Farmer access is denied.
Read [Admin dashboard](36-admin-dashboard.md).

Registered production models and configured research inference versions are
distinct. Missing/multiple production rows are explicit; live readiness remains
NOT_CHECKED. The current assistant does not record AI request telemetry, so the
dashboard reports those statistics unavailable. No model performance, field-health
or disease-prevalence claim is inferred from user predictions. No model is promoted.

Checks pass 286 backend tests, 282 Flutter tests (eight opt-in live contracts skip
by default), format/lint/strict TypeScript/build and Flutter analysis. The enabled
real PostgreSQL/Node/Flutter Admin contract verifies global counts, Farmer denial,
filters, sign-in/logout and rollback. Prisma validates; all eight migrations remain
current. No schema, dependencies, AI, corpus, ML/shared-preprocessing or model
artifacts are changed. Stop after Phase 20.

The preceding Phase 19 is complete and verified for private farmer analytics. Node exposes
owner-filtered scan summary/activity endpoints with bounded UTC dates, one SQL
aggregate, deterministic latest-per-completed-scan counting and private pagination.
Anonymous ownership remains null. Flutter Profile → Field insights uses scoped
MVVM/Provider, responsive cards/charts, filters, loading/retry/empty states and
account-revision fencing. These are usage and prediction statistics, not measured
model accuracy, field health or disease prevalence. Read
[farmer analytics](35-farmer-analytics.md).

Backend checks pass all 278 tests; Flutter checks pass 270 tests with seven opt-in
live contracts skipped by default. The separately enabled real PostgreSQL/Node/
Flutter analytics contract passes aggregate/ownership/UTC/microsecond pagination
and query-plan checks with all synthetic writes rolled back. Prisma validates and
all eight migrations remain current. No schema, dependency, ML/shared-preprocessing,
AI/corpus or model artifact changes are required. Stop after Phase 19.

The preceding Phase 18 is complete and verified for the authorized expected-yield framework scope.
No authoritative project yield formula or applicable rate exists, so **real agronomic
configuration remains pending** and the production YIELD catalogue is empty. The
implemented template performs dimensional area scaling of a future explicitly reviewed
kg/ha scenario; it does not invent an agronomic forecast, coefficients, default rate,
soil/weather/loss/population inputs or a harvest guarantee. Gemini is absent from
the calculation and explanation flow. Read [expected yield](34-expected-yield-calculator.md).

Node adds public configuration/calculation endpoints and controlled ADMIN immutable
draft/publication/audit support using existing YIELD calculator records. One shared
exact-decimal/unit implementation now serves both calculators; fertilizer's API and
kg/gram behavior are preserved. Flutter Tools → Yield uses route-scoped MVVM with
shared area/unit form components, source/applicability/assumption review, exact
server kg/metric-tonne results, versions, loading/error/retry and stale-result fencing.
Pending configuration disables calculation without blocking input editing.

Verification passes 266 backend tests, 249 Flutter tests (six opt-in live tests skip
by default), analyzer/format/lint/strict TypeScript/build and Prisma validation.
Enabled real Flutter → Node → Prisma → PostgreSQL contracts pass for both yield
and fertilizer. Synthetic accounts/configurations/sessions/audits/rules remain in
private rollback transactions; production yield and fertilizer configuration counts
remain zero. All eight migrations are current; no migration or dependency was added.
Frozen ML/preprocessing/AI/corpus/schema and unrelated user edits remain unchanged.
Stop after Phase 18.

The preceding Phase 17 is complete and verified for the authorized calculator foundation scope.
Node provides an exact decimal fertilizer product-area-rate engine, explicit
international-acre/hectare and kg/gram conversion, one final configurable HALF_UP
rounding, version-pinned input, reviewed source/assumption provenance and controlled
ADMIN draft/publication/audit support. Flutter Tools → Fertilizer uses route-scoped
MVVM with input editing, pending content, loading/retry/error, stale-rule refresh
and unchanged server quantity/source/version display. Gemini performs no calculation.
**Real recommendation content remains pending:** the configured database has zero
fertilizer products, rules or fertilizer configurations. No agronomic dosage is
invented, seeded or inferred. An authorized reviewer must supply authoritative
product/rate sources and deliberately publish compatible versions before farmers
receive recommendations. Read [fertilizer calculator](33-fertilizer-calculator.md).

Verification passes 239 backend tests, 221 isolated Flutter tests, five PostgreSQL
guard/snapshot checks and the separately enabled real Flutter → Node → Prisma →
PostgreSQL calculator contract. Four existing live tests plus the new calculator
live test are opt-in/default-skipped. Final lint/format/strict TypeScript/build and
Flutter analyzer pass; Prisma validates and all eight existing migrations are current.
Synthetic ADMIN/farmer/rule/config/audit fixtures are isolated inside a private
rolled-back transaction; production recommendation counts remain zero. No AI/provider,
Cloudinary or raw dataset request is made. Stop after Phase 17.

The preceding Phase 16 is complete and verified. Flutter provides the farmer assistant with
reviewed cited answers, explicit disease/topic focus, safe loading/retry/error and
low-confidence notices, private paginated scan selection and result-to-assistant
navigation. The route-local conversation keeps at most 12 volatile turns; previous
messages are never sent as a transcript or saved under an account. Guest knowledge
questions and authenticated farmer scan history remain intentionally separate.
Account changes clear the chat, draft and selected scan and fence delayed responses.
Read [farmer AI assistant](32-farmer-ai-assistant.md).

Verification passes 175 isolated Flutter tests (four opt-in tests skipped by default),
202 backend tests and 325 AI tests (three opt-in database tests skipped by default).
The separately enabled real Flutter -> Node -> FastAPI -> Google/pgvector/Gemini
contract passes grounded questions/follow-ups, citations, unsupported/injected/long
input, absent Healthy knowledge, owned scan explanation and foreign-farmer denial.
Temporary fixture accounts/scan/prediction/journal are removed. Gemini initially
returned 503 and later recovered; the successful check uses the unchanged configured
generation model, without automatic fallback. Stop after Phase 16.

The preceding Phase 15 is complete and verified. Node exposes grounded knowledge questions and
ownership-protected scan explanations through authenticated FastAPI retrieval and
Gemini. The official `google-genai` SDK is locked to 2.29.0; the configured local
generation model is `gemini-3.5-flash-lite`. Gemini selects reviewed evidence;
the server returns complete verified corpus excerpts with document/chunk/source
citations, honest abstention and unchanged classifier scores/uncertainty.
Read [grounded generation](31-grounded-generation.md).

All four class answers, unrelated/missing Healthy evidence, anonymous capabilities,
farmer ownership and unchanged LOW_CONFIDENCE context pass the real-provider contract.
Six representative FastAPI retrieval-plus-generation calls average **4,937.62 ms**
locally (3,891.36–6,694.37 ms), excluding Node authorization/network overhead.
This is development contract evidence, not agronomic/field validation, exhaustive
semantic safety or a production load benchmark. Sources retain regional/freshness
limits; generation is independently opt-in and server-only. Phase 16 supplies the
Flutter assistant UI. Conversation retention and new migrations remain deferred.

The preceding Phase 14 is complete and verified. The skipped Phase 6 foundation had empty
knowledge tables and no
knowledge APIs; it is now completed for this scope. Twenty-five reviewed source-backed
documents, four catalogue entries and four sources are persisted with 25 READY
768-dimensional Google embeddings. Identical live re-ingestion leaves all 25 unchanged.
Public disease reads and Node-orchestrated internal FastAPI semantic search are available.
Documents/source/config/chunk lineage remain versioned and READY embeddings immutable.
Read [knowledge/retrieval](30-knowledge-retrieval.md).

Real-provider evaluation passes 16/16 positive expected-document top-three hits both
with filters and across the full corpus; three unsupported Healthy sections return
empty. Mean retrieval is 3,899.32 ms locally. This is a small development relevance
check, not independent agronomic validation. Retrieval results remain evidence
candidates; Phase 15 applies the separately documented reviewed-excerpt admission
policy. Flutter knowledge UI and full admin editing remain deferred.

Phase 13 remains complete and verified.
Flutter now completes image selection/preview, upload/progress, real model results
with honest uncertainty and private paginated farmer history/detail. Minimal native
farmer login/logout and serialized refresh use volatile credentials only; guests
remain anonymous without personal history. Ownership and stale-session privacy are
verified by API, PostgreSQL, widget and live contract tests. Read
[farmer detection/history](29-farmer-detection-history.md).

The preceding Phase 12 integration remains intact.
Node preserves the upload/Cloudinary journal and invokes authenticated FastAPI with
unchanged image bytes. Validated predictions are persisted transactionally with
immutable model/preprocessing identity, explicit uncertainty and inference timing.
Owned/private-key GET, safe retries and stale-attempt recovery are implemented;
Flutter handles the public lifecycle without calling FastAPI.
Read [integration contracts](28-node-fastapi-integration.md) and
[artifact/serving contracts](27-production-ml-inference.md).

The Phase 10.5 candidate remains **FIT WITH DOCUMENTED LIMITATIONS** for a local FYP
research inference prototype. The original v1 scoring arithmetic is preserved, but
confirmed transformed-parent leakage invalidates its independent-evaluation claim.
The corrected v2 index and fresh model are verified; all 8,040 original files remain
unchanged. The new evaluation is descriptive on a previously inspected corpus,
without independent field/plant validation or commercial clearance.

Selected model version `mobilenet-v3-small-v2-20261009`, experiment
`mobilenet-v3-small-20261009-v2-01`, checkpoint `checkpoints/epoch-008.pt`,
SHA-256 `e95a2e83262637fc1a08b919e6003bddb2fe70664b9c51418f059b7c8287dc66`.
The completed run stops at epoch 11 under patience 3, out of 12 maximum. Validation:
**96.81% accuracy / 0.9589 macro F1**. One post-freeze final test: **95.83% / 0.9452**,
598 correct of 624. Test Gray Leaf Spot recall is **83.53%**, F1 **0.8659**. These are
internal benchmark scores, not measured farmer-field accuracy. Calibration remains
disabled (`T=1`): group cross-fitting worsens NLL/Brier/ECE. No confidence threshold
is locked; current serving explicitly returns `LOW_CONFIDENCE/THRESHOLD_UNCONFIGURED`
with a null threshold. Read [the fitness report](26-model-fitness-validation.md) and
[safe numerical/artifact evidence](../ml-training/reports/mobilenet-v3-small-20261009-v2-01-fitness/README.md).

The preceding Phase 0–9 audit verified 77 checked-in backend cases, a live farmer
WebP/auth lifecycle probe, five migration replay/checksum checks, 52 isolated Flutter
tests plus both live health/upload tests, and a debug Android APK. The AI suite has
50 passing tests, then five training tests, shared preprocessing 78 in each independent environment
and eight exact cross-environment parity cases. Actual FastAPI startup/shutdown and
six supplemental synthetic scenes pass. Real Cloudinary JPEG/PNG/WebP uploads and
nullable/actual farmer ownership are verified. Every audit-created row/asset was removed;
database counts/catalog/checksums match the pre-audit snapshot. Formatting/lint/types/
build/locked dependencies, repository/template/ignore/links and source-secret checks pass.

Both Python environments import the same `maizedoctor_preprocessing` 1.0.0 package.
Phase 9.5 runs both policies on all 8,040 images and verifies 160 real consumer parity
cases. Review of 81 filenames/78 contents found no obvious preprocessing-caused tissue
loss, without ground-truth lesion masks or classification accuracy. Conservative
extraction falls back for 8,021 of 8,029 accepted files; full-frame is approved for
the first baseline. Generic package defaults/version remain unchanged; Phase 10 pins
224×224/ImageNet settings in its artifact configuration. A reproduced Node/
shared image-admission mismatch, four existing high npm aggregate advisory entries,
native mobile refresh-cookie integration and deployment/platform limitations are recorded.
The recovered backend database client matches HEAD and works. Phase 6 was explicitly
skipped during that audit; Phase 14 completes the missing retrieval foundation.
Phase 9.5 added configured read-only intake; the subsequent approved exclusions,
use restrictions, full-frame policy and Phase 10 baseline are recorded in DECISIONS.md.
Stop after Phase 16; persistent mobile sessions, calculators and full admin
functionality remain deferred.

## Initial workspace findings

- Git was already initialized at `E:\MAIZEDOCTOR`, on `main`, one commit ahead of
  the local `origin/main` reference. No network fetch was performed.
- All seven root directories required by `AGENTS.md` existed; component directories were empty.
- `README.md` was a placeholder and `.gitignore` covered basic environment, Python,
  Node, and editor files.
- Thirteen architecture drafts already existed under `docs/` as untracked files.
- `docs/PROJECT_STATE.md` existed but was empty.
- `AGENTS.md` had pre-existing local changes. Its contents and the architecture drafts
  were preserved. No commits, pushes, or dependency installations were performed.

## Phase 0 changes

- Replaced the root README placeholder with project scope, architecture, directory
  links, configuration guidance, checks, and the next phase boundary.
- Added a documentation index and the phased development roadmap.
- Added component README files so all planned directories persist in Git.
- Added environment examples for backend, AI service, infrastructure, and public
  mobile configuration. Credential placeholders are blank; no environment loader exists.
- Expanded centralized ignore rules for secrets, generated Flutter/Python/Node
  output, local datasets/model binaries, uploads, and infrastructure data.
- Added a read-only PowerShell check for structure, templates, Git root, and ignore rules.

## Current implementation inventory

| Component | Verified implementation |
|---|---|
| Mobile | Flutter 3.41.9/Dart 3.11.5, farmer MVVM workflows/assistant/calculators/private analytics; separate volatile Admin sign-in, dashboard, model-health/offline-runtime view and knowledge/configuration forms with source review, rebuild, confirmed publication, validation and session fences; 296 isolated tests, eleven opt-in live tests; actual management/statistics contracts pass; prior Android debug APK packaging verified |
| Backend | Health/auth/scans/history, sourced knowledge/retrieval/generation, deterministic versioned fertilizer/yield frameworks, Farmer analytics and ADMIN dashboard/management/model health; optimistic display edits, immutable reviewed drafts, index orchestration and audited source/version publication; Prisma 7.10.0, 21 tables/eight unchanged migrations, 299 isolated tests; real isolated-schema management and rollback contracts verified |
| AI service | Once-loaded classifier with pinned development metrics, protected health dashboard and lifespan runtime counters; shared preprocessing unchanged; reviewed pgvector retrieval, protected Admin prepare/index/check with existing chunker/Google provider, official Gemini verified evidence selection and request-local reviewed Admin context alongside pinned originals; 346 isolated tests, three opt-in PostgreSQL checks; Ruff/strict mypy; 76 targeted generation/management regression cases pass; factory remains free of heavy provider/model imports |
| Shared preprocessing | One independently buildable typed package at `shared/preprocessing`, version 1.0.0, explicit JSON configuration, file/byte entrypoints, conservative extraction/fallback, optional unchanged CPU tensor and debug CLI; 78 tests pass in each consumer environment and 12 synthetic baseline parity cases pass |
| ML training | Corrected immutable v2: 4,162 contents/4,121 groups, 2,911/627/624 partitions, no confirmed leakage; fresh MobileNetV3 Small completed 11 epochs, best epoch 8; validation 96.81% accuracy/0.9589 macro F1, single descriptive test 95.83%/0.9452; raw probabilities, no threshold; 219 tests, Ruff over 32 files, mypy over 15 modules and 16 actual TRAIN cases with AI compatibility pass; limited FYP prototype |
| Infrastructure | Neon PostgreSQL 18.6 with pgvector 0.8.6 migrated; pgvector 0.8.7/PostgreSQL 18 Compose configuration; preserved native 18.4 cluster; private local settings ignored |
| Verification | Phase 23 component, SQL/provider, cross-service and connected Flutter/API/MVVM matrices; isolated schemas, actual cloud/provider calls and explicit UI/device/content gaps |
| Documentation | Architecture, database/operations, auth, Flutter foundation, scan uploads/recovery, FastAPI startup/contracts/network, shared preprocessing/configuration/versioning/limitations, decisions, roadmap and verification history |
| Scripts | Repository/environment/auth/admin/PostgreSQL/Python/development checks including shared preprocessing/parity; configured FastAPI startup and 16-TRAIN serving parity/timing verifier; live Flutter scan/assistant/calculator and Farmer/Admin statistics harnesses, rollback/query-plan checks and backend cleanup CLI |

Persistent/browser mobile authentication, conversation retention, authoritative
calculator formula/rate content, notification delivery, distributed durable ML telemetry and ground-truth feedback
remain future work. Deterministic calculator frameworks, Admin knowledge/
configuration management and the real-data Admin overview are implemented. FastAPI
exposes internal prediction/model health, retrieval and grounded generation
alongside process health. The overview retains its inexpensive NOT_CHECKED summary;
the dedicated Admin model-health route now probes live readiness and process statistics.

## Phase 0 verification history

| Check | Result |
|---|---|
| PowerShell repository check | Passed: required nonempty files, seven directories, template keys, blank credentials, correct Git root, and ignore behavior |
| Directory comparison with `AGENTS.md` | Passed: all seven required root directories match |
| Local Markdown links | Passed: 48 links resolve |
| Component file inventory | Passed: README files and environment examples only; no feature source |
| `git diff --check` | Passed; Git emitted line-ending conversion notices |
| Final file/status inspection | Phase 0 changes present; original `AGENTS.md` changes and architecture drafts preserved |

Application tests are not applicable because no application source exists. No external
services, dependencies, data, or models were required or verified.

Commands/checks performed:

- `Get-Content AGENTS.md` before workspace inspection; read existing README, ignore
  rules, state file, and all architecture drafts before changes.
- `Get-ChildItem -Force`, `rg --files --hidden -g '!.git'`, and component file inspection.
- `git --version` (2.52.0.windows.1), `git rev-parse --show-toplevel`,
  `git status --short --branch`, `git log -1`, and `git diff --stat`.
- `./scripts/check-repository.ps1` initially blocked by Windows execution policy;
  `powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/check-repository.ps1`
  passed after correcting Windows CRLF handling in the Git probe invocation.
- `git check-ignore --no-index` checks for secrets/build outputs and source/template visibility.
- PowerShell validation of local Markdown links and directory names against `AGENTS.md`.
- `git diff --check`; final nonempty-file, whitespace, and file inventory checks.

## Files created during Phase 0

- `mobile/README.md`, `mobile/.env.example`
- `backend/README.md`, `backend/.env.example`
- `ai-service/README.md`, `ai-service/.env.example`
- `ml-training/README.md`
- `infrastructure/README.md`, `infrastructure/.env.example`
- `scripts/README.md`, `scripts/check-repository.ps1`
- `docs/README.md`, `docs/14-roadmap.md`

Updated existing files: `README.md`, `.gitignore`, and `docs/PROJECT_STATE.md`.
No root directory or Git initialization was necessary because they already existed.

## Phase 0 open issues and decisions (historical)

- No blocking Phase 0 issues remain. Windows disables direct script execution;
  the documented process-only override runs checks without changing persistent policy.
- Git has `core.autocrlf=true` and reports LF-to-CRLF conversion notices; whitespace
  checks pass. Existing Git configuration was preserved.
- Toolchain/dependency versions, PostgreSQL setup, and pgvector support are not selected.
- Database ERD and Prisma schema are still pending; existing designs are drafts.
- Shared preprocessing package location/version contract must be settled before ML code.
- Actual dataset, disease classes, curated agricultural sources, calculator rules,
  credentials, and model artifacts have not been supplied.
- Hosting, scan retention, confidence handling, detailed API contracts, and the
  Flutter screen map/design system remain future work.

These are later-phase inputs and decisions, not implemented behavior.

## Phase 1 changes and toolchains

- Node.js 24.12.0 / npm 11.6.2; TypeScript 7.0.2 with strict NodeNext compilation.
  Express 5.2.1, Zod 4.6.5, dotenv 18.0.5, and pg 8.23.1 are locked.
- Flutter 3.41.9 / Dart 3.11.5 Android scaffold; Provider 6.1.5+1 and dependency lock.
- Python 3.11.0 with uv 0.12.23; separate AI and training `.venv` environments and
  lockfiles. Windows CPU torch 2.10.0+cpu and torchvision 0.25.0+cpu match across both.
- Locked AI dependencies include FastAPI 0.142.2 and Uvicorn 0.54.0; shared image
  dependencies include NumPy 2.4.6 and OpenCV 4.13.0.92 (standard package on Windows,
  matching headless package on Linux). Training includes scikit-learn 1.8.0 and
  SciPy 1.17.1. Both use pytest 9.1.1.
- PostgreSQL 18.4 native development cluster at `infrastructure/data/postgres`,
  listening on localhost port 5433. The existing system service on 5432 was preserved.
- PostgreSQL-only Compose image `postgres:18.4-bookworm`, named persistent volume,
  localhost binding, and healthcheck. Official portable Compose 5.6.0 downloaded
  to ignored `.cache/tools` and SHA256 checked against the release checksum.
- Generated ignored local `.env` files with random database credentials without
  printing credentials. Provider/JWT secrets remain blank and unused.
- Interrupted scientific-library downloads were resolved by pinning stable versions
  and reusing existing wheel archives only after comparing their SHA256 to the registry
  hashes in the committed locks. Wheels were installed into separate project virtual
  environments; global site-packages remain disabled.
- Installed the missing official Android command-line tools into the existing SDK
  after SHA256 verification. Existing SDK packages/licenses were preserved; no
  outstanding license agreement was accepted automatically.
- Development guide, component README updates, script commands, and roadmap scope
  clarification added. No commits, pushes, model downloads, or dataset operations.

## Phase 1 files created

- Backend: `package.json`, `package-lock.json`, `tsconfig.json`, `.node-version`,
  `src/environment-check.ts`, `src/database-check.ts`.
- Python components: each has `pyproject.toml`, `uv.lock`, `.python-version`,
  and `tests/test_environment.py`.
- Mobile: `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `.flutter-version`,
  `.metadata`, `.gitignore`, `lib/main.dart`, `test/environment_test.dart`, and generated
  Android Gradle/Kotlin/manifest/resource configuration including `android/.gitignore`.
- Infrastructure: `compose.yaml`.
- Scripts: `initialize-dev-env.ps1`, `postgres-local.ps1`, `setup-python.ps1`,
  `check-development.ps1`, `requirements-tools.txt`.
- Documentation: `docs/15-development-environment.md`.
- Ignored local artifacts: `.cache/`, component Python virtual environments,
  `backend/node_modules`, compiled output, Flutter-generated caches, local `.env`
  files, and PostgreSQL data/logs. These are not source files to commit.

Updated root/component README files, `.gitignore`, `infrastructure/.env.example`,
`backend/.env.example`, `scripts/check-repository.ps1`, documentation index/roadmap,
and this state file. The system overview status now links to current project state;
architecture content and existing `AGENTS.md` edits were preserved.

## Phase 1 verification

- Passed: strict TypeScript typecheck, emitted compilation, and compiled dependency probe.
- Passed: Flutter analyzer (no issues) and one scaffold widget test.
- Passed: authenticated PostgreSQL 18.4 connection and temporary-table SQL round trip;
  all probe writes rolled back.
- Passed: actual Compose schema/interpolation validation with official Compose 5.6.0;
  blank required credentials are rejected.
- Passed: all PowerShell scripts parse; both uv locks match their manifests; rerunning
  local environment initialization preserves existing files; repository structure,
  ignore rules, 58 local Markdown links, and source/configuration whitespace checks.
- Passed: three AI environment tests and four ML environment tests; imports, ASGI
  request handling, image codecs, CPU tensor/autograd, compiled torchvision operators,
  and scikit-learn metrics verified without project data or model weights.
- Passed: `uv pip check` in both environments and lockfile consistency checks.
- The AI smoke test uses HTTPX ASGI transport, avoiding the new Starlette test-client
  deprecation warning without adding another HTTP client dependency.
- `flutter doctor -v`: SDK and Android command-line tools are available after repair;
  some Android SDK licenses remain unaccepted. Android packaging is not verified.

Commands include `npm.cmd install`, `npm.cmd run check`, `npm.cmd run check:database`,
`flutter create --empty --platforms=android --no-pub`, `flutter pub get`, `flutter analyze`,
`flutter test`, `flutter doctor -v`, uv lock/sync, the development scripts, official
Compose download/SHA256 comparison, cached-wheel hash validation/offline installation,
Python module compilation/pytest/import checks, `uv pip check`, `git diff --check`,
PowerShell syntax and environment-idempotence checks, and repository inspection.
Dependency downloads, Flutter SDK cache writes, and native database startup required
approved execution outside the sandbox, as did installing the missing Android SDK tools.
Persistent OS policy and existing services were not changed.

## Phase 2 changes

- Read `AGENTS.md`, this state file, the database architecture draft, and relevant LLD,
  API, ML, and RAG documentation before implementation; inspected existing workspace and dependencies.
- Installed and locked stable Prisma/client/PostgreSQL adapter 7.10.0 and tsx 4.23.15.
  Prisma 8 was a release candidate, so no major-version prerelease was adopted.
- Implemented all **19** requested application tables: users, farmer_profiles, diseases,
  disease_images, disease_sources, scans, scan_predictions, knowledge_documents,
  knowledge_chunks, fertilizers, fertilizer_rules, calculator_configs, model_versions,
  model_metrics, ai_queries, ai_responses, audit_logs, notifications, and history.
  `_prisma_migrations` is Prisma's additional internal bookkeeping table.
- Added UUID defaults, snake-case SQL mappings, timezone-aware timestamps, lifecycle
  enums, FK/delete policies, ownership composite keys, uniqueness, and lookup indexes.
  Anonymous scans keep nullable immutable ownership; authenticated scan/history ownership
  requires a farmer and cross-farmer/anonymous history links are rejected.
- Added 19 SQL CHECK constraints, four partial unique indexes, and 33 custom triggers
  for values, source/content hashes, vector dimensions, model class mapping, ownership,
  immutable records/versions, and database-side timestamp updates.
- Enabled pgvector in `public`; nullable chunk embeddings retain model/dimension/status
  metadata. Production embedding dimensions, distance/index choice, and retrieval remain pending.
- Created atomic initial and corrective migrations. Integration tests caught null trigger
  arguments bypassing immutable-event checks; a second migration fixed the function without
  modifying the checksum of the applied initial migration.
- Kept all seed groups empty until reviewed records are supplied. Idempotent upserts
  preserve existing and versioned data; no default credentials or invented agricultural facts.
- Preserved the user's existing pooled Neon `DATABASE_URL`. Added an equivalent ignored
  `DIRECT_DATABASE_URL` for migration/introspection/replay sessions and a blank template key.
  Migrations target the configured Neon development database, not the Phase 1 native cluster.
- Changed PostgreSQL-only Compose to the pgvector maintainer's `0.8.7-pg18-bookworm`
  image because the initial schema now requires the vector extension. No app containers added.
- Updated schema documentation/ERD, operations guide, root/component documentation,
  environment checks, source ignore rules, and the roadmap's explicit Phase 2 scope.
  Existing `AGENTS.md` edits and Git history were preserved; no commits or pushes.

## Phase 2 files created

- `backend/prisma.config.ts`
- `backend/prisma/schema.prisma`
- `backend/prisma/migrations/migration_lock.toml`
- `backend/prisma/migrations/20261005000000_initial_schema/migration.sql`
- `backend/prisma/migrations/20261005010000_enforce_immutable_records/migration.sql`
- `backend/prisma/seed.ts`, `backend/prisma/seed-data.ts`
- `backend/tsconfig.database.json`
- `backend/src/database/client.ts`
- `backend/tests/database-support.ts`
- `backend/tests/database.integration.test.ts`
- `backend/tests/migration-replay.ts`
- `docs/16-database-operations.md`

Updated `.gitignore`, root/backend/infrastructure/scripts README files,
backend `package.json`/lock, `.env.example`, SQL probe, infrastructure Compose,
repository/development check scripts, database design, docs index/roadmap/development
guide, and this state file. Generated Prisma source and compiled output are ignored.
Private `.env` changes and one-off diagnostic helpers under `.cache/` are local artifacts.

## Phase 2 verification

| Check | Result |
|---|---|
| Prisma format/validate/generate | Passed with all 19 requested models |
| Strict TypeScript config/source/seed/test check and emitted build | Passed; compiled dependency probe passes |
| Initial and corrective migrations | Applied successfully to the configured Neon PostgreSQL 18.6 database |
| Migration replay | Both committed SQL migrations replay in an isolated schema with 19 tables/19 checks/33 triggers; schema removed afterward |
| Repeat migration deploy | Passed: no pending migrations; no reset/data replacement |
| Migration status | Passed: both migrations applied, schema up to date |
| Structural Prisma diff | Passed: no difference; custom SQL additionally verified by integration/catalog checks |
| Database integration | Passed: 12 tests, including all model round trips, invalid values, ownership, versioning, vectors, timestamps, immutable payloads, and FK deletion policies |
| Seed repeatability | Passed twice with empty reviewed-data groups; existing records preserved |
| PostgreSQL SQL probe | Passed on Neon 18.6 with temporary table and rollback |
| Durable application/test data | Verified 19 application tables, zero rows, and no remaining migration test schemas |
| Compose configuration | Passed using the standalone official Compose CLI; runtime unavailable |
| Repository/templates/ignore rules | Passed, including blank direct URL template and ignored generated Prisma source |
| PowerShell syntax/Markdown links/whitespace | Scripts parse, local links resolve, Git whitespace checks pass |

Commands/checks performed from `backend/` unless noted:

- `npm.cmd install` for exact Prisma/client/adapter/tsx versions; package lock updated.
- `npm.cmd run db:format`, `db:validate`, `db:generate`, and `npm.cmd run check`.
- `prisma migrate diff --from-empty --to-schema prisma/schema.prisma --script --output ...`
  to generate the relational migration, followed by reviewed PostgreSQL-only invariants.
- `npm.cmd run db:migrate`, `db:status`, `db:check:migrations`, and `db:diff`.
- `npm.cmd run db:check` (12 passing tests), `db:seed` twice, and `check:database`.
- Read-only database extension/table preflight; final table/row/migration/temporary-schema
  inventory and migration-lock diagnostics, without printing credentials.
- Root PowerShell repository and Docker development checks; PowerShell syntax parsing,
  local Markdown link checks, `git diff --check`, and Git status/source inspection.

Networked database commands required approved execution outside the sandbox. A pooled
Neon session temporarily retained Prisma's advisory lock, causing a migration retry timeout.
The lock expired naturally; a narrowly checked cleanup command found no eligible session
and terminated none. Final direct-session migration deployment succeeds with advisory locking
enabled. No unrelated sessions, system services, persistent OS policy, or existing data were reset.
An initially short seed transaction timeout was increased for remote startup latency.

## Phase 2 audit (2026-10-05)

Read `AGENTS.md`, this state file, and relevant PostgreSQL/Prisma configurations,
schema, migrations, seed structure, checks, and database documentation before changes.
`docs/DECISIONS.md` was absent, including a repository search; it was created from
the existing design and the confirmed audit corrections. Phase 2 was audited in place.
No tables, schema fields, packages, APIs, authentication, or Phase 3 behavior were added.

### Audit coverage

| Area | Finding |
|---|---|
| PostgreSQL and connection configuration | Neon PostgreSQL 18.6 connects; runtime and direct URLs target the same database. Client TLS is encrypted with certificate verification. Local Compose interpolation/schema validates. |
| Prisma | Matching CLI/client/adapter 7.10.0, PostgreSQL provider, generated ESM client, config-file URL, and strict TypeScript compile successfully. |
| Environment and secrets | Database URLs come from environment, runtime/direct settings are separate, template credentials are blank, private files/generated output are ignored. Source candidates were checked against actual private environment credentials without printing them. |
| Architecture and schema scope | All 19 requested entities remain. No ML/RAG logic in Node and no application behavior was introduced. |
| Relationships and constraints | UUID PKs, FK indexes, unique/version keys, role/status enums, nullable context references, timezone-aware timestamps, four partial indexes, 19 CHECK constraints, and 33 triggers remain intact. |
| Anonymous and authenticated scans | Rollback tests confirm NULL ownership, valid farmer association, rejection of ADMIN ownership, immutable ownership, and cross-farmer/anonymous history restrictions. |
| Future authentication and profiles | Unique normalized email, password-hash field, FARMER/ADMIN, account status, and one optional farmer profile exist. Token/session flows remain Phase 3 work. |
| Disease/admin knowledge foundation | Disease content/images/sources and versioned source-grounded documents/chunks support future management; creator provenance correction is tested. |
| Scans, predictions, models, metrics | Exact model/preprocessing/dataset/artifact metadata, class/probability mapping, bounded metrics, per-class/confusion/curve JSON, and immutable prediction history remain verified. |
| Fertilizers and calculators | Fixed-point label composition, sourced units/parameters, version keys, active uniqueness, and configuration-linked history remain verified. |
| AI/RAG and audits | Optional scan/disease context, retained responses/citations, provenance presence, nullable actors, and immutable audit payloads remain verified; retrieval and authorization are future services. |
| Migration safety | Previous migrations/checksums were preserved. A new corrective migration was applied; all three replay in an isolated schema. No reset, manual table replacement, or retained synthetic data. |

### Problems found and fixes

1. `docs/DECISIONS.md` was missing. Added the decisions register and documentation
   link; repository checks now require it.
2. Knowledge-document and calculator version creators could be reassigned to another
   account because `created_by_id` was excluded to allow FK SET NULL. A rollback probe
   reproduced both cases. Added `20261005020000_protect_version_creator`, preserving
   old migration checksums and all table definitions. Creator reassignment/restoration
   now fails with SQLSTATE 23514, unchanged creators remain valid, and creator deletion
   still clears references. Added a regression test covering these cases.
3. Prisma CLI connections intermittently failed with schema-engine/P1001 errors at
   the default connection timeout while pg connected to the same direct database.
   A temporary CLI override with `connect_timeout=30` connected successfully without
   changing TLS settings. `prisma.config.ts` now defaults this parameter to 30 seconds
   only when absent; explicit settings and runtime driver timeouts remain unchanged.

Updated database design/operations and the backend environment template comments.
No existing migration was edited and no existing working feature source was rewritten.

### Audit verification and commands

- Passed: `npm.cmd run db:format`, `db:validate`, and `db:generate`.
- Passed: `npm.cmd run check`, strict typecheck of config/source/seed/tests, and emitted build.
- Passed: baseline `db:check` (12 tests), then the revised `db:check` (13 tests).
  Both fixture transactions rolled back; anonymous/farmer/admin and provenance cases verified.
- Passed: `npm.cmd run db:migrate` applied only the new corrective migration;
  `db:status` reports all three migrations applied/up to date; `db:diff` reports no difference.
- Passed: `npm.cmd run db:check:migrations` replays all three atomic migrations in
  an isolated schema and removes it; tables/checks/triggers match expectations.
- Passed: `npm.cmd run check:database` against PostgreSQL 18.6.
- Passed: direct connection/TLS/certificate and migration SHA256/history checks;
  targeted creator regression probes run through savepoints and roll back.
- Passed: PowerShell repository check and Docker component configuration validation;
  private environment values do not occur in source/commit candidates.
- Checked: PowerShell script syntax, local Markdown links, source/Git whitespace,
  final database row/temporary-schema inventory, Git status, and remote history.

Migration status: **three applied, none pending**. Prisma validation status: **valid**.
The actual relational schema remains unchanged; corrections affect trigger behavior
and connection configuration. Original Phase 2 verification above is retained as history.

The previously completed foundation files were still uncommitted at audit start.
The Git handoff checkpoints the existing Phase 0-2 foundation together with these
audit fixes; local credentials, dependencies, generated client/build output, caches,
and database data are excluded. The existing AGENTS.md instruction content is preserved.
Commit/push outcome is reported in the final audit handoff.

## Phase 3 backend foundation (2026-10-05)

Inspected `AGENTS.md`, project state, decisions, backend source/configuration and
Prisma schema before implementation. The existing strict NodeNext TypeScript
settings and Phase 2 database design remain intact. No schema/migration/seed change.

### Implementation

- Added separate Express app factory, startup/shutdown lifecycle and executable.
  Health uses route -> controller -> service -> repository -> shared Prisma -> PostgreSQL.
  Health's module contains its own layers; no empty generic directories or DI container.
- Added startup Zod validation for DATABASE_URL and used operational settings.
  Templates document loopback binding, exact CORS allowlist, log level, shutdown
  deadline and request limit. Existing private settings are preserved; unused
  JWT/provider placeholders are optional. Invalid values are never echoed.
- Added typed success/error envelopes, server-generated request IDs and application
  errors for validation/authentication/authorization/not-found/conflict/internal
  failures, plus parser/encoding/size/rate-limit errors. Authentication itself is absent.
- Added reusable async Zod validation for body, params and query. Parsed values
  are stored in Express locals; request.query is not reassigned. Client details
  contain paths/codes only; internal errors cannot expose details or raw exceptions.
- Added Helmet, explicit CORS, in-memory per-IP rate limiting, 100 KiB JSON limit
  and compressed-body rejection. Request logs omit headers/bodies/query/param values
  and client IDs. Errors after headers are sent delegate only a sanitized error.
- Added one shared application Prisma client; isolated seed/test clients remain
  available. Extracted URL normalization for reuse by startup validation, preserving
  TLS behavior. Added a 5-second query timeout; existing database checks still pass.
- Startup performs a database round trip before HTTP listens. Shutdown drains HTTP
  before Prisma disconnect, is idempotent, and has a configurable deadline. Signals
  and fatal process/server errors use the same path, with failure exit codes when needed.
- Added dev/start/lint/format/test scripts with pinned Helmet 8.3.0, CORS 2.8.6,
  Pino 10.4.0, express-rate-limit 8.7.0 and Biome 2.5.15; reused built-in Node tests/tsx.
  Preserved strict TypeScript configuration rather than replacing it.
- Updated root/backend README, LLD/API guidance, roadmap scope, environment/database
  operations, docs index, repository/development checks and actual architectural decisions.

Endpoint: **GET `/api/v1/health`**. Reports service, time, uptime and database up/down;
HTTP 200 or degraded 503, without sensitive infrastructure details. Both use the
same health-report envelope; monitoring must inspect HTTP status and data.status.
Express also provides HEAD handling; CORS handles OPTIONS preflight. No business routes.

### Important files

Created:

- `backend/biome.json`
- `backend/src/app.ts`, `application.ts`, `server.ts`
- `backend/src/config/environment.ts`, `logger.ts`
- `backend/src/database/connection-url.ts`, `errors/app-error.ts`
- `backend/src/middleware/request-context.ts`, `rate-limit.ts`, `error-handler.ts`
- `backend/src/modules/health/health.routes.ts`, `health.controller.ts`,
  `health.service.ts`, `health.repository.ts`
- `backend/src/routes/index.ts`, `types/api.ts`, `types/express.d.ts`,
  `utils/respond.ts`, `validators/request.ts`
- `backend/tests/foundation/helpers.ts`, `environment.test.ts`, `http.test.ts`,
  `lifecycle.test.ts`
- `docs/17-backend-foundation.md` (complete directory tree and operational contracts)

Changed: backend package/lock/template/README, shared database client, formatting
of the existing SQL probe, root README, docs 04/06/14/15/16/index/decisions/state,
and repository/development check scripts. No Flutter/Python/ML/infrastructure changes.
Generated client, compiled output, live-check helpers and credentials remain ignored.

### Verification and commands

| Check | Result |
|---|---|
| `npm.cmd run format`, `format:check`, `lint` | Passed: authored source/foundation tests formatted; no lint errors |
| `npm.cmd run typecheck`, `build` (through `check`) | Passed: strict source/config/seed/test types and emitted build |
| `npm.cmd test` (through `check`) | 20 passed: health/outages, contracts, CORS/headers, parser limits, Zod body/params/query, logging, rate limiting, singleton, startup failures, draining/idempotence/deadline |
| `npm.cmd run check` | Passed: all foundation checks and preserved dependency probe |
| `npm.cmd run db:check` | Prisma validation/generation/types and all 13 database integration tests passed; fixtures rolled back |
| `npm.cmd run db:status`, `db:diff` | Three migrations applied, none pending; no structural difference |
| `node ../.cache/phase3-live-check.mjs` from backend | Compiled app connects through Prisma/Neon and serves health; executable rejects bad settings safely and exits 0 through SIGTERM shutdown |
| PowerShell repository check | Passed: complete structure/templates, blank secrets, Git root and ignore rules |
| Source/commit credential scan | Passed: no actual private environment credentials in commit candidates |
| Local Markdown links, `git diff --check` | Passed; existing CRLF conversion notices remain informational |
| Source review | No authored TypeScript `any`, duplicate query logic, extra client construction, dead feature code or speculative abstractions found |
| `npm.cmd audit --json`, `--omit=dev --json` | Four high-severity package reports in the pre-existing Prisma dependency graph; unresolved, details below |

An initial strict-type error in a test tuple was corrected. Biome configuration was
updated to its current preset syntax. A final review restricted error details to
validation errors and ensured after-header exceptions delegate a sanitized error.
Live Windows signal verification uses a test-only IPC preload to emit SIGTERM
because Windows child.kill does not deliver a POSIX signal; production has no IPC hook.
The server and test listeners are stopped after verification. No application rows
were persisted and no database reset, new migration or automatic seed was performed.

Git handoff: Phase 3 changes are committed/pushed separately from the completed
Phase 2 checkpoint; commit identifier and push result are reported in the final response.

## Phase 4 authentication and authorization

### Implementation

- Inspected `AGENTS.md`, current state/decisions, Prisma schema, migrations and existing
  backend layers before modification. Preserved the Phase 3 foundation and all three
  Phase 2 migrations. Auth follows route -> controller -> service -> repository -> Prisma.
- Added FARMER-only registration, normalized email, strict Zod inputs, clean duplicate
  409 responses, generic failed-login 401 responses and safe user DTOs without account IDs,
  password hashes, statuses or refresh credentials. Registration does not auto-login.
- Pinned Argon2 0.45.1, jose 6.2.12 and cookie 2.0.1. Argon2id uses a random salt,
  64 MiB memory, three iterations and one lane; plaintext passwords are never persisted.
- Required independent canonical base64url signing keys of at least 32 bytes. Local
  initialization generates 64 random bytes per missing key and preserves existing keys.
  Access defaults to 15 minutes; refresh sessions have a fixed seven-day lifetime.
- JWT verification pins HS256, issuer, separate audiences, purpose, required claims and
  expiry. JWTs contain an opaque session handle, not an account ID, email or role.
- Added `auth_sessions` and an additive fourth migration. Only the current SHA-256
  refresh digest is stored. Atomic conditional updates consume tokens once; replay or
  concurrent reuse commits whole-session revocation. Logout immediately invalidates that
  session's access and refresh tokens. Other independent login sessions remain active.
- Access authentication checks the session and current active account in PostgreSQL.
  Reusable authorization reads current FARMER/ADMIN roles rather than stale token roles.
  Farmer/admin-only routes used to verify authorization exist only as test fixtures.
- Refresh credentials use HttpOnly, SameSite=Strict cookies; production additionally
  requires Secure and a host-prefixed name. Refresh tokens are never JSON fields.
  POSTs require JSON and `X-Auth-Request: 1`; CORS uses exact credentialed origins.
  Auth responses are not cached. Logging redacts tokens, hashes, keys and Set-Cookie.
- Added credential and refresh/logout rate limits. Controlled admin provisioning reads
  credentials from stdin through a masked PowerShell prompt; no public ADMIN registration,
  automatic admin, default password or promotion of an existing account.

Available auth endpoints:

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET /api/v1/auth/me`

`GET /api/v1/health` and the existing response/error envelope remain available.

### Important files

Created:

- `backend/src/modules/auth/`: types, repository, password/token helpers, validators,
  cookie handling, service, controller and routes.
- `backend/src/middleware/authentication.ts`, `authorization.ts`
- `backend/src/cli/create-admin.ts`
- `backend/prisma/migrations/20261006000000_auth_sessions/migration.sql`
- `backend/tests/auth/`: helpers, service, HTTP and credential-log tests.
- `backend/tests/auth.database.integration.ts`
- `scripts/initialize-auth-env.ps1`, `scripts/create-admin.ps1`
- `docs/18-authentication.md`

Updated backend schema/package/lock/template, environment/logger/app/routes/error/types,
reusable rate limiter, shared database client, Biome coverage, existing foundation and
database tests/catalog expectations, development/repository scripts, README files,
database/API/security/setup/roadmap documentation, decisions and this state file.
No Flutter, Python, ML or deployment feature code was changed. Generated Prisma/build
output, one-off probes and private database/signing credentials remain ignored.

### Verification and commands

| Check | Result |
|---|---|
| `npm.cmd run format`, `format:check`, `lint` | Passed; no formatting/lint errors |
| `npm.cmd run typecheck`, `build` | Passed with strict TypeScript |
| `npm.cmd test` / `npm.cmd run check` | 36 passed: 21 foundation and 15 auth tests; dependency probe passes |
| `npm.cmd run test:auth:database` | 6 passed including suite parent: real Prisma/HTTP, digest storage, duplicate handling, rotation races, committed revocation and SQL guards |
| `npm.cmd run db:check` | Schema validation/generation/types plus all 13 domain/catalog regressions passed |
| `npm.cmd run db:format`, `db:validate`, `db:generate` | Passed; current client generated |
| `npm.cmd run db:migrate`, `db:status` | Fourth migration applied; all four applied and none pending |
| `npm.cmd run db:check:migrations` | All four migrations replayed in an isolated schema: 20 tables, 20 CHECKs, 35 custom triggers; temporary schema removed |
| `npm.cmd run db:diff` | No structural difference |
| Compiled application/server probe | Real database health, safe startup failure and graceful SIGTERM exit verified |
| Compiled admin CLI invalid-input probe | Rejects bad credentials/role injection safely without writing accounts or printing input |
| PowerShell syntax/repository/environment checks | Scripts parse; structure/templates/ignores pass; rerunning key initialization preserves credentials |
| Source review/credential scan/Markdown links/`git diff --check` | No authored `any`, redundant Prisma construction, leaked private credentials, unresolved local links or whitespace errors |

Coverage includes registration, duplicates, invalid inputs, login/wrong password,
missing/invalid/expired access, protected endpoint access, refresh/rotation/replay,
logout/revocation, FARMER/ADMIN permissions, CSRF/CORS, rate limits, production cookie
flags, safe DTOs/logging, live account status/roles and database constraints.

Resolved verification issues: the current Argon2 encoder orders PHC parameters
differently, so the test now compares parameter values without assuming order.
Two remote domain checks hit the five-second query timeout; development-only domain
test clients now allow 30 seconds. HTTP/runtime retains its five-second query bound.
Final reruns pass. Auth database fixtures remove only their own new UUID/email and
cascading sessions; domain/constraint probes roll back. No existing account/data was
overwritten, no automatic admin created and no database reset performed.
The compiled startup probe also caught pre-existing local signing values incompatible
with the new key format. Replaced those unused Phase 3 values with independent 64-byte
random keys in ignored `.env`, preserving every other setting. Startup/shutdown then
passed; rerunning the committed initializer preserves the valid keys.

Git handoff: the verified Phase 4 change is committed/pushed with a relevant message;
the commit identifier and push result are reported in the final response. Stop at Phase 4.

## Phase 5 Flutter foundation

### Changes and scope

- Read `AGENTS.md`, project state/decisions, Flutter/LLD/API architecture and the
  current mobile scaffold, dependencies and Android configuration before modification.
- Preserved Flutter 3.41.9/Dart 3.11.5 and Provider; locked compatible go_router
  17.5.0 and http 1.6.0. Created meaningful core/data/feature modules without empty
  files, speculative data or extra unused layers.
- Added centralized agricultural Material 3 light theme: forest scan accents,
  ivory/white surfaces, dark ink, wheat/amber tools and blue knowledge accents;
  explicit Roboto typography, spacing/radii and 48-point interaction minimums.
- Added five-area farmer shell, prominent Scan Leaf, nested/back-safe navigation,
  preserved feature state and scroll positions, safe unknown-route fallback and a
  reserved separate Admin boundary that reveals no privileged UI/data.
- Added honest foundation views for all requested feature areas. Mobile sign-in,
  camera/uploads, diagnoses, calculations, charts, assistant responses and dashboard
  operations are not simulated or implemented.
- Added API configuration through public Dart defines, optional offline shell,
  release HTTPS enforcement, origin-contained relative resource paths, redirect
  rejection, JSON/UTF-8/envelope handling, safe typed errors, 15-second request bound
  with supported transport abortion and 1 MiB response cap.
- Added optional access-token source contract for future secure-storage integration;
  no token persistence, mobile login/refresh implementation or secrets in Flutter.
  Main Android INTERNET permission is present; cleartext permission is debug-only.
- Home's scoped ChangeNotifier drives an explicit connection check through typed
  repository/datasource/API layers. It suppresses duplicate requests and handles
  error/retry/disposal safely. Shared dependencies are stateless app-level Providers;
  future screen state remains scoped. Widgets never call HTTP or use business setState.
- Added reusable loading/empty/error patterns, scalable safe scrolling pages, responsive
  card pairs, bottom bar/scrollable wide rail and constrained content. Large text,
  keyboard insets, long labels and small/landscape/tablet screens are verified.

### Important files

Created `mobile/lib/app.dart` and implementations under `core/{constants,theme,routes,
network,storage,exceptions,utils,widgets}`, `data/{models,datasources,repositories}`,
and all requested feature areas plus `shell` and `tools`. Every feature has a routed
view; only Home currently needs a ViewModel and concrete data workflow.

Added `mobile/test/core/api_client_test.dart`, `test/features/home_view_model_test.dart`,
`test/widgets/foundation_test.dart`, `test/integration/backend_connection_test.dart`
and `docs/19-flutter-foundation.md`. Updated existing entrypoint/scaffold test,
pubspec/lock, public template, Android manifests, mobile/root README, Flutter/setup/
roadmap/docs index, actual decisions, repository checker and this state file.
Backend application, Prisma schema/migrations, Python/ML and infrastructure code are
unchanged. Generated preview PNGs/test artifacts and one-off live helper stay ignored.

### Checks and outcomes

| Check | Result |
|---|---|
| `flutter --version`, `dart --version`, `flutter pub add go_router http` | Existing SDK preserved; compatible dependencies resolved and locked |
| `dart format lib test`; format with `--output=none --set-exit-if-changed` | Passed; 40 authored Dart files formatted |
| `flutter analyze --no-pub` | Passed; no issues |
| `flutter doctor -v` | SDK, network and connected emulator available; some Android licenses remain unaccepted |
| `flutter test --no-pub` | 37 passed: 17 API/repository, 4 ViewModel, 15 widget and one offline smoke test; optional live test skipped |
| Opt-in `backend_connection_test.dart` through local compiled Node server | Passed separately: full Flutter MVVM chain reaches actual Prisma/PostgreSQL-backed health; read-only, server/client stopped afterward |
| Responsive/navigation | Seven sizes: 320x568, 360x800, 412x915, 640x360, 768x1024, 1024x768 and 1024x360; primary small-phone action, 200% text, nested/back/state preservation, unknown/admin boundaries pass |
| State/accessibility | Loading/error/retry, safe keyboard/insets/long text, Android tap/label/contrast guidelines pass |
| Rendered visual review | Reviewed actual 320/360/1024 screenshots with SDK fonts; previews are ignored build artifacts |
| Repository/templates/PowerShell/Markdown/credential/whitespace checks | Passed; no actual secrets in source/commit candidates, no empty feature files or widget HTTP/business setState |

Initial checks caught brace-style lint issues, realistic font selection and semantics
handle cleanup in tests. Added SDK font loading and explicit theme typography,
ensured short rails scroll to every destination and corrected preview image capture
to run in real asynchronous execution. Final checks pass. No SDK license agreement
was accepted, Android device/APK validation or deployment performed.

Git handoff: the verified Phase 5 change is committed/pushed with a relevant message;
its identifier/result is reported in the final response. Stop after Phase 5.

## Phase 7 implementation and verification (2026-10-06)

Scope: secure maize leaf image storage and scan-record foundation only. The workspace
started clean at e5f1949 (Phase 5). AGENTS.md, project state/decisions, relevant
architecture, schema/migrations, auth/backend layers and mobile foundation were read
before edits. The explicit Phase 7 request does not authorize Phase 6 or inference.

- Added the layered scans module, strict multipart/header/Zod validation, optional
  session auth and FARMER ownership. Invalid supplied credentials return 401; ADMIN
  returns 403; request-supplied ownership/provider fields are rejected.
- Accepted still JPEG/PNG/WebP with matching MIME/signature/extension, at most 5 MiB
  and 16 million pixels. Security decoding validates full content with five-second
  processing timeout; original bytes are uploaded unchanged. Python's future shared
  ML preprocessing remains untouched. Two concurrent upload slots and additional
  rate limits protect parsing/decoding/storage work.
- Integrated server-only Cloudinary SDK, authenticated assets, generated IDs,
  overwrite protection and signed HTTPS delivery. Required partial provider
  configuration is rejected; all blank cleanly disables uploads. No provider secrets
  or internal journal/owner fields are returned or included in mobile source.
- Added fifth migration 20261006010000_scan_uploads: one necessary durable upload
  journal and immutable uploaded_at timestamp. Preserve all prior migrations;
  backfill existing scans under the atomic migration lock. Database: 21 application
  tables, 21 CHECK constraints, 37 custom triggers and unchanged partial indexes.
- Added exact-payload, owner-scoped retry identity; atomic scan/journal completion,
  confirmed-upload compensation, lost-commit protection, delayed unknown-outcome and
  crash recovery. `scans:cleanup` processes bounded stale attempts and prunes cleaned
  FAILED journals after 24 hours, preserving all completed scans.
- Added image_picker datasource, typed scan/photo models, repository/datasource,
  route-scoped Scan ViewModel, preview component and upload UI. Gallery/camera
  cancellation, native permission errors, Android lost picker data, upload progress,
  saving state, errors/retry/new selection/disposal are handled. Selected original
  bytes and retry key remain in memory, without plaintext token persistence.
- Added maintained locked backend provider/parser/decoder packages. image_picker
  1.2.3 archive download stalled; compatible cached 1.2.2 resolved and is locked.
  Native Kotlin compilation reported its cross-drive incremental-cache error;
  project kotlin.incremental=false fixed it. Rebuild passed without that error in 32.5s.
- Final camera-style EXIF regression found that Cloudinary reports portrait JPEG
  dimensions after orientation while Sharp reports original dimensions. Fixed the
  provider consistency check to accept the EXIF-authorized swap without modifying
  bytes. Unit and real-provider JPEG/PNG upload regression pass; original bytes remain intact.

New API: POST /api/v1/scans, 201 new PENDING scan, 200 same-key replay.
Existing health/auth endpoints remain available; no inference/read/history API added.

| Check | Result |
|---|---|
| Backend `npm run check` | Formatting, Biome lint, strict typecheck, build, 50 isolated tests and compiled dependency probe pass |
| Image/security/service/HTTP tests | Format signatures/decoding/EXIF portrait metadata, MIME/extension spoofing, size/pixel/animation/multipart bounds, farmer/guest/admin behavior, limits, disconnected-client slot retention, safe replies and idempotency pass |
| Recovery tests | Database failure deletion, uncertain provider outcome, lost commit, failed cleanup, crashed upload, completed-scan protection, retry and failed-journal pruning pass |
| Original database regression `db:check` | 13 catalog/domain/constraint/relationship/ownership/vector/version/timestamp tests pass; synthetic writes roll back |
| Auth database regression | Six tests pass, including real HTTP auth and refresh locking/revocation |
| Scan database integration | Seven tests pass for metadata, null/owned scans, parallel claims, transaction rollback, cleanup exclusion and immutable/state SQL invariants |
| Real Cloudinary integration | One test passes: Node multipart PNG and portrait EXIF JPEG -> authenticated Cloudinary -> PostgreSQL, replay, signed delivery and unsigned denial; exact fixture assets/journals/scans removed |
| Prisma | Format/validation/client generation pass; all five SQL migrations replay in a temporary schema; fifth migration deployed; status up to date; diff has no changes |
| PostgreSQL probe | Real authenticated PG 18.6 temporary-table round trip passes and rolls back |
| Flutter formatting/analyzer | Pass, no issues |
| Flutter isolated tests | 52 pass; both live tests skipped by default |
| Flutter live upload harness | Scan ViewModel -> repository -> datasource -> ApiClient -> real Node/Cloudinary/PostgreSQL passes; only own synthetic asset/SQL rows removed |
| Android APK | `flutter build apk --debug --no-pub` passes with gallery/camera plugin after cross-drive Kotlin cache fix; generated APK ignored |
| Android emulator | APK installation/activity launch succeed on emulator-5554; interactive picker/capture could not be verified because Android System UI repeatedly reports not responding |
| Cleanup command | Ran successfully: zero stale assets/failures/expired journals; no unrelated assets enumerated |

Commands/checks performed from appropriate component directories:

- npm view/install locked Cloudinary 2.11.0, Multer 2.4.0, Sharp 0.35.5 and
  @types/multer 2.3.0; npm audit confirmed the four already-known Prisma graph findings.
- `npm run format`, `npm run check`, `npm run db:format`, `db:validate`, `db:generate`,
  `db:check:migrations`, `db:migrate`, `db:status`, `db:diff`, `db:check`,
  `test:auth:database`, `test:scans:database`, `check:database`, `test:scans:live`
  with explicit live opt-in, `test:scans:mobile`, and `scans:cleanup`.
- `flutter pub get --offline`, `dart fix --apply` for new braces/import issues,
  `dart format lib test`, final format check, `flutter analyze --no-pub`,
  `flutter test --no-pub --reporter expanded`, targeted new/widget tests and
  `flutter build apk --debug --no-pub`.
- Repository structure/template/ignore checks, local Markdown links, actual-secret
  scan, whitespace/source review and Git diff/status checks are recorded at handoff.

Important new files: backend/src/modules/scans/{routes,controller,service,repository,
storage,validation,types} (scan.*.ts), cleanup-scan-uploads CLI, fifth migration,
scan isolated/database/live tests; mobile upload request, image/scan datasources and
models, scan repository/ViewModel/preview, scan unit/widget/live tests;
scripts/check-scan-upload.mjs and docs/20-scan-uploads.md. Configuration/app/routes,
dependency locks, native Android settings, existing catalog counts and docs updated.

Git handoff: verified Phase 7 work is committed/pushed with a relevant message;
its identifier/result is reported in the final response. Stop after Phase 7.

## Phase 8 implementation and verification (2026-10-07)

Read AGENTS.md, project state, AI/RAG/security architecture, decisions, existing Python
manifests/locks/tests, environment template and setup/check scripts before changes.
Workspace started clean on main at 7a7ec71. Two agents independently implemented
foundation tests and reviewed application security/architecture; root implemented
the application, configuration/tooling and documentation. No Phase 9 work was started.

- Added app factory/lifespan and configured Uvicorn entrypoint. Startup loads/validates
  settings before listening, does not import torch/image libraries or load models,
  and creates no database/provider connections. Lifespan marks start/stop explicitly.
- Added Pydantic typed health/query/error/metadata contracts. GET /health reports
  process status, uptime, service version, unimplemented capabilities and unloaded
  model with null model version. It accepts no query fields; 200 follows startup,
  503 is a safe pre-start report. No fake diagnosis/model readiness or business API.
  Final inspection corrected OpenAPI's default validation/error schema to match the
  actual envelope; the generated-contract regression assertion passes.
- Added fixed application/HTTP/validation/unexpected error handling, server-generated
  UUID correlation and no-store/nosniff headers. Validation exposes bounded source/code
  pairs only, without raw input/field names/context. Unknown failures contain no trace.
- Added allowlisted JSON stdout events for lifecycle, request status/route template/
  latency and errors. No raw request URL/query, headers/body, dynamic path values,
  exception/library messages or tracebacks are logged. Uvicorn access logging disabled.
- Settings load from service-local ignored .env with OS precedence; ENVIRONMENT,
  HOST, PORT, LOG_LEVEL and AI_SERVICE_TOKEN are validated. Loopback defaults and no
  browser CORS preserve Flutter -> Node -> private FastAPI. Production/non-loopback
  requires a random base64url shared server token; a reusable bearer dependency compares
  credentials in constant time and future operations fail closed if unconfigured.
  Health requires no token. No Node integration or deployment/firewall changes.
- Added meaningful boundary READMEs for future preprocessing, inference, RAG and model
  management, without placeholder processors/clients/loaders. Shared preprocessing
  implementation/package location remains future work, identical for training/inference.
- Preserved all original locked dependencies; added Pydantic settings 2.15.0/
  python-dotenv 1.2.4 and dev Ruff 0.16.10/mypy 1.20.2 plus their required transitives.
  Python 3.11, FastAPI 0.142.2, Uvicorn 0.54.0, PyTorch/torchvision/image versions remain.
  Lock diff adds seven packages without upgrading existing entries. No global installs.
- Added scripts/start-ai.ps1 and expanded only the AI development-check branch with
  format/lint/types before pytest. Repository checks include the new structure/template
  keys. Documented startup/API/network/logging boundaries and recorded actual decisions.

| Check | Result |
|---|---|
| AI aggregate check | Ruff format (27 files), lint, strict mypy (17 application modules) and 49 pytest cases pass |
| Foundation tests | 46 pass: actual lifecycle/health/correlation, capabilities absent, no heavy imports/external calls, docs/CORS boundaries, query/body/path validation, safe errors/logging, auth dependency and settings |
| Preserved dependency tests | Three pass: isolated Python, in-memory dependency route, image libraries and compiled CPU torch/torchvision operators |
| Live CLI/socket check | Actual python -m app.server on an ephemeral loopback port returns safe health, 404 and validation responses, no CORS/server header; JSON logs omit synthetic sensitive path/query values; only own child stopped |
| Invalid CLI settings | Production startup with invalid synthetic token exits 1, fixed configuration_invalid JSON event, no rejected value |
| uv lock/sync | Lock resolves and sync --locked installs seven additions; lock --check passes |
| uv pip check | All 42 installed packages compatible |
| Compilation | compileall app/tests passes |
| Independent source review | No blocking defect: config/auth, lifespan, safe errors/logs, no heavy imports and phase boundaries verified |
| Repository checks | Required structure/templates/blank secrets/ignore behavior pass; final local links, private-secret and whitespace checks recorded at Git handoff |

Commands performed: component uv lock, sync --locked, lock --check, pip check;
`.venv/Scripts/python.exe -m ruff format app`, `ruff check app`, `mypy`, `pytest`,
`compileall -q app tests`; `scripts/check-development.ps1 -Component AI`,
`scripts/check-repository.ps1`; an ignored temporary actual-CLI HTTP/error/log check;
Git/source/Markdown/credential checks. No external AI provider, database or model is
called by these tests or application startup. Temporary live server was stopped.

Important new files: app/main.py, app/server.py, api middleware/security/health route,
config/settings.py, schemas/common.py/health.py/errors.py, utils/errors.py/logging.py,
four future-boundary READMEs and package markers; tests/conftest.py, test_health.py,
test_settings.py, test_errors_and_logging.py, test_service_authentication.py;
scripts/start-ai.ps1 and docs/21-ai-service-foundation.md. Updated manifest/lock,
environment example, AI/architecture/development/root documentation, decisions and checks.
Original dependency tests and all backend/mobile/ML/database feature files are preserved.

Git handoff: Phase 8 is committed/pushed with a relevant message; identifier/result
reported in the final response. Stop after Phase 8.

## Phase 9 implementation and verification (2026-10-07)

Read AGENTS.md, project state/decisions, ML/AI/RAG architecture, existing Python
configuration/tests, and local scaffold before implementation. Phase 8 was already
committed at 2605164. Existing dataset ignore rules, documentation-only ML scaffold
and its README/state additions were preserved. The unrelated deletion of the backend
database client was also preserved; none of these changes belongs to the Phase 9 commit.
Two agents supplied independent pipeline review and synthetic unit tests while the
root agent implemented the shared package, consumer wiring and verification tooling.

- Added one editable local package, `shared/preprocessing`, imported identically by
  AI and training. Their local modules re-export the actual shared functions without
  additional transforms. No API endpoint, model loader or training loop was added.
- Configuration explicitly pins preprocessing version 1.0.0, dimensions, normalization,
  segmentation thresholds/fallback, input limits, crop padding and resize behavior.
  Immutable validated settings reject invalid/nonfinite/extra fields; canonical JSON
  SHA-256 distinguishes configuration changes. Defaults are foundation values, not
  evaluated classifier hyperparameters.
- Validate bounded JPEG/PNG/WebP bytes, signatures, optional MIME/extensions, full
  decoding, dimensions, animation and containers. Apply EXIF orientation, grayscale/
  palette handling, valid ICC-to-sRGB conversion and configured alpha compositing.
  Unsigned 16-bit grayscale uses fixed-range rounding instead of saturated conversion;
  the regression preserves gradations from dark through white.
- Foreground extraction accepts an oriented supplied mask or non-opaque alpha; otherwise
  it uses full Lab color and removes only uniform-background components connected to
  the perimeter. Enclosed brown/yellow/gray/rust/dead/background-colored lesions remain
  selected. Coverage, border variation, boundary contact and significant component
  gates preserve the full frame when uncertain; strict rejection is configurable.
  There is no green-only threshold, random augmentation, semantic maize detector or
  measured segmentation accuracy. All outputs warn that leaf identity is unverified.
- Use outward-only mask margin, background replacement, padded crop, aspect-preserving
  letterbox, explicit normalization and read-only contiguous RGB CHW float32 arrays.
  Optional PyTorch conversion copies unchanged values. Metadata records image/config/
  supplied-mask hashes, bounds, warnings, extraction status and library versions.
  Supplied masks must follow the same provenance/policy in training and serving.
- Independent review led to fixed-range 16-bit conversion, supplied-mask hashing,
  explicit minimum crop padding and bounded crop coordinate allocations. Strict type
  checks caught and resolved literal/nullable-library typing without adding `Any`.
- Added safe errors and an opt-in debug CLI producing standardized/mask/prepared images,
  a contact sheet and metadata in a new output directory. It refuses overwrite and
  does not copy source EXIF/location metadata. Inspected a generated synthetic contact
  sheet under ignored `.cache/phase9-debug-synthetic-current/`; internal lesion patches
  and leaf silhouette were retained. These artifacts are not real maize validation.
- AI health now truthfully reports preprocessing `library_available`; startup still
  imports no heavy image/ML libraries and loads no model. Existing factory/security/
  logging behavior is preserved. Both locks install the same local package with
  existing scientific/AI dependency versions preserved; training gains matching dev tools.
- Workspace image/data inventory found only launcher/UI graphics and documentation-only
  dataset scaffold. No actual dataset paths, photos, model weights or downloads were
  invented. Representative maize-leaf validation remains pending.

| Check | Result |
|---|---|
| Shared package tests | 78 pass in the AI environment and the same 78 pass in the training environment |
| Input/security coverage | Invalid/truncated/animated files, signature/MIME/extension, byte/pixel limits, orientation/ICC, grayscale 8/16-bit, alpha/palette and safe errors pass |
| Extraction/output coverage | Diseased non-green regions, enclosed background-colored lesions, supplied masks/provenance, ambiguous-frame fallback/strict errors, crop/letterbox/math/layout/read-only outputs and repeated/concurrent determinism pass |
| Tensor/debug coverage | Exact unchanged CPU tensor with independent storage, safe local inspection artifacts and no overwrite pass |
| Cross-environment parity | Eight synthetic scene/configuration cases produce identical implementation identity, masks, array/tensor bytes, dtype/shape and metadata through the two consumer modules |
| AI aggregate | Ruff format/lint (29 files), strict mypy (18 application modules) and 50 pytest tests pass; original foundation/dependency tests preserved |
| Training aggregate | Ruff format/lint (three files), strict mypy (one consumer module) and five pytest tests pass; four original dependency probes preserved |
| Shared source/tooling | Ruff format/lint (16 package files plus parity script) and strict mypy (nine source modules) pass |
| Dependency configuration | Both `uv sync --locked`, `uv lock --check` and `uv pip check` pass; all 43 AI / 34 training installed packages compatible |
| Distributable package | `uv build` successfully creates source archive and wheel under ignored `.cache/phase9-package-artifacts/` |
| Compilation | Shared source and both consumer wrappers compile successfully |
| Repository source safety | Git whitespace checks pass; 261 source/configuration candidates inspected without actual private credentials; intended artifacts remain ignored |
| Documentation links | 138 of 139 local links resolve; the single pre-existing unresolved link targets the unrelated deleted backend database client; Phase 9 links resolve |
| Full repository structure | Blocked by the unrelated local deletion of `backend/src/database/client.ts`; Phase 9 required files/configuration/typing/docs/tooling are present |
| Real maize images | Not available; field validation pending |

Commands/checks performed from the repository or appropriate component directories:

- `uv lock`, `uv sync --locked`, `uv lock --check`, `uv pip check` for both consumers.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1`
  with `-Component AI`, `-Component Training`, and `-Component Preprocessing`.
- Shared Ruff format/lint, `mypy --config-file shared/preprocessing/pyproject.toml`
  against shared source and pytest against shared tests using both environment executables.
- `python scripts/check-preprocessing-parity.py`, synthetic debug generation/contact-sheet
  inspection, and module compilation via the consumer environments.
- `uv build shared/preprocessing --out-dir .cache/phase9-package-artifacts`, repository
  structure/template/ignore checks, local Markdown links, credential/source inspection,
  and `git diff --check`.

Important created files: `shared/preprocessing/pyproject.toml`, `README.md`,
`configs/default.json`, `src/maizedoctor_preprocessing/{config,decoding,segmentation,
pipeline,types,errors,debug,__init__,__main__}.py`, `py.typed`, five shared test files;
`ai-service/app/preprocessing/__init__.py`, `ai-service/tests/test_preprocessing.py`,
`ml-training/preprocessing.py`, `ml-training/tests/test_preprocessing.py`,
`scripts/check-preprocessing-parity.py`, and `docs/22-shared-preprocessing.md`.
Updated Python manifests/locks, AI health contract/test, development/repository checks,
root/component READMEs, relevant architecture/development docs, decisions and this file.
No backend/mobile/schema changes, external provider calls, training, inference or
dataset operations were performed by this phase.

Git handoff: verified Phase 9 work is committed/pushed with a relevant message;
its identifier/result is reported in the final response. Unrelated local changes
remain outside the commit. Stop after Phase 9.

## Post-Phase 9 database client recovery (2026-10-07)

The user authorized recovery of the locally deleted `backend/src/database/client.ts`
if necessary. Inspection confirmed that backend startup, repositories, maintenance
commands, seed and database tests still import its shared-client/factory exports.
An independent read-only review confirmed that restoring the committed implementation
was the appropriate minimal fix.

Restored only this file with `git restore --source=HEAD --worktree`. Git's Windows
checkout produced CRLF line endings rejected by Biome; formatting only the restored
file returned it to the expected LF format. Its Git blob hash matches HEAD exactly,
so no backend implementation change remains. Other existing ignore/ML scaffold/README
changes were preserved and excluded from this documentation commit.

| Check | Result |
|---|---|
| Repository foundation | Required structure, documentation, environment templates and Git ignore/source visibility checks pass |
| Local documentation links | All 139 resolve; the previously missing database-client link is restored |
| Backend aggregate | Formatting, lint, strict typecheck, build, all 50 isolated foundation/auth/upload tests and compiled dependency probe pass |
| Prisma validation | Existing schema is valid; no migration/schema changes |
| Source integrity | Restored client matches HEAD; Git whitespace checks pass |

Commands: `git show HEAD:backend/src/database/client.ts`, import inspection with `rg`,
`git restore --source=HEAD --worktree -- backend/src/database/client.ts`, local Biome
formatting of that file, `scripts/check-repository.ps1`, `npm run check`,
`npm run db:validate`, local Markdown link verification and Git content/diff checks.
The Phase 9 repository/link failure is resolved. No later phase was started.

## Pre-Phase-10 audit (2026-10-07)

Read the whole authored project across backend/database, mobile/native and Python/shared/
training, including all configurations, environment templates, parsed dependency locks,
SQL migrations and tests. Traced actual layering/contracts, not only file presence.
The [full audit](23-pre-phase-10-audit.md) contains the required 18-section report,
all seven Node APIs plus FastAPI health, complete environment-variable inventory,
installed/required dependency matrix, coverage matrix and concrete user prerequisites.

| Phase | Fresh audit status |
|---|---|
| 0 | PASS — required roots/docs/templates/ignore rules |
| 1 | PASS WITH WARNINGS — environments work; optional Docker runtime absent and licenses/Python patch maintenance pending |
| 2 | PASS — schema/client/five migrations/catalog/invariants/live queries |
| 3 | PASS — strict backend architecture/health/errors/lifecycle |
| 4 | PASS WITH WARNINGS — backend auth/RBAC/session checks; native Flutter sessions deferred |
| 5 | PASS WITH WARNINGS — MVVM/design/routes/tests/debug APK; physical/iOS/release checks pending |
| 6 | NOT FULLY TESTABLE — explicitly skipped, no disease knowledge APIs/reviewed seeds |
| 7 | PASS WITH WARNINGS — live guest/farmer upload/replay/compensation; physical capture/scheduled cleanup pending |
| 8 | PASS — FastAPI process foundation, no model/Node orchestration implied |
| 9 | PASS WITH WARNINGS — shared source/parity/synthetic tests; field validation needs real data |

| Check | Fresh result |
|---|---|
| Backend aggregate | Format/lint/strict types/build/dependency probe; 50 isolated tests pass |
| Live backend database suites | 13 domain/catalog, six auth/session, seven scan/journal tests pass |
| Prisma and SQL | Format no diff, validation/client generation pass; five applied checksum-matching migrations, no structural drift; all five replay in only an owned temporary schema |
| Provider/Flutter integration | One checked-in live PNG/oriented-JPEG test, live Flutter upload and live Flutter health pass; additional farmer WebP ownership/replay/auth/logout probe passes |
| Backend count | 77 checked-in cases; supplemental audit probes counted separately |
| Database integrity | Neon PostgreSQL 18.6/vector0.8.6, 21 application tables, 21 checks/37 triggers/four partial indexes; before/after snapshots identical, all counts zero, no temporary schema |
| Flutter | Locked offline dependencies, format54 files/no change, analyzer no issues; 52 isolated and two separately executed live tests pass; debug APK builds |
| Python and shared | AI50/training5/shared78 in each venv/eight parity cases pass; Ruff/strict mypy/locked sync+checks+pip check/package build/compileall pass |
| FastAPI live/synthetic stress | Safe actual test/production startup/health/errors/shutdown; six deterministic synthetic scene/gate probes pass |
| Docker | Compose validation passes; Engine absent, no container runtime claim |
| Security | No configured private values/pattern matches across source candidates or 501 unique historical text blobs; no committed non-template .env; fresh npm audits still report four high aggregate findings |
| Repository/docs | Structure/templates/ignore/local links/Git whitespace pass after minimal documentation corrections |

The live checks used the already configured **development** Neon/Cloudinary account,
not production. Cleanup targeted only freshly generated fixtures/assets; no database
reset, deployment, seed, broad provider cleanup, training or model download occurred.
Remaining original workspace ignore/ML README/scaffold/state changes are preserved
outside the audit commit. No dependency/package/source/schema/migration changes.

Documentation corrections: current Flutter scanning, implemented provider/security
controls and shared preprocessing, backend timeout60/10/5 seconds, testing scope and
development debug packaging. Created this audit report and KNOWN_ISSUES.md; updated
root/AI READMEs and documentation index. DECISIONS.md stays unchanged because no actual
architecture/product decision was made.

Readiness categories:

- **Code:** no new P0/P1 defect; before inference define the reproduced Node/shared
  1×1/trailing-PNG admission/failure contract. The native mobile cookie/session client
  and Node→AI adapter remain deliberately unimplemented later work.
- **Configuration/credentials:** current DB/JWT/Cloudinary settings are configured and
  verified. Regular connected mobile builds still need public API_BASE_URL; no new
  secret, Gemini key, model path or internal service token is needed for local CPU training.
- **External data/files:** supply an actual raw original JPEG/PNG/WebP path, exact labels,
  source/license, available official split/group/augmentation-parent metadata and real
  representative images. Empty scaffold directories are not a dataset.
- **User decisions:** approve actual taxonomy/ambiguous-label policy, independent grouping/
  split provenance, CPU versus identified alternate target, and empirical shared mask
  policy after real-image review. No class count/split ratio/model choice was fabricated.
- **Manual/operational:** real-device camera/gallery checks and relevant Android licenses,
  cleanup scheduler for persistent API use, least-privilege/deployment/privacy choices
  at their proper phases. Docker/GPU/iOS are optional targets, not local CPU blockers.

The training environment and shared implementation are stable, but model training cannot
be justified until those data/empirical prerequisites are met. Training-only splitting,
augmentation/seed/class-map/checkpoint/metrics/plots/run manifests are future Phase 10
implementation, not completed files. Stop after this audit.

## Phase 9.5 dataset intake and real-image verification (2026-10-07)

- Configured the supplied absolute dataset path in ignored `ml-training/.env`.
  Added blank `DATASET_PATH` in `.env.example` and a cwd-independent loader with
  explicit OS precedence, no interpolation/global mutation, and directory validation.
  Future intake, validation and training read this same configuration.
- Added read-only `dataset_inventory.py` and `dataset_review.py`. Reports/debug images
  stay in ignored `.cache/dataset-review/phase95-20261007/`; output cannot overwrite
  existing files or sit inside the source dataset. All 8,040 source hashes/file stats
  were checked again after review and are unchanged.
- Exact classes/counts: Common_Rust 2,498; Gray_Leaf_Spot 1,087; Healthy 2,324;
  Northern_Corn_Leaf_Blight 2,131. All folders are flat; no official split exists.
  Inventory finds 3,854 excess exact copies, ten near-content pairs and three
  contradictory families covering seven filenames/five byte contents. No class was
  merged, relabeled, finalized or assigned a partition.
- Both canonical shared policies accept 8,029/reject 11. Conservative mode extracts
  only eight Rust files/four distinct contents and otherwise preserves the full frame.
  All 80 purposive comparisons plus the fourth extracted family were viewed. No obvious
  tissue/lesion deletion was observed in this sample; most clutter remains and small
  lesions soften through resize. Full-frame is recommended, with approval pending.
- Recovered both local source archives and matched every current byte hash. The
  PlantVillage color contribution duplicates the Corn collection. Original-image
  filenames/UUIDs and confirmed derivatives support grouping; sparse EXIF IDs/timestamps
  do not establish independent plants/sessions. Mixed license/individual rights notices
  leave intended-use eligibility unresolved. Private metadata stays ignored.
- Checks passed: training Ruff format/lint, strict mypy on four sources, 29 tests,
  locked environment/pip compatibility, 160 real-image/two-policy exact cross-environment
  parity cases, repository/template/ignore checks, local links, whitespace and private
  path/credential checks. New tests cover configuration, literal labels, duplicate
  conflicts, corrupt input, source immutability and safe output destinations.
- Updated current documentation and added the complete
  [Phase 9.5 report](24-dataset-intake-preprocessing-review.md). No source image,
  canonical preprocessing code/config/version, model, augmentation or permanent split
  was created/changed. The Phase 0–9 audit remains historical evidence.

## Phase 10 dataset preparation, training and evaluation (2026-10-07)

Historical v1 record: confirmed transformed-parent leakage found in Phase 10.5
invalidates independent-evaluation claims below. Preserve its artifacts; use v2 for
current fitness.

- Approved dataset policy is persisted in `ml-training/configs/research-policy.json`
  and hash-pinned family/invalid/confirmed-relative evidence in `group-evidence.json`.
  Exclude 18 filenames/16 unique contents: eleven shared-rejected inputs plus all seven
  members of three contradictory families. Collapse 3,852 remaining duplicate aliases.
  No original image is converted, relabeled, renamed, deleted or written.
- New `dataset_preparation.py` writes/verifies immutable eligibility, exclusions,
  literal class mapping, provenance, grouped stratified partitions and integrity hashes.
  Committed safe index: `ml-training/manifests/maize-research-20261007-v1/manifest.json`,
  semantic fingerprint `e1abe6c4bba09080371345365ab92067f1f08bfba9f927f66cbc9e58af6b5e98`.
  Future experiments reuse it and resolve source bytes only through `DATASET_PATH`.
- Fixed class counts (eligible/train/validation/test): Common_Rust 1301/910/196/195;
  Gray_Leaf_Spot 568/397/86/85; Healthy 1162/813/175/174;
  Northern_Corn_Leaf_Blight 1139/797/171/171. Seed 20261007; target 70/15/15;
  nine eligible confirmed-relative links stay together. All pairwise group/content
  intersections are empty; all 8,040 original names/bytes/sizes/mtimes match Phase 9.5.
- Shared preprocessing remains package **1.0.0**, with artifact-pinned disabled extraction,
  full-frame RGB/224 letterbox/CHW float32 and centrally configured ImageNet normalization.
  Fingerprint `b142e59f458d27a2d3fddbfc86c2f2f802670ab4909f1275babbef92de9cb5c8`.
  Generic defaults are preserved. Training-only mild flip/affine occurs after shared
  preprocessing; validation/test never use augmentation. Twelve synthetic and sixteen
  real TRAIN-image cases show exact training/AI wrapper parity with this configuration.
- New `model.py`, `training_data.py`, `train.py` and `evaluation.py` implement checked
  official MobileNetV3 Small weights, deterministic CPU transfer learning, AdamW/scheduler/
  validation-only checkpoint selection/early-stopping infrastructure, unique epoch files,
  strict restore parity, guarded final test and typed metrics/standalone plots. Matplotlib
  and its locked dependencies are added; 43 installed distributions pass compatibility.
- Actual `smoke-20261007-01`: 32 train/16 validation, one finite epoch, safe save/reload,
  exact fresh-model outputs, no test evaluation. Actual original run
  `mobilenet-v3-small-20261007-01`: ten completed epochs, then external terminal
  interruption during epoch 11. Its directory/checkpoints remain byte-identical.
  `mobilenet-v3-small-20261007-01-recovery` locks the unchanged epoch-10 validation
  winner before test, strictly restores it and completes evaluation without more fitting.
- Selected unaugmented train/validation/test accuracy: 99.5886%/95.7006%/95.2000%; macro
  F1: 0.9948/0.9411/0.9396. Test has 595 correct of 625, macro precision/recall
  0.9375/0.9421, weighted F1 0.9522 and macro OVR ROC-AUC 0.9946. Per-class P/R/F1,
  specificity, AUC, confusion, curves and fitting analysis are preserved. No test
  result determines hyperparameters, thresholds or selection; test is evaluated once.
- Best local model: `.cache/phase10/experiments/mobilenet-v3-small-20261007-01-recovery/checkpoints/epoch-010.pt`,
  SHA-256 `a7a08eb88510fd8f58c7a30f174935bf9d6a7bfe941a0eec876ff01d32154c6d`.
  [Committed aggregate report](../ml-training/reports/mobilenet-v3-small-20261007-01-recovery/README.md)
  retains 24 hash-verified numerical/code/provenance files plus integrity.json. Full local
  experiment retains immutable model and prediction CSVs. No raw source image is published.
- Checks: **92 tests**, Ruff format/lint on 19 files, strict mypy on nine source files,
  lock/pip compatibility, repository/templates/ignore, links, whitespace, credentials and
  private-path scans pass. An independent auditor recomputes every numerical metric from
  CSVs and validates parent/recovery/config/class/source/environment/checkpoint hashes;
  two zero-input strict restores agree. It performs no additional test-image inference.
- Fixed a pre-commit Windows Git newline-conversion issue that changed report byte
  hashes. Scoped `.gitattributes` retains frozen manifest/report bytes and LF training
  sources. All 34 hash-bound Git index files match their recorded SHA-256 identities.
- Reports/documentation/decisions/testing/development checks are updated. Backend,
  mobile, database, AI service and shared package source remain unchanged. No production
  model promotion or application inference occurs; stop after Phase 10.

## Phase 10.5 completion and verification

- Expanded transformed-photo review confirms 36 additional parent relations,
  including 22 crossings of the v1 partitions. V1 independent-evaluation claims
  are invalid; the original experiments and reported arithmetic remain preserved.
- New immutable `maize-research-20261008-v2` applies the existing contradictory-family
  policy to four newly confirmed families, groups all known relatives and retains
  the original splitter/seed. It contains 4,162 unique eligible contents in 4,121
  groups, split 2,911/627/624; all 8,040 raw files remain unchanged.
- A real 32/16 smoke passes before a fresh bounded classifier fit. Epoch 8 is selected
  by validation macro F1; patience 3 ends the run at epoch 11. Validation diagnostics,
  group-fold calibration, errors/CAM, TRAIN augmentation, source membership and ten
  fixed perturbation probes are reviewed before the candidate freeze.
- All 48 pre-test candidate references and 13 final artifact references validate.
  One post-freeze test scores 598/624 correct; no post-test model/policy change occurs.
  Critical-field rejection checks, independent saved-CSV arithmetic and exact 16-case
  TRAIN model compatibility across training/AI environments pass.
- Checks pass: 219 ML tests, 50 AI tests, 78 shared tests in each environment,
  12 synthetic preprocessing parity cases, Ruff formatting/lint and strict mypy.
  The safe aggregate export contains 98 files, including 93 byte-identical copies
  and 16 numerical plots; raw images and weights stay local/ignored.
- Updated the fitness report, project/ML documentation, known issues, roadmap and
  finalized decisions. No Phase 11 API or application integration is implemented.
  Read [model fitness](26-model-fitness-validation.md) for exact class counts, metrics,
  commands, artifact hashes and remaining limits.

## Phase 11 implementation and verification (2026-10-09)

- Added strict runtime validation for the approved checkpoint, SHA-pinned metadata
  and adjacent calibration sidecar, literal class mapping, model version, explicit
  full-frame preprocessing/normalization configuration, runtime dependencies and
  finite state keys/shapes/dtypes/output. Missing/incompatible artifacts fail startup
  with safe codes; the model is loaded once, frozen/eval and cleared on shutdown.
- Added authenticated `POST /api/v1/predict?top_k=4` with unchanged raw JPEG/PNG/WebP
  bytes and `GET /api/v1/model-health`. Existing public `/health` reports basic readiness.
  Startup requires the server-only token even on loopback. Settings/templates are
  explicit; paths resolve relative to the service and credentials remain ignored.
- Uses the exact shared 1.0.0 full-frame pipeline and tensor conversion. Admission
  enforces 5 MiB, ≥16-pixel sides, ≤16 million pixels, MIME/signature/container/full
  decode agreement and still images. Capacity is reserved before buffering; direct
  CPU callers are bounded too. Uploads have a default 10-second deadline.
- Returns class, confidence/top probabilities, model/preprocessing versions, duration
  and explicit uncertainty. With no approved threshold, all current predictions are
  `LOW_CONFIDENCE/THRESHOLD_UNCONFIGURED`. An optional separately pinned policy must
  declare validation-only provenance and bind the checkpoint/validation CSV; no real
  numerical policy is chosen, recalibration performed or TEST images revisited.
- Checks pass: **219 AI tests**, Ruff format/lint over 40 AI files, strict mypy over
  24 app files, **78 shared tests in each environment**, 12 exact synthetic parity
  cases, script lint/compilation, valid uv lock and 43 compatible installed packages.
  One existing Starlette/HTTPX warning remains; dependencies are unchanged.
- Serving exactly matches saved Phase 10.5 tensor/logit SHA values for **16 actual
  TRAIN samples**, four per literal class, via configured `DATASET_PATH`. Mean
  preprocessing/inference **17.75 ms**, median **15.94 ms**, range **11.20–51.40 ms**
  at batch one/two CPU threads, excluding transfer/response serialization; not an SLA.
- Actual loopback Uvicorn passes JPEG/PNG/WebP, auth, malformed/MIME/size cases,
  model readiness, Node-mismatch rejection and six simultaneous requests (one 200,
  five busy 503). Owned process shutdown exits 0; actual missing-checkpoint startup
  exits 3 with a safe error and no rejected path/secret. Final approved-model startup
  also passes after the strict dtype guard. Local measurements/logs remain ignored.
- Frozen Phase 10.5 source/model/report/index identities are preserved. No Node or
  Flutter feature changes, retraining, repeated TEST evaluation or raw dataset edits.
  Updated architecture/startup/API documentation and actual lifecycle decisions.
  See [production ML inference](27-production-ml-inference.md) for exact commands,
  request/response/error contracts, artifact hashes and remaining deployment limits.
- Final repository/template/ignore and whitespace checks pass; 235 local Markdown
  links resolve, 452 source candidates contain no private credentials/dataset path,
  and 171 frozen Phase 10.5 files match working/committed byte hashes. Existing
  unrelated workspace changes are preserved outside the Phase 11 commit.

## Phase 12 implementation and verification (2026-10-10)

- Preserved Phase 7 upload validation, Cloudinary storage, nullable anonymous ownership,
  authenticated farmer ownership and durable upload journal/compensation. Node sends
  unchanged validated bytes to a configured fixed FastAPI endpoint with a server-only
  token, no redirects/URL fetching, bounded deadline and 64 KiB response limit.
- Enforced compatible minimum side/container/orientation/still-image checks without
  ML transforms. Cross-language admission passes all **56 synthetic cases**, 21 accepted
  and 35 rejected. FastAPI stays authoritative; no shared/Python ML source changes.
- Added validated atomic ScanPrediction + COMPLETED transitions, immutable model
  reference, explicit LOW_CONFIDENCE semantics, all four probabilities and inference
  timing. Controlled SHA-pinned registration stores the approved model as VALIDATED
  research, with no production promotion or artifact replacement.
- Added owner/private-key `GET /api/v1/scans/:scanId`, safe FAILED outcomes, same-key
  inference retry without another upload, two-minute attempt UUID fencing and one-minute
  bounded stale recovery. Inference failures preserve saved images/scans. Cleanup CLI
  also recovers interrupted inference; upload scheduling still needs deployment setup.
- Flutter validates typed scan/prediction contracts, communicates uncertainty and saved
  failures, and retains photo/key for retry. It calls only Node; detailed disease-result
  UI and native sign-in remain outside this phase.
- Backend **156 isolated tests** pass with formatting, lint, strict TypeScript,
  build and environment checks. Real PostgreSQL suites pass: **13 domain**, **6 auth**,
  **7 upload** and **7 inference** tests. Adjusted only the negative-auth SQL fixture's
  transaction deadline to 30 seconds after remote latency exceeded its default five
  seconds; application timeouts and assertions remain unchanged.
- Prisma format/validation/client generation pass. All **six atomic migrations** replay
  in an isolated schema; new migration is deployed, history is current and structural
  diff is empty. Catalog has **21 tables / 23 checks / 37 custom triggers**.
- AI **219 tests**, Ruff format/lint and strict mypy pass; one existing upstream warning
  remains. Shared **78 tests in each environment**, strict checks and **12 synthetic
  parity cases** pass. Admission script strict typing and both Node QA syntax checks pass.
- Flutter format/analyzer and **59 isolated tests** pass. Actual loopback FastAPI with
  approved weights passes four live Node JPEG/PNG/WebP scans (anonymous/farmer), owned
  reads and exact same-key replay. Mean synthetic preprocessing/inference is **41.69 ms**,
  excluding upload/network/DB time; this is neither an SLA nor an accuracy claim.
  Complete live Flutter -> Node -> FastAPI -> shared/model -> PostgreSQL -> Flutter
  passes with real Cloudinary. Only owned synthetic assets/rows are removed afterward.
- The live test fixture initially used the safe public account DTO as a database ID;
  corrected to repository lookup, cleaned its temporary account and reran successfully.
  The real AI process loads once and shuts down cleanly. No retraining, TEST evaluation,
  dataset-image reads or raw-file changes occur; 171 frozen ML identities and approved
  weights, AI/shared source and all five earlier applied migrations remain unchanged.
- Updated API/database/architecture/operations/decision/testing documentation. Stop
  after Phase 12; no Phase 13 or subsequent feature starts automatically.
- Final repository/template/ignore and whitespace checks pass; 249 local Markdown
  links resolve and 471 source candidates contain no private environment credentials
  or machine-specific dataset path. Existing unrelated workspace changes are preserved
  outside the Phase 12 commit.

## Phase 13 implementation and verification (2026-10-10)

- Completed the farmer scan/results flow with friendly literal-class presentation,
  model score/uncertainty, image, local scan/inference time, lifecycle/model versions,
  safe invalid-image/offline/timeout/failed-analysis retry and bounded pending polling.
  Same-image retry preserves bytes/private key; a new scan clears the draft.
- Added FARMER-only `GET /api/v1/scans` with default20/max50 pagination, UUID cursor,
  native timestamp/ID ordering, safe shared projections, no-store/rate limits and
  owner checks. Guests have no history; ADMIN and other-farmer access are denied.
  No tables or migrations added; the six existing migrations remain unchanged.
- Added minimal farmer login/logout with in-memory credentials/restricted refresh
  cookie, serialized expiry refresh and identity revisions. Current401 clears the
  session; delayed old401/refresh failures cannot clear a new login. Routes discard
  old private extras and scoped state after identity changes. Offline logout clears
  local state with honest feedback; persistent/browser sessions remain deferred.
- Flutter formatting/analyzer and **110 isolated tests** pass (three live opt-ins
  skipped in the isolated suite). Android debug APK build passes. New coverage includes 20 history cases, 14 result/
  scan cases, 14 native-session cases and three complete route/widget flows.
- Backend format/lint/strict TypeScript/build/environment and **162 isolated tests**
  pass. New actual PostgreSQL history suite **4 tests** passes, including microsecond
  ordering, tied IDs, new inserts between pages and foreign/anonymous cursor isolation.
  Prisma validation and six-migration status pass; database is up to date.
- FastAPI regression **219 tests**, Ruff format/lint and strict mypy pass, with one
  existing upstream TestClient deprecation warning. AI/shared/model/training source,
  class mapping, preprocessing and unapproved confidence policy remain unchanged.
- Actual live Flutter guest and farmer chains both pass through Node, real Cloudinary,
  private FastAPI/shared/model and PostgreSQL. Farmer login/history/detail, cross-farmer
  detail/cursor denial and logout pass. Two synthetic images and two throwaway farmers
  were cleaned. FastAPI loads once and exits gracefully with code0. No dataset or
  test-partition images were read, no evaluation repeated and no model overwritten.
- Updated [workflow/API/session documentation](29-farmer-detection-history.md),
  architecture, decisions, roadmap, checks and component READMEs. Existing unrelated
  workspace changes remain preserved outside the Phase 13 commit.

## Current limitations and pending decisions

- V1 transformed-parent leakage invalidates historical independence claims; original
  run/recovery/artifacts remain immutable. Corrected v2 repairs all confirmed families
  and excludes four newly contradictory families without raw edits. Unresolved pair 24
  may relate TRAIN/VAL Healthy images; physical plant/session identity remains unavailable.
- Fresh v2 fits successfully with patience 3, stopping at epoch 11 with epoch 8 selected;
  mild internal overfitting (unaugmented accuracy gap 2.57 percentage points), no
  significant task underfitting. Test GLS recall 83.53%/F1 0.8659; Corn-only VAL GLS
  recall 2/9 and source accuracy 77.08% show domain weakness. Confident wrong
  predictions persist (three test errors above 0.99). Calibration cross-fitting does
  not improve diagnostics; calibration is disabled, T=1, and no threshold is locked.
- The corpus was previously inspected/its v1 test consumed. V2's single final test is
  descriptive; it is not fresh external/field validation. Classifier seed stability,
  plant/field independence, OOD/maize rejection and clinical/agronomic validity remain
  unestablished. Commercial clearance and deployment uncertainty policy remain open.

- Starlette TestClient emits one upstream deprecation warning recommending httpx2.
  Existing HTTPX remains locked and tests pass; a test-client migration is maintenance
  work rather than an unverified change to this phase's dependency baseline.
- Shared preprocessing has dataset-wide mechanical checks and sampled real-image
  visual review, without annotated lesion ground truth or independent field accuracy.
  Perimeter-camouflaged leaf edges can still be removed before uncertainty gates detect
  them; outward padding does not guarantee recovery. Resize can lose tiny lesions.
  Extraction retains background for almost all current images and does not identify
  maize. The user approved full-frame policy, invalid/conflicting-family exclusions and
  academic/FYP use. Commercial licensing or source replacement remains required. Future
  deployment needs worst-case memory/time profiling and target-platform codec parity;
  representative local latency and bounded six-request concurrency are now verified.
- Phase 12 resolves the observed Node/shared admission mismatch: minimum-side,
  container termination/length, malformed orientation and animated PNG guards agree
  on 56 synthetic cases. FastAPI remains authoritative for ML/profile/codec validation;
  accepted-scan failures retain the asset/record and explicit FAILED outcome.
- FastAPI provides classifier readiness, validated startup and internal predictions;
  Node orchestration is implemented. Retrieval/generation remain future work. Deployment
  requires private networking, TLS, coordinated token rotation and deployment-specific
  limits. Generic library/server log events intentionally omit diagnostic messages
  to protect secrets. Python 3.11.0 remains the workstation baseline; provision a
  maintained 3.11 patch release for a new/production environment.

- Dependency audit reports four high-severity entries (`prisma`, `@prisma/config`,
  `deepmerge-ts` 7.1.5, and `mysql2` 3.15.3), including propagated reports from
  [recursive merging](https://github.com/advisories/GHSA-ggr8-5vv4-36mx),
  [MySQL authentication](https://github.com/advisories/GHSA-3f6p-5ww8-9rcr), and
  [MySQL decompression](https://github.com/advisories/GHSA-rgwj-5xj2-c3m3).
  Both vulnerable versions already existed in the Phase 2 lock. npm's suggested
  automatic remediation downgrades Prisma to 6.19.3, conflicting with the verified
  Prisma 7 architecture; no forced downgrade or unverified major transitive override.
  Audit also reports these with omit-dev due to the dependency/peer graph. The
  implemented PostgreSQL health/auth paths do not use MySQL or merge client-supplied
  object graphs, but dependency remediation remains a follow-up maintenance issue.
- Rate-limit counters are per-process/in-memory. Shared storage, proxy trust and
  least-privilege database roles must be chosen for an actual deployment. Default
  binding is loopback; LAN/container hosting needs explicit HOST/CORS configuration.
- Production auth requires HTTPS and same-site browser hosting for Strict cookies.
  Clients must serialize refresh calls; parallel/retried token reuse requires login again.
  Hashing throughput and native Argon2 deployment compatibility need deployment checks.
  Email verification, password recovery/change, MFA, security-event auditing, session
  management and expired-session cleanup remain future work. Future password/status
  management must revoke affected sessions; current access checks already reject inactive accounts.

- Persistent secure token storage, browser/mobile registration, session-aware admin
  navigation, localization, dark theme and remaining business workflows are future work.
  Native farmer login/logout/refresh are now implemented with volatile credentials;
  restarting requires sign-in and offline logout cannot confirm server revocation.
  Android debug APK builds; physical devices, iOS scaffolding/permissions and release
  packaging/signing remain unverified. Public API configuration is required for upload.
- Interactive Android gallery/capture needs a responsive emulator or physical device;
  a previously recorded emulator-5554 System UI ANR blocked historical checks and was
  not reproduced or cleared by this audit. APK/plugin compilation, picker
  routing/error tests and complete live Flutter upload through a synthetic image source pass.
- Schedule `npm run scans:cleanup` from backend every five minutes for crash/unknown
  outcome recovery. No OS task/deployment worker was installed. Recovery depends on
  database/provider availability; completed-scan retention and deletion are deferred.
- Signed Cloudinary URLs are persistent bearer capabilities; avoid publishing/logging
  them. Original photos can retain EXIF/location data. Future owner-checked delivery
  policy and successful-scan retention require an explicit later decision.
- Docker Engine/Desktop is not installed. Compose configuration passes validation;
  container startup is unverified. The complete schema and pgvector are verified on Neon.
- The preserved native Windows PostgreSQL installation lacks pgvector binaries;
  install the extension before applying Phase 2 migrations there, or use Neon/pgvector Compose.
- pg 8.23 can emit a query-queue deprecation warning during Prisma internal related
  queries; verified transactions pass. Keep the current lock until future adapter/pg compatibility is checked.
- CPU ML environment and the first transfer-learning baseline are implemented;
  GPU/CUDA, further validation-only experiments and model promotion remain future work.
- Production hosting/promotion, local agronomic/source-freshness review, deterministic
  agricultural rules, larger retrieval evaluation/relevance policy, detailed
  business APIs and completed-scan retention/Cloudinary deletion remain pending. The initial light
  design system is implemented; domain workflow designs remain future work.
- Prisma seed data remains intentionally empty; reviewed knowledge is ingested explicitly.
  Database checks enforce structure/provenance presence;
  future services must validate full JSON contracts, agricultural sources, hashes, authorization,
  uploads, and deterministic formula semantics. Separate least-privilege runtime roles remain future work.

## Phase 14 implementation and verification (2026-10-12)

- Inspected instructions/state/decisions, database/RAG/AI architecture, schema,
  existing API/service structure, locked dependencies and templates before edits.
  Live starting counts: zero diseases, sources, documents and chunks.
- Completed required Phase 6 foundations using existing tables: sourced active
  catalogue/detail APIs and controlled local-reviewed corpus ingestion. Four sources,
  four literal labels, 25 document versions and 25 READY vectors are now present.
  Re-ingestion reports `created=0, unchanged=25` without provider calls or new rows.
- Google/Gemini embedding provider was explicitly user-approved. Configure text-only
  `gemini-embedding-001`, deployment version `google-task-v1-20261012`, dimensions 768,
  L2 normalization and exact cosine retrieval. No provider model/key fallback in source.
- Added topic/provenance/chunk metadata/embedding version in the seventh migration,
  then corrected the READY guard for restricted schema search paths in an eighth
  migration. Both are applied; eight migrations replay cleanly in a temporary schema,
  Prisma validation/client generation succeed, status is current and diff is empty.
  There remain 21 tables, 26 checks and 38 custom triggers. Six pre-existing migration
  files are unchanged. Test schemas are removed and relational fixtures roll back.
- Documents preserve original sources/review/rights/region and immutable configuration;
  deterministic `unicode-char-window-v1` records offsets/hashes, explicit windows and
  overlap. Prepare embeddings before a locked atomic transaction; archive previous
  versions without deleting chunks, reject changed same-version payloads and preserve
  unchanged historical attribution. READY vectors cannot be replaced.
- Retrieval filters active English disease documents, active catalogue entries and
  exact embedding/config identity, plus optional literal label/topic/active version.
  Exact vector search suits 25 chunks; no premature approximate index or extra tables.
- Live checks fixed actual integration issues: ignored AI configuration referenced
  a different unmigrated local database; libpq needed public CA roots for verified TLS
  on Windows; Neon rejected startup options, now set per transaction with no schema
  fallback. Real Google returned 3,072 values for ignored nested config; explicit
  documented task/output fields return 768, and incompatible vectors fail closed.
- Verified actual Node -> authenticated FastAPI -> Google -> PostgreSQL for all four
  labels, source retention and empty Healthy management. Internal missing-token requests
  fail. One owned lifespan also serves the unchanged model on a generated PNG and exits
  gracefully with one startup/shutdown; no raw dataset partition is read.
- Saved development evaluation: 16/16 positive expected-document hits at top three
  with filters and separately 16/16 unfiltered across the corpus; 3/3 unsupported
  Healthy topics are empty. Mean retrieval 3,899.32 ms locally. This small curated set
  is not independent agronomic validation or a calibrated insufficient-evidence policy.
- Tests/checks: backend format/lint/strict types/build/dependency probe and 180 isolated
  cases; 13 real relational checks; AI 260 isolated cases and three separately enabled
  real ingestion/version/vector/source/filter/immutability/isolation checks; Ruff/strict
  mypy; shared preprocessing 78 cases in each environment and 12 synthetic parity cases;
  Flutter analyzer and 110 unchanged tests (three opt-in live tests skipped in default run).
- Source-secret/template/ignore/local-link/whitespace checks and frozen artifact proof
  run before commit. The 171 hash-bound ML files, approved weights, shared/mobile source,
  unrelated user `.gitignore`/ML workspace edits and raw dataset remain unchanged.

Public APIs: `GET /api/v1/diseases`, `GET /api/v1/diseases/:slug`,
`POST /api/v1/knowledge/search`. Internal: `POST /api/v1/retrieve`.
Responses carry evidence candidates and original provenance; cosine similarity is
not confidence. Safe errors, size/deadline/concurrency/rate limits and routed no-store apply.
No answer generation, Flutter knowledge UI or full admin editing starts here.
Remaining limits: U.S. regional and partly 2018-reviewed sources, local agronomic
review, independent/out-of-domain retrieval evaluation, production least-privilege
roles/hosting/shared limits and future generation evidence policy. Existing model,
mobile persistence/platform and dependency advisory limitations remain documented.
See [knowledge/retrieval](30-knowledge-retrieval.md) and
[saved evaluation](../ai-service/evaluation/results/maize-extension-v1-google-task-v1-20261012.json).

## Phase 15 grounded generation verification (2026-10-13)

- Added centralized versioned prompts, strict evidence-selection schema, bounded
  reviewed context and official SDK client. Only retrieved complete canonical
  paragraphs covered by verified offsets are rendered; overlapping chunks merge,
  gaps and inconsistent repeated chunk IDs fail closed. Content/source/curation
  identity must match the pinned reviewed corpus/ledger. Competing approved topic
  documents abstain; fresh database versions require a reviewed deployment update.
- General questions use one literal maize class/topic with conservative English
  recognition or explicit filters. Missing Healthy disease topics, multiple inferred
  topics, unrelated/numerical requests and recognized injection patterns abstain.
  These are bounded admission rules, not comprehensive semantic relevance or
  injection detection; no arbitrary cosine cutoff is invented.
- Node adds `POST /api/v1/knowledge/ask` and
  `POST /api/v1/scans/:scanId/explanation`. FastAPI exposes protected internal
  `POST /api/v1/generate` and `POST /api/v1/explain`. Existing farmer ownership and
  anonymous original-key capabilities precede provider work. Caller-submitted
  classifier/context/knowledge payloads are rejected. No widget calls FastAPI.
- Persisted classifier label, confidence, model/preprocessing versions and all
  uncertainty fields round-trip unchanged. Gemini selects evidence IDs only;
  factual sections/source references are server-built reviewed corpus excerpts.
  Even a high score keeps `LOW_CONFIDENCE/THRESHOLD_UNCONFIGURED` explicit.
- Credentials and generation model are server-configured, never supplied to Flutter.
  Generation is opt-in; invalid startup review/config fails safely. One SDK/custom
  HTTPX client is owned and closed per lifespan. Provider raw JSON is limited to
  128 KiB before SDK parsing, one attempt, no redirects/compression, and structured
  text is capped at 8 KiB. HTTPX I/O timeout plus elapsed checks is not a strict
  total deadline; Node independently enforces its configured 30-second full deadline.
  Five requests/minute per IP and two concurrent generation slots are defaults.
- Operational logs retain only allowlisted metadata, not question/prompt/body/key
  content. Existing AI conversation tables are unused until retention is defined.
  No migration, corpus mutation, classifier retraining or ML threshold change occurs.

| Check | Result |
|---|---|
| `scripts/check-development.ps1 -Component AI` | Ruff format/check, strict mypy over 43 modules, 321 tests pass; three opt-in PostgreSQL tests separately enabled below |
| AI `RUN_RAG_DATABASE_TESTS=1 pytest tests/test_rag_database.py -q` | Three pass in owned disposable schemas, including version/pgvector/source/filter/immutability behavior |
| Backend `npm run check` | Format/lint, strict TypeScript, build, 202 isolated tests and dependency import probe pass |
| `scripts/check-development.ps1 -Component Prisma` | Prisma validation/client generation/typecheck, 13 real PostgreSQL checks and migration status pass; all eight migrations current |
| Backend `RUN_LIVE_GENERATION=1 npm run test:generation:live` | Nine checks pass (parent plus eight subchecks); four class answers, four local abstentions, guest/farmer explanations, ownership/body-forgery rejection; fixtures cleaned |
| Owned actual AI lifespan | Model, RAG and generation ready; unauthorized internal calls fail; unchanged classifier processes generated PNG; one startup/shutdown and clean exit; no raw dataset reads |
| Shared preprocessing regression | 78 tests in each consumer environment, strict types/lint/format and 12 synthetic training-serving parity cases pass |
| Repository/security/artifact checks | Templates, ignores, documentation links, whitespace, secret/private-path scans and frozen source/weight/corpus/migration proof pass |

[Saved metadata-only live evaluation](../ai-service/evaluation/results/grounded-evidence-selection-v1-20261013.json)
records ten case outcomes, model/prompt/context/review identities and six provider
timings. Mean 4,937.62 ms measures FastAPI retrieval/context/Gemini processing,
excluding Node authorization/database/network overhead. Ownership explanation
fixtures are controlled persisted synthetic predictions; a separate generated PNG
verifies the unchanged actual classifier in the same lifespan. No class accuracy,
agronomic truth, independent field usefulness or final-test performance is inferred.

All test-created model/scan/journal/account rows are removed; no Cloudinary asset
is created by these Phase 15 fixtures. Knowledge counts remain four diseases/four
sources/25 documents/25 READY vectors. The 171 hash-bound ML files, approved
checkpoint, shared/mobile source, eight migrations and reviewed corpus remain
unchanged. Unrelated user ignore/ML workspace/state-section edits are preserved
outside the phase commit.

Remaining issues: independent/local agronomic and source-freshness review, narrow
English single-topic support, uncalibrated retrieval relevance, no exhaustive semantic
injection guarantee, private production hosting/least-privilege credentials/shared
rate limits and retention policy. Existing model/domain/commercial licensing limits
remain. Test tools emit existing Starlette/httpx and pg query deprecation warnings;
these do not fail checks. Flutter knowledge/assistant UI, admin editing, persistence
and free-form model-authored factual paraphrases remain outside this baseline.

## Phase 16 farmer assistant verification (2026-10-14)

- Replaced the assistant placeholder with route-scoped Provider/ChangeNotifier
  MVVM: View -> ViewModel -> repository -> datasource -> shared API client -> Node.
  Six composed assistant widgets handle suggested questions, explicit focus,
  conversation turns, verified answer sections/references and selected scan context.
  No widget calls HTTP, Gemini or FastAPI directly, and no new dependency is added.
- Store at most 12 volatile turns in this screen; no database/local-file conversation
  history is written. Each request carries the current question and optional known
  disease/topic enums only. Clears/route disposal/account revision changes remove
  state and discard late results. Switching tabs may retain the open route; closing
  the assistant or changing identity clears it, as described in the UI.
- Support 3–1,000 Unicode code points, at most 1,800 UTF-8 bytes and safe controls.
  Shared pure client validation avoids inconsistent limits; Node remains authoritative.
  An explicit known class filter now supplies bounded maize scope for a short follow-up.
  Existing unsupported-topic/injection, missing-evidence and reviewed-source checks remain.
- Immutable typed response parsing enforces statuses/policy versions, citations/source
  membership and provenance, finite numbers and coherent classifier uncertainty.
  Reviewed content and source URLs render as plain/selectable text, without HTML,
  executable links or source fetching. Non-grounded answers display honest abstention.
- Farmer scan context uses private paginated history or an explicit completed-result
  action. The request sends only scan ID and `{}` with the existing bearer session;
  Node verifies ownership and uses its persisted prediction. The seven returned
  classifier fields must match, and high scores retain LOW_CONFIDENCE/null-threshold
  warnings. Guest UI supports questions without personal scan/conversation history.
- Loading, clear, retry, no-network, timeout/provider failure, empty/missing evidence,
  long input, keyboard, narrow phones and large text are verified. The assistant uses
  a 40-second request-specific deadline; the generic 15-second timeout and Node's
  strict 30-second generation deadline remain unchanged.

| Check | Result |
|---|---|
| Dart formatting and `flutter analyze` | 99 Dart files formatted, analyzer has no issues |
| Complete `flutter test` | 175 pass, four explicitly opt-in live tests skipped in the default run |
| Assistant coverage | 36 model/repository, 10 ViewModel, 15 widget, three navigation/privacy/pagination cases plus shared request-timeout regression pass |
| Real `scripts/check-assistant.mjs` | One enabled Flutter contract passes questions/follow-ups/sources, scope/injection/long-input limits, absent Healthy management, owned scan explanation/unchanged uncertainty and cross-farmer denial |
| Backend `scripts/check-development.ps1 -Component Backend` | Format/lint/strict types/build, all 202 tests and dependency probe pass; existing server application source unchanged |
| AI `scripts/check-development.ps1 -Component AI` | Ruff format/check, strict mypy over 43 modules and 325 tests pass; three opt-in SQL checks default-skip, previously verified in Phase 15 |
| Prisma validation/migration status | Valid schema; eight unchanged migrations current, no Phase 16 migration required |
| Repository/security/frozen proof | Required files/templates/ignores, local links, whitespace, secret/private-path scans pass; 171 ML files/approved checkpoint/shared package/corpus/backend/eight migrations unchanged |

[Saved metadata-only live evidence](../ai-service/evaluation/results/farmer-assistant-contract-v1-20261014.json)
records six generation outcomes with three actual provider calls, the unchanged
generation model/prompt/review identities and one clean startup/shutdown. Mean
FastAPI retrieval/context/generation time is 5,524.50 ms, excluding Node authorization
and Flutter/network overhead. The ownership fixture is a controlled persisted synthetic
Common_Rust prediction; this is a contract check, not classifier accuracy, field-image
validation or independent agronomic assessment. No raw dataset partition is read.

The initial attempt on October 13 returned genuine Google 503 responses. Local safe
error handling passed; test-created rows were cleaned. On October 14 the original
configured model recovered and the full contract passed without model switching,
fallback output or relaxed validation. Knowledge counts remain four diseases/four
sources/25 documents/25 READY vectors, and no Cloudinary asset is created by these tests.

Remaining limits: small English single-topic corpus, source freshness/local agronomic
review and wider semantic/injection evaluation; no durable conversation/session
retention, offline factual assistant, new calculators/admin functions or production
hosting/shared limits. Existing classifier research/commercial restrictions remain.
No deployment, new platform or ML/data change is introduced. Unrelated user workspace
edits remain outside the phase commit. Stop after Phase 16.

## Phase 17 fertilizer calculator verification (2026-10-15)

- Reused existing Fertilizer/FertilizerRule/CalculatorConfig/AuditLog tables and
  immutable payload/identity guards; no migration, dependency or seed data added.
  Public catalogue/calculation routes and authenticated ADMIN draft/status routes
  follow Route → Controller → Service → Repository → Prisma. Controllers stay thin.
- Engine `area-rate-v1` supports positive decimal-string area up to 1000000 in the
  entered unit, six decimal places, HECTARE/ACRE and KG/G. Reviewed product rate
  strings are nonnegative up to 1000000 kg/ha. Exact BigInt coefficients preserve
  international-acre conversion `0.40468564224` ha and 1000 g/kg; no intermediate
  rounding. Config pins zero to six output places and HALF_UP; exact unrounded
  value and positive-rounded-zero warning remain visible. Bounds are operational,
  not agronomic advice; N/P2O5/K2O label percentages are not dosage inputs.
- Admission requires known MAIZE algorithm/engine, exact rule/config units,
  reviewed source/actor/time/note, applicability/assumptions and a frozen full
  product snapshot. Mutable product drift and incompatible stored JSON fail closed.
  Unknown caller rates/formulas/review fields are rejected. One repeatable-read
  snapshot binds rule/config; stale pins return 409 and require explicit review/retry.
- ADMIN writes use existing JWT/live-session RBAC, shared advisory locking and
  bounded 10-second acquisition/15-second metadata transactions. Activation retires
  prior active rule/config versions atomically without rewriting historical payloads.
  Same-version/different payload conflicts; CREATE/ACTIVATE/DEACTIVATE audit retains
  actor/request/version. Public responses omit reviewer IDs/internal JSON/secrets.
  Review attestation remains an authorized human trust boundary, not URL validation
  of agronomic truth. Publishing a new global config needs compatible rule versions.
- Feature-local ChangeNotifier state sits above typed repository/datasource/shared
  API client. Widgets make no HTTP calls or quantity conversions; exact server
  decimal strings are preserved. Editing, reload/disposal fence delayed results;
  stale-rule retry refreshes only and requires a new explicit calculation. Sources
  are plain selectable references, and guest/farmer calculations have no account
  association, credentials on public requests or persisted calculation history.
- Final code review removed duplicate snapshot comparison/unused error code, used
  executeRaw for PostgreSQL void-returning locks and fixed malformed percentage
  refinements to return 400 instead of Decimal errors. Twelve malformed N/P2O5/K2O
  inputs and all existing valid/boundary/version/error cases pass. No TypeScript any,
  frontend secrets, fake production rates or Gemini numeric path is introduced.

| Check | Result |
|---|---|
| Backend `npm run check` | Format/lint/strict types/build, dependency imports and 239 tests pass, including 37 calculator cases |
| Final changed-core checks | Format/lint/typecheck/build pass; all 37 focused cases pass, then 17 HTTP/service cases verify the malformed-percentage fix |
| `npm run test:fertilizer:database` | Five real PostgreSQL checks pass: active snapshots, immutable rule/config payloads, one-active constraints and inactive exclusion; fixtures roll back |
| Dart formatting / `flutter analyze` | Formatting passes and analyzer has no issues, including final live-test source |
| Complete `flutter test` | 221 isolated tests pass; four existing live tests skip by default; the new opt-in calculator test separately default-skips and passes when enabled |
| Calculator Flutter coverage | 34 input/model/repository/ViewModel plus 12 widget cases pass; includes pending content, error/retry/stale rules, exact string/units, 320px/200% text/keyboard/long sources |
| `node --env-file=backend/.env scripts/check-fertilizer.mjs` | Real Node/Prisma/PostgreSQL ADMIN draft/publish/source/review/audit/replacement/drift/deactivation checks and one enabled Flutter guest/farmer contract pass; every synthetic write rolls back |
| Prisma validation / migration status | Schema valid; eight unchanged migrations current, no Phase 17 migration needed |
| Repository/security/frozen checks | Required files/templates/ignores, local documentation links, whitespace, secret/private-path scan pass; 171 ML files/checkpoint/shared/AI/corpus/schema/migrations unchanged; user edits preserved |

The first live-contract attempt reached valid results but its test omitted the
authentication flag for the FARMER admin-denial assertion, producing 401. Correcting
the test to send its existing bearer session verifies the intended 403; the entire
contract then passes. Both attempts roll back all synthetic data. No actual dosage
source is approved by these tests, and no Gemini/model/Cloudinary call is involved.

Remaining prerequisite: authoritative project-approved fertilizer products/rates
with applicable region/crop/conditions and local agronomic review. Production
catalogue remains honestly PENDING_RULES; the calculator scales a reviewed rate
rather than diagnosing nutrient needs. Full admin UI, AI calculator explanation,
calculation retention, offline recommendation data, yield calculator and deployment
remain outside this phase. Existing classifier/corpus/commercial restrictions and
shared production rate-limit requirements remain. Unrelated user ignore/ML/state
workspace edits are preserved outside the phase commit. Stop after Phase 17.

## Phase 18 expected-yield verification (2026-10-15)

- Read AGENTS/state/decisions/schema, Phase 17 code/docs, current Flutter yield
  placeholder and project sources. Repository seeds contain no approved yield data;
  read-only PostgreSQL inventory confirms zero YIELD configurations. Implemented a
  framework with explicit pending agronomic configuration instead of guessed formulas.
- Template `AREA_TIMES_REVIEWED_YIELD_RATE_V1`, formula version
  `area-times-reviewed-yield-rate-v1`, engine `area-yield-v1` supports only cultivated
  area and a selected reviewed kg/ha configuration. Input pins UUID/version; area
  is positive up to 1000000 in HECTARE/ACRE with six decimal places. Configuration
  rate is a nonnegative decimal string up to 1000000 kg/ha. Operational limits do
  not assert plausible yields. Output is KG or metric TONNE; one tonne is 1000 kg.
- Extracted one common BigInt decimal/unit implementation and admission contract
  from Phase 17. International acres retain exactly 0.40468564224 ha, no intermediate
  rounding; output uses configured zero to six places with HALF_UP. Results preserve
  exact unrounded quantity, assumptions, source, config/formula/engine versions,
  unit reference and conditional planning language. Tiny positive rounded zeros are
  disclosed. Fertilizer kg/gram values, public API and `area-rate-v1` remain intact.
- Existing immutable CalculatorConfig/YIELD and audit records suffice. ADMIN
  creation fixes template/crop/rounding and stamps review actor/time. Source URL,
  citation, applicability/assumptions, review note and known model versions are
  required. Activation validates and atomically retires the prior active version;
  write locking and bounded metadata transactions preserve historical payloads.
  Stale/retired selections return 409, incompatible data 503, bad input 400.
  Public responses omit internal JSON, reviewer IDs/secrets; no personal calculation
  history, arbitrary formula evaluation or automatic source fetching is introduced.
- Flutter keeps feature-local Provider/ChangeNotifier state and typed repository
  calls through the existing API client. Shared wire helpers/area validation/source
  models/form controls avoid duplicated calculator logic while preserving old type
  names. Widgets perform no HTTP or quantity math. Applicability/assumptions/source
  are visible before calculation, and result strings/precision/versions remain exact.
  Edits/reload/disposal fence late results; stale retry refreshes for explicit review
  and recalculation. Keyboard, 320px/200% text, scrolling and long references pass.

| Check | Result |
|---|---|
| Backend `npm run check` | Format/lint/strict TypeScript/build, dependency imports and all 266 tests pass, including 27 yield engine/service/HTTP cases |
| Expanded stored-config admission check | Five service cases pass after explicitly testing unknown formula/engine/algorithm/crop, missing approval and invalid rate/rounding |
| Dart format / `flutter analyze` | 131 Dart files checked/formatted; analyzer reports no issues |
| Complete `flutter test --no-pub` | 249 pass, six opt-in live contracts default-skip; 22 yield input/model/repository/ViewModel and six widget cases pass |
| `node --env-file=backend/.env scripts/check-yield.mjs` | Real ADMIN/auth/source/review/audit/publication, SQL immutable/one-active constraints, version replacement/stale rejection/retirement and enabled Flutter guest/farmer acre/kg/tonne/ADMIN-denial contract pass |
| `node --env-file=backend/.env scripts/check-fertilizer.mjs` | Prior calculator real HTTP/Prisma/PostgreSQL/Flutter contract passes after exact-unit/form/source reuse; every synthetic write rolls back |
| Prisma validation/migration status | Valid schema; all eight existing migrations current; no schema/seed/dependency change |
| Repository/security/frozen proof | Required files/templates/ignores, local links, whitespace, configured-secret/private-dataset-path checks pass; all 171 frozen ML files/checkpoint/shared/AI/corpus/schema/eight migrations unchanged |

The live contracts verify unchanged production counts after rollback, including
yield configurations/accounts/sessions/audits/history and fertilizer configuration.
No provider, ML, Cloudinary or raw dataset operation is performed. Synthetic test
values and review attestations establish arithmetic and access/version contracts
only; they do not approve any real agronomic model or rate.

Remaining prerequisite: authoritative project-approved yield formula and applicable
data with source, crop/region/conditions and local agronomic review. The current
projection template may be published only if that review justifies area-rate use;
a different empirical model requires a separately implemented/versioned template.
No guaranteed harvest, disease/soil/weather adjustment, AI explanation, calculator
history, full admin dashboard, analytics or deployment is added. Existing source,
classifier/commercial and production rate-limit/retention limitations remain.
Unrelated user ignore/ML/state edits are preserved outside the phase commit.
Stop after Phase 18.

## Phase 19 farmer analytics verification (2026-10-15)

- Read project instructions/state/decisions, Prisma schema, scan persistence/history,
  auth/session middleware, Flutter routing/session/API/design system before changes.
- Added FARMER-only `GET /api/v1/analytics/scans` and
  `GET /api/v1/analytics/scans/activity`, through route/controller/service/repository.
  Every query derives ownership from the live session. Guest/invalid sessions get
  401, ADMIN 403, foreign/anonymous/out-of-window cursors 404. No anonymous scan is
  attached to an account. Responses use no-store and omit private configuration.
- Strict filters require actual paired UTC dates, ordered/not future, at most 366
  days; default last 30 inclusive. Activity limits 1–50 (default 10), native database
  timestamp/UUID cursors and owner/range checks avoid JavaScript microsecond loss.
  Added validated `ANALYTICS_RATE_LIMIT_MAX` default 30/minute/IP, sharing the
  endpoint limiter and retaining global rate limiting.
- One parameterized SQL aggregate uses existing owner/date and prediction indexes.
  Total/lifecycle counts, healthy/disease/legacy labels, policy-flag counts and all
  UTC daily buckets reconcile. Only the latest result of each COMPLETED scan
  contributes a prediction; missing results remain explicit. Multi-model ties use
  prediction timestamp/UUID descending consistently with scan detail. No model
  accuracy, average confidence correctness or prevalence is inferred.
- Flutter uses feature-local ChangeNotifier/Provider, repository and shared bearer
  client. Private data clears/hides across session revision changes, delayed replies
  are fenced, and statistics are not persisted. Date presets/custom dates, summary
  cards, accessible count bars, up to six contiguous time periods, recent activity,
  load-more and existing owned detail support guest/empty/loading/error/retry states.

| Check | Result |
|---|---|
| Backend `npm run check` | Format/lint/strict TypeScript/build/environment imports and all 278 tests pass; 12 new analytics service/repository/HTTP tests |
| Dart format / `flutter analyze` | All 141 Dart files formatted; analyzer reports no issues |
| Full `flutter test --no-pub` | 270 pass, seven opt-in live contracts default-skip; 21 new analytics model/repository/ViewModel/widget cases |
| Real `node --env-file=backend/.env scripts/check-analytics.mjs` | SQL/latest-model/status/legacy/empty/UTC/microsecond/cursor/ownership/API and enabled Flutter contracts pass; all synthetic writes rolled back |
| Local query plan | Eight eligible scans amid 7,000 bulk excluded rows plus individual boundary fixtures; existing owner/date index selected; execution 0.268 ms, planning 0.299 ms, excluding network; no production benchmark claim |
| Prisma validation/status | Valid schema; all eight migrations current, no schema/seed/index/dependency change |
| Repository/privacy/frozen checks | Required files/templates/ignores, local Markdown links, whitespace and private-secret/path checks pass; 171 frozen files/checkpoint/shared/AI/corpus/schema/migrations and unrelated user edits preserved |

The rollback fixture yields eight own scans: five completed, one pending, one
processing, one failed. Four latest predictions comprise one Healthy, two disease
and one legacy label; one completed result is missing. Flags are two LOW_CONFIDENCE,
one CONFIDENT and one legacy/unavailable. UTC daily counts are five and three.
Other farmers/anonymous/out-of-window scans never contribute. Multiple model
versions count once, and tied microseconds paginate without loss/duplication.

Production-scale concurrency/very large histories need workload measurements.
Separate summary/activity HTTP requests do not form a frozen snapshot during new
scans/status changes. Deployment still needs shared rate-limit/retention policy;
existing classifier/source/licensing/calculator-content limitations remain. No
new provider/cloud/raw-dataset operation, ML evaluation/training or Phase 20 work
is performed. Unrelated user ignore/ML/state edits stay outside the phase commit.
Stop after Phase 19.

## Phase 20 Admin dashboard verification (2026-10-15)

- Inspected instructions, state/decisions, Prisma, scan/auth/analytics/inference/
  generation code and Flutter session/routes/Admin placeholder before implementation.
  Existing backend ADMIN provisioning/RBAC works; Flutter previously accepted
  FARMER grants only. AI generation does not journal request data.
- Added one ADMIN-only dashboard route through controller/service/repository. One
  parameterized SQL statement returns current all-time FARMER status counts,
  selected-window global scan lifecycle/ownership/latest-prediction counts, daily
  dates/class distribution, bounded production registry status and ten minimal
  recent entries. Shared Phase 19 logic keeps counting/ties/date validation/zero
  buckets consistent. No emails, owner/scan IDs, image URLs or artifact paths leak.
- Reused 1–366-day UTC paired dates (default last 30), analytics rate-limit setting,
  no-store/central errors and safe count conservation. ADMIN authorization precedes
  query execution; missing/invalid/revoked access is 401, FARMER is 403. Unknown,
  partial, invalid/future/reversed/excessive filters are 400.
- Production registry reports NOT_PROMOTED/SINGLE_PRODUCTION/MULTIPLE_PRODUCTION,
  returning a version only for one actual production row. Configured inference
  version is separate, readiness NOT_CHECKED. AI statistics NOT_RECORDED reflects
  actual persistence coverage, not a fabricated zero or provider health claim.
- Extracted tested shared SessionAccount/Repository/ViewModel mechanics, retaining
  Farmer-only wrappers/admission. Admin uses separate volatile token/cookie/client/
  Provider identity; wrong-role grants are logged out and discarded. Admin route
  is outside farmer navigation with explicit return/sign-out, shared visual
  tokens/cards/bars/time periods, date presets, loading/retry/error, empty scans
  with real account/system summary and recent activity without identities/photos.
  Revision/disposal/filter fences prevent delayed responses restoring private data.

| Check | Result |
|---|---|
| Backend `npm run check` | Format/lint/strict TypeScript/build/environment imports and all 286 tests pass; eight new Admin service/repository/API cases |
| Flutter format/analyzer | All 157 Dart files formatted; analyzer reports no issues |
| Full `flutter test --no-pub` | 282 pass, eight opt-in live checks default-skip; 12 new Admin session/model/repository/ViewModel/widget tests |
| Real `scripts/check-analytics.mjs --admin` | Enabled Flutter → Node → PostgreSQL Admin contract and global/count/ownership/latest-result/UTC checks pass; synthetic writes all roll back |
| Existing no-flag analytics contract | Farmer ownership/date/native-microsecond/cursor/DTO regression passes after shared session/aggregate extraction; synthetic writes roll back |
| Global aggregate query plan | 6,010 selected fixture scans plus older/boundary rows, one aggregate statement; 24.241 ms execution/0.620 ms planning locally, existing scan status/date index used; not a production load benchmark |
| Prisma validation/status | Valid schema; eight migrations current, no schema/index/seed/dependency change |
| Repository/security/frozen checks | Required files/templates/ignores, local links, whitespace and configured-secret/private-path checks pass; 171 frozen files/checkpoint/shared/AI/corpus/schema/migrations and unrelated user edits preserved |

Live fixture deltas cover 6,010 selected scans: 4,009 authenticated, 2,001 anonymous;
three additional Farmer accounts, four latest completed predictions and one failed
scan. Multi-model ties still count once and other/anonymous ownership remains
unchanged. Only ten recent minimal entries cross the API. All fixture accounts,
sessions, scans, predictions and metadata remain in one private rollback transaction;
before/after production row counts match. No raw dataset, provider/cloud call,
inference/training run, model promotion or source editing occurs.

Remaining limits: live runtime ML health and AI request recording are deliberately
unavailable, not fabricated. Production-scale global workload measurements,
distributed limiting and durable/browser sessions/retention remain later work.
Existing classifier/source/licensing/calculator-content limitations remain. Full
admin knowledge management and detailed ML-health/deployment phases are untouched.
Unrelated user ignore/ML/state edits are preserved outside the phase commit.
Stop after Phase 20.

## Phase 21 Admin management verification (2026-10-15)

- Inspected instructions/state/decisions, disease/document/source schema and SQL
  immutability guards, RAG ingestion/retrieval, pinned generation, calculator
  publication and Admin session/router before changes. Existing calculator APIs
  were reused; no classifier-class editor or generic formula execution was added.
- Added seven ADMIN knowledge route operations for bounded version listing/detail,
  source-reviewed new drafts, indexing, activation/archive and disease display/
  visibility edits. Fixed class contexts/slugs are not writable. Actor/request ID,
  review time and next document version are server-owned. Strict schemas reject
  injected actor/model fields, missing approval/provenance and malformed data.
- Node owns document/source/status/audit transactions; internal Python owns text
  canonicalization, existing chunking/embedding identity and atomic READY insertion.
  New source snapshots and immutable document IDs/versions preserve old citations.
  Provider failure/timeout leaves an inactive draft; repeated completed indexing
  reuses its index. Current-policy/hash/count checks and the shared ingestion lock
  prevent stale publication. Activation retires old active documents/sources in
  the same transaction; archive/deactivated disease filters exclude old vectors.
- Added request-local generation admission for ACTIVE reviewed Admin records with
  creator/review/current identity and activation audit. Exact content/hash/offset/
  coverage/source/class/curation checks still apply; pinned identities cannot be
  overwritten. The applicability warning now covers each source's region rather
  than assuming every future Admin source is U.S. material.
- Calculator lists expose admitted draft input/timestamps for form prefilling.
  Publication audits identify auto-retired rule/config IDs/versions. Existing
  numerical engines, source review, version pins and immutable historical payloads
  remain intact; revised fertilizer product snapshots need a new product slug.
  No production recommendation or fake agronomic formula/rate is seeded.
- Flutter management uses the separate Admin client and route-scoped MVVM. Named
  forms, fixed context selectors, fresh review approval, field/date/decimal/line
  validation, confirmation, indexing/loading/errors, list refresh and pagination
  preserve the design system. Account/disposal fences prevent old private state
  reappearing. No HTTP or numerical calculation is placed in widgets.

| Check | Result |
|---|---|
| Backend `npm run check` | Format/lint/strict TypeScript/build/import checks and all 292 tests pass; six new management validation/service/API cases cover every route for guest/Farmer/revoked denial |
| Flutter format / analysis / full tests | All 166 Dart files formatted; analyzer clean; 291 pass with nine opt-in live checks default-skipped; nine new management model/repository/ViewModel/widget cases |
| AI Ruff format/lint, mypy, full pytest | 336 pass, three existing opt-in database checks skip; 11 new management/index/policy/provider/generation cases; one existing upstream Starlette/httpx warning remains |
| Final generation/management checks | 76 relevant cases pass after the source-region warning correction; app/scripts strict checks remain clean using the AI component configuration |
| `scripts/check-admin-management.py` | Real protected Node/FastAPI/Google indexing/pgvector persistence and Gemini grounding of version 2 pass; optimistic disease edits/visibility, source retirement, archive exclusion, audit identities and calculator replacement lineage pass |
| Enabled real Flutter management contract | Creates/indexes/publishes/archives a reviewed version and reads both calculator versions; passes in 69 seconds with an explicit five-minute opt-in test timeout |
| Cleanup and integrity | Generated schema is dropped, production account/knowledge/calculator/model counts unchanged; no raw dataset, training/evaluation, model overwrite or promotion |
| Prisma validation/status | Valid schema, all eight migrations current; no schema/seed/dependency change |
| Repository/privacy/frozen checks | Required files/templates/ignores, local Markdown links, whitespace and configured-secret/private-path checks pass; 171 frozen ML files/checkpoint/shared/classifier/corpus/schema/migrations and unrelated user edits preserved |

The first live run passed backend/provider/version/audit controls but its Flutter
contract exceeded the default 30-second test timeout. The explicit opt-in timeout
was corrected to cover remote indexing and the complete workflow passed on rerun.
All synthetic calculator quantities and review attestations are test-only and
confined to the disposable schema; they do not approve real recommendation content.
Production knowledge/source files and all model artifacts remain unchanged.

Remaining boundaries: source freshness/local agronomic/legal review is a human
responsibility; real calculator content remains subject to approved sources.
Admin credentials remain volatile, and distributed limits/workload testing remain
deployment work. Detailed runtime ML health and later phases are untouched.
Unrelated user ignore/ML/state edits stay outside the commit. Stop after Phase 21.

## Phase 22 verification

- Added ADMIN-only `GET /api/v1/admin/model-health`, safe bounded model registry
  projections and internal authenticated `GET /api/v1/model-dashboard` probing.
  Missing/multiple production records, unavailable/not-loaded service and artifact
  version mismatch are explicit. No arbitrary current model or false zero is used.
- Added sanitized saved development/evaluation metadata to the startup-loaded model.
  Label/support/matrix/accuracy inconsistency fails startup. Class constants are
  shared within model management; shared image preprocessing is unchanged.
- Added lock-protected constant-space operational counters for handler requests,
  in-flight work, successes/failures, mean completed-handler latency, low-confidence
  fraction and prediction distribution. UTC timestamps are normalized by Node for
  the public Flutter contract. No identity/image/private path is included.
- Flutter uses scoped MVVM, separate Admin credentials, responsive cards/tables,
  confusion axes and count bars, refresh/loading/error/empty states and stale-session
  fencing. Offline evidence, runtime outcomes, research promotion and drift limits
  are labeled separately; the current unconfigured threshold is explained.

| Check | Result |
|---|---|
| Backend full checks | 296 tests pass; formatting/lint/strict types/build/import checks pass |
| Flutter full checks | 296 tests pass, ten opt-in checks default-skip; analyzer and formatting pass; five new focused model/repository/ViewModel/widget tests |
| AI full checks | 346 pass, three existing opt-in SQL tests skip; ten new dashboard/evidence/counter/startup cases; full inference/RAG/generation regressions included |
| Live read-only model-health contract | Real pinned checkpoint + saved 624-content evaluation, one synthetic inference success and one malformed-image rejection, real PostgreSQL registry and enabled Flutter transport/ViewModel pass |
| Admission/timestamp corrections | Live check fixed a helper assumption about unsupported byte admission and normalized internal UTC offsets to the public ISO-Z contract; no FastAPI image policy was weakened |
| Database/model boundary | Prisma valid, eight migrations current; read-only PostgreSQL is enforced by the live helper; no model promotion, metric write, final-test rerun or source-dataset access |
| Integrity/privacy | Frozen ML artifacts/manifests/checkpoint, shared preprocessing, source corpus, Prisma schema/migrations and unrelated user changes remain unchanged |

Remaining limits: model has no approved operational threshold or independent field/
commercial clearance. Training timestamp is not recorded. Runtime counts are local
to one process since startup, not durable distributed telemetry; full request rejection
accounting, cluster aggregation and verified ground-truth feedback need later work.
Offline evidence cannot be served by this screen when its pinned model service is
unavailable. Existing upstream Starlette/httpx deprecation warning remains.
Stop after Phase 22.

## Phase 23 verification

Added a connected Flutter/API/MVVM farmer/Admin journey, actual unreachable-DB/
FastAPI and stalled-HTTP failure checks, explicit live orchestration and a
test-only database search-path preflight. Each owned schema replays the eight
existing migrations and copies sourced knowledge/model metadata, never accounts,
scans, private requests or real calculator recommendations. Results/logs are
timestamped under ignored `.cache/phase23/`. Skips, nonzero exits and timeouts
cannot be reported as passing live tasks. Cleanup uses a fresh control connection,
saves results incrementally and preserves compensation records if cleanup is unknown.

The only application change fixes the Admin model-health registry transaction's
default two-second acquisition deadline (`P2028`) on cold remote connections.
`maxWait: 10000` matches existing pool/analytics acquisition bounds; isolation and
query/execution deadlines remain intact. The real read-only registry/model/Flutter
case reproduces the failure before the change and passes afterward. No new feature,
schema, dependency, classifier, shared preprocessing or corpus change is included.

| Command/check | Measured result |
|---|---|
| `scripts/check-development.ps1 -Component Backend` / final `backend: npm.cmd run check` | 299 tests pass, zero skips; format/lint/strict TypeScript/build/import checks pass after the transaction fix |
| `-Component AI` | 346 pass, three opt-in SQL skips; Ruff format/lint and mypy pass; all three SQL tests enabled separately and pass |
| `-Component Flutter`, `dart format`, final `flutter analyze` | 296 pass, 11 default opt-in skips; analyzer has no issues and formatting passes; opt-in contracts have separate live evidence |
| `-Component Training` | 219 fixture tests pass, Ruff/mypy pass; no real classifier fitting or held-out evaluation |
| `-Component Preprocessing` | 78 tests pass in each Python environment; 12 exact synthetic training/serving parity cases pass; Ruff/mypy pass |
| `check-image-admission-contract.py` | 56 pass: 21 admitted, 35 rejected; no source dataset |
| `-Component Prisma`, live database and replay tasks | 13 Prisma checks and 42 live integration cases pass; schema/client/type checks pass, eight migrations current; fresh replay passes |
| `-Component Docker`, `check-repository.ps1` | Compose configuration and repository/templates/ignore checks pass; running containers/deployment not verified |
| `flutter build apk --debug --no-pub` | Android debug APK built successfully in 62.4 s; generated outputs later removed by `flutter clean` to resolve disk exhaustion |
| Broad live run `20261015T094831Z-10991b2b` | DB/replay, Python SQL, real Google/pgvector, enabled upload API, anonymous/farmer cloud/model/history, assistant, calculators and farmer analytics pass; generation/late Admin failures retained in recovered results |
| Journey `20261015T095107Z-f4a8650c` | Two Flutter tests pass in 220.92 s; 16 connected API/MVVM steps, real cloud/model/provider calls; owned cloud cleanup, schema removal and 21 unchanged production counts verified |
| Generation `20261015T095657Z-9c32f04d` | Nine tests pass, zero skips in 163.94 s, covering all four literal classes and scan contexts; earlier Healthy abstention remains recorded |
| Admin recheck `20261015T122146Z-1b3315f1` | Analytics/Flutter pass in 66.55 s with 7,000 synthetic scans and one aggregate statement; management 503 and pre-fix model-health failure retained; schema removed/counts unchanged |
| Management recheck `20261015T122903Z-77aa6aeb` | Complete source/version/index/archive/Gemini/audit/calculator/Flutter contract passes in 337.20 s; this run also retains its pre-fix model-health failure |
| Model-health final `20261015T123435Z-5233c9e0` | After fix, actual read-only registry + pinned FastAPI + Node + Flutter repository/ViewModel passes in 55.69 s; no skipped live case |
| Integrity/privacy review | 171 frozen files and approved checkpoint checked, eight migrations/corpus/shared/ML and unrelated user edits preserved; local documentation links and configured-secret/path checks pass |

The matrix distinguishes actual service calls from mocked failures, API contracts
from widget/device acceptance, and synthetic calculator fixtures from approved
agronomic content. Farmer registration UI and Knowledge UI remain missing; real
fertilizer/yield rules await sources. No Android device/emulator was available for
physical camera/permission/tap-through acceptance. Intermittent upstream 503 and
safe grounding abstention mean this is not an uninterrupted all-green provider run.
The original disk-failed batch lost its final cleanup comparison; its recovered
log and separate verified cleanup proof are retained. Saved final-test metrics
remain historical evidence, not newly measured field accuracy or commercial clearance.
Final cleanup inspection found no generated Phase 21/23 schema remaining and all
21 production counts match the final run's baseline.
Read the [full test matrix](39-testing-e2e-verification.md). Stop after Phase 23.

## Phase 23.5 audit record

- Read/indexed the complete history/design set and crosschecked source routes,
  configuration, schema/migrations, corpus/vector rows, test collection/proofs,
  training/manifests/artifact metadata and Flutter consumers. Documentation was not
  accepted as implementation proof. No CI pipeline or production Docker builds exist;
  these are deployment work rather than reasons to rebuild earlier foundations.
- Created the detailed 28-section completeness report plus per-endpoint and per-variable
  inventories. Every phase has one explicit status; user tasks, Codex coding work,
  manual acceptance and intentionally deferred work are separated.
- Fresh live database contains four diseases/four sources/25 documents/25 READY chunks,
  one VALIDATED research model, zero calculator rules/configs and zero named users.
  No active PRODUCTION registry row exists. Historical test users/assets were cleaned
  by their owned Phase 23 harnesses; fresh audit probes use read-only access.
- Found/fixed cwd-dependent Ruff first-party import grouping in check-e2e.py using
  an explicit bootstrap import boundary; the full AI suite now passes from its actual
  component working directory. Corrected stale Tools copy and architecture headers.
  The affected Flutter analyzer and 18 widget/flow tests pass after the copy fix.
- Full current component results: backend 299/0 skipped, AI 346/3 opt-in skips,
  Flutter 296/11 opt-in skips, training tooling 219, shared 78 in both environments,
  12 shared parity cases, Prisma 13/eight migrations current/no structural diff,
  Compose configuration and Android ARM64 debug packaging. No lock/dependency change.
- Fresh real requests verify loaded immutable model/startup/shutdown/auth rejection,
  three synthetic predictions, four source-retaining retrievals, a grounded actual
  Gemini answer and unsupported-question refusal. Separate actual TCP Node → FastAPI
  → Google/pgvector/Gemini and one enabled native Flutter MVVM health test pass.
  Cloudinary authenticated readonly ping passes. Prior real guest/FARMER upload/
  history/assistant/calculator/Admin proofs were inspected, not relabeled as new
  physical-device tests. Provider outage branches remain mocked/previously observed.
- Verified all 8,040 raw files by SHA256/size/mtime without modifying them; the v2
  index still has 4,162 contents/4,121 groups split 2,911/627/624, with zero confirmed
  content/group leakage. No training, calibration/threshold change, test-set scoring,
  production promotion, dataset redistribution, DB reset or new migration occurred.
- Preserved unrelated ignore/ML/state edits. DECISIONS.md is unchanged because no
  architectural choice was finalized. Stop after Phase 23.5.

## Next step

Stop after Phase 23.5. Request targeted farmer registration and Phase 6 knowledge UI
remediation; do not recommend starting Phase 24 yet. Larger missing features were
reported rather than implemented in this audit. Subsequent phases require the
next explicit instruction. Independent
field validation and commercial
licensing/source replacement remain requirements before real farmer/commercial use.
Read [farmer workflow](29-farmer-detection-history.md), [integration contracts](28-node-fastapi-integration.md), [inference contracts](27-production-ml-inference.md), [model fitness](26-model-fitness-validation.md) and reconcile the next instruction
with the [roadmap](14-roadmap.md).
