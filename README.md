# MAIZEDOCTOR

AI-powered maize disease detection and agricultural decision support for farmers,
with administrative tools for maintaining knowledge and monitoring the system.

## Current status

Phase 25 deployment and release engineering is **PARTIALLY COMPLETE**. The implementation
includes private container topology, shared quotas, scheduled cleanup, encrypted
restore-tested backups, least-privilege roles, operational monitoring, protected
release workflows and Android release configuration. CI builds all four images
and verifies shared quotas across two Node processes. The complete connected stack
and hosted deployment have **not** been verified. Latest normal full
E2E `20261018T173013Z-6deb0e3f` is19 PASS/2 FAIL/0 selected skips, with clean
fixture removal and preserved source counts. Management connection setup and
Farmer Knowledge network failures remain acceptance failures; cause is not assumed.
Hosted CI39169960027 at bc42fb1 passes all four jobs, including a real private
monitoring pipeline and fresh least-privilege SQL bootstrap, separately from this
live evidence. No authorized Linux deployment host is available yet.
See [Phase 25 implementation, evidence and operator commands](docs/phase-25-deployment-release-engineering.md).
Phase 26 and public release have not started. The following entries are historical
handoffs and do not supersede this current status.

Phase 24.7 final closeout is **COMPLETE WITH DOCUMENTED RELIABILITY RISK —
READY FOR PHASE 25 ENGINEERING**. Preserved full normal verification21/0/0,
independent4/0/0 and final focused reliability4/0/0 pass. No current reproducible
blocking application defect remains in the checked scope; historical connection
interruptions remain documented risks. **Public release is NOT READY.** Read the
[final assessment](docs/phase-24-7-integration-stability.md). Phase25/26 have not
started and need separate authorization. Earlier handoffs follow.

Phase 24.6 implements the pre-deployment startup, avatar cleanup, operational
monitoring, catalogue/media, independent product/source intake and generated
OpenAPI remediations. Verdict: **PARTIALLY COMPLETE**; normal-config full integration: 18 PASS / 3 FAIL / 0 selected skips. Phase 25 **NOT READY**. Read the
[remediation report and current evidence](docs/phase-24-6-pre-deployment-remediation.md).
The [Phase 24.5 audit](docs/phase-24-5-master-system-audit.md) remains historical.
No Phase 25/26 or deployment has started. Real reference-image licenses, agricultural
rules/forecast models, calibration/field/privacy/release approvals remain explicit gates.

The preceding completed implementation phase follows.

Phase 24 security hardening is complete: **PASS WITH DOCUMENTED LIMITATIONS**. Protected Node image
reads replace exposed Cloudinary capabilities; display metadata removal preserves
original ML inputs. Authentication/RBAC, subprocess isolation, dependency/runtime
patching and production DB privilege/TLS admission pass component and live verification; public hosting still has explicit release gates.
See the [security report, actual results and release prerequisites](docs/phase-24-security-hardening.md).
No Phase 25/26 or deployment has started. Retention remains unchanged by approval.

Licensed disease-library images and authoritative fertilizer/yield inputs remain
pending; the dataset/model remain non-commercial research assets. Physical-device
acceptance and production credentials/networking/retention approval are still
required before public release. Do not equate implementation checks with full
original-product acceptance.

Phase 23.6 previously completed farmer registration and the real sourced Knowledge
catalogue/search/details through existing Node/PostgreSQL and Google/pgvector.
Read the [remediation report](docs/phase-23-6-remediation-report.md).

Phase 23 verifies component and real cross-service contracts, including a connected
Flutter/API/MVVM farmer/Admin journey. The [test matrix](docs/39-testing-e2e-verification.md)
explicitly records skipped tests, failed attempts and the then-missing registration/knowledge
UI. Phase 23.6 resolves those UIs; approved calculator-content and physical-device gaps remain.
Verification also fixes an existing Admin model-health transaction acquisition
failure on cold database connections; component and live rechecks pass afterward.

Phase 22 adds the Admin model-health dashboard with pinned offline test/per-class/
confusion-matrix evidence, explicit registry versus live readiness, and bounded
process-local inference counters. No runtime statistic is called model accuracy or
formal drift. See [model health](docs/38-model-health-dashboard.md).

Phase 21 adds reviewed Admin knowledge/configuration forms, immutable sourced
document versions, explicit embedding rebuild/publication/archive and audited
disease display edits. Calculator management reuses existing validated versioned
services. Model class mappings remain read-only. See
[Admin management](docs/37-admin-management.md).

