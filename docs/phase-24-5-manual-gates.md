# Phase 24.5 — external inputs, acceptance and Phase 25 boundaries

No replacement provider keys, dataset path, manual dataset labels/splits/provenance,
model files or hand-written manifest JSON are needed. Existing PostgreSQL,
Cloudinary, Google embeddings/Gemini, JWT and internal-service configuration is
present and exercised. The reusable DATASET_PATH loader remains authoritative.

| Gate | What is actually required | Owner / scope |
|---|---|---|
| Reference media | Approved photographs for supported disease contexts; owner/source, permission/license allowing hosting/display, credit, alt text, publication/delivery policy | User/content reviewer supplies or approves rights. Code for provenance/Admin workflow/Farmer gallery is separately missing; do not redistribute training images |
| Fertilizer | Authoritative applicable recommendation model, products/rates/composition, source, units, region/crop/stage/soil applicability and qualified approval | Domain reviewer; Codex can research candidate drafts in separately authorized work. A product kg/ha rate alone does not establish N/P/K need |
| Yield | Approved agronomic model/data with justified inputs, applicability and minimum/expected/potential definitions | Domain reviewer; current area×kg/ha engine is only a planning projection |
| Confidence | Validation-derived risk/coverage/class-cost policy and explicit approval | Product/domain/model reviewer. No test tuning or arbitrary cutoff; currently all outputs honestly LOW_CONFIDENCE |
| Disease metadata | Reviewed growth-stage/severity and any richer catalogue content | Content reviewer. Required CRUD/schema/API/UI work must remain separate from immutable trained class mapping |
| Named Admin | Intended operator identity and controlled CLI enrollment | Operator. No persistent demonstration account or supplied password is created by this audit |
| Device acceptance | Device/OS/build, camera/gallery/cancel/denial/background/lost-data, restart/refresh/logout, slow/offline image/history/assistant/calculator flows | Human or attached device QA; debug APK/widget checks do not substitute |
| Provider/privacy | Explicit provider processing/data residency/consent, retention and erasure approval | User/owner. Retention remains unchanged as already approved; no user data is erased |
| Legacy image review | Inventory any provider-only older assets/disclosed signed links; approve migration/invalidation if relevant | Owner/operator; existing link revocation is not claimed and no real assets are deleted |
| Field/scientific validation | Independent plant/field data with legal rights and ground truth before field-accuracy claims | Research/domain reviewer. No new training or locked-test re-score authorized here |
| Commercial use | Licensing clearance or replacement of research-only dataset/model dependencies | Owner/legal/domain review before commercial deployment |

## Legitimate Phase 25 engineering

Separately authorize production Node/AI Docker builds and immutable model packaging;
staging/production hosting and regions; private AI networking; HTTPS/reverse proxy
and exact trust; secret manager and distinct least-privilege migration/Node/AI roles;
shared quotas/rate limiting if multiple instances; scheduled existing cleanup CLIs;
DB backups/restore drills and migration/rollback release procedure; operational
metrics/alerts/log access; reproducible CI/CD; Android application identity, signing,
release API defines and distribution. None is implemented by this audit.

Infrastructure monitoring does not supply missing application AI request metrics.
Missing Admin workflows, application contracts and original calculator capabilities
must not be hidden in deployment engineering. General notifications, persistent
chat, optional calculator AI prose and formal drift without ground truth are
extensions, not mandatory invented deliverables.
