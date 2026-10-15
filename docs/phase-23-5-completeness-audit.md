# 1. OVERALL COMPLETENESS VERDICT

**Historical checkpoint, superseded for the two UI gaps by Phase 23.6.** Read the
[remediation report](phase-23-6-remediation-report.md). That review also corrects this
audit's profile/user-management scope finding: the original master brief explicitly
requires a customizable farmer profile (§2 item 13), Admin farmer/user management
(§2/§4), disease image management and audit-log viewing (§4). Their absence remains
reported separately; they were not silently implemented in the two-feature remediation.

**NOT READY FOR PHASE 24**

Audit date: 2026-10-15. Reviewed repository baseline: `f646150` (Phase 23).
The implementation is substantial and its external services are real. Nevertheless,
farmer self-registration has no screen, and the farmer Knowledge tab is a production
placeholder despite populated, working knowledge APIs. These are coding gaps, not
credentials the user should supply. Do not start Phase 24 to conceal them.

Fertilizer/yield engines, versioning and UI exist, but real agronomic rules do not.
Those phases explicitly authorized a pending-content framework, so missing approved
rates do not independently prevent security work after the coding gaps are repaired.
They do prevent calling the calculators complete FYP recommendation features.

Evidence coverage: 733 authored-file inventory, 45 history/design documents indexed
with full-content hashes, implementation/route/configuration/test searches, traced
feature wiring, current component checks, read-only live service/database probes,
8,040-file raw integrity check, immutable manifests/artifacts, and retained successful
Phase 23 real-service proofs. Documentation assertions were crosschecked rather than
used as completion evidence. This is not a formal security or field-efficacy certification.

Companion inventories: [all 35 Node endpoints](phase-23-5-endpoint-inventory.md) and
[all 70 runtime configuration entries](phase-23-5-configuration-inventory.md).
Ignored evidence/logs: `.cache/phase235/`. Raw paths and secret values are omitted.
No dataset modification, retraining, final-test scoring, user-data deletion, database
reset, new migration, security-hardening phase or deployment work was performed.

# 2. PHASE 0–23 STATUS MATRIX

Each phase has exactly one requested status. Code means implemented behavior;
Integration records actual wiring; Real Test distinguishes fresh checks from retained
Phase 23 evidence. **Blocks** refers to proceeding to Phase 24, not final demo acceptance.

