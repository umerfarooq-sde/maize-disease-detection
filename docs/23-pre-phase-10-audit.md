# Pre-Phase-10 engineering audit

Audit date: 2026-10-07 (Asia/Karachi). Scope: the implemented Phase 0–9 foundation.
This report records fresh checks and traced contracts, rather than relying on previous
phase reports. No training, inference, RAG, Gemini, mobile authentication, disease APIs
or deployment was implemented. No dependency versions or applied migrations were changed.
See [project state](PROJECT_STATE.md), [known issues](KNOWN_ISSUES.md) and the
[roadmap](14-roadmap.md). Unresolved choices remain unresolved in [decisions](DECISIONS.md).

## 1. OVERALL STATUS

**NOT READY FOR PHASE 10.** Existing implemented foundations pass their checks, including
real development PostgreSQL and Cloudinary integration. No new P0/P1 application-code
defect was established. Training readiness is blocked by missing raw data, an approved
class taxonomy, source/split/group provenance, and real-maize preprocessing review.
The repository is technically prepared for dataset inspection; it is not yet a verified
training dataset or an executable training pipeline.

The explicit compatibility answer is: the implemented foundation is stable enough to
build Phase 10 on, once its external inputs and evaluated preprocessing policy exist.
Starting training now would rely on unconfirmed labels and synthetic-only extraction
evidence. Passing compilation cannot resolve those inputs.

### Review coverage and architecture

Read AGENTS.md, README, state, decisions, architecture/operations documents, scripts,
root configuration, all environment templates and all authored component source/tests.
KNOWN_ISSUES.md was absent at audit start and is created by this audit. Reviews covered
42 backend source files, 17 test/support files, the complete schema/seeds/five SQL
migrations, 43 Flutter lib files and 11 test files plus native configuration, all AI/
shared/training source/tests, manifests and parsed locks. Installed dependencies were
checked against manifests/locks. Generated clients, vendored dependencies, build output,
virtual environments and caches were inspected only where needed for actual versions
and execution; they are not additional authored application implementations.

The seven required roots exist. `shared/preprocessing` is the documented Phase 9 addition.
No actionable circular import, duplicated preprocessing, business logic in controllers/
widgets, unsafe application `any`, or broken authored import was found. Empty feature
boundaries document future ownership and do not pretend to implement functionality.
Android release-signing/application-ID TODOs remain release work. Test fixture typing,
explicit inspection CLI output and ordinary exception declarations are not dead features.

Current traced flows:

```text
Flutter View → scoped ChangeNotifier → Repository → Datasource/API Client
  → /api/v1 Node route → Controller → Service → Repository → shared Prisma → PostgreSQL
                                              → Cloudinary storage adapter

FastAPI app.preprocessing ───────┐
                                ├→ shared/preprocessing/maizedoctor_preprocessing
ml-training/preprocessing.py ────┘

Node → FastAPI orchestration: future, not implemented
FastAPI → model / retrieval / Gemini: future, not implemented
```

Flutter does not call FastAPI. Node performs upload security validation and business
orchestration; it does not run ML preprocessing. Python owns the shared model-input
transformation. Training and future inference must retain this exact shared package.

## 2. PHASE STATUS

| Phase | Status | Evidence and practical limit |
|---|---|---|
| 0 — repository/docs | PASS | Required roots/templates/ignore checks pass; stale current-status documentation corrected. |
| 1 — development infrastructure | PASS WITH WARNINGS | Actual Node, Flutter and both Python environments work; Android debug APK builds. Docker Engine absent, some Android licenses unaccepted, installed Python patch old. |
| 2 — PostgreSQL/Prisma | PASS | Schema/client valid, all five applied migrations consistent, no structural drift, SQL replay/catalog/constraint tests pass. |
| 3 — backend foundation | PASS | Strict types, middleware, safe envelopes/errors, health and lifecycle verified. |
| 4 — backend authentication | PASS WITH WARNINGS | Registration/login/session rotation/replay/logout/RBAC pass; secure native Flutter session integration is deliberately deferred. |
| 5 — Flutter foundation | PASS WITH WARNINGS | MVVM/design/navigation/state/error tests and responsive renders pass; physical-device and iOS/release verification pending. |
| 6 — disease knowledge | NOT FULLY TESTABLE | This phase was explicitly skipped. No disease CRUD/knowledge API or reviewed seed facts exist. It was not completed implicitly. |
| 7 — uploads/scans | PASS WITH WARNINGS | Guest and farmer pending scans, actual PNG/JPEG/WebP provider upload, replay and cleanup pass. Physical camera/gallery and scheduled crash cleanup remain manual/operational items. |
| 8 — FastAPI foundation | PASS | Actual startup/health/errors/settings/logging/shutdown and 50 tests pass. No model readiness or Node integration is implied. |
| 9 — shared preprocessing | PASS WITH WARNINGS | Same source, 78 tests in each consumer and eight parity cases pass. Real leaves and field behavior are NOT FULLY TESTABLE without data. |

The Phase 6 skip does not prevent local supervised training if appropriately licensed
labels are supplied, but the product's disease knowledge and later management workflows
remain incomplete.

## 3. CRITICAL ISSUES

No P0 issue or new P1 implementation defect was found. Two P1 external prerequisites
block the training checkpoint:

1. No actual maize image dataset, confirmed class list/mapping, license/source manifest,
   original/augmentation linkage, or independent grouping/official split information.
2. No representative real-image assessment of shared extraction, lesion retention and
   fallback. The default dimensions/normalization/mask policy are foundation settings,
   not empirically selected classifier settings.

There is no evidence of data loss from audit checks. Before/after snapshots match:
all 21 application tables contain zero records, five migration checksums match the
committed SQL, and no temporary replay schema remains. Only generated audit fixtures
and their provider assets were removed. No reset, seed, migration deployment or broad
cleanup worker was run.

## 4. COMPATIBILITY ISSUES

| Boundary | Verified behavior / mismatch | Resolution boundary |
|---|---|---|
| Flutter ↔ Node health/scans | Live MVVM health and multipart scan round trips pass; current DTO parsers accept the actual single envelopes, ISO timestamps, UUID scan IDs and 201/200 replay. | No contract fix required for implemented endpoints. |
| Flutter ↔ backend auth | AccessTokenSource supports farmer upload headers. Native default http.Client has no secure refresh-cookie jar, persisted session or serialized rotation; no mobile auth DTO/screens exist. | Implement secure native cookie/session handling in the explicitly authorized mobile auth work; never put refresh tokens in ordinary API JSON. |
| Node ↔ PostgreSQL | Prisma 7 driver adapter, all current models/constraints, null anonymous ownership and actual farmer ownership pass. | Preserve schema/client alignment; least-privilege production role remains deployment work. |
| Node ↔ Cloudinary | Real authenticated PNG/JPEG/WebP upload, signed HTTPS delivery, replay and exact cleanup pass. | Keep credentials backend-only; schedule cleanup for interrupted attempts before persistent service use. |
| Node image admission ↔ shared preprocessing | Real validator probes: valid 1×1 PNG passes Node but fails shared minimum-side validation (`INVALID_DIMENSIONS`); PNG trailing bytes pass Node but fail strict shared container checks (`INVALID_IMAGE`). A normal 32×32 PNG passes both. | P2: agree common admission or explicit scan-to-preprocessing failure semantics before Phase 11/12. Do not copy ML preprocessing into Node or silently loosen Python validation. |
| Node ↔ future FastAPI | AI_SERVICE_URL/TOKEN are template placeholders, not consumed/validated by Node; there is no client or prediction route. FastAPI correlation is `meta.requestId`, Node correlation is root `requestId`. | Future adapter must validate configuration and translate typed responses/errors. Independent envelopes are not current bugs. |
| FastAPI/training ↔ shared package | Identical physical source/function objects, default configuration hash, masks, arrays, tensors and provenance across separate environments. | Keep model artifact, configuration, codec versions and supplied-mask policy aligned; callable identity alone does not prevent train/serve distribution shift. |

