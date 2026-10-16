# Phase 24.5 — vertical-slice traceability

Every row identifies actual View → ViewModel → Repository/API → Node → dependency
→ returned state. Route names are in `mobile/lib/core/routes/app_router.dart`.
Node composition is in `backend/src/routes/index.ts` and `app.ts`. Verification
levels/results are in the [ledger](phase-24-5-verification-matrix.md); “live” means
isolated generated fixtures and configured services, never edits to real users.

| Journey | Actual function/file chain and persistence | Returned state / failure / evidence |
|---|---|---|
| A Registration | RegistrationView → RegistrationViewModel → ApiRegistrationRepository → POST auth/register → auth controller.register → service.register → repository.createAccount → `users` | 201 safe account; sign-in explicitly follows; duplicate409, invalid400, role injection rejected; farmer-remediation live widget gate |
| B Authentication | AuthIntroView/AdminSignInView → role-specific session ViewModel → SessionRepository → auth/login/refresh/me/logout → auth service/token functions → auth repository → `auth_sessions` | JWT and rotating HttpOnly refresh cookie; live session/status checked; replay/revocation/error/logout and separate role-store tests; real journey |
| C Profile | ProfileView → ProfileEditorView → ProfileViewModel → ApiProfileRepository → GET/PATCH profile → profile controller/service/repository → own `farmer_profiles` | Safe revision-pinned projection; conflicts require reload, optional nulls clear; real save/relogin/reconstructed-app proof |
| D Avatar | ProfilePhotoEditor → ProfileViewModel → profile repository/picker → POST/DELETE profile/avatar → media service/repository/storage → authenticated Cloudinary + profile journal → GET protected avatar → PrivateImage | Normal provider path, ownership and durable cleanup verified. AUD-16 separately reproduces response delay beyond Flutter15s after a committed removal; privacy/association remain safe |
| E Guest scan | ScanView → ScanViewModel → ApiScanRepository/ScanDatasource → POST scans with original key/image → service.create/analyze → upload journal/Cloudinary → AI client → shared pipeline/model → prediction transaction | nullable user; model status/result and relative image; original capability authorizes read/image; no account history; real guest upload/inference gates |
| F Farmer scan | Same scan chain, ApiClient supplies current FARMER access token → repository.complete binds principal user ID → completeInference binds registry model | Owned persisted prediction/history, source image and model/preprocessing identity; real farmer upload gate; wrong-owner/Admin denial |
| G History | HistoryView → ScanHistoryViewModel → ApiScanRecordsRepository → GET scans cursor → history controller/service/repository → own rows; detail → ScanResultViewModel → GET scan/image | Stable owned list/detail and bounded pagination; loading/empty/retry; revision-based disposal on account switch; live UI/API tests |
| H Knowledge | KnowledgeView/KnowledgeDetailView → scoped ViewModels → ApiKnowledgeRepository → GET diseases/detail and POST knowledge/search → knowledge controller/service/repository + retrieval client → DB/AI/Google/pgvector | Four current catalogue entries, source/version sections and navigable search; all four contexts live; no media/stage/severity gallery |
| I Assistant | AssistantView/Composer → AssistantViewModel.ask → assistant repository/datasource → POST knowledge/ask → generation controller/service/client → AI generate → scope/retrieval/Google/vector → reviewed context → Gemini → selected-evidence renderer | Typed answer, citations, uncertainty/abstention; 12 local turns, only current question/scope sent; live provider/widget tests plus simulated failures |
| J Scan explanation | ResultView Ask action or AssistantScanPicker → AssistantViewModel.explainScan → repository → POST scans/id/explanation → generation.service.explain → scans.read ownership → saved classifier context → AI explain/retrieval/Gemini | Original label/confidence/model preserved; cross-owner denied before provider; low-confidence notice; live owned scan explanation. Guest UI intentionally has no owned-scan selection |
| K Fertilizer | FertilizerView → FertilizerViewModel → repository → rules/calculate → controller/service → reviewed active rule/config repository → exact-unit engine | Framework verified with synthetic versioned fixtures. Real empty catalogue PENDING_RULES; no real recommendation or N/P/K need assessment exists |
| L Yield | YieldView → YieldViewModel → repository → configurations/calculate → controller/service → reviewed active config repository → exact-unit engine | Framework verified with synthetic fixtures. Real PENDING_CONFIGURATION. Area×reviewed kg/ha projection is not min/expected/potential agronomic forecasting |
| M Farmer analytics | Profile Field insights → AnalyticsView → AnalyticsViewModel → analytics repository → summary/activity API → service/repository parameterized aggregates → own scans/latest predictions | Responsive counters/bars/activity, date/cursor validation; real aggregate/owner/empty tests, not model-performance reporting |
| N Admin overview | AdminAccessView/sign-in → AdminDashboardView/ViewModel → admin repository/client → admin/dashboard → controller/service/repository → SQL aggregates/registry | Real counts/charts/status and NOT_RECORDED AI usage; ADMIN enforced, FARMER denied; live dashboard gate |
| O Farmer management | Admin farmer list/forms → FarmerManagementViewModel → ApiAdminAccountsRepository → GET farmers/PATCH status → accounts controller/service/repository locked transaction → user status/session revocation/audit | Exact normalized email/status/cursor filters; confirmation and revision conflict; atomic audit rollback; live isolated account gate |
| P Knowledge management | AdminManagementView/forms → AdminManagementViewModel/repository → knowledge routes → management controller/service/repository → AI prepare/index/check → Google/pgvector → explicit publication/archive | Version/source/reviewer lineage preserved, old active version retired, current identity verified; archive excluded; live real indexing/retrieval and DB audit tests |
| Q Audit viewer | Admin audit route → AuditLogView/ViewModel → accounts repository → GET audit-logs → accounts service/repository → immutable audit rows | Server pagination/filters, redacted allowlisted changes, current actor role; actual immutable/rollback/redaction gate |
| R Model health | Admin ModelHealthView → ModelHealthViewModel → repository → admin/model-health → Node service/registry repository + internal model-dashboard → pinned offline snapshot + runtime counters | Loaded/configured/registered/promoted distinction; actual READY research candidate, unavailable path tested; no formal drift |
| S Reference media | Existing `disease_images` relation and Cloudinary generic capability only | Missing Admin upload/provenance/review/publication/delivery and Farmer gallery. No licensed approved images. No E2E chain to call complete |

