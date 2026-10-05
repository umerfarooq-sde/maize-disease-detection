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
| 4 | Flutter foundation and design system |
| 5 | Farmer UI |
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
