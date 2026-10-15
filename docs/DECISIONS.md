# Engineering decisions

Recorded: 2026-10-05 (Asia/Karachi), during the Phase 2 audit. This file was missing
at audit start. Entries below consolidate the existing implemented database design
and the audit corrections; they do not authorize later feature implementation.
See [database design](05-database-design.md) and [project state](PROJECT_STATE.md).

| Decision | Rationale and boundary |
|---|---|
| PostgreSQL + Prisma 7.10.0 and the pg driver adapter | Relational persistence follows AGENTS.md. Stable, matching CLI/client/adapter versions remain locked; no ORM upgrade during the audit. |
| Nineteen application tables in `public` | Implements the requested list. Prisma's migration bookkeeping table is additional. No speculative session, token, job, or other feature tables are added. |
| Environment-supplied runtime and migration URLs | `DATABASE_URL` serves runtime queries; `DIRECT_DATABASE_URL` serves session-dependent CLI/replay operations, falling back for unpooled local servers. Secrets stay in ignored local files or deployment environment. |
| CLI connection timeout defaults to 30 seconds | The default 5-second CLI connection timeout failed against the configured remote development database; 30 seconds connected successfully. Explicit URL timeout settings take precedence; runtime pg timeout is separate. |
| UUID IDs and timezone-aware timestamps | PostgreSQL generates IDs. Mutable records track update times in Prisma and SQL; immutable event/version payloads retain their creation identity. |
| FARMER and ADMIN roles, optional farmer profile | Accounts represent future authentication/RBAC without implementing authentication. Profiles and owned scans/history require farmers. |
| Nullable, immutable anonymous scan ownership | Anonymous scans have no user. Owned scans stay associated with their farmer; account deletion cannot silently anonymize them. History/scan notification foreign keys prevent cross-farmer and anonymous references. |
| Versioned model, knowledge, rule, and calculator records | Changes to version payloads require a new version. Predictions reference the exact model. Partial unique indexes select one active logical record or production model. |
| Creator provenance may clear but cannot be reassigned | Nullable creator references support account deletion through SET NULL. The audit correction prevents another account being assigned to the original version, including reassignment after clearing. |
| Curated agricultural sources and deterministic configuration | Documents retain text hashes/source/version; calculator/rule records retain units and source references. JSON payloads support future contracts, not implemented RAG or numerical formulas. |
| N / P2O5 / K2O fertilizer label percentages | Fixed-point values are individually bounded. Oxide-equivalent label values must not be subjected to an elemental-sum rule. |
| PostgreSQL pgvector with explicit embedding metadata | Nullable vectors retain model/dimension/readiness. Prisma marks the vector unsupported; future Python/parameterized SQL handles vector operations. No production embedding dimensions or ANN indexes are selected. |
| Versioned atomic SQL migrations own database-only invariants | CHECK constraints, partial indexes, and trigger functions remain in migrations. Applied migrations are preserved; fixes use a follow-up migration. Validation/diff are supplemented by catalog and rollback tests. |
| Empty, typed seed groups until reviewed data exists | Repeat upserts preserve existing records. No invented agricultural advice, production models, or default credentials. |
| Neon verifies the complete development schema | The configured Neon database provides pgvector. Local Compose includes pgvector but cannot be started without Docker Engine; native Windows PostgreSQL needs pgvector installed. |

## Phase 3 backend foundation decisions (2026-10-05)