| Phase | Status | Code | Integration | Real Test | Missing | User Input |
|---|---|---|---|---|---|---|
| 0 Repository/docs | COMPLETE | Seven roots, instructions/docs/scripts, Git/ignores | Actual repository | Repository checker | Blocks: NO | None |
| 1 Dev infrastructure | COMPLETE WITH LIMITATIONS | Locked Node/Python/Flutter environments, dev scripts, PostgreSQL Compose | Managed PostgreSQL actually used | Fresh component checks, debug ARM64 APK, Compose config | Blocks: NO; Docker runtime/container deployment unverified | Deployment choices later |
| 2 PostgreSQL/Prisma | COMPLETE WITH LIMITATIONS | 21 application tables, relations/constraints/triggers/vector support | Real Prisma/SQL database | 13 fresh DB checks, eight migrations current, no structural diff | Blocks: NO; some deliberately reserved entities unused | None |
| 3 Node foundation | COMPLETE | Strict TS, layered API, environment validation, middleware/errors/lifecycle | Real HTTP + DB | 299 backend checks; fresh Flutter health chain | Blocks: NO | None |
| 4 Auth/RBAC and mobile handoff | PARTIALLY IMPLEMENTED | Backend FARMER registration, login, rotation/revocation and ADMIN CLI complete; mobile login works | Real native session/API/DB flows | Backend suites plus Phase 23 real auth/journey proofs | Blocks: YES for end-user onboarding; no registration UI. Original Phase 4 was backend-only | No credential needed to code UI |
| 5 Flutter foundation | COMPLETE WITH LIMITATIONS | MVVM/Provider/theme/router/network/state patterns | Real Node clients | 296 fresh tests, analyzer/format/APK | Blocks: NO; native interaction not device-tested | Device access for acceptance |
| 6 Disease knowledge | PARTIALLY IMPLEMENTED | DB/content/public APIs/Admin updates supplied by Phases 14/21 | Backend/RAG real; farmer library disconnected | Fresh four-class retrieval/catalogue; earlier Admin live proof | Blocks: YES; KnowledgeView is still FeatureIntro, no browse/search/detail repository/ViewModel | Existing corpus is sufficient for UI |
| 7 Upload/scans | COMPLETE WITH LIMITATIONS | Byte admission, Cloudinary adapter, durable upload journal/compensation | Guest/FARMER real cloud/database flow | Phase 23 real JPEG/PNG/WebP/API/mobile proofs; fresh Cloudinary ping | Blocks: NO; scheduled orphan-job operation and physical picker acceptance pending | Scheduler at deployment; device test before demo |
| 8 FastAPI | COMPLETE | Settings/logging/errors/schemas/health/lifespan/internal auth | Real application startup/shutdown | Fresh AI suite and loaded lifespan | Blocks: NO | None |
| 9 Shared preprocessing | COMPLETE WITH LIMITATIONS | One installed shared implementation; deterministic configured transforms | Imported by training and inference | 78 tests in each environment; 12 fresh parity cases | Blocks: NO; corpus/field robustness limitations remain | None for existing baseline |
| 9.5 Dataset intake | COMPLETE WITH LIMITATIONS | Inventory/provenance/exclusion/group evidence; reusable DATASET_PATH | Actual configured dataset | Fresh 8,040 hashes/sizes/mtimes match historical inventory | Blocks: NO; commercial clearance absent | No labels/path metadata to resupply |
| 10 Training/evaluation | COMPLETE WITH LIMITATIONS | Reproducible preparation/training/evaluation/experiment artifacts | Shared preprocessing and saved checkpoints | Actual retained run/history/metrics; 219 fresh fixture tests | Blocks: NO; original v1 independence claim superseded by Phase 10.5 | None |
| 10.5 Fitness repair | COMPLETE WITH LIMITATIONS | Corrected v2 groups/exclusions/fresh selected model/calibration review | Approved artifact now served | Frozen artifact/hash checks; fresh split intersections/model load | Blocks: NO; inspected public corpus, unresolved possible Healthy relation, no independent fields | Optional independent field data later |
| 11 Inference | COMPLETE WITH LIMITATIONS | Startup-verified CPU model, admission, probability/uncertainty contracts | Exact shared pipeline and class map | Fresh startup, three synthetic inferences, service-auth rejection | Blocks: NO; no operational threshold or production promotion | None; do not invent a threshold |
| 12 Node/FastAPI | COMPLETE WITH LIMITATIONS | Dedicated byte client, schema validation, durable lifecycle/ownership/retry | Real internal transport/model persistence | Backend regressions and Phase 23 guest/FARMER real proofs | Blocks: NO; synchronous/local-scale operational limits | None |
| 13 Detection/history | COMPLETE WITH LIMITATIONS | Selection/preview/progress/result/private paginated history | Real Scan ViewModel/repositories/Node/cloud/model | Phase 23 connected and separate farmer/guest live tests | Blocks: NO for scan/history scope; physical camera/gallery unverified | Device acceptance |
| 14 RAG | COMPLETE WITH LIMITATIONS | Sourced immutable docs/chunks/vectors and exact cosine retrieval | Real Google embeddings/PostgreSQL pgvector | Fresh all-four-class retrieval; retained version/index live proof | Blocks: NO; small English/U.S. corpus and uncalibrated relevance | Local review before real advice |
| 15 Gemini | COMPLETE WITH LIMITATIONS | Official SDK, bounded evidence selection, reviewed excerpts/citations | Real RAG/provider calls | Fresh grounded answer and unsupported-question refusal; mocked failures | Blocks: NO; provider variability and limited scope/injection evaluation | No new key |
| 16 Assistant | COMPLETE WITH LIMITATIONS | Scoped chat, sources, bounded 12 local turns, owned scan context | Real Node/RAG/Gemini and scan ownership | Phase 23 assistant/journey live proof; current AI/Flutter suites | Blocks: NO; no persistent chat or unlimited conversational memory by design | None |
| 17 Fertilizer | BLOCKED BY USER INPUT | Exact deterministic area-rate engine, versioned rules/Admin forms/Flutter UX | Connected, but catalogue empty | Real isolated SYNTHETIC arithmetic proof; fresh PENDING_RULES | Blocks: NO under approved framework fallback; real recommendation content absent | USER / DOMAIN DATA REQUIRED before complete calculator demo |
| 18 Yield | BLOCKED BY USER INPUT | Exact conditional area-rate framework, versioned Admin configuration/Flutter UX | Connected, but catalogue empty | Real isolated SYNTHETIC arithmetic proof; fresh PENDING_CONFIGURATION | Blocks: NO under approved fallback; no approved agronomic rate/model | USER / DOMAIN DATA REQUIRED before complete calculator demo |
| 19 Farmer analytics | COMPLETE WITH LIMITATIONS | Owner/date-filtered SQL summary/activity and charts | Real scan-derived aggregates | Suites and real Phase 23 aggregate/ownership/query-plan/Flutter proof | Blocks: NO; prediction usage, not ground-truth accuracy | None |
| 20 Admin dashboard | COMPLETE WITH LIMITATIONS | ADMIN-only aggregate cards/charts/system summary | Real SQL and separate Admin session | Real 7,000-fixture-scan/Flutter proof plus current suites | Blocks: NO; AI totals explicitly NOT_RECORDED, no fake zero | Provision named Admin before demo |
| 21 Admin management | COMPLETE WITH LIMITATIONS | Disease display edits, immutable source/doc versions, index/publish/archive, calculator forms/audits | Real Node/Python/Google/DB/Flutter | Retained full real management proof; current suites | Blocks: NO; human content review and no audit-browser feature | Reviewer and real domain content before publication |
| 22 Model health | COMPLETE WITH LIMITATIONS | Registry + pinned offline evidence + bounded runtime counters/Admin UI | Real protected FastAPI/Node/Flutter | Phase 23 final post-P2028 real read-only contract; fresh model dashboard | Blocks: NO; process-local counters, no formal drift, no recorded training timestamp | None |
| 23 Testing/E2E | COMPLETE WITH LIMITATIONS | Broad suites, actual-failure probes, scoped live harness/test matrix | Real connected API/MVVM journeys | Retained logs inspected and fresh safe checks rerun | Blocks: NO independently; no physical tap-through proof; initial cwd-dependent lint defect fixed here | Manual acceptance before demo |

Registration is an **unfinished later Flutter handoff**, not a claim the original
backend-only Phase 4 failed to implement its specified API. Phase 6's database/backend
skip was repaired; its farmer-facing feature was not. These distinctions prevent
both false completion and unfairly treating deliberate phase boundaries as bugs.

# 3. FEATURES COMPLETELY IMPLEMENTED

Verified within their stated scope: layered Node/FastAPI foundations, backend auth/
RBAC/refresh revocation, native volatile login, upload validation/compensation, guest
and farmer scan inference, saved prediction/history ownership, shared preprocessing,
version-pinned research serving, sourced disease APIs, semantic retrieval, grounded
evidence answers, scan explanations, scoped assistant, exact calculator frameworks,
farmer/Admin aggregate APIs and UI, Admin version/index lifecycle and model-health UI.

