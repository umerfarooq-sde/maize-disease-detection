# Development roadmap

Work incrementally under [AGENTS.md](../AGENTS.md). Before each phase, inspect existing
files, explain the scope and dependencies, implement only that phase, run relevant
checks, fix failures, and update [project state](PROJECT_STATE.md).

| Phase | Scope |
|---|---|
| 0 | Repository, documentation, ignore rules, and environment templates |
| 1 | Development infrastructure (scope updated by the user's instruction) |
| 2 | PostgreSQL + Prisma (scope updated by the user's instruction) |
| 3 | Node.js + TypeScript backend foundation (scope updated by the user's instruction) |
| 4 | Backend authentication and authorization (scope updated by the user's instruction) |
| 5 | Flutter foundation and reusable UX/design system (scope updated by the user's instruction) |
| 6 | Disease knowledge base |
| 7 | Image upload and Cloudinary |
| 8 | Python FastAPI foundation |
| 9 | Shared ML preprocessing pipeline |
| 10 | ML training pipeline |
| 11 | Disease inference |
| 12 | Node/Python integration |
| 13 | Disease result UI |
| 14 | RAG knowledge system |
| 15 | Gemini integration |
| 16 | AI assistant |
| 17 | Deterministic fertilizer calculator |
| 18 | Deterministic yield calculator |
| 19 | Farmer analytics |
| 20 | Admin dashboard |
| 21 | Admin knowledge management |
| 22 | ML health dashboard |
| 23 | Security hardening |
| 24 | Expanded testing |
| 25 | Docker and deployment |
| 26 | Final QA |

Validation and appropriate tests belong in every phase; Phase 24 does not defer them.
No phase advances automatically under the current instruction.

## Phase 1 scope clarification

The current instruction replaces the original Phase 1 database/Prisma implementation
with independent development environments for Flutter, TypeScript, PostgreSQL, FastAPI,
ML, and optional Docker infrastructure. Business features and schema implementation
are deferred. Later phase scopes above are the original roadmap and must be reconciled
with the next user instruction; no automatic renumbering or implementation is implied.

## Phase 2 scope clarification

The user explicitly authorized PostgreSQL + Prisma for Phase 2. This phase implements
the 19 requested tables, relationships, nullable anonymous scan ownership, provenance,
constraints/indexes/enums, pgvector storage, migrations, seed structure, checks, and
database documentation. Node backend feature foundations and authentication services
remain future work. Later phase scopes above retain the original roadmap and must
be reconciled with the next explicit instruction. Stop after Phase 2.

## Phase 3 scope clarification

The user explicitly authorized the backend foundation for Phase 3: strict TypeScript,
validated environment, middleware, standard responses/errors, Zod validation,
versioned health, shared Prisma access, lifecycle, scripts and tests. Authentication
and RBAC remain future work and need an explicitly authorized phase; they were
removed from this phase's scope. Later roadmap entries are planning guidance only.
Stop after Phase 3; no next phase starts automatically.

## Phase 4 scope clarification

The user authorized backend authentication for FARMER/ADMIN: registration, login,
JWT access, stateful refresh rotation/revocation, logout, RBAC, controlled admin
creation, validation/rate limits, migrations and tests. Flutter foundation/auth
screens, disease APIs and AI/ML/RAG remain deferred. Later phase scopes must follow
the next explicit instruction. Stop after Phase 4.

## Phase 5 scope clarification

The user authorized the Flutter application foundation: MVVM/Provider structure,
centralized light theme/design tokens, responsive farmer shell, routing, safe API
infrastructure, loading/empty/error patterns and appropriate tests. The existing
health endpoint provides an integration check. Feature areas have honest foundation
views; mobile authentication, complete scanning, calculations, disease/AI/RAG workflows
and the admin dashboard remain future work. Stop after Phase 5.

## Phase 7 scope clarification

The user explicitly authorized leaf selection/capture, preview, authoritative image
validation, backend Cloudinary storage, anonymous/farmer pending scan records, error
compensation, durable cleanup, progress/retry UI, tests and documentation. Phase 6 is
not inferred from this request. No ML inference, disease knowledge APIs, mobile login,
AI/RAG or other business features are implemented. Stop after Phase 7.

## Phase 8 scope clarification

The user authorized the internal FastAPI foundation: app/lifespan, validated settings,
structured safe logs, central errors and typed contracts, process health, private
network/shared-token preparation, tests/tooling and startup documentation. Future
preprocessing/inference/RAG/model areas contain ownership documentation only. There is
no final preprocessing, model training/loading/inference, Gemini, retrieval or Node
integration. Preserve existing phases and stop after Phase 8.

## Phase 9 scope clarification

The user authorized one reusable deterministic preprocessing package for training and
serving: bounded validation/color handling, non-green foreground preservation, explicit
configuration/version, conservative segmentation/fallback, background removal/crop/
resize/normalization, model-ready output, debug inspection and tests/parity. No real
dataset was found, so real-image validation is pending. No random augmentation, model
training, inference, RAG/Gemini or new business API. Stop after Phase 9.

## Phase 9.5 and Phase 10 scope clarification

Phase 9.5 inspected the supplied dataset and compared the exact shared pipeline on
real images. The user approved exclusions, deduplication/derivative grouping,
academic/FYP non-commercial use without raw redistribution, and full-frame policy.
Phase 10 is explicitly authorized: immutable eligibility/exclusion/class/split manifests,
grouped stratified partitions, fixed seed, leakage checks, train-only augmentation,
small smoke before full transfer-learning training, validation-only selection, final
held-out test evaluation, versioned checkpoints/history/metrics/plots and fitting analysis.
Read [training/evaluation](25-ml-training-evaluation.md). Stop after Phase 10; inference,
application integration and all subsequent phases remain separate.

## Phase 10.5 scope clarification

The user authorized a dedicated complete model-fitness audit before inference work.
The audit investigates transformed duplicate leakage, fitting behavior, class metrics,
calibration, confidence/threshold evidence, actual errors, Grad-CAM, source bias,
robustness and offline artifact compatibility. Confirmed cross-partition parent
families require a versioned grouped-index repair and fresh bounded training, with
all source bytes/labels preserved and all contradictory families wholly excluded.
Validation choices are frozen before one descriptive test evaluation on the corrected,
previously inspected corpus. Read [model fitness](26-model-fitness-validation.md).
Stop after Phase 10.5; no inference API or integration starts automatically.

## Phase 11 scope clarification

The user authorized serving the approved frozen Phase 10.5 classifier in FastAPI:
strict artifact/configuration validation, once-per-lifespan loading, shared full-frame
preprocessing, internal token protection, typed prediction/model health, bounded image
admission/resources, configurable validation-derived uncertainty and parity/tests.
No threshold is approved or selected here; current predictions explicitly report
`LOW_CONFIDENCE/THRESHOLD_UNCONFIGURED`. No retraining, repeated TEST evaluation,
Node/Flutter integration or RAG/Gemini is included. Read
[production inference](27-production-ml-inference.md). Stop after Phase 11;
Phase 12 requires a separate explicit instruction.
