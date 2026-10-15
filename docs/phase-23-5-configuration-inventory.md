# Phase 23.5 configuration inventory

Audited 2026-10-15. Values are deliberately omitted. This is configuration presence,
not proof of availability; fresh service results are in the [main audit](phase-23-5-completeness-audit.md).
OS settings override local dotenv values. Node and AI validators were read and startup
was exercised. Flutter reads build-time defines, not a bundled dotenv file.

| Variable | Service | Purpose | Required now? | Configured locally? | In template? | Secret/private? | User action |
|---|---|---|---|---|---|---|---|
| `NODE_ENV` | `backend` | Runtime mode and production cookie policy | Yes for enabled feature | YES | YES | No | None |
| `PORT` | `backend` | Listening port | Yes for enabled feature | YES | YES | No | None |
| `HOST` | `backend` | Bind address; local default | Default sufficient | DEFAULT/intentional blank | YES | No | None now; deployment review later |
| `CORS_ORIGINS` | `backend` | Exact browser allowlist; empty denies cross-origin browsers | Default sufficient | DEFAULT/intentional blank | YES | No | None now; deployment review later |
| `LOG_LEVEL` | `backend` | Operational log verbosity | Default sufficient | DEFAULT/intentional blank | YES | No | None |
| `SHUTDOWN_TIMEOUT_MS` | `backend` | Graceful shutdown bound | Default sufficient | DEFAULT/intentional blank | YES | No | None |
| `RATE_LIMIT_MAX` | `backend` | Global per-process/IP request bound | Default sufficient | DEFAULT/intentional blank | YES | No | None |
| `AUTH_RATE_LIMIT_MAX` | `backend` | Login/registration abuse bound | Default sufficient | DEFAULT/intentional blank | YES | No | None |
| `SCAN_RATE_LIMIT_MAX` | `backend` | Upload attempt bound | Default sufficient | DEFAULT/intentional blank | YES | No | None |
| `DATABASE_URL` | `backend` | Application/RAG PostgreSQL connection | Yes for enabled feature | YES | YES | YES | None |
| `DIRECT_DATABASE_URL` | `backend` | Direct migration/schema-isolation connection | For managed migration/session checks | YES | YES | YES | None |
| `JWT_SECRET` | `backend` | Access JWT signing key | Yes for enabled feature | YES | YES | YES | None |
| `JWT_REFRESH_SECRET` | `backend` | Independent refresh JWT signing key | Yes for enabled feature | YES | YES | YES | None |
| `JWT_ISSUER` | `backend` | JWT issuer identity | Default sufficient | DEFAULT/intentional blank | YES | No | None |
| `JWT_ACCESS_TTL_SECONDS` | `backend` | Access lifetime | Default sufficient | DEFAULT/intentional blank | YES | No | None |
| `JWT_REFRESH_TTL_SECONDS` | `backend` | Absolute refresh-session lifetime | Default sufficient | DEFAULT/intentional blank | YES | No | None |
| `CLOUDINARY_CLOUD_NAME` | `backend` | Storage account identity | Yes for enabled feature | YES | YES | No | None |
| `CLOUDINARY_API_KEY` | `backend` | Storage credential identifier | Yes for enabled feature | YES | YES | YES | None |
| `CLOUDINARY_API_SECRET` | `backend` | Storage signing secret | Yes for enabled feature | YES | YES | YES | None |
| `AI_SERVICE_URL` | `backend` | Trusted internal AI origin | Yes for enabled feature | YES | YES | No | None |
| `AI_SERVICE_TOKEN` | `backend` | Internal Bearer service credential | Yes for enabled feature | YES | YES | YES | None |
| `AI_MODEL_VERSION` | `backend` | Expected classifier identity | Yes for enabled feature | YES | YES | No | None |
| `AI_PREPROCESSING_VERSION` | `backend` | Expected shared pipeline identity | Yes for enabled feature | YES | YES | No | None |
| `AI_SERVICE_TIMEOUT_MS` | `backend` | Node inference/retrieval whole-call deadline | Yes for enabled feature | YES | YES | No | None |
| `KNOWLEDGE_RATE_LIMIT_MAX` | `backend` | Retrieval/Admin knowledge request bound | Default sufficient | DEFAULT/intentional blank | YES | No | None |
| `KNOWLEDGE_INDEX_TIMEOUT_MS` | `backend` | Admin rebuild whole-call deadline | Default sufficient | DEFAULT/intentional blank | YES | No | None |
| `GENERATION_RATE_LIMIT_MAX` | `backend` | Grounded-answer request bound | Default sufficient | DEFAULT/intentional blank | YES | No | None |
| `GENERATION_TIMEOUT_MS` | `backend` | Node whole-call generation deadline | Default sufficient | DEFAULT/intentional blank | YES | No | None |
| `CALCULATOR_RATE_LIMIT_MAX` | `backend` | Calculator request bound | Default sufficient | DEFAULT/intentional blank | YES | No | None |
| `ANALYTICS_RATE_LIMIT_MAX` | `backend` | Farmer/Admin aggregate request bound | Default sufficient | DEFAULT/intentional blank | YES | No | None |
| `ENVIRONMENT` | `ai-service` | AI runtime mode and internal exposure policy | Yes for enabled feature | YES | YES | No | None |
| `HOST` | `ai-service` | Bind address; local default | Default sufficient | DEFAULT/intentional blank | YES | No | None now; deployment review later |
| `PORT` | `ai-service` | Listening port | Yes for enabled feature | YES | YES | No | None |
| `LOG_LEVEL` | `ai-service` | Operational log verbosity | Default sufficient | DEFAULT/intentional blank | YES | No | None |
| `AI_SERVICE_TOKEN` | `ai-service` | Internal Bearer service credential | Yes for enabled feature | YES | YES | YES | None |
| `DATABASE_URL` | `ai-service` | Application/RAG PostgreSQL connection | Yes for enabled feature | YES | YES | YES | None |
| `GEMINI_API_KEY` | `ai-service` | Google embedding/generation credential | Yes for enabled feature | YES | YES | YES | None |
| `RAG_ENABLED` | `ai-service` | Explicit retrieval enable switch | Yes for enabled feature | YES | YES | No | None |
| `EMBEDDING_MODEL` | `ai-service` | Explicit Google text embedding model | Yes for enabled feature | YES | YES | No | None |
| `EMBEDDING_VERSION` | `ai-service` | Embedding deployment/version identity | Yes for enabled feature | YES | YES | No | None |
| `EMBEDDING_DIMENSIONS` | `ai-service` | Vector dimension contract | Yes for enabled feature | YES | YES | No | None |
| `EMBEDDING_TIMEOUT_SECONDS` | `ai-service` | Embedding provider I/O timeout | Yes for enabled feature | YES | YES | No | None |
| `RAG_CHUNK_CHARS` | `ai-service` | Deterministic chunk window size | Yes for enabled feature | YES | YES | No | None |
| `RAG_CHUNK_OVERLAP` | `ai-service` | Deterministic overlap | Yes for enabled feature | YES | YES | No | None |
| `RAG_MAX_CONCURRENCY` | `ai-service` | Retrieval work admission slots | Yes for enabled feature | YES | YES | No | None |
| `GENERATION_ENABLED` | `ai-service` | Explicit generation enable switch | Yes for enabled feature | YES | YES | No | None |
| `GEMINI_MODEL` | `ai-service` | Explicit official-SDK generation model | Yes for enabled feature | YES | YES | No | None |
| `GENERATION_TIMEOUT_SECONDS` | `ai-service` | Provider I/O/between-read budget | Yes for enabled feature | YES | YES | No | None |
| `GENERATION_MAX_CONCURRENCY` | `ai-service` | Generation admission slots | Yes for enabled feature | YES | YES | No | None |
| `GENERATION_CONTEXT_CHARS` | `ai-service` | Maximum retrieved context characters | Yes for enabled feature | YES | YES | No | None |
| `GENERATION_MAX_CHUNKS` | `ai-service` | Maximum context chunks | Yes for enabled feature | YES | YES | No | None |
| `GENERATION_CORPUS_PATH` | `ai-service` | Pinned reviewed corpus location | Yes for enabled feature | YES | YES | Private filesystem location | None |
| `GENERATION_REVIEW_PATH` | `ai-service` | Pinned curation ledger location | Yes for enabled feature | YES | YES | Private filesystem location | None |
| `INFERENCE_ENABLED` | `ai-service` | Explicit classifier enable/maintenance switch | Yes for enabled feature | YES | YES | No | None |
| `MODEL_PATH` | `ai-service` | External approved checkpoint location | Yes for enabled feature | YES | YES | Private filesystem location | None |
| `MODEL_METADATA_PATH` | `ai-service` | Approved model metadata location | Yes for enabled feature | YES | YES | Private filesystem location | None |
| `MODEL_METADATA_SHA256` | `ai-service` | Pinned trusted metadata digest | Yes for enabled feature | YES | YES | No | None |
| `MODEL_VERSION` | `ai-service` | Expected loaded model identity | Yes for enabled feature | YES | YES | No | None |
| `PREPROCESSING_VERSION` | `ai-service` | Expected shared implementation version | Yes for enabled feature | YES | YES | No | None |
| `INFERENCE_THREADS` | `ai-service` | CPU inference threads | Yes for enabled feature | YES | YES | No | None |
| `INFERENCE_MAX_CONCURRENCY` | `ai-service` | Inference admission slots | Yes for enabled feature | YES | YES | No | None |
| `INFERENCE_UPLOAD_TIMEOUT_SECONDS` | `ai-service` | Encoded-image upload deadline | Yes for enabled feature | YES | YES | No | None |
| `CONFIDENCE_POLICY_PATH` | `ai-service` | Optional approved validation-only policy location | No; approved policy is intentionally unlocked | NO; intentional null policy | YES | Private filesystem location | None |
| `CONFIDENCE_POLICY_SHA256` | `ai-service` | Optional policy integrity pin | No; approved policy is intentionally unlocked | NO; intentional null policy | YES | No | None |
| `DATASET_PATH` | `ml-training` | Reusable raw dataset location; never committed | For intake/training/integrity; not serving | YES | YES | Private filesystem location | None |
| `API_BASE_URL` | `mobile` | Public Node /api/v1 build-time URL | For real device/API use | NO; build define required | YES | No | Set reachable Node URL for device/release build |
| `POSTGRES_DB` | `infrastructure` | Optional local infrastructure database name | Only for optional local PostgreSQL; current DB is managed | YES | YES | No | None now; deployment review later |
| `POSTGRES_USER` | `infrastructure` | Optional local infrastructure account | Only for optional local PostgreSQL; current DB is managed | YES | YES | YES | None now; deployment review later |
| `POSTGRES_PASSWORD` | `infrastructure` | Optional local infrastructure password | Only for optional local PostgreSQL; current DB is managed | YES | YES | YES | None now; deployment review later |
| `POSTGRES_PORT` | `infrastructure` | Optional local infrastructure port | Only for optional local PostgreSQL; current DB is managed | YES | YES | No | None now; deployment review later |