Architecture traces remain View → ViewModel → Repository → API client → Node and
Route → Controller → Service → Repository → Prisma. Python owns vector SQL, ML and
Gemini. No direct Prisma access was found in controllers or raw HTTP calls in feature
widgets. Dependency injection and test factories do not replace production defaults.
Image display uses Node-issued Cloudinary delivery URLs, not secret storage APIs.

# 4. PARTIALLY IMPLEMENTED FEATURES

| Feature | Implemented | Missing | Owning remediation | Blocks Phase 24 |
|---|---|---|---|---|
| Farmer registration | Validated FARMER-only API/DB/hash/duplicate/RBAC behavior | Form, ViewModel/repository method, navigation and UX integration | Auth/mobile handoff after Phases 4/13 | YES |
| Farmer knowledge library | Four catalogue records, 25 sourced sections, public list/detail/search, Admin lifecycle | Actual browse/search/detail/source UI and MVVM wiring | Missing Phase 6 farmer feature | YES |
| Fertilizer recommendations | Exact engine, units, rules/config versions, source review forms, public UX | Real approved products/rates/conditions and publication | Phase 17 domain-content completion | NO by itself; approved pending-content fallback |
| Expected yield | Deterministic conditional area-rate projection and full framework | Approved yield model/rate/applicability/source | Phase 18 domain-content completion | NO by itself; approved pending-content fallback |
| Profile editing | Profile/account summary; FarmerProfile schema | No editable profile API/UI | Not established as an approved Phase 0–23 implementation requirement | NO; do not invent scope |
| Persistent sign-in | Restricted in-memory cookie/access token, serialized renewal | OS secure-storage persistence; restart intentionally signs out | Phase 24 storage/privacy decision if persistence is required | NO; explicit current design |

# 5. FEATURES THAT EXIST BUT ARE NOT CONNECTED

- `POST /auth/register` is consumed by tests, not a production farmer registration view.
- `/diseases`, `/diseases/:slug` and `/knowledge/search` have no farmer library consumer.
  The assistant's `/knowledge/ask` usage does not connect the Knowledge tab.
- `farmer_profiles`, `disease_images`, `model_metrics`, `ai_queries`, `ai_responses`,
  `notifications` and generic `history` have no active application writer. They are
  reserved schema support, not proof of profile editing, chat history, notifications,
  photo libraries or calculation history. Existing scan history reads scans/predictions.
- Offline model metrics intentionally come from verified saved artifacts, not an
  empty model_metrics table. Chat/calculators intentionally remain stateless.

Persistence was checked against both Prisma and all eight applied migrations:

| Persistent area | Actual implementation and data |
|---|---|
| users/auth_sessions | Real account/refresh-digest/revocation repositories; live DB currently empty after test cleanup |
| farmer_profiles | Valid optional one-to-one schema; no profile creation/editing workflow |
| diseases/disease_sources | Four real catalogue/source entries; active/version-aware read/Admin behavior |
| disease_images | Schema only, zero curated media; no licensed photo management workflow |
| scans/scan_uploads/scan_predictions | Durable uploads/lifecycle/model-bound outcomes/ownership, real integration and recovery tests; current user DB empty |
| knowledge_documents/knowledge_chunks | 25 real versioned/source-backed documents and READY vectors; explicit rebuild/archive lineage |
| fertilizers/fertilizer_rules/calculator_configs | Real typed framework/publication/audit repositories; current real catalogue empty; YIELD uses calculator_configs |
| model_versions/model_metrics | One VALIDATED model; metrics table unused, offline dashboard reads verified artifact evidence |
| ai_queries/ai_responses | Schema reserved; no current writer or persistent conversation/request statistics |
| audit_logs | Admin version/status/display/config transactions write immutable audit rows; no audit-browser route |
| notifications/history | Reserved schema; no notification delivery or generic persisted activity/calculation history |

FK/unique/index/enumeration/nullability/immutability guards are exercised by actual
catalog and rollback tests. All migrations are applied and structural diff is empty;
no code/column mismatch or orphan knowledge/vector linkage was found. Reserved
tables are not misrepresented as implemented user features. No database was reset.

# 6. DOCUMENTED BUT NOT IMPLEMENTED

The architecture baseline proposes secure persisted storage, broader profile/user
management, generalized histories, notification delivery and a maintained Node
OpenAPI specification. These are not all implemented. The baseline documents label
themselves target designs; they must not be presented as an as-built feature list.

Specific stale language found: Flutter architecture still described calculators/
Admin workflows as future and Admin as a reserved boundary; AI architecture still
called the assistant future; Tools copy said tools were being prepared. Those small
descriptions are corrected in this audit. Historical phase reports retain their dates
and original scope. The current README/Phase 23 matrix already disclose missing
registration/knowledge UI and calculator content; they are not hidden successful flows.

Marker searches were interpreted by context, including plausible static output:

| Classification | Actual finding | Consequence |
|---|---|---|
| Legitimate test mocks | Memory auth repositories, fake provider transports/embedders, synthetic images, controlled widget repositories | Valid for logic/failure checks; not external-service or physical-device proof |
| Development/sample data | Blank environment examples and explicitly SYNTHETIC isolated calculator drafts/example.invalid references | Not production seed recommendations; real database catalogue remains empty |
| Production placeholder | KnowledgeView renders FeatureIntro and promises a future library | P1 missing farmer feature; working backend does not make the tab complete |
| Missing functionality without an obvious stub marker | No registration form/repository method; profile editing and reserved-table workflows absent | Report registration as missing; do not confuse target-design extras with approved implemented features |
| Static-looking but honest state | PENDING_RULES, PENDING_CONFIGURATION, NOT_RECORDED and NOT_CHECKED | Explicit missing content/telemetry/readiness, not invented successful metrics |

Protocol method ellipses, sample/count names and test-only fixed expectations for the
approved model are not production stubs. Default factories instantiate real services;
dashboard numbers come from SQL or verified artifact metadata, not demo constants.