### Database review

All implemented tables were reviewed, not only the Prisma diff:
`users`, `farmer_profiles`, `auth_sessions`, `diseases`, `disease_images`,
`disease_sources`, `scans`, `scan_uploads`, `scan_predictions`, `knowledge_documents`,
`knowledge_chunks`, `fertilizers`, `fertilizer_rules`, `calculator_configs`,
`model_versions`, `model_metrics`, `ai_queries`, `ai_responses`, `audit_logs`,
`notifications`, `history`. Prisma migration bookkeeping is additional.

UUID keys, SQL snake_case/Prisma mappings, timezone-aware creation/update fields,
lifecycle enums, foreign keys/delete policies, lookup indexes, composite ownership
keys and uniqueness are coherent. Migration-owned checks/triggers enforce values,
immutable versions/events/ownership, source hashes, model class mapping and vector
metadata. The live catalog has 21 CHECK constraints, 37 custom triggers and four
partial unique indexes. Nullable `scans.user_id` supports guests; owned scans/profiles/
history enforce FARMER and prevent cross-farmer/anonymous history links. Account
deletion cannot silently anonymize immutable owned scans. Nullable creator provenance
can clear without reassignment. Session and upload journals are the two justified
post-Phase-2 additions. Existing disease/source records and versioned knowledge-document provenance
support later admin management without inventing more tables. Prediction/model version
relations support future classification; vector metadata is present without a guessed
embedding dimension or retrieval index. Empty seed groups remain intentional.

Actual target: development Neon PostgreSQL 18.6, vector 0.8.6. Native Windows 18.4 lacks
pgvector; the pgvector 0.8.7/PostgreSQL 18 Compose definition validates but has not run.
All five applied checksums match source and all five replay in an isolated own schema.
`prisma migrate diff` alone does not inspect every database-only invariant; the catalog,
negative fixture and replay tests provide that additional evidence. No Phase 10 schema
blocker was found. See [database design](05-database-design.md) and
[operations](16-database-operations.md).

### Current endpoint inventory

`A` below means `X-Auth-Request: 1`. `U` is `{email, role, createdAt}`; account IDs,
password hashes, refresh tokens, Cloudinary public IDs and configuration are omitted.
Every Node result has one success/error envelope and server-generated `requestId`.

| Method/path | Authentication / role | Request | Response | Database interaction | Flutter usage / status |
|---|---|---|---|---|---|
| GET /api/v1/health | Public | No body/query | 200 or 503; data `{status,service,timestamp,uptimeSeconds,checks:{database}}` | Read-only repository SELECT 1 | Home connection state; live pass |
| POST /api/v1/auth/register | Public; FARMER only | A; JSON email/password, strict unknown-field rejection | 201 `{user:U}`; duplicate409 | Argon2id hash + FARMER account insert | Future mobile auth; backend pass |
| POST /api/v1/auth/login | Public | A; JSON email/password | 200 `{accessToken,tokenType:"Bearer",expiresIn,user:U}` + HttpOnly refresh Set-Cookie; failure401 | Read account; persist digest/session | Future mobile auth; live pass |
| POST /api/v1/auth/refresh | Valid refresh cookie | A; JSON `{}` | 200 rotated access grant + replacement cookie; invalid/replay401 | Atomic consume/rotate; replay family revocation | Future secure cookie/session client; pass |
| POST /api/v1/auth/logout | Valid refresh cookie | A; JSON `{}` | 200 `{loggedOut:true}`; cookie cleared; invalid401 | Session revocation | Future mobile auth; live pass |
| GET /api/v1/auth/me | Bearer; FARMER or ADMIN | No body/query | 200 `{user:U}`; missing/invalid401 | Live user/session lookup | Future mobile auth; pass |
| POST /api/v1/scans | Guest or Bearer FARMER; ADMIN403 | A; UUIDv4 Idempotency-Key; multipart one `image`, no extra fields | 201 new/200 replay `{id,status:"PENDING",createdAt,image:{url,mimeType,bytes,uploadedAt}}` | Journal claim; atomic scan+completion, nullable/actual farmer ownership | Scan ViewModel/repository; guest live pass, farmer live backend probe pass |

Express HEAD for GET and CORS OPTIONS preflight are transport behavior. Unknown
routes/methods yield safe404. Request validation and JSON parsing use centralized errors;
validation400, auth401, role403, duplicate/conflict409, too-large413, unsupported media415
and internal/provider errors have consistent safe codes. API names are camelCase,
database mappings snake_case, IDs opaque UUID strings and times ISO8601 UTC. No current
paginated endpoint exists, so no invented pagination convention was audited.

FastAPI exposes **GET /health**: public operational process report, 200 after lifespan
startup (503 before), safe service/version/timestamp/lifecycle and capability information,
`meta.requestId`, preprocessing `library_available`, model `not_loaded` with no fake
model identifier. Extra query gives422, wrong method405, unknown path404. Development
OpenAPI/docs are available; production docs are404. No prediction/RAG/generation endpoint.
Its settings/token dependency prepare future private operations; health is not proof
of model readiness. No browser CORS is configured and Flutter has no AI service URL.

### Authentication, transport and UI

Registration normalizes email and rejects public ADMIN/extra-field injection. Registration
passwords are 15–128 code points; login accepts existing nonempty passwords up to128.
Passwords are hashed with Argon2id (64 MiB, three passes, one lane, random salt),
never returned or stored plaintext. Login gives a generic failure for wrong/unknown/
inactive accounts. Separate validated random access/refresh keys sign fixed-purpose
HS256 JWTs. Access defaults900 seconds, refresh absolute604800 seconds. Refresh values
are returned only in host-bound HttpOnly cookies, stored as SHA256 digests and rotated
transactionally; replay revokes the family. Access middleware checks live session/user
state, so logout/replay revokes existing access promptly. Role checks use current
database roles. Controlled stdin admin CLI neither silently promotes nor provisions a
default admin; tests cover ADMIN access without requiring a permanent operator account.
Refresh calls must be serialized. Production cookies use Secure/__Host-/SameSite Strict;
JSON/custom headers, exact credentialed origins and rate limits protect browser POSTs.

Node startup validates settings and connects/probes the one reusable Prisma client
before listening. Shutdown drains HTTP then disconnects, with an idempotent bounded
deadline. Controllers are thin; services and repositories own their respective logic.
Zod handles body/params/query, strict TS/NodeNext and Biome enforce the baseline. Request
logging omits headers/cookies/bodies/query values, central errors omit stack traces and
raw provider details. CORS defaults deny browser origins while allowing originless
native/internal clients; trust proxy stays disabled until topology is selected.

