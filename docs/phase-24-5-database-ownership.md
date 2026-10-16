# Phase 24.5 — database ownership and integrity

Fresh read-only catalog at baseline: **21 application tables**, nine finished/unrolled
back migrations, **27 CHECK constraints, 27 foreign keys, 38 custom triggers,
84 indexes**, pgvector **0.8.6**. `_prisma_migrations` is additional infrastructure,
not a 22nd application model. Source is `backend/prisma/schema.prisma` plus SQL
migrations; Prisma alone cannot express all guards. Current migration verification,
rollback/replay and drift results are in the [ledger](phase-24-5-verification-matrix.md).

| Table | Writer and reader | Ownership / integrity / current baseline count |
|---|---|---|
| users | auth repository, controlled Admin CLI, accounts status repository | Unique normalized email, FARMER/ADMIN/status, farmer-role guards; 0 |
| auth_sessions | auth repository; every protected request/session rotation | User FK, digest uniqueness, absolute expiry and irreversible revoke; 0 |
| farmer_profiles | profile/profile-media repositories | Unique farmer owner; revision locks; current/pending/cleanup asset journal; 0 |
| diseases | seed/intentional ingestion, Admin display edits; catalogue/retrieval | Unique slug/status; fixed model identity separated; 4 active |
| disease_images | No application writer/consumer | Disease FK, unique cloud ID/alt/order; image-specific license/publication contract missing; 0 |
| disease_sources | curated ingestion/Admin document version; references | Source/title/URL/citation/status checks, version snapshots preserve citations; 4 |
| scans | scan repository/service | Nullable guest owner, FARMER FK/trigger, controlled image metadata and lifecycle/lease; 0 |
| scan_uploads | scan repository/cleanup CLI | Unique request/image digest and preselected cloud asset; upload/cleanup state fences; 0 |
| scan_predictions | transactional completeInference; history/analytics/model context | Model FK/class/probability constraints, immutable result, inference timestamp/status; 0 |
| knowledge_documents | AI ingestion/Node Admin version workflows | Immutable content/source/creator/version, one active key, disease/topic/status; 25 active |
| knowledge_chunks | AI deterministic indexer/retrieval | Parent FK, immutable READY vector/content/offset, embedding identity/status; 25 READY |
| fertilizers | reviewed fertilizer draft/publication repository | Unique frozen product snapshot, exact composition metadata and status; 0 |
| fertilizer_rules | fertilizer repository | Immutable version/source/reviewer metadata, one active product/key; 0 |
| calculator_configs | fertilizer/yield repositories | Kind/key/version, immutable parameters, one active version, retained source/reviewer; 0 |
| model_versions | controlled register-model CLI; inference/model dashboard repositories | Hash/artifact/class/preprocessing/dataset metadata, one PRODUCTION partial index; 1 VALIDATED |
| model_metrics | Reserved; dashboard uses approved artifact instead | Immutable metric/model/dataset/split relations; 0, not proof of missing evaluation |
| ai_queries | Reserved; no request telemetry producer | Optional user/scan owner guards, kind/status/time; 0, AI monitoring gap |
| ai_responses | Reserved; no request telemetry producer | Immutable query-linked grounded-status/source/result structure; 0 |
| audit_logs | Admin knowledge/rule/account/profile mutations; audit viewer | Append-only update/delete protection and safe projection, actor FK/retained metadata; 0 |
| notifications | Reserved extension | Composite owned-scan relation; no delivery feature claimed; 0 |
| history | Reserved extension; actual scan history uses scans | Composite owner relations; no duplicate general-history persistence needed; 0 |

## Actual migration inventory

1. `20261005000000_initial_schema`
2. `20261005010000_enforce_immutable_records`
3. `20261005020000_protect_version_creator`
4. `20261006000000_auth_sessions`
5. `20261006010000_scan_uploads`
6. `20261009000000_scan_inference`
7. `20261012000000_knowledge_retrieval`
8. `20261012010000_knowledge_embedding_guard_scope`
9. `20261015000000_profile_media_journal`

No migration or schema change was made. Active-version and production-model partial
unique indexes prevent double publication. Immutable record guards retain historical
predictions/versions/audits; account deletion is not the implemented erasure policy.
RESTRICT guards protect referenced scans/knowledge/model results; permitted CASCADEs
on owned sessions/profiles do not authorize application account deletion.

Complete scan predictions/status, version publication/audits, account suspension/
session revocation/audits and profile media revisions use transactions/locks.
Cloudinary cannot join PostgreSQL transactions: durable intent, uncertainty-aware
compensation and bounded cleanup are the explicit consistency mechanism.

No corpus-scale ANN index is justified for 25 chunks. Current filtered exact pgvector
search is intentional, not an absent vector store. No duplicated active persistence
model or new orphan relation was found in exercised workflows. Reserved tables do
not establish user-facing completeness.

Configured development identities still possess CREATE DATABASE/CREATE ROLE/BYPASSRLS
and ownership privileges. Production guards reject them; separate runtime/migration
roles are Phase 25 work, not silently provisioned here. The fresh psycopg connection
reports client TLS enabled. Provider-side `pg_stat_ssl` reports false behind its
termination boundary; that is not evidence that this client sent plaintext.