# 7. MOCKED BUT NOT REAL-WORLD VERIFIED

**MOCK VERIFIED ONLY:** provider outage/timeout/invalid payload branches, DB commit-loss
compensation, most widget interaction/navigation/error states, permission denial and
camera/gallery callbacks. Closed-loopback DB/FastAPI and stalled-HTTP failure probes
also exist, but real provider accounts were not deliberately sabotaged.

**NOT VERIFIED:** physical camera/gallery/permission/restart acceptance, emulator
tap-through, browser sessions, release signing/install/distribution, running production
containers, Linux codec/target hosting parity, distributed limits/load and independent
field accuracy. Calculator numerical integrations use SYNTHETIC rules only.

Normal PostgreSQL/Cloudinary/FastAPI/model/Google/Gemini paths are not merely mocked.
The standalone model-health helper uses in-memory auth but real read-only registry/model;
real DB authentication is separately demonstrated by the connected journey/auth suites.
No one fixture is claimed to prove every layer at once.

# 8. REAL END-TO-END VERIFIED FLOWS

| Integration | Required classification | Evidence and boundary |
|---|---|---|
| Flutter ↔ Node | REAL VERIFIED | Fresh native MVVM health test over HTTP; earlier feature contracts |
| Node ↔ PostgreSQL | REAL VERIFIED | Fresh readonly HTTP/catalogues and 13 Prisma checks; Phase 23 transactional auth/scan tests |
| Node ↔ Cloudinary | REAL VERIFIED | Phase 23 actual uploads/signed delivery/owned cleanup; fresh read-only API ping |
| Node ↔ FastAPI | REAL VERIFIED | Fresh actual TCP Node → private Uvicorn → grounded generation; earlier raw-byte scan persistence |
| FastAPI ↔ model | REAL VERIFIED | Fresh actual approved weights/lifespan/three synthetic predictions; not image accuracy testing |
| FastAPI ↔ pgvector | REAL VERIFIED | 25 stored READY vectors and fresh four-class searches |
| FastAPI ↔ Gemini | REAL VERIFIED | Fresh actual providerUsed=true GROUNDED answer with source metadata |
| Farmer complete scan | REAL VERIFIED | Phase 23 real Scan ViewModel/API/cloud/model/DB/result contract; synthetic picker, not camera hardware |
| Farmer history | REAL VERIFIED | Real private pages/detail/cursor/ownership/logout proof |
| Farmer RAG/chat | REAL VERIFIED | Phase 23 assistant/scan context and fresh Node/provider answer; widgets tested separately |
| Flutter calculators | REAL VERIFIED | Exact transport/version/unit/authorization against SYNTHETIC isolated configurations; agronomy NOT verified |
| Farmer analytics | REAL VERIFIED | Real aggregates/ownership/query-plan/Flutter proof; not model accuracy |
| Admin dashboard | REAL VERIFIED | Real 7,000-scan fixture aggregate/Flutter contract, rolled back |
| Admin management | REAL VERIFIED | Actual Google vectors, publication/retirement, Gemini admission, audit lineage and Flutter repositories |

Retained proofs inspected: journey `20261015T095107Z-f4a8650c`, generation
`20261015T095657Z-9c32f04d`, analytics `20261015T122146Z-1b3315f1`, management
`20261015T122903Z-77aa6aeb`, final model health `20261015T123435Z-5233c9e0`.
These are successful individual checks, not a claim their combined failed parent
runs passed. [Phase 23](39-testing-e2e-verification.md) retains the Healthy abstention,
upstream 503, disk-exhaustion/timeouts and original lost final cleanup comparison.
This audit did not recreate destructive fixture cleanup operations against user data.

# 9. ML STATUS

- Configured serving model: `mobilenet-v3-small-v2-20261009`; registry **VALIDATED**,
  not PRODUCTION. No model has been promoted. This is a local FYP research candidate.
- Fitness: **FIT WITH DOCUMENTED LIMITATIONS**; experiment
  `mobilenet-v3-small-20261009-v2-01`, selected epoch 8, architecture MobileNetV3 Small.
- Checkpoint SHA-256: `e95a2e83262637fc1a08b919e6003bddb2fe70664b9c51418f059b7c8287dc66`.
  Metadata, calibration sidecar, dependency/config/class invariants and weights were
  checked by the actual startup loader; no silent alternate checkpoint was loaded.
- Shared preprocessing `1.0.0`, approved full frame, segmentation disabled, 224×224
  aspect-preserving bilinear letterbox/white padding, RGB float32 NCHW. RGB/255 then
  mean `[0.485,0.456,0.406]`, std `[0.229,0.224,0.225]`; no independent serving transform.
- Literal mapping: `Common_Rust=0`, `Gray_Leaf_Spot=1`, `Healthy=2`,
  `Northern_Corn_Leaf_Blight=3`. Version-bound v2 class-map SHA-256:
  `71fc97c485026196263e1e12398735ca2efbf5cccb1ef9e9a45d15fb7d2df58d`.
- Dataset/index `maize-research-20261008-v2`: 4,162 eligible contents/4,121 groups;
  TRAIN 2,911 / VAL 627 / TEST 624. Fresh manifest intersections are zero for both
  content and confirmed group identity. Exclusions retain 26 files/24 contents,
  including original invalid/contradictory inputs and Phase 10.5 repairs.
- All 8,040 raw files freshly match original hashes/sizes/mtimes. TRAIN-only
  augmentation is enforced in training_data; VAL/TEST reject augmentation. Dataset
  path still comes from configuration. No model fitting or final-test scoring rerun.
- Calibration disabled, temperature 1; no approved threshold. Every current result is
  LOW_CONFIDENCE/THRESHOLD_UNCONFIGURED, including high scores. Do not invent a cutoff.