## Cross-layer identities

| Identity | Verified binding |
|---|---|
| Account/profile | JWT session lookup → active DB user → repository principal-supplied owner; no client owner override |
| Guest scan | Stored hash of `anonymous:<key>` and nullable owner; UUID alone is insufficient |
| Farmer scan | DTO UUID/cursor → exact owned DB row; other owners and Admin cannot read private assets |
| Model | AI configured/pinned version → Node strict version/mapping check → registry FK in prediction transaction → Flutter preserved scalar version |
| Disease | Four literal classifier labels remain fixed; knowledge slugs map separately; display-name edits do not retrain or rename model classes |
| Image | Original input hash binds idempotency/inference; sanitized derivative binds stored asset/scan; protected path resolves stored asset only. Display-byte identity is deliberately different |
| Knowledge | Immutable document key/version/hash/source → chunk parent/offset/current embedding identity → retrieval/citation → rendered source/version |
| Calculator | Client selected rule/config ID+version → reviewed DB snapshot → exact engine input → returned source/version; no mutable rate substitution |
| Audit | Transaction actor/action/request ID → immutable record → redacted viewer; actor role is current, not a historical role snapshot |

UTC timestamps are emitted as ISO strings. Exact decimals remain strings. Node's
public envelope uses `requestId`; internal AI uses `meta.requestId`; dedicated
clients explicitly translate these, so their different envelopes are intentional.