| Decision | Rationale and boundary |
|---|---|
| Express app factory, separate executable/lifecycle, feature modules | Preserve the required route/controller/service/repository chain. Health keeps its layers together; shared infrastructure stays at root. No DI container or empty generic layers. |
| One runtime Prisma client; standalone factory retained | Avoid per-request pools while keeping seed and database verification isolated. A startup query verifies connectivity before HTTP listens. No schema or migration change. |
| Single JSON envelope with server-generated correlation ID | Success returns data, errors return stable safe codes/messages; validation exposes paths/codes only. Reject arbitrary client IDs and keep secrets out of request logs. |
| Database-aware health is a readiness report | 200 when reachable, 503 with the same safe report when down. The health envelope's success flag means the report was produced; monitoring uses HTTP status/data.status for readiness. No provider/ML health checks yet. |
| Zod validation stores parsed input in Express locals | Supports body/params/query including coercion without assigning Express 5's query getter. Only operational settings are validated at startup; unused provider/auth secrets remain optional. |
| Loopback binding, exact CORS allowlist, bounded JSON and per-process rate limits | Secure, explicit local defaults; originless mobile/server clients remain supported. Proxy trust and shared rate-limit storage require actual deployment topology. |
| Bounded shutdown drains HTTP before disconnecting Prisma | Signals and fatal errors share an idempotent path; deadline prevents indefinitely stalled cleanup. Fatal failures exit nonzero. |
| Biome and built-in Node tests through tsx | One maintained formatter/linter with an explicit any ban; reuse existing Node test tooling without a new test framework. Preserve applied SQL and generated client formatting. |

## Phase 4 authentication decisions (2026-10-06)

| Decision | Rationale and boundary |
|---|---|
| One additional AuthSession table | Stateful revocation is required now; preserve the 19 domain tables and add only the necessary session persistence with an additive fourth migration. |
| Argon2id: 64 MiB, three passes, one lane, random salts | Memory-hard password hashing; support 15-128 code-point registration passwords without trimming/composition rules. Store only hashes. |
| Independent required base64url keys; HS256 with fixed purpose/audiences | No hardcoded credentials; verify issuer/type/claims/expiry. Access defaults to 15 minutes, refresh session to 7 days with a fixed absolute end. |
| Digest rotation through transactional conditional UPDATE | Atomic token consumption works across replicas. Reuse revokes the family; commit revocation before throwing. Clients serialize refresh; no grace window or sliding lifetime. |
| Access checks live session/user state | Logout and replay revoke access immediately; current database roles/status avoid stale token privileges. JWT subject is an opaque session handle; account IDs/roles/email are not JWT claims. |
| Refresh only in host-bound HttpOnly cookies | Keep refresh tokens out of JSON. Secure/SameSite Strict in production plus exact credentialed CORS, JSON and custom-header POST guard. Native clients retain a secure cookie jar; arbitrary cross-site browser hosting is unsupported. |
| Registration FARMER only, ADMIN through operator stdin CLI | Reject role injection; no public admin creation, default credentials, silent promotion or user overwrite. No automatic admin is provisioned. |
| Explicit duplicate registration, generic failed login | Return required 409 conflicts; login hides account/status distinction and incurs work for unknown identities. Auth endpoints have additional per-IP limits. |

## Phase 5 Flutter foundation decisions (2026-10-06)

| Decision | Rationale and boundary |
|---|---|
| core/data/features with scoped MVVM state | Respect View -> ViewModel -> Repository -> API client; stateless dependencies are app-scoped, Home ChangeNotifier is route-scoped. Create other feature layers when workflows exist. |
| Compatible go_router stateful shell with five farmer branches | Preserve navigation/scroll state and nested back behavior; bottom bar changes to scrollable rail on wide screens. Keep reserved Admin boundary separate. |
| Material 3 light theme with centralized tokens | Forest scan accents, ivory surfaces, blue knowledge and amber tools, readable Roboto typography, scalable spacing/radii and minimum 48-point interactions. |
| Public dart-define URL, optional offline shell, HTTPS in release | No hardcoded production URL or bundled .env/secrets. Validate configuration and provide bounded JSON transport/safe errors. Secure token persistence and refresh integration are deferred. |
| Existing health API is the concrete integration example | Verify the entire MVVM/transport chain without inventing agricultural data or implementing business/AI features. Other areas expose honest foundation views only. |

## Phase 7 upload decisions (2026-10-06)