- Saved internal TEST accuracy 95.8333% (598/624), macro F1 about 0.9452; GLS recall
  about 83.53%. These are historical saved metrics, not performance on 8,040 independent
  photos or field accuracy. Original v1 independence was invalidated and superseded.
  A possible Healthy TRAIN/VAL relative remains unresolved, plant/session identities
  are incomplete, the corpus was previously inspected, and commercial clearance is absent.
  There is no dedicated maize-leaf/OOD detector: an admitted arbitrary image can
  still receive one of the four softmax labels. LOW_CONFIDENCE is not formal OOD detection.

Exact persisted v2 partitions (read from manifests, not recomputed by model evaluation):

| Literal class | Eligible contents | TRAIN | VAL | TEST |
|---|---:|---:|---:|---:|
| Common_Rust | 1,301 | 910 | 196 | 195 |
| Gray_Leaf_Spot | 564 | 394 | 85 | 85 |
| Healthy | 1,162 | 813 | 175 | 174 |
| Northern_Corn_Leaf_Blight | 1,135 | 794 | 171 | 170 |
| Total | 4,162 | 2,911 | 627 | 624 |

# 10. RAG STATUS

**Real knowledge, chunks, vectors and live retrieval: YES.** Fresh readonly SQL found
four disease records, four sources, 25 documents and 25 chunks with READY 768-dimensional
Google vectors; pgvector version 0.8.6. All four disease/scouting retrieval probes
returned the correct label with retained sources. Exact cosine search is appropriate
for this size; no ANN index is falsely claimed.

The curated initial summaries cite Minnesota Extension (three diseases) and Iowa State
Extension scouting. Each disease has seven topic sections. Healthy has four scouting/
overview/prevention/reference sections; disease treatment/causes for Healthy are
intentionally absent. There are no curated disease photographs; no publisher images
were silently copied. Local region/freshness/agronomist review remains necessary for
real advice; existing content is sufficient to implement the missing library UI.

Immutable document/source versions, deterministic chunks/config hashes, explicit real
embedding rebuild, READY guards, activation recheck and archive filtering are coded and
real-tested. Old citations remain historical; stale versions are excluded. Provider
failure cannot automatically publish a draft. Retrieval ranking is not calibrated
agronomic confidence or comprehensive out-of-domain rejection.

# 11. GEMINI STATUS

**FULLY CONFIGURED AND LIVE VERIFIED**

The official locked Google GenAI SDK is used for generation. `GEMINI_API_KEY` and
`GEMINI_MODEL` are server-side in the AI service; generation model is explicitly
configured as `gemini-3.5-flash-lite`, not guessed in source. Embeddings use the
configured `gemini-embedding-001`/`google-task-v1-20261012` identity.

Fresh direct and actual Node/TCP service probes returned GROUNDED, providerUsed=true,
and source metadata. An unrelated movie request returned OUT_OF_SCOPE/providerUsed=false.
The generation model selects bounded reviewed evidence; the server renders verified
excerpts rather than publishing unchecked model-written agricultural paragraphs.
This is the documented conservative implementation, not fake generation or a general
unrestricted chatbot. Previous live 503/abstention behavior remains a reliability limit.

# 12. FERTILIZER CALCULATOR STATUS

**FRAMEWORK IMPLEMENTED, REAL DOMAIN DATA MISSING — USER / DOMAIN DATA REQUIRED.**

Fresh DB: zero fertilizers, zero fertilizer rules, zero calculator configs. Public
HTTP correctly returns PENDING_RULES. No SYNTHETIC test rate is production content.
The deterministic engine scales area in hectares × explicitly reviewed product kg/ha;
international acre conversion is exact, kg/grams explicit, decimal strings/BigInt
preserve precision and a single final HALF_UP round is versioned. Gemini performs no
arithmetic and is absent from the calculation/explanation path.

Admin source/applicability/review/version controls and Flutter editing/validation/
assumption/result UX exist. Human-approved products, rates, units, source references
and applicable conditions are needed before a real recommendation can be shown.
The engine does not select a nutrient dose from soil or diagnose fertilizer need.

# 13. YIELD CALCULATOR STATUS

**FRAMEWORK IMPLEMENTED, REAL DOMAIN DATA MISSING — USER / DOMAIN DATA REQUIRED.**

Fresh public HTTP returns PENDING_CONFIGURATION. The implemented formula template
is dimensional `area_ha × reviewed_expected_kg_per_ha`, with exact acre/kg/metric-tonne
conversion and versioned rounding. It is a conditional planning framework, not an
empirically validated crop model. No population/weather/soil/disease adjustment is
invented and no Gemini arithmetic occurs. A source must justify the kg/ha scenario
and its applicability, or a different approved formula requires separately scoped
implementation. Admin publication/UI and exact unit/version tests are connected.

# 14. FARMER APP STATUS

| Main feature | Status | Actual boundary |
|---|---|---|
| Launch/design/navigation/home | PASS | Widget/analyzer/debug packaging; actual device launch not tested |
| Registration | MISSING | Backend exists; no farmer form/repository handoff |
| Login/logout/current-session refresh | PASS | Native restricted in-memory cookie, single-flight refresh, server revocation |
| Restart persistence/secure-storage plugin | MISSING | Intentional volatile design; restart must sign out, not silently persist |
| Profile summary | PASS | Current email/guest/session/history/analytics links |
| Profile editing | MISSING | No specified approved editing feature implemented; scope-dependent future work |
| Gallery/camera adapters and lost-data recovery | NOT REAL-LIVE VERIFIED | Implemented plugin/system-intent handling; no physical Android or emulator |
| Preview/submit/progress/retry | PASS | Real fixture datasource through ViewModel/API; camera is not that fixture |
| Model result/class/confidence/uncertainty/image/time | PASS | Backend source of truth; model prediction wording, not guaranteed diagnosis |
| Anonymous scan | PASS | Nullable user, private original key, no account history/retroactive attachment |
| Authenticated scan/private history/detail | PASS | Real ownership, pagination and cross-farmer denial proofs |
| Knowledge browse/search/detail | MISSING | Static FeatureIntro; no library repository/ViewModel |
| Assistant/scoped question/source display | PASS | Current-question/filter context; bounded local conversation; real Gemini |
| Selected scan explanation | PASS | FARMER ownership enforced by Node; classifier context unchanged |
| Fertilizer UX | PARTIAL | Framework wired; real rules absent |
| Yield UX | PARTIAL | Framework wired; real agronomic configuration absent |
| Personal statistics/charts | PASS | Own scan-derived usage/prediction aggregates |
| Loading/error/empty/offline/timeout/failed inference | PASS | Unit/ViewModel/widget coverage and actual dependency-refusal probes; device acceptance still pending |