Phase 20 adds an Admin dashboard with server-aggregated account/scan statistics,
charts, recent activity and stored model registry/configuration summaries. The
Admin workspace has separate volatile sign-in/navigation and ADMIN-only access;
Farmer access is denied. Unrecorded AI metrics and unchecked live model readiness
are explicitly unavailable. See [Admin dashboard](docs/36-admin-dashboard.md).

Phase 19 adds private farmer scan statistics: saved-scan totals/statuses, healthy
versus disease model labels, distribution, time periods, confidence-policy flags
and paginated recent activity. Profile → Field insights uses scoped Flutter MVVM
and owner-filtered Node/PostgreSQL aggregates. Guest scans remain anonymous;
prediction statistics do not establish model accuracy or field prevalence.
See [farmer analytics](docs/35-farmer-analytics.md).

Phase 18 adds the expected-yield framework, exact hectare/acre and kg/metric-tonne
conversion, versioned reviewed configurations and Flutter planning UX. **Real yield
configuration remains pending** because no authoritative project formula/rate exists.
Only a future reviewed configuration can enable a conditional estimate; Gemini does
no numerical calculation. See [expected yield](docs/34-expected-yield-calculator.md).

Phase 17 adds the deterministic fertilizer calculator, exact hectare/acre and kg/gram
conversion, versioned ADMIN rule publication and Flutter input/result/error UX.
**Real fertilizer recommendations remain pending** until approved source-backed
rates are provided and reviewed. No fabricated rate is seeded; Gemini never computes
the quantities. See [fertilizer calculator](docs/33-fertilizer-calculator.md).

Phase 16 adds the Flutter farmer assistant with reviewed answers, visible references,
bounded local conversation and ownership-protected scan explanations. Guests can ask
questions; signed-in farmers can select their private scans. Conversations are not
stored under an account or sent as unlimited history. See
[farmer AI assistant](docs/32-farmer-ai-assistant.md).

Phase 15 adds Gemini selection of verified reviewed evidence, cited knowledge answers
and owner-checked scan explanations. Classifier results and uncertainty remain
unchanged. See [grounded generation](docs/31-grounded-generation.md) for configuration,
contracts, excerpt policy and limitations.

Phase 14 adds sourced disease knowledge, versioned ingestion and semantic retrieval
through Google embeddings and PostgreSQL/pgvector. See
[knowledge/retrieval](docs/30-knowledge-retrieval.md) for source provenance, setup,
contracts and evaluation.

Phase 13 completes Flutter scanning, model results with uncertainty, farmer sign-in/
logout and private paginated history/detail through the existing Node/FastAPI flow.
Guest scans remain anonymous without personal history. See
[farmer detection/history](docs/29-farmer-detection-history.md),
[Node/FastAPI integration](docs/28-node-fastapi-integration.md) for setup and contracts,
and [production ML inference](docs/27-production-ml-inference.md) for artifact startup.

The Phase 10.5 candidate remains **FIT WITH DOCUMENTED LIMITATIONS** for a local
research/FYP inference prototype. The audit found transformed-photo leakage in the original v1
partitions; its independence claim is invalid. The corrected immutable v2 contains
**4,162 unique contents / 4,121 groups**, split **2,911 train / 627 validation / 624
test**, with no confirmed group leakage. Raw source files remain unchanged/external.

Fresh MobileNetV3 Small fits successfully for 11 epochs (patience 3, best epoch 8), scoring
**96.81% validation accuracy / 0.9589 macro F1** and **95.83% final descriptive test
accuracy / 0.9452 macro F1**. This reused public corpus is not an independent field
holdout. Gray Leaf Spot, source-domain and confident-error limitations are explicit;
raw probabilities are retained and no confidence threshold is locked. See
[model fitness](docs/26-model-fitness-validation.md). Use remains non-commercial
academic/FYP research without raw redistribution or commercial clearance. Shared
preprocessing, existing FastAPI/Flutter/backend/database features are preserved;
Persistent mobile sign-in, approved calculator content and disease-reference media remain future work; profile editing and Admin farmer/audit tools are implemented in Phase 23.7.
With no approved operational cutoff, every current prediction is `LOW_CONFIDENCE`
with `THRESHOLD_UNCONFIGURED`; numerical scores do not establish field correctness.
See [project state](docs/PROJECT_STATE.md) for verified progress and outstanding decisions.
Use the [development setup guide](docs/15-development-environment.md) for commands and limitations.
Use [database operations](docs/16-database-operations.md) for migration and verification commands.
Use [backend foundation](docs/17-backend-foundation.md) for server setup and HTTP contracts.
Use [authentication](docs/18-authentication.md) for credentials, cookies, endpoints and admin provisioning.
Use [Flutter foundation](docs/19-flutter-foundation.md) for mobile setup, design tokens, routes and tests.
Use [scan uploads](docs/20-scan-uploads.md) for request contracts, validation, privacy and cleanup operations.
Use [AI service foundation](docs/21-ai-service-foundation.md) for Python startup, health, internal access and checks.
Use [shared preprocessing](docs/22-shared-preprocessing.md) for the single training/serving pipeline and its limitations.
Use the [pre-Phase-10 audit](docs/23-pre-phase-10-audit.md) and [known issues](docs/KNOWN_ISSUES.md)
for environment results and compatibility findings. Use the
[dataset intake and preprocessing review](docs/24-dataset-intake-preprocessing-review.md)
for historical dataset findings, visual artifacts and provenance.