All 70 runtime-template entries are accounted for. No extra ignored local keys were
found. Optional/defaulted Node HOST/log/rate/issuer/lifetime values need no manual
population. Empty browser CORS is intentional for native development. Confidence
policy path/hash must remain jointly empty until a real validation-approved policy exists.

Configured internal tokens match across backend and AI; JWT keys are distinct.
No additional provider key is needed now. The raw dataset path resolves through
the shared loader; its machine-specific value is omitted. The current debug build
uses the offline default unless API_BASE_URL is explicitly passed.

## Test-only and tooling configuration

These are not missing production settings or additions required in .env.example.
Opt-in flags are intentionally default-off; the Phase 23.5 audit enabled one native
health contract separately and inspected the Phase 23 connected-run proofs.

- `MODEL_HEALTH_DART`: generated test/tooling context; no production configuration required.
- `MODEL_HEALTH_FLUTTER_TOOLS`: generated test/tooling context; no production configuration required.
- `MODEL_HEALTH_IMAGE`: generated test/tooling context; no production configuration required.
- `PHASE21_SCHEMA`: generated test/tooling context; no production configuration required.
- `PHASE23_DART`: generated test/tooling context; no production configuration required.
- `PHASE23_DB_CONTEXT_LOADED`: generated test/tooling context; no production configuration required.
- `PHASE23_FLUTTER_TOOLS`: generated test/tooling context; no production configuration required.
- `PHASE23_OUTPUT`: generated test/tooling context; no production configuration required.
- `PHASE23_SCHEMA`: generated test/tooling context; no production configuration required.
- `RUN_LIVE_ADMIN_CHECK`: explicit opt-in live check; no user secret.
- `RUN_LIVE_ANALYTICS_CHECK`: explicit opt-in live check; no user secret.
- `RUN_LIVE_API_CHECK`: explicit opt-in live check; no user secret.
- `RUN_LIVE_ASSISTANT_CHECK`: explicit opt-in live check; no user secret.
- `RUN_LIVE_E2E_CHECK`: explicit opt-in live check; no user secret.
- `RUN_LIVE_FERTILIZER_CHECK`: explicit opt-in live check; no user secret.
- `RUN_LIVE_GENERATION`: explicit opt-in live check; no user secret.
- `RUN_LIVE_KNOWLEDGE`: explicit opt-in live check; no user secret.
- `RUN_LIVE_MANAGEMENT_CHECK`: explicit opt-in live check; no user secret.
- `RUN_LIVE_MODEL_HEALTH_CHECK`: explicit opt-in live check; no user secret.
- `RUN_LIVE_SCAN_CHECK`: explicit opt-in live check; no user secret.
- `RUN_LIVE_SCAN_INFERENCE`: explicit opt-in live check; no user secret.
- `RUN_LIVE_SCAN_UPLOAD`: explicit opt-in live check; no user secret.
- `RUN_LIVE_YIELD_CHECK`: explicit opt-in live check; no user secret.
- `RUN_RAG_DATABASE_TESTS`: explicit opt-in live check; no user secret.