# 15. ADMIN APP STATUS

| Main feature | Status | Boundary |
|---|---|---|
| Controlled Admin provisioning/login | PASS | Operator CLI; no actual named user account currently exists |
| Separate navigation/session/RBAC | PASS | Farmer denied every protected route group; no public Admin registration |
| Real aggregate dashboard/charts/recent activity | PASS | SQL-derived, not downloaded raw scans or static dashboard numbers |
| Disease display/visibility editing | PASS | Fixed classifier labels/slugs; no casual model class rename/delete |
| Knowledge/source-version editing | PASS | New immutable document/source snapshot and optimistic checks |
| Index/rebuild/activate/archive | PASS | Actual Google/pgvector lifecycle with audit lineage |
| Fertilizer/YIELD management forms | PARTIAL | Real management code; no approved recommendation data to publish |
| Model-health/offline/per-class/confusion evidence | PASS | Startup-verified artifact; no metric recalculation from user scans |
| Runtime latency/failure/uncertainty/distribution | PASS | Process-local since restart, not formal drift or accuracy |
| AI request totals | PARTIAL | Explicit NOT_RECORDED; assistant tables deliberately unwritten |
| Audit-history browser | MISSING | Audit writes exist; no intended full audit-browser feature was implemented |

# 16. TEST STATUS

| Actual current command/check | Result |
|---|---|
| `scripts/check-development.ps1 -Component Backend` | PASS: 299 tests, zero skipped; format/lint/strict types/build/import checks |
| `-Component AI` | Initial FAIL: cwd-dependent import ordering in new Phase 23 script. Fixed; rerun PASS: 346 tests, 3 explicitly skipped opt-in SQL tests; Ruff/mypy pass |
| `-Component Flutter` | PASS: 296 tests, 11 default opt-in skips; analyzer |
| `flutter pub get`; `dart format --output=none --set-exit-if-changed lib test` | PASS; no dependency/lock update |
| `flutter analyze` + affected foundation/farmer widget tests after copy fix | PASS: no issues; 18 tests |
| `flutter build apk --debug --no-pub --target-platform android-arm64` | PASS: 200.1 s; packaging only, no API URL or device interaction implied |
| `-Component Preprocessing` | PASS: 78 cases in each Python environment, 12 exact synthetic parity cases, Ruff/mypy |
| `-Component Training` | PASS: 219 fixture/tooling tests, Ruff/mypy; no real training/test-set scoring |
| `-Component Prisma` | PASS: validation/client generation/strict types, 13 actual DB cases, eight migrations applied/current |
| `npm.cmd --prefix backend run db:diff` | No structural difference detected; custom SQL invariants additionally covered by catalog tests |
| `-Component Docker` | PASS: Compose config only; not a Docker Engine deployment test |
| Raw integrity + v2 partition checks | PASS: all 8,040 byte hashes/sizes/mtimes; 4,162 eligible contents; zero confirmed content/group intersections |
| Fresh actual model/ASGI lifespan | PASS: startup/shutdown, unauthorized service call rejected, three real synthetic inferences; full-frame/class/artifact/dependency pins validated |
| Fresh actual RAG/provider | PASS: four class retrievals with source metadata; real grounded Common Rust answer; unrelated request safely refused |
| Fresh Node/TCP FastAPI/Gemini + Flutter HTTP health | PASS: real readonly DB, catalogue, pending calculators, protected endpoints reject guest; providerUsed=true/sources; one enabled native Flutter contract |
| Fresh Cloudinary | PASS: readonly authenticated API ping; uploads remain supported by inspected Phase 23 live proofs |
| Repository/privacy/frozen checks | Required roots/templates/ignores, secret/path absence and immutable model/manifests/corpus/schema boundaries checked; results saved in audit evidence |

Default skips are not counted as passes. Three AI SQL tests and eleven Flutter
live tests are deliberately opt-in; Phase 23 enabled/real-tested their contracts,
and this audit freshly enabled only the safe native health case plus readonly probes.
No mock is relabeled a physical UI test. Existing Starlette/httpx and pg concurrency
deprecation notices remain; no dependency/security upgrade was performed here.

# 17. CURRENT CODE ISSUES

- **P0:** none established by this audit. This is not a production-security clearance.
- **P1:** missing farmer registration UI; missing farmer knowledge library integration.
  Codex can implement both against existing APIs/content in a separately requested
  remediation scope. They block this completeness checkpoint.
- **P2:** real calculator domain content; native hardware acceptance; source/local
  agronomic review; secure persistence/privacy decisions; scheduled upload cleanup
  operations; production service/limit/workload policy. Assign each to its deadline
  below rather than pretending all are prior-phase coding defects.
- **P2 security phase:** the local model-health and scan-upload test helpers forward the server
  environment to their Flutter children. The app does not consume/bundle those values,
  but the harness should use the existing minimal tooling allowlist. No secret value
  is included in this report. This audit did not start Phase 24 hardening.
