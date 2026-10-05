# MAIZEDOCTOR — Codex Engineering Instructions

## Project

MAIZEDOCTOR is an AI-powered maize disease detection and agricultural decision-support platform.

The system contains:

- Flutter mobile frontend
- Node.js + TypeScript backend
- PostgreSQL database
- Prisma ORM
- Cloudinary image storage
- Python + FastAPI AI service
- Computer vision preprocessing
- PyTorch disease classification
- RAG-based agricultural knowledge system
- Gemini API
- Farmer and Admin roles

---

# Core Architecture

```text
Flutter
   ↓
Node.js / TypeScript REST API
   ↓
PostgreSQL
   +
Cloudinary
   +
Python FastAPI
        ↓
   Computer Vision
        ↓
   ML Model
        ↓
       RAG
        ↓
     Gemini
```

---

# Repository

```text
mobile/          Flutter application
backend/         Node.js + TypeScript API
ai-service/      Python + FastAPI AI service
ml-training/     ML training/evaluation pipeline
docs/            Architecture and technical documentation
scripts/         Development/automation scripts
infrastructure/  Docker/deployment configuration
```

---

# Flutter Architecture

Use:

- MVVM
- Provider
- ChangeNotifier
- Repository pattern

Preferred flow:

```text
View
 ↓
ViewModel
 ↓
Repository
 ↓
API Client
 ↓
Backend
```

Do not put API calls directly in widgets.

Do not put business logic directly inside widgets.

Avoid unnecessary `setState`.

Use reusable UI components.

---

# Backend Architecture

Use:

```text
Route
 ↓
Controller
 ↓
Service
 ↓
Repository
 ↓
Prisma
 ↓
PostgreSQL
```

Do not put business logic inside routes.

Do not access Prisma directly from controllers unless there is a documented reason.

Use TypeScript strictly.

Use request validation.

Use centralized error handling.

Use API versioning:

`/api/v1/...`

---

# AI Architecture

Python FastAPI owns:

- image validation
- preprocessing
- segmentation
- background removal
- normalization
- ML inference
- model health
- RAG retrieval
- Gemini interaction

Node.js owns business logic and orchestration.

Do not move ML logic into Node.js.

---

# CRITICAL ML RULE

Training and production inference MUST use the same preprocessing implementation.

Never create separate preprocessing implementations for training and production.

The shared pipeline must include, where applicable:

- validation
- decoding
- color conversion
- segmentation
- background removal
- crop
- resize
- normalization
- tensor conversion

---

# ML RULES

Never use test data during training.

Never augment validation/test data.

Split data before augmentation.

Track:

- accuracy
- precision
- recall
- F1
- confusion matrix
- per-class metrics
- training loss
- validation loss
- training accuracy
- validation accuracy

Track experiments and model versions.

Never overwrite production models.

---

# RAG RULES

RAG knowledge must be grounded in the project's agricultural knowledge base.

Use PostgreSQL + pgvector where appropriate.

Knowledge flow:

```text
Knowledge
 ↓
Document
 ↓
Chunks
 ↓
Embeddings
 ↓
Vector Search
 ↓
Context
 ↓
Gemini
```

Gemini must not be treated as the authoritative source of agricultural facts.

If sufficient information is unavailable, the system should state that.

---

# Calculator RULE

Numerical agricultural calculations must be deterministic.

Do not allow Gemini to independently calculate critical fertilizer or yield quantities.

Gemini may explain calculator results using retrieved knowledge.

---

# Authentication

Use:

- JWT access tokens
- refresh tokens
- secure token storage
- RBAC

Roles:

- FARMER
- ADMIN

Anonymous disease detection is supported.

Anonymous scans must have nullable `user_id`.

Authenticated scans must be associated with the farmer.

---

# Security

Never expose secrets to Flutter.

Secrets belong in environment variables.

Never commit:

- API keys
- database passwords
- JWT secrets
- Cloudinary secrets

Validate uploaded files.

Use MIME/type validation and file size limits.

Use rate limiting.

Use centralized error handling.

Never return stack traces to clients.

---

# UI/UX

The Flutter application must feel like a real agricultural technology product, not a generic university CRUD application.

Prioritize:

- simplicity
- readability
- accessibility
- large touch targets
- clear hierarchy
- clear loading states
- clear error states
- clear empty states
- responsive layouts
- minimal cognitive load

The primary farmer action should be disease scanning.

Use reusable design-system components.

---

# Coding Standards

Before modifying a file:

1. Read the existing implementation.
2. Understand its dependencies.
3. Preserve working behavior.
4. Make the smallest reasonable change.

Do not rewrite entire files unnecessarily.

Do not duplicate logic.

Do not create unnecessary abstractions.

Use meaningful names.

Prefer simple maintainable code.

---

# Testing

Every feature should include appropriate tests.

Flutter:

- unit tests
- ViewModel tests
- repository tests
- widget tests where useful

Backend:

- unit tests
- integration/API tests

Python:

- preprocessing tests
- inference tests
- RAG tests
- API tests

ML:

- dataset validation
- preprocessing consistency
- class mapping
- model output shape
- evaluation

---

# Execution Rules

Work incrementally.

Do not attempt to build the entire system in one step.

Before implementation:

1. Inspect the repository.
2. Identify relevant files.
3. Explain the intended change.
4. Implement.
5. Run relevant checks.
6. Fix errors.
7. Report what changed.

Never assume code works without checking it.

Do not silently change architecture.

If a major architectural change is necessary, explain the reason first.

---

# Definition of Done

A feature is not complete merely because code compiles.

A feature is complete when:

- implementation exists
- architecture is respected
- validation exists
- errors are handled
- loading states exist where needed
- tests exist where appropriate
- integration works
- documentation is updated where necessary
- no obvious regression exists