## Planned architecture

```text
Flutter -> Node.js / TypeScript REST API -> PostgreSQL (Prisma)
                         |
                         +-> Cloudinary
                         +-> Python FastAPI -> shared preprocessing -> PyTorch
                                           -> RAG -> Gemini
```

- Flutter uses MVVM, Provider/ChangeNotifier, and repositories.
- The backend uses routes, controllers, services, and repositories with `/api/v1` APIs.
- Python owns image processing, inference, retrieval, and Gemini interaction.
- Training and inference must import one preprocessing implementation.
- Agricultural knowledge must be grounded in curated sources; calculator arithmetic is deterministic.
- Planned roles are `FARMER` and `ADMIN`. Anonymous scans have a nullable user reference;
  authenticated scans belong to the farmer.

## Repository

| Directory | Purpose |
|---|---|
| [mobile/](mobile/README.md) | Flutter application |
| [backend/](backend/README.md) | Node.js + TypeScript API and Prisma persistence |
| [ai-service/](ai-service/README.md) | Python + FastAPI AI service |
| [ml-training/](ml-training/README.md) | Dataset validation, training, evaluation, and experiment tracking |
| [docs/](docs/README.md) | Architecture and technical documentation |
| [scripts/](scripts/README.md) | Development and repository automation |
| [infrastructure/](infrastructure/README.md) | Local PostgreSQL Compose and native development configuration |
| [shared/preprocessing/](shared/preprocessing/README.md) | One reusable Python preprocessing package for training and serving |

Read [AGENTS.md](AGENTS.md) before changing the project. Architecture drafts are
design guidance, not evidence that features exist.

## Environment configuration

Templates contain server-only settings or public mobile configuration. Generate ignored
local database settings without printing passwords:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/initialize-dev-env.ps1
```

Populate secrets locally or through deployment secret management. Templates leave all
credentials blank. Backend and AI database access will need separate least-privilege
credentials in later phases. Prisma and database checks read backend `.env`; cloud
transaction poolers need a separate `DIRECT_DATABASE_URL` for migration sessions.
Mobile configuration contains only a public API URL and may later be
supplied through Flutter build configuration; never supply server secrets to Flutter.
Dependency smoke checks use fixtures; starting inference requires the approved model,
metadata, calibration sidecar and server-only service token. See the inference guide.

Dataset intake reads `DATASET_PATH` from ignored `ml-training/.env`, independent of
the working directory. The supplied local value is configured; the committed
`ml-training/.env.example` placeholder remains blank. An explicitly set OS variable
takes precedence. Future inventory, preprocessing validation and training must call
`load_dataset_path()` from the training configuration module rather than hardcode a
machine path. See [ML configuration and commands](ml-training/README.md).

## Repository checks

From the repository root, using PowerShell and Git:

```powershell
./scripts/check-repository.ps1
git diff --check
git status --short --branch
```

The [development setup guide](docs/15-development-environment.md) describes TypeScript
compilation, Python environment tests, Flutter analysis/tests, and PostgreSQL/Compose checks.

If Windows blocks script execution, run the check with a process-only policy override:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/check-repository.ps1
```

This does not change the machine's persistent execution policy.

## Next step

Stop after Phase 24. Phase 25 requires a separate explicit instruction.
Preserve the frozen v2 candidate and its documented limitations. See the
[remediation report](docs/phase-23-6-remediation-report.md),
[farmer assistant](docs/32-farmer-ai-assistant.md),
[grounded generation](docs/31-grounded-generation.md), [fitness audit](docs/26-model-fitness-validation.md) and
[roadmap](docs/14-roadmap.md).