- **P3 fixed here:** cwd-sensitive Ruff import grouping in check-e2e.py; stale Tools
  copy; stale Flutter/AI architecture current-status language.

# 18. WHAT CODEX CAN STILL FIX ITSELF

Implement farmer registration MVVM/repository/form/navigation and meaningful API/
widget tests; implement the farmer disease catalogue/search/detail/source UI over
existing real APIs/corpus; maintain accurate as-built docs and endpoint references.
These are larger missing features and were **reported, not silently implemented**.
No new key, label list, raw path, model training or invented agricultural content is
needed for those coding tasks.

Codex can later implement authorized secure-storage/test-harness isolation changes,
hosting-specific scheduled cleanup/CI, source-backed draft preparation and release
configuration once the relevant phase and human content/hosting choices are supplied.
Do not ask the user to write code, reconstruct dataset metadata or create embeddings manually.

# 19. WHAT I PERSONALLY MUST PROVIDE

**No additional user-provided resource is required before Phase 24.** This does not
mean the code is ready: Codex must first repair the two UI gaps in an authorized
remediation task. Existing provider keys, database, dataset and model all work.

- [ ] **Approved fertilizer content/source and applicability review.** Why: no real
  product kg/ha rule exists. Required by: before claiming a complete calculator at
  the final FYP demo. Provide an authoritative document/link plus product/crop/region/
  stage/conditions/units and approve a justified rate; Codex can prepare candidate drafts.
- [ ] **Approved yield model/rate source and assumptions.** Why: area scaling is not
  an agronomic forecast. Same deadline; supply/approve a sourced kg/ha scenario and
  applicability, or specify an approved different formula for scoped implementation.
- [ ] **Named controlled Admin identity.** Why: live DB has zero users/Admins; tests
  used temporary fixtures. Before demo content administration, choose an email and
  password using the existing masked operator CLI; never send the password in chat.
- [ ] **Android device/emulator access and human acceptance.** Before final demo:
  camera/gallery/permissions/background-return/session/network behavior requires
  real interaction. Codex cannot claim taps on unavailable hardware.

Fresh keys, another dataset path, labels, split metadata and fabricated original
plant identities are **not** requested. Independent field images are optional for
stronger external validation, not required to repair the current UI.

# 20. MY REQUIRED MANUAL ACTIONS

## Before Phase 24

No manual credential/data/configuration task is blocking. The blockers are coding
remediation tasks above. Do not use manual API calls as a substitute for the missing
registration or Knowledge feature.

## Before Phase 25

**Action:** select hosting/target network/domains and who operates secrets/backups.
**Why:** deployment targets/accounts cannot be inferred from local source.
**How:** provide the intended platforms and access through their secret/configuration
facilities, not chat. **Verify:** the deployment phase can map each service, TLS
boundary, database role and immutable artifact to a concrete environment.

**Action:** arrange scheduled `npm.cmd run scans:cleanup` from backend in the selected
environment. **Why:** the CLI exists, but no cron/platform job is configured.
**How:** Codex can configure a platform job after hosting is selected; use the same
DB/storage account, bounded repeated runs and monitored exit codes. **Verify:** a
controlled interrupted upload is compensated and pending counts/exit codes are visible.
The live backend already sweeps interrupted inference every minute; this is a
different job from orphan-upload cleanup. Do not delete completed scan assets.

## Before Final FYP Demo

**Action:** review/publish sourced calculator content. **Why:** agronomic approval
cannot be inferred or invented. **How:** use reviewed Admin draft/version forms,
verify units/region/assumptions, activate explicitly. **Verify:** catalogue READY,
actual-source-backed expected quantities and unchanged historical versions. Until
then label calculators pending; never present synthetic fixture values as recommendations.

**Action:** provision a named Admin. **How:** run
`powershell -File scripts/create-admin.ps1`, enter the chosen email/password through
its secure prompt. **Why:** controlled enrollment requires an operator decision.
**Verify:** Admin can sign in/manage; farmer registration cannot self-select ADMIN.

**Action:** run/install a debug build with a reachable public Node `/api/v1` URL.
**How:** pass `--dart-define=API_BASE_URL=<reachable Node origin>/api/v1`; Android
emulator normally reaches the host through `10.0.2.2`, while a phone needs the host's
reachable LAN address. Configure a development-only LAN bind/network allowance if
needed. Never put the FastAPI origin or provider keys in this define.
**Why:** target-device routing is not inferable without that device/network.
**Verify:** real Home connection and guest/farmer scan/result/history/assistant flows.

**Action:** complete camera/gallery/permission/cancel/resume and restart/logout/expiry
acceptance. **How:** follow section 23 with generated/owned permitted images.
**Why:** no Android device or emulator was connected. **Verify:** record platform,
build, steps/outcome; restart currently must sign out, not restore a session.

## Optional / Future

Independent field/plant/session-labelled validation, larger locally reviewed RAG
evaluation, additional languages/platforms and a validated confidence objective.
Commercial use requires separate dataset/source licensing review or replacement;
research approval is not commercial clearance.

### Unresolved decisions, with deadlines

| Question | Why it matters | Recommended default | Deadline |
|---|---|---|---|
| Which source-backed product rates/yield scenario and local applicability are approved? | Cannot infer agronomic recommendations from an empty catalogue | Keep pending; approve a narrow authoritative scope and reference | Before complete calculator demo/publication |
| Must sessions survive restart? | Controls credential retention/platform storage | Keep documented volatile behavior until Phase 24 explicitly chooses secure persistence | Phase 24 |
| What retention/erasure/provider privacy policy applies? | Determines scan/assets/session/log handling | Minimize retained data; define reviewed policy before deployment | Phase 24/25 |
| Which hosts/domains/roles/operating owner? | Determines TLS, internal networking, scheduler and secrets | Private AI, separate least-privilege credentials and explicit builds | Before Phase 25 configuration |
| Should a model be promoted or confidence cutoff approved? | Research candidate is not field-certified; no approved risk objective | No promotion, T=1 and all LOW_CONFIDENCE until justified validation-only approval | Optional future; before any changed claim |