| Decision | Rationale and boundary |
|---|---|
| One durable ScanUpload journal, plus explicit scan uploadedAt | Required for cross-provider compensation, interrupted-upload recovery and safe retries. Preserve existing domain tables and applied SQL; add only a fifth migration. Original bytes stay outside PostgreSQL. |
| Owner-scoped UUIDv4 request digest and exact image SHA256 | Conditional claims prevent parallel uploaders; completed same-key retries return the same scan. Anonymous keys act as private retry capabilities, with no unrestricted read endpoint. |
| Upload first, atomic scan + journal completion, bounded compensation CLI | No scan row exists before accepted storage. Reread completion on uncertain commits; delay uncertain provider cleanup 15 minutes. Scheduled cleanup never claims completed scans and prunes cleaned failed attempts after 24 hours. |
| JPEG/PNG/WebP, 5 MiB and 16 million pixels, still frames only | Security decode original bytes on Node with strict decoder/time/concurrency limits; no separate ML preprocessing implementation. Python still owns training/inference preprocessing. |
| Cloudinary authenticated assets with server-signed HTTPS URLs | Avoid unsigned public delivery and keep provider credentials server-only. Signed URLs are persistent bearer capabilities; saved-scan retention and owner-checked future delivery remain unresolved. |
| Scoped Flutter Scan ChangeNotifier and unchanged-byte multipart upload | Explicit preview before upload, genuine transfer progress followed by saving state, retry uses the same in-memory key. Gallery/camera business logic stays in datasource/repository/ViewModel layers. |

## Phase 8 AI foundation decisions (2026-10-07)

| Decision | Rationale and boundary |
|---|---|
| FastAPI factory/lifespan and configured Uvicorn executable | Keep tests isolated and startup validation before listening; preserve locked Python 3.11 CPU/image setup without heavy imports or external calls in the application. |
| Safe typed process health independently of model readiness | `/health` reports lifecycle, absent model and unimplemented capabilities; no fake model version or readiness. Future operations will use `/api/v1`; health remains an operational exception. |
| Loopback/no browser CORS; future shared-token dependency | Node owns public authorization/orchestration. Production or non-loopback binding requires a random base64url server token; future protected routes fail closed. Health needs no local credentials. No Node integration, mTLS or deployment change yet. |
| Pydantic settings, allowlisted JSON events and fixed error contracts | Service-local dotenv with OS precedence; never echo rejected values, arbitrary exception/library messages, headers/body/query or dynamic path values. Generic server events trade detail for secret protection. |
| Ruff formatting/lint and strict mypy for service source | Extend existing pytest/HTTPX without a new test framework; dev tools stay in the locked environment. Future AI directories document boundaries rather than fake implementations. |

## Phase 9 preprocessing decisions (2026-10-07)

| Decision | Rationale and boundary |
|---|---|
| One typed installable package in shared/preprocessing | Both Python manifests/locks install exactly the same local dependency, avoiding consumer-owned duplicate transforms. Existing seven component roots remain; shared hosts this requested cross-component implementation. |
| Version 1.0.0 plus canonical configuration and supplied-mask hashes | Record source bytes, settings, mask provenance and library versions. Future models pin the evaluated version/configuration; default 224/RGB/neutral normalization is a foundation contract, not selected classifier hyperparameters. |
| Full-color perimeter-connected extraction with conservative fallback | Preserve enclosed brown/yellow/gray/rust/dead tissue without a healthy-green assumption. Uniform-background gates, all-component retention and outward-only margin reduce loss; uncertain scenes preserve the full frame or explicitly fail by policy. No semantic leaf detector or random GrabCut. |
| Explicit orientation/profile/alpha and unsigned16 grayscale handling | Standardize color before segmentation, preserve nonzero-alpha tissue and grayscale gradations; no per-image contrast enhancement/lesion cleaning. Provided masks describe the oriented frame and require identical training/serving policy. |
| Aspect-preserving letterbox and RGB CHW float32 with unchanged optional tensor | One crop/resize/normalization implementation, no random augmentation or extra torch transforms. Debug artifacts and deterministic/cross-environment tests support review; real-image validation was pending at Phase 9 and is recorded in the subsequent Phase 9.5 report. |

## Phase 9.5 dataset configuration decision (2026-10-07)

