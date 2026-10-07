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

Pending decisions:
curated agricultural sources, full JSON validation contracts, retention and
completed-scan retention/delivery/deletion, production least-privilege roles,
production model promotion/serving compatibility, and embedding model/dimensions/distance/indexes. Address these
only in a phase explicitly authorized by the user.