None of these choices is needed to implement the two missing UI handoffs.
Previously pending class taxonomy/preprocessing/dataset exclusions/embedding provider
questions are resolved; do not ask them again. Broad old JSON-contract TBDs are
superseded for implemented endpoints by current Zod/Pydantic schemas.

# 21. REQUIRED ACCOUNTS / API KEYS

**No provider credential is genuinely missing now.** PostgreSQL/Neon and Cloudinary
are configured/live; AI `GEMINI_API_KEY` supplies working embedding/generation access;
backend/AI service tokens match; JWT access/refresh keys are present and distinct.
Templates already contain the corresponding blank placeholders. See the complete
presence-only configuration inventory; no secret values are printed.

The missing named Admin account is an operator enrollment action, not a missing
Cloudinary/Google/database service account. Production platform/store accounts are
Phase 25 inputs, not invented prerequisites to finish Phase 0–23 code.

# 22. REQUIRED DOMAIN CONTENT

| Content | Required status | Meaning |
|---|---|---|
| Initial maize disease knowledge | ALREADY COMPLETE | Four mapped catalogue entries/25 sourced sections; sufficient for initial UI |
| Initial RAG source documents | ALREADY COMPLETE | Real reviewed texts/vectors/source metadata, not empty tables |
| Fertilizer product/rate data | REQUIRED | Approved product mass rates and applicability absent |
| Fertilizer formula/justification | REQUIRED | Dimensional scaling is coded; source must justify recommendation values/model |
| Yield formula/rate/applicability | REQUIRED | Approved agronomic scenario/model absent |
| Existing disease references | ALREADY COMPLETE | Real extension-source provenance retained |
| Calculator agricultural references | REQUIRED | Must support the actual rules published, not example.invalid fixtures |
| Local source-freshness/agronomist review and richer disease media | OPTIONAL IMPROVEMENT for bounded research demo | Required before broader real advisory claims; publisher-photo rights not assumed |

Codex can research/prepare candidate source-backed drafts in a separately authorized
task. Human approval/local applicability remains the domain trust boundary; the
user need not manually reverse-engineer already-discovered dataset or corpus metadata.

# 23. REQUIRED DEVICE TESTING

Detected targets: Windows, Chrome, Edge. **No Android emulator or physical device was
verified.** Native Flutter tests run on the host; debug ARM64 packaging is not a phone test.

- Camera/gallery: select, capture, cancel, denied/unavailable camera, lost-data recovery
  after background/app interruption; verify valid JPEG/PNG/WebP and rejected oversized files.
- Permissions: system intent/permission flows and recovery after denial. The manifest
  uses optional camera hardware/system picker intents, not broad storage permissions.
- Session: login, concurrent refresh, expiry/revocation and logout; restart must clear
  credentials under the current volatile design. Persistent restoration is not implemented.
- Network: target device → Node URL, slow/offline/timeout/retry, saved scan/history/AI
  sources and low-confidence messaging; no direct device → FastAPI/Gemini secret call.
- Release build: signing/TLS/install behavior is not verified; assign to Phase 25/26.

Record device/OS/build and actual results. Do not label repository/ViewModel/widget
fixtures as emulator-verified or physical-device-verified acceptance.

# 24. DEFERRED TO PHASE 24

Security-only work: current dependency-advisory review/remediation (old findings are
not a fresh vulnerability clearance), production rate/proxy/CORS policy, least-privilege
DB/provider roles, secrets rotation/management, secure native persistence if selected,
privacy/retention and public image-delivery policy, broader semantic prompt-injection/
abuse evaluation, and isolating server environment from local frontend test children.
Already implemented input/auth/RBAC/grounding checks must be preserved. Do not call
these intentionally assigned security tasks a failure of prior feature implementation.
No Phase 24 hardening was performed by this audit.

# 25. DEFERRED TO PHASE 25

Production Docker builds/runtime, hosting/accounts/domains/TLS, private AI networking,
release API defines, approved immutable artifact packaging/promotion policy, Android
identity/signing/distribution, CI/CD, controlled migration deployment/backups/restore,
scheduled upload cleanup and monitoring/alerts. Local Compose validation does not
prove these. Their absence alone is not a Phase 0–23 implementation blocker.

# 26. DEFERRED TO PHASE 26

Final acceptance/tap-through evidence, release/device regression, complete current
screenshots/demo script, as-built documentation reconciliation, viva/FYP explanation,
limitations/disclosure and final cleanup. Missing registration/Knowledge code belongs
to remediation before this final QA, not a documentation-only task.

# 27. BLOCKERS

1. Farmer onboarding cannot self-register in the app despite a real registration API.
2. Farmer knowledge browse/search/detail is not implemented despite real content/APIs.

Separate demo blockers: authoritative fertilizer/yield recommendation content, named
Admin enrollment and native device acceptance. No missing provider key/dataset/model
resource was discovered. No confirmed invalid selected model or current known-group
leakage justifies retraining. Do not replace unknown field identity with fabricated metadata.

# 28. EXACT NEXT STEP

**Request targeted Phase 4/13 mobile-onboarding and Phase 6 farmer-knowledge remediation.**
Reuse existing backend registration and sourced disease APIs, implement MVVM UI wiring,
and verify the actual user-facing flows. This is Codex coding work requiring no new
credentials or agricultural paragraphs. Larger missing features were intentionally
not implemented during this audit.

Keep calculator content honestly pending until reviewed sources are approved, and
schedule native/manual acceptance before the final demo. After those coding repairs,
repeat this readiness checkpoint. **Do not begin Phase 24 automatically.**