| Decision | Rationale and boundary |
|---|---|
| One DATASET_PATH loader for intake, validation and future training | Read training-local ignored `.env` independently of cwd, with explicit OS precedence and no interpolation/global environment mutation. Require an absolute existing directory; keep the machine path out of code/templates/Git. Inventory invokes the existing shared pipeline and writes development review artifacts only. No training or preprocessing policy change is authorized. |

## Approved Phase 10 preparation and baseline decisions (2026-10-07)

| Decision | Rationale and boundary |
|---|---|
| Exclude 11 shared-rejected inputs and all three contradictory label families | User approved auditable reason-coded index exclusions. Do not delete, rename, modify or relabel originals. Collapse content-identical copies; confirmed derivative families stay in one partition. Preserve the four literal class labels. |
| Non-commercial academic/FYP research only | Preserve source/license/provenance declarations; no redistribution of raw dataset images through Git, reports, artifacts or app. This approval does not establish commercial clearance. Commercial licensing review or dataset replacement is required before commercial use. |
| Full-frame shared preprocessing for the first baseline | User approved disabled extraction following Phase 9.5 evidence. Both training and future serving load the exact recorded shared 1.0.0 configuration/hash. Canonical generic package defaults are preserved. |
| Explicit 224×224 RGB letterbox and ImageNet normalization in the shared configuration | The selected pretrained MobileNetV3 Small uses ImageNet channel mean/std. Configure those values in the shared package rather than adding a consumer-owned preprocessing transform. Keep the full leaf frame instead of adopting the weight library's center crop. Pin the complete configuration with each artifact. |
| Grouped stratified 70/15/15 split, seed 20261007 | No official split exists. Group content-identical and confirmed derivative relatives first; persist class mapping, eligibility, exclusions and partition manifests with checksums. Test is reserved for final evaluation, never augmentation or tuning. |
| CPU MobileNetV3 Small transfer-learning baseline | Lightweight architecture suits the existing four-core CPU environment. Verify dataset/index/splits and a small train/validation smoke test before the full run. Select checkpoints using validation only; retain versioned experiment outputs. |

## Final Phase 10.5 candidate decisions (2026-10-09)

| Decision | Evidence and boundary |
|---|---|
| Versioned v2 lineage repair, full contradictory-family exclusion | Actual transformed-parent leakage invalidates v1 independence; preserve all originals/labels/artifacts, union confirmed families and apply existing exclusion policy to four newly contradictory components. Keep existing grouped splitter/seed; record all moves/reasons. |
| Research/FYP MobileNetV3 Small v2 candidate, epoch 8 | Fresh bounded correction selects highest validation macro F1 only. Freeze checkpoint/config/source/data/class hashes before single descriptive test. FIT WITH DOCUMENTED LIMITATIONS; no field/commercial certificate or Phase 11 implementation. |
| Calibration disabled, method none, T=1 | Validation-group cross-fit worsens NLL/Brier/ECE; apparent all-validation fitted-T improvement is in-sample. Preserve raw probabilities rather than promote unsupported temperature scaling. |
| Confidence threshold remains unlocked | Validation cutoff 0.95 retains confident errors and reduces GLS coverage; risk/coverage/class-cost objectives undefined. Null is an explicit pending product policy, not approval for a default arbitrary cutoff. |

## Phase 11 inference decisions (2026-10-09)

| Decision | Rationale and boundary |
|---|---|
| Three-file pinned runtime, once-per-lifespan frozen CPU classifier | Configure the approved metadata SHA; metadata binds checkpoint/calibration bytes. Validate explicit class/input/shared config/runtime/state/output before readiness, with no downloads or guessed defaults. Deployment needs no raw dataset or training modules; immutable model artifacts remain unchanged. |
| Raw image bytes on authenticated internal versioned routes | Reuse existing constant-time server-token authentication for predict/model health, required even on loopback inference startup. Shared image validation is authoritative. Reserve bounded capacity before buffering, limit bytes/upload time and run CPU work off the event loop; Node/Flutter orchestration is deferred to Phase 12. |
| Null certainty policy remains explicit; optional separately pinned validation-derived policy | Phase 10.5 did not approve an operational cutoff. All current predictions are LOW_CONFIDENCE/THRESHOLD_UNCONFIGURED. Any future research policy must bind the exact model/checkpoint/validation predictions and record an approved validation-only rationale; no threshold selection, calibration or TEST tuning occurs here. |

