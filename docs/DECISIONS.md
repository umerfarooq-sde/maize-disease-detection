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

Pending decisions:
curated source licensing and taxonomy, full JSON validation contracts, retention and
Cloudinary deletion, production least-privilege roles, shared preprocessing package,
actual model artifacts, and embedding model/dimensions/distance/indexes. Address these
only in a phase explicitly authorized by the user.
