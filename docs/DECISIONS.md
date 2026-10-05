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

Pending decisions: refresh-token persistence/rotation contracts during authentication,
curated source licensing and taxonomy, full JSON validation contracts, retention and
Cloudinary deletion, production least-privilege roles, shared preprocessing package,
actual model artifacts, and embedding model/dimensions/distance/indexes. Address these
only in a phase explicitly authorized by the user.