## Phase 12 integration decisions (2026-10-10)

| Decision | Rationale and boundary |
|---|---|
| Configured origin and unchanged raw image bytes | Fixed internal prediction path, server-only token, bounded deadline/body and no redirects or user-controlled URL fetching. Node validates eligibility without implementing ML transforms; FastAPI stays authoritative. |
| Synchronous bounded inference after durable upload completion | Reuse Cloudinary and upload journal; inference failure retains image/scan with safe FAILED outcome. Same owner/key/bytes retries inference without uploading again. No queue, stored-image download or automatic inference replay is invented. |
| Conditional attempt UUID and bounded stale recovery | Prevent expired writers from overwriting a later retry. Two-minute lease, one-minute lifecycle sweep and cleanup CLI mark interrupted work failed; max100 rows with DB locking. Recovery preserves completed assets and never fabricates results. |
| Prediction outcome columns, immutable ModelVersion reference | Sixth additive migration, no extra tables. Validate all probabilities and uncertainty before atomic insert/completion; historical predictions keep absent metadata. Register pinned approved metadata as VALIDATED research, never silently promote/overwrite. |
| Farmer ownership or anonymous private original request key for GET | Scan UUID alone grants no anonymous access. Existing request-key digest provides bounded rate-limited/no-store reads and retry capability; ADMIN remains denied until an explicit admin access policy exists. |

## Phase 13 farmer experience decisions (2026-10-10)

| Decision | Rationale and boundary |
|---|---|
| Reuse public scan projection for private FARMER history | Add one bounded owner-filtered GET, UUID cursor and native timestamp/ID ordering. No extra tables, migration, public guest history or ADMIN listing. Foreign cursor access is 404. |
| Minimal volatile native farmer sessions | Enable authenticated scans/history through existing backend login/rotation/logout. App identity and HTTP share one credential source, replacing the unused app-level raw-token injection seam so UI/network cannot represent different farmers. Transport tests retain AccessTokenSource injection. Credentials/cookie remain only in memory; serialize refresh and fence delayed responses. Restart requires login; no persistence/browser implementation. |
| Route-scoped result/history state bound to identity revision | One shared result presentation, local private guest key and same-byte retry; remount on identity changes and ignore old route extras. No signed URLs/private keys in navigation URLs. Original-byte-free history details start a fresh scan rather than fetching/reuploading stored images. |
| Display model score and explicit uncertainty | Preserve literal labels and current null threshold; even high scores remain uncertain. No advice, arbitrary cutoff, calibration, preprocessing or model changes. |

## Phase 14 knowledge/retrieval decisions (2026-10-12)

| Decision | Rationale and boundary |
|---|---|
| Complete the missing Phase 6 foundation within Phase 14 | Existing knowledge tables were empty and had no ingestion/read API. Add sourced catalogue/read APIs and only required topic/provenance/embedding-version columns; seventh additive migration plus an eighth correction for the READY guard under restricted search paths. No new tables or full admin UI. |
| Intentionally curated university-extension summaries | Preserve four literal labels, original publisher/source/date/rights/region and content/review hashes. No automatic scraping, copied pages/images or generated facts. Healthy has scouting context only; unsupported topics remain absent. |
| User-approved Google embeddings, explicit text-only model configuration | Select `gemini-embedding-001`, deployment version `google-task-v1-20261012`, 768 dimensions and L2 normalization. No hardcoded model fallback or Flutter secrets. Live verify explicit task/output fields; incompatible vectors fail closed. |
| Python owns ingestion/embedding/pgvector retrieval; Node owns public read/orchestration | Prisma repositories serve the catalogue; typed authenticated fixed-origin Node client invokes internal retrieval. Python uses parameterized PostgreSQL for unsupported vector fields; this follows the existing AI ownership boundary. |
| Immutable versions and atomic publication after provider work | Persist source/config/content/chunk lineage; unchanged re-ingestion skips network embeddings, changed same-version payload conflicts. Archive prior active versions without deleting historical chunks; READY vectors cannot be replaced. |
| Deterministic character windows and exact cosine search | Explicit chunk size/overlap, canonical NFC/line endings, offset/hash identities. Actual initial corpus has 25 chunks; no premature ANN index. Filters require active English documents, active diseases and matching embedding/config identity. |
| Retrieval returns evidence candidates with no calibrated cutoff | Small filtered and unfiltered development evaluations support basic relevance; they do not establish agronomic accuracy or out-of-domain rejection. Similarity is a ranking score, and no answer is generated in Phase 14. |