Test fixture accounts/passwords, ephemeral scan-context values, SYNTHETIC calculator
drafts, Flutter/Dart executable paths and PATH/TEMP/JAVA/ANDROID/PUB SDK discovery
variables are harness inputs. They are not product environment requirements. The
model-health and scan-upload helpers currently forward their server process environment
to local Flutter test children; restrict that test-only boundary in Phase 24. The
application itself does not bundle or read those server variables.

No hardcoded provider key, signing secret, dataset path or production API origin was
found in authored application code. Pinned class labels, engine IDs and approved
artifact schema invariants are intentional contracts, not credentials or substitute
runtime model configuration. Development bind/port/rate defaults require a production
review in the assigned security/deployment phases.

## Explicit native-fixture and SDK variables

The following additional names were found in Platform.environment/PowerShell usage.
They are generated test identities/context or operating-system tooling, not missing
backend service configuration. No values are recorded.

| Variable | Service/purpose | Required now? | Locally configured? | Template? | Secret? | User action |
|---|---|---|---|---|---|---|
| `ADMIN_DASHBOARD_EXPECTED` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | No; test/tooling context | None; do not manually populate |
| `ANALYTICS_ADMIN_EMAIL` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | No; test/tooling context | None; do not manually populate |
| `ANALYTICS_ADMIN_PASSWORD` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | YES; generated test credential | None; do not manually populate |
| `ANALYTICS_EMPTY_EMAIL` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | No; test/tooling context | None; do not manually populate |
| `ANALYTICS_EMPTY_PASSWORD` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | YES; generated test credential | None; do not manually populate |
| `ANALYTICS_OWNER_EMAIL` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | No; test/tooling context | None; do not manually populate |
| `ANALYTICS_OWNER_PASSWORD` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | YES; generated test credential | None; do not manually populate |
| `ASSISTANT_FIXTURE_SCAN_ID` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | No; test/tooling context | None; do not manually populate |
| `E2E_ADMIN` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | YES; generated test credential | None; do not manually populate |
| `E2E_DOCUMENT` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | No; test/tooling context | None; do not manually populate |
| `E2E_FARMER` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | YES; generated test credential | None; do not manually populate |
| `FERTILIZER_FIXTURE_FARMER_EMAIL` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | No; test/tooling context | None; do not manually populate |
| `FERTILIZER_FIXTURE_FARMER_PASSWORD` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | YES; generated test credential | None; do not manually populate |
| `FERTILIZER_FIXTURE_RULE_ID` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | No; test/tooling context | None; do not manually populate |
| `FLUTTER_ROOT` | SDK discovery/cache path | Only relevant tooling/opt-in test | Discovered from current environment/tools | Not a runtime template requirement | No; test/tooling context | None; do not manually populate |
| `MAIZEDOCTOR_PG_BIN` | Optional native PostgreSQL binary-location override | Only native helper | Auto-discovered unless explicitly overridden | Not a runtime template requirement | Private tooling path | None if native tools are discovered |
| `MANAGEMENT_ADMIN_EMAIL` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | No; test/tooling context | None; do not manually populate |
| `MANAGEMENT_ADMIN_PASSWORD` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | YES; generated test credential | None; do not manually populate |
| `MANAGEMENT_DRAFT` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | No; test/tooling context | None; do not manually populate |
| `MODEL_HEALTH_ADMIN_EMAIL` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | No; test/tooling context | None; do not manually populate |
| `MODEL_HEALTH_ADMIN_PASSWORD` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | YES; generated test credential | None; do not manually populate |
| `PGPASSWORD` | PostgreSQL CLI subprocess credential from POSTGRES_PASSWORD | Only native PostgreSQL helper | Passed temporarily by helper | No; credential already represented in infrastructure template | YES | None; never print it |
| `UV_CACHE_DIR` | SDK discovery/cache path | Only relevant tooling/opt-in test | Discovered from current environment/tools | Not a runtime template requirement | No; test/tooling context | None; do not manually populate |
| `UV_PYTHON_DOWNLOADS` | Python-tool bootstrap download policy | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | No; test/tooling context | None; do not manually populate |
| `YIELD_FIXTURE_CONFIG_ID` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | No; test/tooling context | None; do not manually populate |
| `YIELD_FIXTURE_EMAIL` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | No; test/tooling context | None; do not manually populate |
| `YIELD_FIXTURE_PASSWORD` | Native integration fixture identity/context | Only relevant tooling/opt-in test | Generated by harness, not persistent | Not a runtime template requirement | YES; generated test credential | None; do not manually populate |

Dynamic fixture families are also generated: `SCAN_FIXTURE_OWNER_EMAIL`,
`SCAN_FIXTURE_OWNER_PASSWORD`, `SCAN_FIXTURE_OTHER_EMAIL`, `SCAN_FIXTURE_OTHER_PASSWORD`,
and `ANALYTICS_FOREIGN_CURSOR`/`ANALYTICS_ANONYMOUS_CURSOR`. They are required only by
their opt-in tests, not local runtime templates; the harness supplies them. Password
values are secret test credentials and are never included in reports.