Flutter app-scoped providers hold stateless dependencies; Home/Scan ChangeNotifiers are
route-scoped and disposed correctly. Stateful five-branch navigation preserves state,
switches bar/rail responsively and reserves an unprivileged Admin boundary. Central
Material3 light typography/spacing/radii, ivory surfaces and green/blue/amber accents,
48-point targets, safe-area/keyboard scrolling, loading/error/empty patterns and large
text handling are implemented. Dark theme/localization are deferred. Widgets do not
make raw HTTP calls or use setState for business state. Current tests cover seven screen
sizes and 200% text; additional 320×568 and 1024×768 renders showed no clipping.

Image selection/capture is datasource-backed, previews before upload, recovers Android
lost selections and handles cancellation. Client checks/size limits support UX; Node
remains authoritative with signature/MIME/extension/full-decode/still-frame checks,
5 MiB and 16M-pixel limits, bounded decoding and one image field. Original bytes go to
Cloudinary authenticated storage, metadata to PostgreSQL. Durable owner-scoped journal
and image hash enforce retries/concurrent claims. Upload succeeds before scan insertion;
atomic completion and uncertain-outcome rereads/compensation avoid silent orphans.
Flutter shows transfer progress then saving/error/retry; retries preserve request key.
Current platform uses Android system picker/camera intents without broad storage/CAMERA
permission. Physical intents remain unverified; an iOS scaffold/usage descriptions do
not exist. This is a pending platform check, not proof of a missing Android permission.

### Shared preprocessing deep review

Package: `shared/preprocessing/src/maizedoctor_preprocessing`, version **1.0.0**.
Both consumer wrappers export the same unchanged functions. Canonical default config
SHA256: `77561635e69fafbda50a75ed7c7b2e59a95f858f45420f89079b855a9b1e7f27`.

1. Bounded bytes/file validation: JPEG/PNG/WebP signatures, optional MIME/extension,
   max5 MiB/max16M pixels/minimum side16, still-frame container/end-marker checks,
   Pillow verify and full decode; fixed safe failures, no unsafe filename processing.
2. EXIF orientation first; valid bounded ICC profile → sRGB; grayscale/palette/alpha
   → RGB uint8. Unsigned16 grayscale uses fixed-range conversion; alpha compositing
   is explicit and nonzero-alpha tissue is eligible. No location metadata is copied
   to outputs/debug metadata.
3. Explicit oriented H×W supplied mask, disabled extraction, or nonopaque alpha takes
   precedence; otherwise use bounded working image (default512), RGB→Lab full-color
   border statistics. Remove only color-similar background connected to the perimeter.
   No green HSV selection, erosion, largest-component-only discard or random GrabCut.
4. Border variation, foreground coverage/boundary and significant-component gates
   choose conservative full-frame fallback (or explicit strict-policy failure).
   Retain enclosed non-green lesion regions and small components; outward-only margin
   and nearest mask upsampling reduce loss. Every result warns leaf identity unverified.
5. Replace background, crop all selected regions with 8%/minimum2-pixel padding;
   preserve aspect ratio with centered bilinear letterbox to default224×224.
6. Explicit `(RGB/255 - mean)/std`, default mean0/std1 gives [0,1]; configurable values
   need not retain that range. Return contiguous read-only float32 **CHW (3,H,W)**,
   default(3,224,224), no batch axis. Optional torch tensor copies unchanged CPU values.
7. Immutable strict config, preprocessing/config/source/supplied-mask hashes,
   bounds/status/warnings/library versions accompany output. Opt-in new-directory
   debug images/contact sheet/JSON refuse overwrite. No production random augmentation.

Tests verify grayscale8/16, alpha/palette, profiles/orientation, portrait/landscape,
resolutions/crops/normalization/layout and invalid/container/security behavior. Additional
six generated scenes retained sampled interior brown/yellow/gray/rust-colored patches:
healthy/diseased and blurred scenes segmented; low light/uniform no-leaf, clutter and
multiple objects triggered conservative fallback. These synthetic colors do not prove
clinical rust/gray-leaf-spot/blight classification or measured field segmentation.
Exterior tissue similar to the background can disappear before gates; padding cannot
guarantee recovery. Tiny lesions may be lost at working/final resolution. Unrelated
objects may be selected; this is not a semantic maize/no-leaf detector. Real-data review
must choose evaluated settings and the same mask policy for training/serving.
See [shared preprocessing](22-shared-preprocessing.md).

## 5. FIXES YOU MADE

Only documentation corrections were necessary. No application source, schema, migration,
dependency lock or native configuration was changed.

| File | Problem | Fix |
|---|---|---|
| ai-service/README.md | Preprocessing described as unresolved/future | Records actual shared1.0.0 import and remaining model pinning. |
| docs/07-flutter-architecture.md | Scanning/MVVM described as future/health-only | Documents current Phase7 datasource/repository/ScanViewModel flow. |
| docs/11-security.md | Upload/provider controls described as future | Distinguishes implemented security from later inference/deployment work. |
| docs/12-testing.md | Baseline test scope stale | Records implemented component suites and audit evidence link. |
| docs/15-development-environment.md | Current scope omitted preprocessing/uploads and debug APK evidence | Corrects current implementation and packaging limits. |
| docs/17-backend-foundation.md | Obsolete15-second request receipt timeout | Matches actual60-second request,10-second headers,5-second keepalive. |
| docs/21-ai-service-foundation.md | Current ending still implied preprocessing future/Phase8 stop | Distinguishes Phase8 history from Phase9 library/current audit boundary. |
| README.md, docs/README.md | No consolidated audit/issues index | Link audit/known issues and correct current state/database inventory. |
| docs/PROJECT_STATE.md | Earlier checks lacked fresh complete audit | Adds phase status, fresh integrations, blockers and exact handoff. |
| docs/KNOWN_ISSUES.md, this report | Missing consolidated prioritized issues/checkpoint | Created explicit findings, environment/API/coverage/resource inventories. |

The previously deleted backend database client was already recovered before this audit;
its content matches HEAD, and fresh checks confirm imports work. This audit did not
rebuild/rewrite it. Existing user ignore/ML README/dataset-scaffold/state changes remain
outside the audit commit. DECISIONS.md is unchanged because no architecture/product
decision was made by this audit.

## 6. REMAINING CODE ISSUES

| Priority | Finding | Action / timing |
|---|---|---|
| P0 | None established | No urgent destructive repair. |
| P1 | No current code defect established; missing data/empirical policy are external prerequisites | Section12/15 before training. |
| P2 | Node/shared image acceptance differs | Define/map invalid preprocessing outcomes before inference integration. |
| P2 | Native Flutter secure refresh-session handling and Node/AI adapter do not yet exist | Their authorized later phases; do not call pending-only foundation complete authentication/inference UI. |
| P2 | Four high npm aggregate findings remain, including omit-dev graph | Deliberate tested dependency remediation before relevant deployment; do not use the proposed Prisma6 downgrade blindly. |
| P2 | Current DB role has CREATEDB/CREATEROLE, although not superuser; counters in-memory, proxy trust undefined for deployment | Separate migration/runtime roles and select hosting/shared limiter policy before public deployment. |
| P2 | Crash cleanup scheduler absent; persistent signed image URLs and original EXIF have privacy/retention consequences | Schedule documented cleanup for persistent API use; choose later successful-scan delivery/retention policy. |
| P2 | Installed Python3.11.0 patch is old; future worker concurrency/memory/codec target unmeasured | Provision maintained compatible3.11 patch and rerun locks/parity for new/deployment environments; measure real workloads. |
| P3 | Starlette HTTPX and pg query-queue deprecation warnings | Planned compatible test/driver maintenance; current tests pass. |
| P3 | Some claim/provider/CLI rejection branches lack explicit cases; optional WASM installs reported extraneous but match lock | Targeted future regression tests; no speculative reinstall or implementation-mirroring tests added. |