## Phase 15 grounded-generation decisions (2026-10-13)

| Decision | Rationale and boundary |
|---|---|
| Official Google GenAI SDK with explicit deployment model | Lock `google-genai` 2.29.0 in the existing AI environment; keep Phase 14 REST embeddings unchanged. One owned SDK/HTTPX client per lifespan, no source-code model fallback, server-only key. The local selection is `gemini-3.5-flash-lite`; availability is verified separately from startup readiness. |
| Gemini selects evidence; server renders reviewed document excerpts | Structured `{status, evidenceIds}` avoids publishing unchecked paraphrases whose truth cannot be established merely from citation IDs. Pin corpus/review hashes, verify text offsets/content/source/curation and full retrieved coverage, deduplicate overlap and bound context. This is a conservative first generation policy, not a claim of agronomic entailment or calibrated answer safety. |
| Scoped English questions and explicit honest abstention | Support one known label/topic per general question and four relevant topics for scan explanation. Refuse unsupported numerical/local prescriptions, missing evidence, ambiguous competing documents and recognized injection. Lexical scope guards do not provide comprehensive semantic out-of-domain or injection detection; no arbitrary cosine cutoff is introduced. |
| Explain only authorized, persisted classifier context | Node reads through the existing owner/private-key scan policy, then sends seven immutable scalar prediction fields. Reject changed class/score/versions/uncertainty in the reply. No image URLs, account IDs or anonymous capabilities go to Gemini; high scores retain the approved model's LOW_CONFIDENCE/null-threshold warning. |
| Bounded provider calls and metadata-only logs without conversation persistence | Fixed service/provider origins, strict structured contracts, response limits and safe error mapping preserve the existing trust boundary. Node enforces a whole-call deadline; SDK I/O timeout plus between-read budget is not a strict total deadline. No new table/migration, private-content logs, `ai_queries`/`ai_responses` writes or retention policy. |

See [grounded generation](31-grounded-generation.md) for complete contracts, setup,
official SDK/model references and remaining evaluation/source limitations.

## Phase 16 farmer-assistant decisions (2026-10-13)

| Decision | Rationale and boundary |
|---|---|
| Route-local bounded conversation without persistence | Keep at most 12 temporary turns in a feature-scoped ChangeNotifier; send only the current question and explicit enum filters, never chat transcripts. Existing AI query/response tables remain unused. Guests have no account history; farmer scan history remains a separate owned resource. A retention/privacy design is required before future conversation storage. |
| Explicit condition/topic focus for short follow-ups | Flutter exposes the four existing literal labels and seven reviewed topics. FastAPI accepts a validated known label as a maize-domain hint while retaining unsupported-topic/injection/conflicting-label checks, reviewed-context admission and provider abstention. No hidden history inference, general chatbot or arbitrary similarity cutoff. |
| FARMER-only scan-context UI through the existing ownership API | Reuse private paginated history and completed-result navigation with identity revision binding. Send the scan ID and empty JSON under authentication; Node obtains the persisted seven-field prediction and verifies ownership. Preserve the existing guest capability API, but guest assistant UI handles questions only. Classifier scores/uncertainty remain unchanged. |
| Strict typed evidence and selectable source presentation | Reuse Node's versioned answer contract, rejecting malformed/unused citations and incompatible classifier context. Show verified evidence, source/date/rights and uncertainty using existing design tokens and plain selectable text/URLs. No HTML execution, URL launcher or Gemini credential in Flutter. |
| Volatile identity/draft boundaries and assistant-specific deadline | Remount on identity revision, ignore stale navigation extras and fence cleared/disposed requests. Closing the route or Clear discards conversation; switching tabs can retain the mounted route. Use a 40-second assistant deadline above Node's existing 30-second deadline without changing ordinary 15-second calls or upload behavior. Clear is state cancellation, not a guarantee of provider-worker cancellation. |

See [farmer AI assistant](32-farmer-ai-assistant.md) for the public flow, privacy,
input/response contracts and verification.

## Phase 17 fertilizer decisions (2026-10-15)

| Decision | Rationale and boundary |
|---|---|
| Reviewed product-area-rate engine with pending content | No authoritative rate exists in repository/seeds/database. Scale an intentionally approved MAIZE product kg/ha rate; do not infer soil/NPK need, invent defaults or seed synthetic fixtures. Empty catalogue stays PENDING_RULES. |
| Exact decimal strings/BigInt and one final HALF_UP rounding | Preserve input and every international-acre conversion digit, then optionally convert kg to grams. Round only in the selected output unit under a pinned config; disclose exact unrounded value and tiny-positive rounded-zero warning. NIST's international acre is exactly 0.40468564224 ha. |
| Reuse immutable rule/configuration tables with frozen product snapshot | Existing SQL guards/one-active constraints suffice without migrations. Rules bind source/review and full product snapshot/config version; mutable product drift or unknown/legacy parameters fail closed. Input pins reject stale versions rather than silently substituting a new rate. |
| Controlled ADMIN draft/publication and source-review attestation | Existing JWT/live-session RBAC protects management. Stamp server-owned actor/time, require source/citation/applicability/assumptions/review note, serialize publication and retain audit/version lineage. An authorized review is a trust boundary, not automated URL verification. No full admin dashboard or historical payload editing. |
| Public stateless Flutter MVVM calculator without AI | Guests/farmers use the same public catalogue/calculation and no personal calculation history. Route-local form/result state preserves server decimal strings; stale-rule retry only refreshes for explicit recalculation. No Flutter/provider secrets, client quantity math or Gemini explanation is introduced. |

See [fertilizer calculator](33-fertilizer-calculator.md) for contracts, unit provenance,
publication semantics, verification and the real-content prerequisite.

## Phase 18 expected-yield decisions (2026-10-15)

| Decision | Rationale and boundary |
|---|---|
| Pending agronomic configuration with dimensional projection framework | No project-approved yield model/rate exists. Implement only area scaling of a future reviewed kg/ha scenario; no crop-performance coefficients, arbitrary formula eval, population/history/soil/weather inputs or default forecast. Production stays PENDING_CONFIGURATION. |
| Reuse exact calculator units/admission and Flutter form primitives | One BigInt coefficient/scale implementation serves fertilizer and yield. Preserve Phase 17's kg/gram API; yield adds kg/metric-tonne output with exact international-acre conversion and one final HALF_UP round. Share area validation/wire helpers/source parsing/form, retaining feature-local ViewModels. |
| Existing immutable YIELD configuration and controlled publication | No migration/table is required. Server-owned template/engine/formula/review identity, source/applicability/assumptions and pinned ID/version bind each result. ADMIN transactions retire prior active config and audit changes; invalid/legacy/unreviewed metadata fails closed. Human approval remains the source-review trust boundary. |
| Conditional, stateless farmer planning UX | Show assumptions/source before calculation and exact decimal results/version/uncertainty afterward. Guests/farmers use public Node calls with no personal calculation history. Edits/disposal fence late results; stale retry refreshes without silent recalculation. Gemini is absent from the numeric and explanation flow. |

See [expected yield](34-expected-yield-calculator.md) for contracts, pending source
requirements and verification. Stop after Phase 18.