Fresh npm audit and omit-dev audit both exit1: `deepmerge-ts`7.1.5 and `mysql2`3.15.3
are vulnerable implementation packages; Prisma/@prisma/config7.10.0 carry propagated
reports. Source tracing found no MySQL authentication/query path or client-supplied
cyclic object merge in the implemented PostgreSQL services; this limits demonstrated
exposure but does not declare the dependency graph safe. Primary advisories:
[recursive merge](https://github.com/advisories/GHSA-ggr8-5vv4-36mx),
[MySQL authentication](https://github.com/advisories/GHSA-3f6p-5ww8-9rcr),
[MySQL decompression](https://github.com/advisories/GHSA-rgwj-5xj2-c3m3).
The automatic proposed remediation is Prisma6.19.3, incompatible with the verified
Prisma7 adapter/configuration baseline. No forced downgrade or unverified override.

Secret checks found no configured private values or recognizable provider/private-key
patterns in current commit candidates or 501 unique historical text blobs, and no
committed non-template `.env`. Examples leave credentials blank; local secrets/data/
models/generated output remain ignored. This is evidence from targeted scans and source
review, not proof that arbitrary unknown secrets or every dependency vulnerability are
absent. Python consistency/import checks are not a Python CVE database audit.

## 7. TEST RESULTS

Commands ran in the named component unless a root path is shown. Normal compilation/
generated outputs are ignored. Existing locks unchanged; no blind reinstall/upgrade.

| Actual command/check | Outcome |
|---|---|
| backend: `npm.cmd run check` | PASS format/lint60 files, strict TypeScript, build, 50 isolated tests, compiled dependency probe. |
| backend: `npm.cmd ls --depth=0`; `npm.cmd ls --all --json` | Exit0; all25 direct pins match manifest/lock/installed; three optional matching WASM graph entries extraneous. |
| backend: `npm.cmd run db:format`, `db:validate`, `db:generate`, `db:status`, `db:diff` | PASS; no schema formatting diff; client7.10.0; five applied migrations, no structural drift. |
| backend: `npm.cmd run db:check` | PASS13 catalog/domain/ownership/vector/version tests; transactional fixtures rolled back. |
| backend: `npm.cmd run test:auth:database` | PASS6 actual persistence/HTTP/concurrent rotation/replay/SQL-guard cases; exact fixtures cleaned. |
| backend: `npm.cmd run test:scans:database` | PASS7 null/farmer ownership/journal/concurrent-claim/compensation/cleanup/SQL cases; exact fixtures cleaned. |
| backend: `npm.cmd run db:check:migrations` | PASS all5 SQL migrations replay in generated isolated schema; only that schema removed. |
| backend: `npm.cmd run check:database` | PASS authenticated PG18.6 temporary-table round trip, rollback. |
| backend: RUN_LIVE_SCAN_UPLOAD=true then `npm.cmd run test:scans:live` | PASS1 live PNG+EXIF JPEG/provider/signed-delivery/replay test; own assets/rows removed. |
| backend: `npm.cmd run test:scans:mobile` | PASS existing Flutter live scan test through actual Node/Cloudinary/PostgreSQL; exact own fixtures/asset removed. |
| backend: `node ../.cache/pre10-mobile-health.mjs` | PASS existing Flutter live health test against temporary loopback Node/real DB; server stopped. |
| backend: `node ../.cache/pre10-farmer-webp.mjs` | PASS supplemental live FARMER register/login/me→WebP upload/ownership/replay→rotation/logout/access-revocation probe; exact own account/sessions/scan/journal/asset removed. |
| backend: `node ../.cache/pre10-db-audit.mjs` before/after, snapshot comparison | PASS exact before/after counts/catalog/extensions/migration checksums; no replay schema remains. |
| backend: `npm.cmd audit --json`; `npm.cmd audit --omit=dev --json` | Both exit1, four high aggregate entries; unresolved maintenance findings above. |
| mobile: `flutter pub get --offline --enforce-lockfile` | PASS locked resolution, no lock changes. |
| mobile: `dart format --output=none --set-exit-if-changed lib test` | PASS54 files, zero changes. |
| mobile: `flutter analyze --no-pub` | PASS no issues. |
| mobile: `flutter test --no-pub --reporter expanded` | PASS52 isolated tests; two opt-in live cases skipped here, each run separately above and passed. |
| mobile: `flutter build apk --debug --no-pub` | PASS fresh Android debug APK. |
| mobile: `flutter doctor -v`; existing wrapper `gradlew.bat --version` | SDK/JDK/Gradle available; unaccepted Android licenses warning. No licenses accepted. |
| root: `scripts/check-development.ps1 -Component AI` | PASS Ruff format/lint29 files, strict mypy18 sources, 50 tests; one upstream deprecation warning. |
| root: `scripts/check-development.ps1 -Component Training` | PASS format/lint3 files, strict mypy1 source, five tests. |
| root: `scripts/check-development.ps1 -Component Preprocessing` | PASS shared format/lint16 files and parity script, mypy9 sources; 78 tests in AI and78 in training; eight exact cross-environment parity cases. |
| each Python project: `.cache/tools/Scripts/uv.exe lock --check`, `sync --locked`, `pip check` (root-relative tool path) | PASS43 AI/34 training installed distributions compatible; local uv fallback used because uv absent on PATH. |
| root: `uv build shared/preprocessing --out-dir .cache/audit-package-artifacts` through fallback | PASS source archive and wheel. |
| root: AI python `-m compileall -q` over AI/shared/training source/tests | PASS byte compilation. |
| root: AI python `.cache/audit-python-probes.py --live` | PASS actual test+production loopback HTTP health422/405/404/docs restrictions, safe failed settings, lifespan startup/shutdown. |
| root: AI python `.cache/audit-python-probes.py --stress` | PASS six generated stress scenes, deterministic finite output/expected gates/interior patches. |
| root AI `.cache/audit-image-contracts.py`; backend `node --import tsx ../.cache/audit-node-image-contracts.mjs` | Investigative probes reproduce the two admission mismatches; normal PNG agrees. |
| root: `scripts/check-development.ps1 -Component Docker` | PASS Compose configuration/interpolation only; no Docker Engine/runtime available. |
| root: `scripts/check-repository.ps1`, local Markdown-link checks, credential scans, `git diff --check` | PASS structure/templates/ignore/source/link/whitespace checks after documentation corrections; no secrets detected. |

PowerShell scripts use `powershell -NoProfile -ExecutionPolicy Bypass -File` as documented,
without changing persistent policy. The backend checked-in aggregate is **77 cases**:
50 isolated +13 domain/database +6 auth/database +7 scan/database +1 provider. Supplemental
live FARMER WebP/stress/startup probes are additional audit evidence, not extra checked-in
test cases. Isolated provider tests use stubs; actual Cloudinary tests used configured
development credentials. All temporary servers stopped. Physical camera/gallery,
iOS/release, container startup and field preprocessing remain unverified.

### Test coverage audit

| Area | Expected tests | Existing evidence | Missing / deferred | Status |
|---|---|---|---|---|
| Node health/foundation | Healthy/degraded, envelopes, validation, lifecycle | Isolated plus actual DB/live Flutter health | Deployment proxy/multi-instance checks | PASS |
| Auth | Register/duplicate/input/login/wrong password/token/expiry/refresh/replay/logout | Isolated +6 real DB + supplemental farmer lifecycle | Individual future-iat/typ/jti branches, actual operator stdin entrypoint | PASS WITH WARNINGS |
| RBAC | FARMER/ADMIN/revoked role/forbidden | Middleware/API tests and live farmer ownership | Native authenticated UI deferred | PASS |
| Body/params/query | Coercion/strict rejection/safe errors | Zod infrastructure/endpoints and security fixtures | New business validators when endpoints exist | PASS |
| Database/repositories | Relations/checks/indexes/versions/vector/ownership | 13 domain cases, catalog, five-migration replay, live auth/scans | Future JSON/formula/RAG semantics intentionally unimplemented | PASS |
| Disease APIs | CRUD/admin/public contracts | None; Phase6 skipped | Disease services/APIs and corresponding tests | NOT FULLY TESTABLE |
| Upload validation | Size/signature/MIME/extension/decode/animation/limits | Isolated backend/mobile and Python package fixtures | Some provider malformed-result branches | PASS WITH WARNINGS |
| Scan creation | Metadata/PENDING/retries/claims/rollback/cleanup | Seven SQL cases +real Cloudinary/Flutter | Inference outcome transitions deferred | PASS |
| Anonymous scan | Null ownership and no access downgrade | Isolated/SQL/provider/Flutter live | Successful-scan retrieval/retention deferred | PASS |
| Farmer scan | Bearer→actual farmer association; ADMIN rejected | Isolated/SQL and real WebP lifecycle | Actual mobile sign-in/cookie persistence | PASS WITH WARNINGS |
| FastAPI foundation | Settings/start/health/security/errors/logs/stop | 50 cases +actual loopback test/production probes | No inference/RAG route tests before implementation | PASS |
| Shared preprocessing | Codecs/colors/masks/crop/norm/determinism/tensor/debug/parity | 78 cases in each venv +8 parity +6 stress scenes | Real leaves/field images/clinical lesion retention | PASS WITH WARNINGS |
| Flutter foundation | Theme/state/router/errors/responsiveness/accessibility | 52 isolated cases with Scan/health coverage | Physical device/iOS/release | PASS WITH WARNINGS |
| Flutter repository/ViewModel | DTO/network failures/progress/cancel/retry/scoping | Existing health/Scan tests +two separate live tests | Mobile auth models/session flow | PASS WITH WARNINGS |
| Training | Dataset validation/leakage/split/map/model/metrics | Five environment/shared-identity cases | Phase10 implementation and actual data, not fabricated tests now | NOT FULLY TESTABLE |

## 8. DEPENDENCY COMPATIBILITY MATRIX

Versions below come from executables, installed metadata, native tooling or actual DB
queries, not just documentation. Exact locks/pins are the tested baseline. No upgrade
was made merely because a newer release exists.

| Component | Current version | Expected/required | Status | Problem | Recommended action |
|---|---|---|---|---|---|
| Flutter / Dart | 3.41.9 stable /3.11.5 | Flutter pin3.41.9; lock≥3.41.0, Dart^3.11.5 | PASS | Device/release coverage pending | Preserve lock/toolchain. |
| Flutter packages | provider6.1.5+1, go_router17.5.0, http1.6.0, http_parser4.1.2, image_picker1.2.2, flutter_lints6.0.0 | Manifest-compatible locked versions | PASS | No native refresh jar | Later secure session integration. |
| Image picker platform | Android0.8.13+17 /iOS0.8.13+9 | Pub lock | Android build PASS | iOS platform absent | Device validation; iOS only when authorized. |
| Android build | Gradle8.14, AGP8.11.1, Kotlin plugin2.2.20 | Existing wrapper/plugins | PASS | Release uses debug signing | Choose release signing/application ID before distribution. |
| JDK/SDK | Studio JBR21.0.10; Java/Kotlin target17; compile/targetSDK36, min24, NDK28.2.13676358 | Configured toolchain; doctor SDK/build-tools36.1.0 | PASS WITH WARNINGS | Licenses unaccepted | User review/accept relevant licenses. |
| Node / npm | 24.12.0 /11.6.2 | Node≥24.12.0,<25; existing npm lock | PASS | None found | Preserve supported major. |
| TypeScript / execution / checks | TS7.0.2, tsx4.23.15, Biome2.5.15, Node built-in tests | Exact package pins, strict NodeNext | PASS | None found | No new framework required. |
| Express / schema | Express5.2.1, Zod4.6.5 | Exact pins | PASS | None found | Preserve Express5 async/error/query handling. |
| Prisma / pg | CLI/client/adapter7.10.0; pg8.23.1 | All Prisma packages aligned | PASS WITH WARNINGS | Audit graph reports vulnerabilities; pg deprecation | Tested maintenance, no blind6.x downgrade. |
| PostgreSQL / vector | Neon18.6 /0.8.6 | PostgreSQL+vector schema requirements | PASS | Runtime role broad for production | Least privilege before deployment. |
| Optional DB environments | Native18.4; Compose0.8.7-pg18-bookworm; standalone Compose5.6.0 | pgvector-enabled PostgreSQL18 | NOT FULLY TESTABLE | Native lacks vector; Docker Engine absent | Keep verified Neon or deliberately provision optional target. |
| Auth / HTTP middleware | argon2 0.45.1, jose6.2.12, cookie2.0.1, cors2.8.6, Helmet8.3.0, express-rate-limit8.7.0, Pino10.4.0, dotenv18.0.5 | Exact pins | PASS | Shared limiting/deployment policy pending | Recheck native Argon2 on deployment target. |
| Image storage/upload | Cloudinary2.11.0, Multer2.4.0, Sharp0.35.5 | Exact pins | PASS | Input eligibility differs from Python | Resolve future inference admission policy. |
| Python / uv | Python3.11.0 in both venvs; uv0.12.23 | All manifests≥3.11,<3.12; existing uv locks | PASS WITH WARNINGS | Old Python patch; uv absent on PATH | Maintained3.11 patch for new/prod target; fallback works. |
| FastAPI / ASGI | FastAPI0.142.2, Starlette1.7.0, Uvicorn0.54.0 | Locked compatible graph | PASS WITH WARNINGS | TestClient deprecation | Deliberate compatible maintenance later. |
| Settings/HTTP | Pydantic2.13.5/core2.46.5, settings2.15.0, httpx0.28.1, anyio4.15.1, python-dotenv1.2.4 | Both relevant locks | PASS | No actual AI-to-DB/inference calls yet | Do not treat placeholders as integration. |
| PyTorch / torchvision | 2.10.0+cpu /0.25.0+cpu | Matching CPU pins in both venvs | PASS | CUDA unavailable in installed build | CPU is ready; GPU target optional deliberate provisioning. |
| Image numerics/codecs | NumPy2.4.6, OpenCV4.13.0.92, Pillow12.3.0 | Shared compatible locked graph | PASS | Windows regular/Linux headless markers intentional | Recheck codec parity on deployment target. |
| Training metrics | scikit-learn1.8.0, SciPy1.17.1 | Training lock | PASS imports/metrics | No trained metrics yet | Use during authorized Phase10 evaluation. |
| Python checks | pytest9.1.1, Ruff0.16.10, mypy1.20.2 | Locked dev tools | PASS | No incompatible distributions | Preserve locks. |
| Shared preprocessing | 1.0.0, same local source | Exact evaluated config/model pin later | PASS synthetic/parity | No field validation yet | Section12 before choosing training policy. |
| TensorFlow | Not installed or referenced | PyTorch architecture | NOT APPLICABLE | None | Do not install a second framework. |

No invalid direct/peer dependency or compiled NumPy/OpenCV/torchvision incompatibility
was found. GPU hardware was not conclusively inventoried: the installed torch build
is CPU-only with no available CUDA devices; this does not prove there is no physical GPU.
Git2.52.0.windows.1 is available. Some commands were slow under observed host memory
pressure; free RAM/space need measurement for actual dataset/batch workloads.

## 9. ENVIRONMENT VARIABLES I NEED TO PROVIDE

**No new secret is required to prepare local CPU Phase10.** Database, JWT and Cloudinary
values are already configured privately and verified. Do not paste them into reports or
Flutter. The tables list every authored runtime/template key, including unused placeholders;
all rows in these four service tables exist in the respective `.env.example`. “Absent”
means unset locally; defaults may make this entirely valid. “User action” states whether
you must supply a value. OS environment overrides local dotenv. Mobile `.env` is not loaded.

### Backend — backend/.env (server only)

| Variable | Required/purpose | Local presence | User action now | Sensitive |
|---|---|---|---|---|
| NODE_ENV | Optional mode; default development | Set | None | No |
| HOST | Optional binding; default127.0.0.1 | Absent/default | Set deliberately for LAN/container only | No |
| PORT | Optional listener; default3000 | Set | None | No |
| CORS_ORIGINS | Optional exact browser-origin allowlist; default empty | Blank/default | Set only for actual browser origin | No |
| LOG_LEVEL | Optional safe logger level; default info | Absent/default | None | No |
| SHUTDOWN_TIMEOUT_MS | Optional deadline; default10000 | Absent/default | None | No |
| RATE_LIMIT_MAX | Optional global requests/window; default120 | Absent/default | None | No |
| AUTH_RATE_LIMIT_MAX | Optional sensitive auth requests/window; default10 | Absent/default | None | No |
| SCAN_RATE_LIMIT_MAX | Optional scan requests/window; default10 | Absent/default | None | No |
| DATABASE_URL | Required PostgreSQL runtime | Configured, live verified | None; preserve private development URL | Yes |
| DIRECT_DATABASE_URL | CLI/replay direct-session URL; optional fallback for unpooled DB | Configured, verified | None; required separate URL if runtime transaction pooler used | Yes |
| JWT_SECRET | Required canonical random base64url≥32 decoded bytes; access signing | Configured | None | Yes |
| JWT_REFRESH_SECRET | Required independent key; refresh signing | Configured | None; must differ from access key | Yes |
| JWT_ISSUER | Optional issuer; default maizedoctor | Absent/default | None | No |
| JWT_ACCESS_TTL_SECONDS | Optional60–900; default900 | Absent/default | None | No |
| JWT_REFRESH_TTL_SECONDS | Optional3600–2592000; default604800 | Absent/default | None | No |
| CLOUDINARY_CLOUD_NAME | Required with both provider keys for uploads | Configured, live verified | None | No; server configuration |
| CLOUDINARY_API_KEY | Required with provider pair for uploads | Configured, live verified | None | Yes |
| CLOUDINARY_API_SECRET | Required with provider pair for uploads | Configured, live verified | None | Yes |
| AI_SERVICE_URL | Reserved future Node client URL; not consumed/validated | Set | None for Phase10 | No; internal address |
| AI_SERVICE_TOKEN | Reserved future Node client token; not consumed/validated | Blank | Later integration/private hosting only | Yes |

All three Cloudinary values may be blank to disable uploads; partial credentials fail
startup. Credentials were present for live testing. Rate windows/defaults are current
implementation policy, not user-selected production capacity.

### AI service — ai-service/.env (server only)

| Variable | Required/purpose | Local presence | User action now | Sensitive |
|---|---|---|---|---|
| ENVIRONMENT | Optional mode; default development | Set | None | No |
| HOST | Optional binding; default127.0.0.1 | Absent/default | Non-loopback needs service token | No |
| PORT | Optional listener; default8000 | Set | None | No |
| LOG_LEVEL | Optional structured logger level; default INFO | Absent/default | None | No |
| AI_SERVICE_TOKEN | Required production/non-loopback/future protected operations; optional loopback health | Blank, valid local setup | Later generate random base64url token and match Node | Yes |
| DATABASE_URL | Reserved retrieval persistence, not currently consumed | Configured | None for training/foundation | Yes |
| GEMINI_API_KEY | Reserved generation, not currently consumed | Blank | Future Gemini phase only | Yes |
| MODEL_PATH | Reserved artifact loading, not currently consumed | Blank | After real model artifact exists | No |
| MODEL_VERSION | Reserved model resolution, not currently consumed | Blank | After model version exists | No |
| PREPROCESSING_VERSION | Reserved artifact contract, not currently consumed | Blank | No current env effect; shared typed config/package owns version | No |

### Infrastructure — infrastructure/.env

| Variable | Required/purpose | Local presence | User action now | Sensitive |
|---|---|---|---|---|
| POSTGRES_DB | Optional database name for native/Compose | Set | None for verified Neon | No |
| POSTGRES_USER | Required native/Compose account | Set | None for verified Neon | No; private account identifier |
| POSTGRES_PASSWORD | Required native/Compose account password | Configured | None for verified Neon | Yes |
| POSTGRES_PORT | Optional local published port; default5433 | Set | None | No |

### Mobile — public dart-define, not bundled dotenv

| Variable | Required/purpose | Local presence | User action now | Sensitive |
|---|---|---|---|---|
| API_BASE_URL | Optional offline shell; required connected app; include /api/v1 | Not set for regular build; injected by live tests | Supply public Node URL for your connected device; release HTTPS | No |

Example connected emulator address: `http://10.0.2.2:3000/api/v1` when your chosen Android
emulator maps host loopback. A physical phone needs the reachable host address and
deliberate backend HOST/firewall configuration. Do not use a physical phone's own
localhost for the computer's API. No production URL is hardcoded.

### Tool/test controls (not missing business settings)

| Variable | Consumer/purpose | Required / example / local state | User action / sensitive |
|---|---|---|---|
| MAIZEDOCTOR_PG_BIN | Native PostgreSQL script binary directory override | Optional; script parameter also supported; not an env-template setting | Only if selecting native target; no secret |
| PGPASSWORD | Native PostgreSQL tooling transient authentication | Script sets/restores from infrastructure settings; no separate template | Do not commit or print; sensitive |
| UV_CACHE_DIR | Python setup/check cache directory | Tool-managed ignored cache; not template | None; no secret |
| UV_PYTHON_DOWNLOADS | Python setup control, never for checks | Tool-managed; not template | None; no secret |
| RUN_LIVE_SCAN_UPLOAD | Backend opt-in provider test flag | Optional false unless explicitly true; test/docs rather than template | Enable only with intended dev account; no secret |
| RUN_LIVE_API_CHECK | Flutter health integration dart-define | Optional false; test/docs rather than template | Test harness supplies; no secret |
| RUN_LIVE_SCAN_CHECK | Flutter upload integration dart-define | Optional false; test/docs rather than template | Test harness supplies; no secret |

SDK PATH/JAVA_HOME/Android SDK selection are toolchain settings, not hidden application
credentials. There is currently **no implemented ML dataset-path environment variable**;
provide the real path, then Phase10 can establish its configuration. Do not invent a
DATASET_PATH requirement or substitute names like JWT_ACCESS_SECRET for actual JWT_SECRET.

Checklist:

- [x] Backend DATABASE_URL/DIRECT_DATABASE_URL privately configured and verified.
- [x] Separate JWT_SECRET/JWT_REFRESH_SECRET configured and validated.
- [x] All three Cloudinary settings configured and live verified.
- [ ] API_BASE_URL for your device, only if running the connected mobile app.
- [ ] AI_SERVICE_TOKEN for later production/non-loopback or Node/AI integration.
- [ ] GEMINI_API_KEY/model settings for their future phases; not needed now.

## 10. SOFTWARE I NEED INSTALLED

- [x] Git2.52.0.windows.1 and PowerShell available.
- [x] Node≥24.12.0,<25 and npm; actual24.12.0/11.6.2.
- [x] Flutter3.41.9 with Dart3.11.5 and locked mobile dependencies.
- [x] Android SDK/command-line tools, compatible Studio JDK21.0.10, existing Gradle8.14/
  AGP8.11.1 tooling; actual debug build succeeds.
- [x] Python≥3.11,<3.12 and separate locked AI/training environments; actual3.11.0.
- [x] uv0.12.23 via `.cache/tools/Scripts/uv.exe` fallback; global PATH installation optional.
- [x] PostgreSQL+pgvector access through verified Neon; no mandatory new local server.
- [ ] Maintained compatible Python3.11 patch for new/production provisioning; follow
  [Python branch support](https://devguide.python.org/versions/) and rerun lock/parity checks.
- [ ] Responsive Android emulator/physical device for actual camera/gallery acceptance.
- [ ] Docker Engine/Desktop only if choosing the optional container environment.
- [ ] GPU/CUDA target only if deliberately choosing GPU training; CPU dependencies work.

No TensorFlow, Gemini SDK, separate segmentation model or Dockerized app fleet is
required for local CPU Phase10. Recheck RAM/free disk and batch throughput against the
actual dataset before selecting training batch/workers.

## 11. ACCOUNTS / SERVICES I NEED TO CREATE OR CONFIGURE

| Service | When | What you must create/provide and where | Flutter secret? | Verification |
|---|---|---|---|---|
| Development PostgreSQL/Neon | Existing workflows; already configured | No new account now; preserve backend DATABASE_URL and direct migration URL privately | Never | db:status/db:check/check:database already pass |
| Cloudinary | Existing uploads; already configured | No new account now; backend cloud name/key/secret already verified | Never | test:scans:live and mobile upload already pass |
| Dataset source/license | Before Phase10 | Raw data access and lawful use permission/source reference; download/source credential only if genuinely required by chosen source | Never | Actual file/label/license inventory and leakage review |
| Local CPU training | Before Phase10 | No external service account required | Not applicable | Locked training/shared checks pass |
| GPU/cloud compute | Optional Phase10 target | Only if selected: quota/storage/hardware and private target configuration | Never | Torch device/operator/parity check on chosen target |
| Private AI hosting | Inference/integration/deployment later | Reachable internal URL plus coordinated AI_SERVICE_TOKEN on both servers, TLS/network policy | Never | Authenticated internal round trip after implementation |
| Gemini / embedding provider | RAG/Gemini phases later | Approved grounded corpus/embedding choice, then only genuinely needed API credentials in AI service | Never | Future retrieval/generation tests, not health alone |

No missing external account or credential currently blocks local CPU training; missing
data and evaluation do. No account was created or credentials disclosed during this audit.

## 12. DATASET I NEED TO PROVIDE

No real dataset was found. `ml-training/dataset` contains its README and empty scaffold
areas; those directories are not labeled images, class maps or runnable pipelines.

Provide an **actual absolute folder path**. Suggested ignored local layout (proposal,
not an existing dataset/configuration):

```text
E:\MAIZEDOCTOR\ml-training\dataset\raw\
  <approved-class-slug>\<original-filename>.jpg
  <another-approved-class-slug>\<original-filename>.png
```

An existing external directory is equally acceptable; no move is necessary. Folder names
can supply labels if you confirm their exact disease meanings. Alternatively provide
a CSV manifest with relative_path,label, and available source_id/group_id/original_id/
is_augmented/split. Explain unknown values rather than inventing collection information.

Required specifics:

1. **Raw original, non-preprocessed, non-augmented** images. Accepted pipeline formats
   are still JPEG/JPG, PNG and WebP. Current admission caps are5 MiB/16M pixels/minimum
   side16; retain and disclose originals outside these limits or HEIC/TIFF files for
   an explicit evaluated ingestion-policy choice. Do not silently convert/overwrite.
2. Exact class list and taxonomy/label meanings, including healthy if your dataset has
   it. The repository defines no authoritative disease classes or class count. Identify
   mixed-disease, uncertain-label, non-maize and unknown samples separately; do not force
   them into an invented four-class benchmark.
3. Source/download reference, license or use permission, labeling provenance and label
   confidence/reviewer information where available. Give known collection/plant/field/
   session/source groups to assess leakage. Missing grouping metadata must be disclosed.
4. Keep originals, duplicates and potentially corrupt files intact until inventory.
   Future Phase10 should quarantine/report corruption, assess exact/near duplicates
   and related-image groups, and preserve traceability rather than delete blindly.
5. Keep existing augmented/derived images separately identifiable with original-parent
   linkage. If originals are unavailable, disclose that; random splitting of related
   derivatives cannot establish independent evaluation.
6. Preserve official train/validation/test partitions and disclose their provenance.
   Otherwise, prefer reproducible grouped/stratified splitting where counts allow;
   choose ratios/seed after class/group inventory. Split originals before augmentation,
   augment only training, never train/tune on test data.
7. Include representative actual images for each approved class and tissue color,
   lesion size/leaf edge, orientation/resolution, simple/cluttered backgrounds, shadows,
   low light/blur and multiple leaves where those reflect deployment. They are needed
   for shared debug/mask review before expensive fitting, not to claim unseen-data accuracy.

Do not manually preprocess through a separate workflow. Authorized training will invoke
the same shared implementation automatically. Reviewable masks/contact sheets help
choose its policy; training-only manual masks must not create a serving mismatch.

### Training readiness inventory

| Requirement | Current evidence | Needed next |
|---|---|---|
| Dataset/location/classes | No raw data or confirmed taxonomy | User supplies path, labels/source/groups/splits |
| Corrupt/duplicate handling | Shared invalid-image checks; no dataset-wide inventory | Phase10 inventory/quarantine/duplicate-group implementation |
| Splitting/augmentation | Rules documented; no executable splitter/augmentation or recorded seed | Phase10 reproducible group-aware split; training-only augmentation |
| Class mapping persistence | DB model metadata supports later mapping; no dataset map file | Approved ordered label map in future run/artifact |
| Output/model/metrics/plots | Empty models/experiments scaffold only; no checkpoint/metrics/plots | Versioned outputs/metrics/plots/checkpoint handling in Phase10 |
| Experiment/version manifest | Shared version/hash/dependency provenance available | Future run seed/splits/source/map/model/config/metrics manifest |
| CPU/GPU/dependencies | Both CPU environments verified; no CUDA build | CPU default or deliberate tested alternate target |
| Evaluation | Libraries available; no learned metrics | Accuracy/precision/recall/F1/confusion/per-class metrics and train/validation loss/accuracy curves required |

Those missing training implementations are the authorized purpose of future Phase10,
not defects to implement during this audit. No production checkpoint exists to overwrite.

## 13. FILES / RESOURCES I NEED TO PROVIDE

- Real raw-image folder or archive plus absolute extracted path; no fake path, model
  weights or empty class directories are a substitute.
- A class-label description or CSV path-to-label manifest when labels are not reliably
  encoded by folders; preserve original provider manifests.
- Source/license/permission information and known official split/group/parent metadata.
  Metadata may accompany the dataset rather than being fabricated into new files.
- Representative real examples for each approved label and intended camera conditions.
- If choosing GPU/remote compute, available hardware/driver/runtime/storage constraints.
  None are needed for the working local CPU baseline.

No trained model, production model version, Gemini key, vector embeddings, agricultural
calculator formulas or UI redesign assets are requested for this training checkpoint.

## 14. MANUAL ACTIONS I NEED TO COMPLETE

| What | Why | When | How to verify |
|---|---|---|---|
| Supply raw folder path and original labels/license/source/group/split information | Establish lawful data and independent evaluation; avoid invented taxonomy/leakage | Before Phase10 training | Real inventory/counts/label manifest and provenance review |
| Review representative shared debug results after data is supplied | Confirm real lesion/edge preservation and choose extraction/fallback policy | Before selecting training preprocessing | Contact sheets/masks/warnings reviewed for each real label/field condition |
| Choose local CPU or an identified alternate compute target | Installed torch is CPU-only; throughput depends on actual data/model | Before long training run | Target import/operators/parity and measured batch memory/throughput |
| Set public API_BASE_URL and reachable backend HOST if running a phone | Offline shell has no server address; device localhost is different | Connected mobile testing, not local training | Live health then preview/upload/pending confirmation on intended device |
| Review/accept appropriate Android licenses, test real gallery/camera | Doctor reports licenses; synthetic picker test does not verify system intents | Before fresh SDK provisioning/device acceptance | flutter doctor -v and manual camera/gallery/cancel/deny/resume test |
| Schedule documented scans:cleanup every five minutes on intended development/deployment host | Recover crash/unknown upload outcomes | Before persistent unattended API use | Inspect task schedule/exit status and own fixture recovery; never indiscriminate provider deletion |
| Provision least-privilege runtime DB/private AI/TLS/shared limiter/release signing | Current workstation owner/debug setup is not production policy | Related deployment phase, not a training prerequisite | Catalog/role/network/auth/release tests on actual target |

No SDK license, service account or OS scheduled task was accepted/created implicitly.
Native Windows pgvector installation and Docker Engine are optional alternatives to
the working Neon target; choose them only if you intend to use those environments.

## 15. DECISIONS REQUIRED FROM ME

1. **What exact labels/taxonomy should the supplied dataset represent, and how are
   healthy, mixed/uncertain and non-maize images labeled?** Why: output mapping and
   independent evaluation depend on truthful ground truth. Recommended default:
   preserve the source's documented labels, include healthy only when supplied, and
   keep ambiguous images flagged until reviewed; do not invent a class count.
2. **Does the dataset have official held-out partitions and plant/capture/source or
   original-parent grouping metadata?** Why: related images across partitions leak
   information. Recommended default: preserve an independent official test set; otherwise
   grouped/stratified original-image splits where feasible, with ratios/seed set after inventory.
3. **Will Phase10 target the working local CPU environment or an identified GPU/cloud
   environment?** Why: runtime, model/batch limits and dependencies differ. Recommended
   default: CPU for inventory/preprocessing/small smoke runs; choose GPU only when actual
   throughput requirements and available target justify it.
4. **After reviewing real debug outputs, should training use conservative automatic
   extraction/fallback or full-frame preprocessing for this dataset?** Why: automatic
   extraction is not field-validated and may lose perimeter tissue. Recommended default:
   compare representative real results first and pin one evaluated training/serving
   policy; do not choose blindly or use training-only masks.

These are questions for the user/dataset evidence, not decisions made by the audit.
Model architecture/pretrained-weight normalization follows actual Phase10 evaluation.
Image delivery/retention, hosting/proxy policy and later knowledge/embedding choices are
later-phase decisions; no need to resolve all product decisions before inspecting data.

## 16. FUTURE REQUIREMENTS — NOT NEEDED YET

Mobile sign-in/secure native cookie persistence; disease knowledge/admin management;
model artifact loading/inference and typed Node→AI adapter; model-confidence/unknown
policy; sourced agricultural corpus and reviewed factual content; embedding dimensions/
index/distance and optional provider; Gemini credentials only when generation is added;
deterministic fertilizer/yield formula data; analytics/admin dashboards; successful-scan
retention/owner-checked delivery; production hosting/TLS/least privilege/shared rate
limits; iOS platform/release signing; optional Docker/GPU/cloud packaging. None was
implemented here or silently treated as an already passing integration.

## 17. PRE-PHASE-10 CHECKLIST

- [x] Existing backend format/lint/typecheck/build/tests pass.
- [x] Flutter formatting/analyzer/52 isolated tests and two separate live cases pass.
- [x] Android debug APK builds; physical/iOS/release limits recorded.
- [x] AI/training dependency checks, formatter/linter/types/tests pass.
- [x] Prisma format/validation/client generation and five migrations verified.
- [x] Development DB available; catalog/replay/rollback and unchanged before/after verified.
- [x] Real guest/farmer Cloudinary PNG/JPEG/WebP upload contracts verified.
- [x] Shared source/determinism/provenance/parity and synthetic checks pass.
- [x] Current templates/secrets/ignore/docs checks pass; known npm security findings recorded.
- [ ] Raw original sourced dataset available at an actual path.
- [ ] Class meanings, source permission, grouping/derived images/official splits confirmed.
- [ ] Representative real-leaf masks/lesions/fallback reviewed and policy selected.
- [ ] Compute target confirmed; Phase10 run/config/output implementation explicitly authorized.
- [ ] No remaining Phase10 data/validation blockers.

## 18. EXACT NEXT STEP

Provide the absolute raw-data path, exact label list/meanings and source/license reference,
plus available official split/group/original-parent metadata. If those files already
exist outside this workspace, tell us their paths; do not move or manually preprocess
them. Then perform dataset inventory and real-image shared-preprocessing review before
authorizing model training. No new Cloudinary, Gemini or JWT secret is needed for this.

Stop after this audit. Phase10 has not started and must not start automatically.