## Phase 19 farmer analytics decisions (2026-10-15)

| Decision | Rationale and boundary |
|---|---|
| Own-scan usage and latest-prediction counts | Use the live FARMER session ID only. Anonymous scans stay anonymous; ADMIN has no implicit access. Count one latest prediction per COMPLETED scan, deterministically by timestamp/UUID, with missing and unknown legacy labels explicit. Do not infer correctness, prevalence or calibrated confidence from user predictions. |
| Bounded UTC SQL aggregates without a new schema | Inclusive 1–366-day creation-date windows, one parameterized summary statement and bounded native-timestamp cursor activity reuse existing owner/date and prediction indexes. Avoid returning raw histories to Node or adding premature caches/summary tables/indexes. |
| Route-local private Flutter analytics | Provider/ChangeNotifier → repository → shared authenticated API client. Session revisions hide old data and fence delayed results. Responsive cards/count bars and at most six contiguous time periods retain every day; no persisted statistics, chart dependency or ML evaluation is added. |

See [farmer analytics](35-farmer-analytics.md) for contracts, semantics and verification.
Stop after Phase 19.

## Phase 20 Admin dashboard decisions (2026-10-15)

| Decision | Rationale and boundary |
|---|---|
| One ADMIN-only system aggregate API | Query current FARMER account statuses, date-filtered lifecycle/ownership/latest-label counts and ten minimal activity entries in PostgreSQL. Reuse shared Phase 19 SQL/date/zero-bucket behavior; no client raw-scan aggregation, user identities, extra migration/cache or model-performance claim. |
| Separate volatile Admin session and navigation | Admin route sits outside the farmer shell, with independent credential/cookie stores and API clients. Extract existing refresh/revocation mechanics for reuse; role-specific admission retains Farmer-only login and rejects/revokes wrong-role grants. Restart requires sign-in; no credential persistence or public Admin registration. |
| Explicit registry/configuration and missing telemetry | Report only a single actual PRODUCTION row as current registry version; multiple rows are a conflict. Configured inference is separate and live readiness remains NOT_CHECKED. The assistant does not journal requests, so AI totals are NOT_RECORDED rather than inferred from unrelated tables. Detailed runtime ML health remains later scope. |

See [Admin dashboard](36-admin-dashboard.md) for contracts and verification.
Stop after Phase 20.

## Phase 21 Admin management decisions (2026-10-15)

| Decision | Rationale and boundary |
|---|---|
| Immutable reviewed draft → explicit index → explicit publish | Node owns validated versions/status/audits; Python owns canonical text, configured chunking/embedding and atomic READY insertion. Existing immutable tables/locks suffice. Provider failure never publishes a draft or replaces old content, and policy mismatch requires a new version rather than rewriting READY vectors. |
| Versioned source snapshots and fixed classifier contexts | Source edits accompany a new document version/source record, preserving old citations. Disease name/description/visibility edits use revision checks and audits; class labels/slugs have no rename/delete API. Calculator product snapshot edits require a new product slug; no trained model or algorithm changes. |
| Request-local admission of reviewed active Admin evidence | Pinned corpus identities remain pinned. Current Admin documents require stamped review/creator/current index identity and activation audit, then the same exact content/hash/offset/source/coverage/injection checks. Archived evidence is not cached as active or silently reused. |
| Reuse calculator publication and typed Admin forms | Expose admitted draft projections, require fresh review, confirm lifecycle changes and retain immutable old results/versions. Publication audit identifies auto-retired IDs/versions. No arbitrary JSON/formula editor, invented agronomic rate or new history store is added. |

See [Admin management](37-admin-management.md) for API contracts, rebuild semantics,
human review trust boundary and verification. Stop after Phase 21.

Pending decisions:
full business JSON validation contracts, retention and
completed-scan retention/delivery/deletion, production least-privilege roles,
production hosting/promotion and operational confidence policy, larger retrieval evaluation/relevance policy,
source freshness/local agronomic review and future vector-index scaling. Address these
only in a phase explicitly authorized by the user.
