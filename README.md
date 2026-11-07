<!--
  MAIZEDOCTOR — Premium GitHub Repository Landing Page
  Visual Identity: Forest Green (#174C38), Leaf Green (#287551), Lime (#E4F09A), Ivory (#F7F8F3)
-->

<div align="center">

  <img src="mobile/assets/branding/maizedoctor-mark.svg" alt="MAIZEDOCTOR Logo" width="84" height="84" />

  # MAIZEDOCTOR

  ### AI-Powered Maize Disease Detection & Agricultural Decision Support

  **An open, end-to-end agritech platform delivering real-time foliar disease classification, calibrated uncertainty reporting, grounded extension knowledge retrieval (RAG), and deterministic crop input planning.**

  <p align="center">
    <a href="#key-features">Features</a> •
    <a href="#system-architecture">Architecture</a> •
    <a href="#aiml-disease-detection">AI / ML Engine</a> •
    <a href="#rag-based-ai-assistant">RAG Assistant</a> •
    <a href="#database-architecture">Database</a> •
    <a href="#installation-and-setup">Quickstart</a> •
    <a href="#api-documentation">API Docs</a> •
    <a href="requirements.md">Full SRS Specification</a>
  </p>

  <!-- 3D Hero Graphic -->
  <p align="center">
    <img src="docs/assets/maizedoctor-hero.svg" alt="MAIZEDOCTOR 3D Architecture and Scanning Interface Hero" width="100%" />
  </p>

  <!-- Genuine Tech Stack Badges -->
  <p align="center">
    <img src="https://img.shields.io/badge/Flutter-3.11+-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
    <img src="https://img.shields.io/badge/Dart-3.11+-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
    <img src="https://img.shields.io/badge/Node.js-24.22-339933?style=for-the-badge&logo=node.js&logoColor=white" alt="Node.js" />
    <img src="https://img.shields.io/badge/TypeScript-5.x-3178C6?style=for-the-badge&logo=typescript&logoColor=white" alt="TypeScript" />
    <img src="https://img.shields.io/badge/FastAPI-0.128-009688?style=for-the-badge&logo=fastapi&logoColor=white" alt="FastAPI" />
    <img src="https://img.shields.io/badge/Python-3.11-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python" />
    <img src="https://img.shields.io/badge/PyTorch-2.10-EE4C2C?style=for-the-badge&logo=pytorch&logoColor=white" alt="PyTorch" />
    <img src="https://img.shields.io/badge/PostgreSQL-16%20%2B%20pgvector-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL" />
    <img src="https://img.shields.io/badge/Prisma-7.10-2D3748?style=for-the-badge&logo=prisma&logoColor=white" alt="Prisma" />
    <img src="https://img.shields.io/badge/Redis-8.10-DC382D?style=for-the-badge&logo=redis&logoColor=white" alt="Redis" />
  </p>

</div>

---

## 📖 Table of Contents

- [1. Project Overview](#1-project-overview)
- [2. Problem Statement](#2-problem-statement)
- [3. The MAIZEDOCTOR Solution](#3-the-maizedoctor-solution)
- [4. Key Features](#4-key-features)
- [5. System Architecture](#5-system-architecture)
- [6. Technology Stack](#6-technology-stack)
- [7. Application Modules](#7-application-modules)
  - [7.1 Farmer & Guest Experience](#71-farmer--guest-experience)
  - [7.2 Administrator Control Plane](#72-administrator-control-plane)
- [8. AI/ML Disease Detection Pipeline](#8-aiml-disease-detection-pipeline)
  - [8.1 Shared Preprocessing Invariant](#81-shared-preprocessing-invariant)
  - [8.2 MobileNetV3 Small Architecture](#82-mobilenetv3-small-architecture)
  - [8.3 Calibrated Uncertainty & Truth-Telling Policy](#83-calibrated-uncertainty--truth-telling-policy)
- [9. Supported Foliar Disease Classes](#9-supported-foliar-disease-classes)
- [10. RAG-Based Agricultural Assistant](#10-rag-based-agricultural-assistant)
- [11. Deterministic Agronomic Calculators](#11-deterministic-agronomic-calculators)
- [12. Database Architecture & ERD](#12-database-architecture--erd)
- [13. Repository Directory Structure](#13-repository-directory-structure)
- [14. Installation and Setup](#14-installation-and-setup)
- [15. Environment Configuration](#15-environment-configuration)
- [16. Database Migrations & Administration Setup](#16-database-migrations--administration-setup)
- [17. Running Individual Services](#17-running-individual-services)
- [18. API Specification](#18-api-specification)
- [19. Testing and Quality Assurance](#19-testing-and-quality-assurance)
- [20. Security, Privacy & Sanitization](#20-security-privacy--sanitization)
- [21. Scientific Limitations & Domain Boundaries](#21-scientific-limitations--domain-boundaries)
- [22. Roadmap & Future Work](#22-roadmap--future-work)
- [23. License and Acknowledgements](#23-license-and-acknowledgements)

---

## 1. Project Overview

**MAIZEDOCTOR** is a comprehensive, production-grade agricultural decision-support and disease detection ecosystem. Engineered for smallholder farmers, agronomists, and agricultural extension services, MAIZEDOCTOR bridges the gap between state-of-the-art computer vision, dense vector semantic search, large language models, and practical agronomic fieldwork.

The project is structured into three clean, decoupled tiers:
1. **Cross-Platform Flutter Client (`mobile/`)**: An accessible, high-performance mobile application implementing Model-View-ViewModel (MVVM) architecture with `Provider`, five-tab navigation, custom brand tokens, and offline-tolerant state machines.
2. **Node.js Orchestration API (`backend/`)**: A TypeScript REST API built on Express 5, implementing strict Zod schema validation, Argon2id authentication, Jose JWT token management, Sharp EXIF metadata sanitization, Prisma ORM persistence, and Redis distributed rate-limiting.
3. **Python AI Microservice (`ai-service/` & `shared/preprocessing/`)**: A FastAPI service hosting PyTorch deep-learning inference, a strictly coupled shared computer-vision preprocessing package (`maizedoctor_preprocessing v1.0.0`), a `pgvector` semantic retrieval engine, and Google Gemini grounding with verifiable citation verification.

---

## 2. Problem Statement

Maize (*Zea mays*) is a vital crop supporting global food security and economic stability. Smallholder maize farmers face crippling yield losses—often exceeding 40% to 70% in epidemic conditions—due to foliar diseases such as **Common Rust**, **Gray Leaf Spot**, and **Northern Corn Leaf Blight**.

Key challenges confronting farmers and extension officers:
- **Diagnostic Uncertainty:** Visual diagnosis in the field is prone to confusion between fungal leaf spots and blights with overlapping symptom morphology.
- **Untrustworthy AI Advice:** Generic conversational AI systems frequently hallucinate chemical treatment dosages or recommend off-label fungicides that damage soil health.
- **Arithmetic Inaccuracy:** Generative LLMs are notoriously unreliable at calculating exact area-based fertilizer dosages and metric yield forecasts.
- **Data Privacy & Metadata Leaks:** Farm images uploaded to cloud services often inadvertently leak sensitive location (EXIF GPS) metadata.

---

## 3. The MAIZEDOCTOR Solution

MAIZEDOCTOR solves these challenges through strict architectural guarantees:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        MAIZEDOCTOR CORE PILLARS                        │
├───────────────────┬───────────────────┬────────────────────────────────┤
│  COMPUTER VISION  │  GROUNDED RAG     │  DETERMINISTIC CALCULATORS     │
│  & UNCERTAINTY    │  AI ASSISTANT     │  (ZERO LLM ARITHMETIC)         │
├───────────────────┼───────────────────┼────────────────────────────────┤
│ • MobileNetV3     │ • pgvector search │ • Pure TypeScript / Dart math  │
│ • Shared Preproc  │ • 768-dim vectors │ • Exact ha/acre & kg/g math    │
│ • Truthful Low    │ • Verified papers │ • Versioned ministerial rules  │
│   Confidence flag │ • Anti-hallucinate│ • Qualitative LLM explanation  │
└───────────────────┴───────────────────┴────────────────────────────────┘
```

---

## 4. Key Features

| Capability | Module | Description | Verified Status |
|---|---|---|---|
| 📸 **Instant Leaf Scanning** | `mobile` / `backend` | Capture or pick leaf images; client-side file size and MIME checks; Sharp EXIF metadata stripping. | ✅ Implemented |
| 🔬 **Multi-Class Detection** | `ai-service` | PyTorch MobileNetV3 Small classifier identifying Common Rust, Gray Leaf Spot, Blight, and Healthy leaves. | ✅ Implemented |
| ⚠️ **Uncertainty Transparency**| `ai-service` / `mobile` | Calibrated probability distribution; truthful `LOW_CONFIDENCE` flags when thresholds are unconfigured. | ✅ Implemented |
| 📚 **Sourced Disease Library** | `backend` / `mobile` | Peer-reviewed disease catalogue with pathogens, growth stages, favorable conditions, and reference photos. | ✅ Implemented |
| 🧠 **Grounded RAG Assistant** | `ai-service` / `backend`| Natural language Q&A backed by PostgreSQL `pgvector`; Gemini generation with citations and insufficient-info fallback. | ✅ Implemented |
| 🔗 **Scan-Linked Explanations**| `ai-service` / `backend`| Signed-in farmers can ask the AI assistant to explain a specific past scan; verifies owner-scoped permissions. | ✅ Implemented |
| ⚖️ **Fertilizer Calculator** | `backend` / `mobile` | Deterministic N-P-K nutrient and commercial fertilizer planning. Zero LLM math. Versioned agronomic rules. | ✅ Implemented |
| 🌾 **Expected Yield Engine** | `backend` / `mobile` | Deterministic harvest projections across hectares and acres. Zero LLM math. Versioned baseline rates. | ✅ Implemented |
| 📊 **Field Health Analytics** | `backend` / `mobile` | Private farmer insights tracking total scans, healthy vs. disease ratios, and disease trends over time. | ✅ Implemented |
| 🛡️ **Administrator Control** | `backend` / `mobile` | System dashboard, farmer moderation, disease catalogue CRUD, reference image lineage, and pgvector re-indexing. | ✅ Implemented |
| 🩺 **Model Health Dashboard** | `backend` / `ai-service`| Live classifier inspection, confusion matrices, class mapping, and real-time process execution counters. | ✅ Implemented |
| 🔒 **Enterprise Security** | Stack-wide | Argon2id passwords, Jose JWT, HttpOnly cookies, least-privilege DB roles, Redis rate limiting, private Cloudinary reader. | ✅ Implemented |

---

## 5. System Architecture

MAIZEDOCTOR enforces a strict separation of concerns across presentation, orchestration, persistence, and intelligence layers.

### High-Level Component Flow

```mermaid
flowchart LR
    subgraph Client["Mobile Client (Flutter MVVM)"]
        UI["Views & Screens"]
        VM["ViewModels (ChangeNotifier)"]
        Repo["Repositories"]
        UI --> VM --> Repo
    end

    subgraph Edge["Edge Infrastructure"]
        Caddy["Caddy Reverse Proxy<br>(Port 80/443 -> 3000)"]
    end

    subgraph Backend["Node.js Orchestration Tier (Express 5)"]
        API["REST Controllers (/api/v1)"]
        Auth["Argon2 + JWT + RBAC"]
        Sharp["Sharp EXIF Sanitizer"]
        Prisma["Prisma ORM Adapter"]
        API --> Auth
        API --> Sharp
        API --> Prisma
    end

    subgraph Data["Persistence & Caching"]
        DB[("PostgreSQL 16<br>+ pgvector")]
        Redis[("Redis 8<br>Rate Limits & Quotas")]
        Cloud[("Cloudinary<br>Private Storage")]
    end

    subgraph AI["Intelligence Tier (FastAPI)"]
        Preproc["Shared Preprocessing<br>(maizedoctor_preprocessing v1.0.0)"]
        Model["PyTorch MobileNetV3 Small"]
        RAG["pgvector Semantic Retrieval"]
        Gemini["Google Gemini API<br>(text-embedding-004 & gemini-2.5-flash)"]
        Preproc --> Model
        RAG --> Gemini
    end

    Repo -->|"HTTPS REST"| Caddy
    Caddy --> API
    Prisma --> DB
    API --> Redis
    API --> Cloud
    API -->|"HTTP Binary / JSON"| AI
    AI -->|"SQL Cosine Distance"| DB
    AI --> Gemini
```

### End-to-End Disease Detection Sequence

```mermaid
sequenceDiagram
    autonumber
    actor Farmer as Farmer (Mobile App)
    participant Node as Node.js Backend API
    participant Cloud as Cloudinary Storage
    participant AI as Python AI Service
    participant DB as PostgreSQL Database

    Farmer->>Node: POST /api/v1/scans (Image file + Idempotency-Key)
    Note over Node: 1. Validate MIME & 5MB size limit<br/>2. Strip EXIF metadata with Sharp<br/>3. Compute SHA-256 byte hash
    Node->>Cloud: Upload sanitized image (Private folder)
    Cloud-->>Node: Return public_id & secure_url
    Node->>DB: INSERT into scans (status: PENDING)
    Node->>AI: POST /api/v1/predict (Raw image bytes)
    Note over AI: 1. Shared Preprocessing v1.0.0 (224x224 RGB)<br/>2. Aspect letterboxing & normalization<br/>3. PyTorch MobileNetV3 Small inference
    AI-->>Node: Return class probabilities & duration
    Note over Node: Check confidence threshold policy.<br/>Emit LOW_CONFIDENCE if unconfigured.
    Node->>DB: INSERT scan_predictions & UPDATE scan COMPLETED
    Node-->>Farmer: HTTP 201 Created (Scan DTO, Probabilities, Uncertainty Status)
    Farmer->>Farmer: Display Result & Uncertainty Alert
```

---

## 6. Technology Stack

```
MAIZEDOCTOR ARCHITECTURAL STACK
├── Frontend: Flutter 3.11.5 • Dart 3.11.5 • GoRouter 17.5 • Provider 6.1 • Plus Jakarta Sans
├── Backend: Node.js 24.22 • TypeScript 7.0 • Express 5.2 • Prisma 7.10 • Zod 4.6 • Sharp 0.35
├── Security: Argon2id (argon2) • Jose JWT (jose 6.2) • Helmet • CORS • HttpOnly Cookies
├── Intelligence: Python 3.11 • FastAPI 0.128 • PyTorch 2.10 (CPU) • OpenCV 4.13 • Pillow 12.1
├── Preprocessing: maizedoctor_preprocessing 1.0.0 (Shared package between AI & ML training)
├── RAG & LLM: PostgreSQL pgvector • Google Gemini 2.5 Flash • text-embedding-004 (768-dim)
├── Storage: PostgreSQL 16 • Redis 8.10 (Alpine) • Cloudinary Media API (Private Reader)
└── Infrastructure: Caddy 2.11 • Docker Compose • Prometheus v3 • Grafana 13 • Loki • Alloy
```

---

## 7. Application Modules

### 7.1 Farmer & Guest Experience

The mobile application provides an intuitive, accessible interface structured around five primary destinations:

```
┌─────────────────────────────────────────────────────────────┐
│                       FLUTTER SHELL                         │
├────────────┬────────────┬────────────┬─────────────┬────────┤
│   HOME     │   LEARN    │    SCAN    │ AI ASSISTANT│ TOOLS  │
│  Overview  │ Knowledge  │   Detect   │ Conversing  │ Calcs  │
└────────────┴────────────┴────────────┴─────────────┴────────┘
```

1. **Home Screen (`/home`)**: Welcoming agricultural dashboard with real-time status, quick scan launch button, recent scan summaries, and agronomic insights.
2. **Learn Screen (`/knowledge`)**: Peer-reviewed disease catalogue allowing farmers to search symptoms, inspect disease descriptions, study growth stages, and view verified reference images.
3. **Scan Screen (`/scan`)**: Real-time camera capture and photo picker with client validation, progress feedback, probability breakdown, and low-confidence warning indicators.
4. **AI Assistant (`/assistant`)**: Conversational interface grounded in agricultural literature. Tapping citation chips opens detailed source modals. Authenticated farmers can link private scans for personalized explanations.
5. **Tools Screen (`/tools`)**: Hub for deterministic Fertilizer Calculations, Expected Yield Estimations, and Administrator portal access.
6. **Profile Sub-Tree (`/profile`)**: Manage farm acreage, region, and phone; inspect paginated scan history; review disease trends; and submit GDPR-compliant account erasure requests.

### 7.2 Administrator Control Plane

Accessible exclusively to authenticated identities with the `ADMIN` role (`/admin`):
- **System Overview Dashboard**: Aggregate metrics covering total farmers, scan volumes (24h / 7d / all-time), disease detection prevalence, and active model readiness.
- **Farmer Moderation**: Review registered farmer profiles, inspect scanning activity, and modify account status (`ACTIVE` vs. `SUSPENDED`).
- **Disease Catalogue Management**: Author and edit disease records, update scientific names, symptoms, treatments, and growth stages.
- **Reference Image Management**: Upload, review, and publish reference disease imagery with explicit copyright provenance and replacement lineage tracking.
- **Knowledge Curation & pgvector Indexing**: Author markdown documents, preview chunking, and trigger vector embedding generation via the FastAPI AI service.
- **Agronomic Rule Authoring**: Publish versioned fertilizer formulas and regional yield configurations.
- **Model Health Dashboard**: Inspect offline evaluation metrics (accuracy, F1, confusion matrix), active model versions, and real-time inference latency counters.
- **Audit Logging**: Searchable, immutable record of every administrative action with actor IDs, entity types, and before/after JSON diffs.

---

## 8. AI/ML Disease Detection Pipeline

### 8.1 Shared Preprocessing Invariant

> [!IMPORTANT]
> **CRITICAL ML RULE:** Training and production inference **must use the exact same preprocessing implementation**.
> The `shared/preprocessing` package (`maizedoctor_preprocessing v1.0.0`) is the single authoritative implementation.

The preprocessing pipeline performs:
1. **Input Validation:** Enforces max 5 MiB file size, max 16 million pixels, min 16 px side.
2. **Decoding & Orientation:** Decodes image to 8-bit unsigned RGB, honoring EXIF orientation before stripping.
3. **Conservative Background Segmentation:** Removes uniform background connected to image perimeter; enclosed non-green lesion tissue is strictly preserved.
4. **Aspect-Preserving Letterbox:** Scales image to fit 224×224 bounding box with reflection or constant padding.
5. **Normalization:** Scales values to `[0.0, 1.0]` and applies ImageNet standard normalization (mean = `[0.485, 0.456, 0.406]`, std = `[0.229, 0.224, 0.225]`).
6. **Output Tensor:** Generates contiguous CHW `float32` array shaped `(3, 224, 224)`.

### 8.2 MobileNetV3 Small Architecture

The model uses a lightweight `MobileNetV3 Small` backbone fine-tuned for CPU inference efficiency:
- **Trained Checkpoint:** `epoch-008.pt` (SHA-256: `e95a2e83262637fc1a08b919e6003bddb2fe70664b9c51418f059b7c8287dc66`).
- **Dataset Manifest:** `maize-research-20261008-v2` (4,162 unique images, 4,121 groups, 2,911 train / 627 val / 624 test).
- **Validation Accuracy:** **96.81%** (Macro F1: **0.9589**).
- **Descriptive Test Accuracy:** **95.83%** (Macro F1: **0.9452**).

### 8.3 Calibrated Uncertainty & Truth-Telling Policy

MAIZEDOCTOR rejects artificial overconfidence. In accordance with responsible agricultural AI principles:
- **Operational Cutoff:** Because no empirical field calibration trial has been authorized by agricultural extension services, the confidence threshold defaults to `null` (`THRESHOLD_UNCONFIGURED`).
- **Status Flag:** All predictions currently report `prediction_status = 'LOW_CONFIDENCE'` with `uncertainty_reason = 'THRESHOLD_UNCONFIGURED'`.
- **UI Disclosure:** The mobile client renders an amber alert banner advising visual cross-verification against reference symptoms.

---

## 9. Supported Foliar Disease Classes

| Class Label | Pathogen / Scientific Name | Symptoms & Field Morphology | Primary Risk Period |
|---|---|---|---|
| **Common Rust**<br>`Common_Rust` (Index 0) | *Puccinia sorghi* | Golden-brown to cinnamon-brown powdery pustules on both upper and lower leaf surfaces. Pustules rupture the epidermis. | Cool, humid conditions (16–23°C), high dew duration. |
| **Gray Leaf Spot**<br>`Gray_Leaf_Spot` (Index 1) | *Cercospora zeae-maydis* | Rectangular, tan-to-gray lesions strictly delimited by leaf veins. Lesions expand longitudinally to form large necrotic zones. | Warm, humid conditions (25–30°C), prolonged overcast periods. |
| **Healthy Foliage**<br>`Healthy` (Index 2) | N/A (Non-pathological) | Uniform green pigmentation, intact leaf margins, absence of chlorotic spots, pustules, or necrotic lesions. | Optimal crop growth. |
| **Northern Leaf Blight**<br>`Northern_Corn_Leaf_Blight` (Index 3) | *Exserohilum turcicum* | Long, elliptical, grayish-green or tan "cigar-shaped" lesions (2.5 to 15 cm in length), often with dark fungal sporulation in damp weather. | Moderate temperatures (18–27°C) with frequent rainfall. |

---

## 10. RAG-Based Agricultural Assistant

The assistant operates as a **Retrieval-Augmented Generation (RAG)** pipeline backed by PostgreSQL `pgvector` and Google Gemini:

```
[ Farmer Question ]
        │
        ▼
[ Query Embedding: text-embedding-004 (768-dim) ]
        │
        ▼
[ Vector Search in PostgreSQL: embedding <=> query_vector ]
        │
        ▼
[ Top-k Curated Context Chunks (maize-extension-20261012-v1) ]
        │
        ▼
[ Grounding Prompt with Strict Anti-Hallucination Guardrails ]
        │
        ▼
[ Gemini 2.5 Flash Generation ]
        │
        ├─► [ GROUNDED ] ─────────► Returns answer with [Source X] citations
        │
        └─► [ INSUFFICIENT_INFO ] ─► Explicitly states no verified advice exists
```

**Guardrail Invariants:**
- Gemini is never treated as the authoritative source of truth.
- If retrieved chunks do not contain the answer, Gemini emits `INSUFFICIENT_INFORMATION`.
- Farmers can inspect full source text by tapping citation chips in the UI.

---

## 11. Deterministic Agronomic Calculators

> [!CAUTION]
> **CALCULATOR RULE:** Numerical agricultural calculations **must be deterministic**.
> Gemini and LLMs are strictly forbidden from performing calculations.

### Fertilizer Dosing Engine
Calculates commercial fertilizer requirement based on field area and versioned rules:
$$\text{Area}_{\text{ha}} = \begin{cases} \text{Area}_{\text{input}} & \text{if unit is HECTARE} \\ \text{Area}_{\text{input}} \times 0.40468564224 & \text{if unit is ACRE} \end{cases}$$
$$\text{Required Quantity (kg)} = \text{Area}_{\text{ha}} \times \text{Rule Rate (kg/ha)}$$
$$\text{Required Quantity (g)} = \text{Required Quantity (kg)} \times 1000$$

### Expected Yield Forecasting Engine
Calculates expected harvest volume based on area and regional baseline yield:
$$\text{Yield (Metric Tonnes)} = \text{Area}_{\text{ha}} \times \text{Baseline Yield (t/ha)}$$
$$\text{Yield (kg)} = \text{Yield (Metric Tonnes)} \times 1000$$

---

## 12. Database Architecture & ERD

The database schema is managed via Prisma ORM across **15 verified migrations**, defining **23 interconnected models**:

```mermaid
erDiagram
    users ||--o{ auth_sessions : "has"
    users ||--o| farmer_profiles : "owns"
    users ||--o{ scans : "captures"
    users ||--o{ audit_logs : "records"
    users ||--o| privacy_requests : "submits"

    diseases ||--o{ disease_images : "exhibits"
    diseases ||--o{ disease_sources : "cites"
    diseases ||--o{ scan_predictions : "matches"
    diseases ||--o{ knowledge_documents : "informs"

    scans ||--o| scan_uploads : "tracks"
    scans ||--o{ scan_predictions : "contains"
    scans ||--o{ ai_queries : "contextualizes"

    model_versions ||--o{ scan_predictions : "scores"
    model_versions ||--o{ model_metrics : "evaluates"

    knowledge_documents ||--o{ knowledge_chunks : "chunked_into"

    fertilizers ||--o{ fertilizer_rules : "governs"
    fertilizers ||--o{ knowledge_documents : "references"

    calculator_configs ||--o{ history : "logs"

    ai_queries ||--o{ ai_responses : "generates"
```

---

## 13. Repository Directory Structure

```text
E:\MAIZEDOCTOR\
├── .github/                 GitHub Actions CI/CD workflows and security policies
├── ai-service/              Python 3.11 + FastAPI microservice
│   ├── app/
│   │   ├── api/             FastAPI endpoints (predict, retrieve, generate, health)
│   │   ├── config/          Pydantic settings and environment loaders
│   │   ├── generation/      Grounded Gemini generation service
│   │   ├── inference/       PyTorch inference service
│   │   ├── model_management/Artifact loaders, confidence policy, dashboard stats
│   │   ├── rag/             pgvector repository and semantic retrieval service
│   │   └── utils/           Operations telemetry, metrics, and structured logging
│   ├── evaluation/          Offline model benchmark evaluation tools
│   ├── pyproject.toml       Python dependencies (uv / pip)
│   └── Dockerfile           Hardened production Docker container specification
├── backend/                 Node.js + TypeScript REST API
│   ├── knowledge/           Curated agricultural knowledge documents and JSON review files
│   ├── prisma/              Database schema (schema.prisma) and 15 PostgreSQL migrations
│   ├── scripts/             Interactive admin seeding and DB maintenance tools
│   ├── src/
│   │   ├── cli/             Cleanup workers, OpenAPI generators, model registration
│   │   ├── config/          Environment loading and strict configuration validation
│   │   ├── middleware/      Auth (Jose), RBAC, rate limiting, error handling
│   │   ├── modules/         Admin, analytics, auth, calculators, knowledge, scans, yield
│   │   └── server.ts        HTTP server lifecycle, Caddy proxy trust, graceful shutdown
│   ├── tests/               Unit, database integration, and live verification suites
│   ├── openapi.json         Complete OpenAPI 3.1 specification (50 business endpoints)
│   └── package.json         Node.js dependencies and script definitions
├── docs/                    System documentation, architecture reports, and visual assets
│   ├── assets/              Visual assets including maizedoctor-hero.svg
│   ├── 01-system-overview.md through 16-database-operations.md
│   └── PROJECT_STATE.md     Authoritative engineering phase ledger (200KB+)
├── infrastructure/          Container deployment and operations infrastructure
│   ├── runtime/             Docker compose topology (Caddy, Redis, Node, AI, Loki, Grafana)
│   ├── data/                Local PostgreSQL database cluster volume
│   └── compose.yaml         Multi-container orchestration specification
├── ml-training/             Machine learning training pipeline and fitness verification
│   ├── manifests/           Immutable dataset manifests (maize-research-20261008-v2)
│   ├── reports/             MobileNetV3 Small evaluation reports and confusion matrices
│   ├── train.py             PyTorch training script with validation patience stopping
│   └── evaluation.py        Held-out test set evaluation and probability serialization
├── mobile/                  Flutter mobile application (Android / Web)
│   ├── assets/              Variable Plus Jakarta Sans typography and brand marks
│   ├── lib/
│   │   ├── core/            Design tokens, themes, routing (GoRouter), API client, network
│   │   ├── data/            DTO models and remote API repositories
│   │   └── features/        MVVM feature modules (home, scan, learn, AI, tools, admin)
│   └── pubspec.yaml         Flutter dependencies, fonts, and assets
├── scripts/                 Repository automation, parity checks, and test harnesses
│   ├── check-repository.ps1 Master validation suite for all project tiers
│   ├── check-preprocessing-parity.py Parity verification between AI and ML training
│   ├── run-on-phone.ps1     Physical Android phone test launcher and reverse proxy
│   └── initialize-dev-env.ps1 Local development environment initializers
├── shared/
│   └── preprocessing/       Single authoritative computer vision preprocessing package
│       ├── configs/         Default pipeline JSON configurations
│       ├── src/             Decoding, background segmentation, letterboxing, normalization
│       └── pyproject.toml   Reusable package definition (maizedoctor_preprocessing v1.0.0)
├── requirements.md          Complete Software Requirements Specification (SRS)
└── README.md                Canonical GitHub landing documentation
```

---

## 14. Installation and Setup

### Prerequisites

Ensure the following runtimes and developer tools are installed on your host machine:
- **Node.js**: `>=24.22.0 <25`
- **Python**: `3.11.x` (with `uv` or `venv`)
- **Flutter SDK**: `3.11.5` or higher (with Dart SDK 3.11.5+)
- **PostgreSQL**: `16.x` with `pgvector` extension enabled (or Docker Compose)
- **Git** & **PowerShell 7+** (Windows) or **Bash** (Linux/macOS)

---

## 15. Environment Configuration

### 1. Initialize Local Secrets
Run the automated initialization script from the project root to generate local development secrets without printing passwords to the console:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/initialize-dev-env.ps1
```

### 2. Environment Variables Reference Table

#### Backend API (`backend/.env`)
| Variable | Description | Required | Default / Example |
|---|---|---|---|
| `PORT` | HTTP port for Node.js API | No | `3000` |
| `HOST` | Bind address | No | `127.0.0.1` |
| `NODE_ENV` | Runtime environment (`development` / `production`) | Yes | `development` |
| `DATABASE_URL` | Full PostgreSQL connection URL | Yes | `postgresql://user:pass@127.0.0.1:5433/maizedoctor?schema=public` |
| `DIRECT_DATABASE_URL` | Direct unpooled session URL for migrations | No | (Matches `DATABASE_URL` if unpooled) |
| `JWT_SECRET` | Secret key for access token signing (min 32 bytes) | Yes | (Generated random string) |
| `JWT_REFRESH_SECRET` | Secret key for refresh tokens (min 32 bytes) | Yes | (Generated random string) |
| `AI_SERVICE_URL` | Internal URL of the Python FastAPI service | Yes | `http://127.0.0.1:8000` |
| `AI_SERVICE_TOKEN` | Shared authentication token with AI service | Yes | (Generated random string) |
| `CLOUDINARY_CLOUD_NAME`| Cloudinary cloud account name | Yes (for uploads)| Server-only name |
| `CLOUDINARY_API_KEY` | Cloudinary API Key | Yes (for uploads)| Server-only key |
| `CLOUDINARY_API_SECRET`| Cloudinary API Secret | Yes (for uploads)| Server-only secret |
| `REDIS_URL` | Redis connection URL | Optional (Dev) | `redis://127.0.0.1:6379` |

#### AI Service (`ai-service/.env`)
| Variable | Description | Required | Default / Example |
|---|---|---|---|
| `ENVIRONMENT` | Runtime environment (`development` / `production`) | Yes | `development` |
| `PORT` | HTTP port for FastAPI service | No | `8000` |
| `HOST` | Bind address | No | `127.0.0.1` |
| `AI_SERVICE_TOKEN` | Must match backend `AI_SERVICE_TOKEN` | Yes | (Shared secret token) |
| `DATABASE_URL` | PostgreSQL connection for pgvector queries | Yes | `postgresql://...` |
| `GEMINI_API_KEY` | Google Gemini API Key | Yes (for RAG) | API Key |
| `RAG_ENABLED` | Enable vector retrieval and embeddings | Yes | `true` |
| `GENERATION_ENABLED` | Enable Gemini grounded answering | Yes | `true` |
| `EMBEDDING_MODEL` | Embedding model identity | Yes | `text-embedding-004` |
| `GEMINI_MODEL` | Grounded generation model identity | Yes | `gemini-2.5-flash` |
| `MODEL_PATH` | Path to PyTorch model weights checkpoint | Yes | `../ml-training/checkpoints/epoch-008.pt` |
| `MODEL_METADATA_PATH` | Path to model metadata JSON | Yes | `../ml-training/reports/.../model-artifact.json`|

#### Mobile Client (`mobile/`)
The Flutter mobile application receives its public configuration exclusively through compilation parameters (`--dart-define`). **Never inject secrets or private API keys into Flutter.**

```bash
flutter run --flavor staging --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

---

## 16. Database Migrations & Administration Setup

### 1. Execute Prisma Migrations
Apply the 15 database migrations and generate the typed Prisma Client:

```powershell
cd backend
npm run db:migrate
npm run db:generate
```

### 2. Provision an Authorized Administrator
Create an `ADMIN` identity securely via the interactive terminal prompt. Password entry is masked and confirmed; existing accounts cannot be hijacked or promoted:

```powershell
cd backend
npm run admin:seed
```

### 3. Ingest Agricultural Knowledge & Embeddings
Index the curated extension literature into PostgreSQL `pgvector`:

```powershell
cd ai-service
python -m app.rag.cli ingest --corpus ../backend/knowledge/maize-extension-20261012-v1.json --review ../backend/knowledge/maize-extension-20261012-v1.review.json
```

---

## 17. Running Individual Services

### Native Local Development

```powershell
# 1. Start PostgreSQL (Native or Compose)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/postgres-local.ps1 -Action Start

# 2. Start Python FastAPI AI Service (Port 8000)
cd ai-service
.venv/Scripts/python.exe -m uvicorn app.main:create_app --factory --host 127.0.0.1 --port 8000

# 3. Start Node.js Backend API (Port 3000)
cd backend
npm run dev

# 4. Start Flutter Mobile Application
cd mobile
flutter run --flavor staging --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

### Run on Physical Android Phone
Connect an Android phone via USB cable with **USB Debugging** enabled:

```powershell
# 1. Probe connected phone and prerequisites
.\run-on-phone.ps1 -Action Check

# 2. Launch complete stack with automatic ADB reverse port forwarding
.\run-on-phone.ps1 -DeviceId YOUR_ADB_SERIAL
```

### Complete Docker Compose Deployment
To launch the full production topology (Caddy, Node, FastAPI, Redis, Prometheus, Grafana, Loki):

```powershell
cd infrastructure/runtime
docker compose -f compose.yaml -f compose.local.yaml up -d
```

---

## 18. API Specification

The Node.js backend provides **50 fully documented and tested endpoints** conforming to OpenAPI 3.1 (`backend/openapi.json`).

### Key Public & Farmer Routes

```
GET    /api/v1/health                          Service liveness and health probe
POST   /api/v1/auth/register                   Register new farmer account
POST   /api/v1/auth/login                      Authenticate farmer or administrator
POST   /api/v1/auth/refresh                    Rotate access token via HttpOnly cookie
POST   /api/v1/auth/logout                     Revoke session and invalidate cookies
GET    /api/v1/auth/me                         Fetch active authenticated identity
POST   /api/v1/scans                           Submit leaf photograph for disease detection
GET    /api/v1/scans                           Fetch paginated personal scan history
GET    /api/v1/scans/{scanId}                  Fetch scan detail and probability breakdown
GET    /api/v1/scans/{scanId}/image            Stream protected leaf image bytes (Proxy)
POST   /api/v1/scans/{scanId}/explanation      Request grounded AI explanation for this scan
GET    /api/v1/diseases                        List published disease catalogue
GET    /api/v1/diseases/{slug}                 Fetch disease description and symptoms
GET    /api/v1/diseases/{slug}/images          Fetch published reference leaf photos
POST   /api/v1/knowledge/search                Perform semantic search in knowledge base
POST   /api/v1/knowledge/ask                   Ask conversational AI assistant (RAG)
POST   /api/v1/calculators/fertilizer/calculate Execute deterministic fertilizer dosing
POST   /api/v1/calculators/yield/calculate      Execute deterministic yield forecast
GET    /api/v1/analytics/scans                 Fetch personal field disease analytics
GET    /api/v1/profile                         Fetch farmer profile & field area
PATCH  /api/v1/profile                         Update farmer profile details
POST   /api/v1/profile/avatar                  Upload profile avatar image
POST   /api/v1/profile/data-deletion           Submit GDPR account & data erasure request
```

### Administrative Control Plane Routes (`/api/v1/admin`)

```
GET    /api/v1/admin/dashboard                 Platform-wide overview statistics
GET    /api/v1/admin/farmers                   List registered farmer accounts
PATCH  /api/v1/admin/farmers/{id}/status       Suspend or reactivate farmer account
GET    /api/v1/admin/knowledge/diseases        Manage disease catalogue entries
POST   /api/v1/admin/knowledge/documents       Author agricultural knowledge document
POST   /api/v1/admin/knowledge/documents/{id}/index Trigger pgvector vector embedding
GET    /api/v1/admin/disease-images            Manage reference photo library
PATCH  /api/v1/admin/disease-images/{id}/status Publish or replace reference photo
GET    /api/v1/admin/calculators/fertilizer/rules Author fertilizer dosing rules
GET    /api/v1/admin/model-health              Inspect classifier benchmarks & live health
GET    /api/v1/admin/ai-operations             Inspect real-time AI latency/error metrics
GET    /api/v1/admin/audit-logs                Query immutable administrative audit log
```

---

## 19. Testing and Quality Assurance

Every layer of the platform incorporates rigorous automated verification:

```powershell
# Master repository health check
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-repository.ps1

# Backend unit and database integration tests (371+ passing)
cd backend
npm test

# Python AI service and retrieval tests
cd ai-service
pytest

# Preprocessing parity check (100% bitwise equality across 160 test cases)
python scripts/check-preprocessing-parity.py

# Flutter static analysis and automated test suite (882 unit tests, 68 golden tests)
cd mobile
flutter analyze
flutter test
```

---

## 20. Security, Privacy & Sanitization

MAIZEDOCTOR implements defensive engineering across every tier:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        SECURITY SAFEGUARDS                             │
├───────────────────┬───────────────────┬────────────────────────────────┤
│  AUTHENTICATION   │  DATA PRIVACY     │  INFRASTRUCTURE                │
├───────────────────┼───────────────────┼────────────────────────────────┤
│ • Argon2id hash   │ • Sharp EXIF strip│ • Least-privilege DB roles     │
│ • Jose JWT tokens │ • No GPS storage  │ • Non-root Docker containers   │
│ • HttpOnly cookie │ • Cloudinary proxy│ • Read-only root filesystem    │
│ • Auto session rot│ • GDPR erasure API│ • Redis sliding rate limits    │
└───────────────────┴───────────────────┴────────────────────────────────┘
```

1. **Zero Client Secrets:** Flutter applications contain zero private API keys, Cloudinary credentials, or database connection strings.
2. **Metadata Sanitization:** Uploaded photographs are stripped of all EXIF, GPS, camera model, and device serial metadata using `sharp` before persistent storage.
3. **Protected Image Delivery:** Clients never receive direct Cloudinary URLs or upload tokens; all media is served through the backend proxy with strict ownership verification.
4. **Least-Privilege Database Roles:** Production PostgreSQL provisions dedicated users (`node_app`, `ai_service`, `migration_runner`, `backup_worker`) with strictly scoped DDL/DML permissions.

---

## 21. Scientific Limitations & Domain Boundaries

To uphold scientific integrity and academic transparency:
- **Corpus Independence:** The model was trained on the corrected `maize-research-20261008-v2` benchmark (4,162 unique contents across 4,121 groups). Although leak-free across train/validation/test partitions, this represents a reused academic benchmark rather than an unseen real-world field trial.
- **Gray Leaf Spot (GLS) Variance:** GLS samples comprise 13.5% of the training dataset. Consequently, GLS classifications carry higher variance than Common Rust or Healthy leaves.
- **Unconfigured Operational Threshold:** Because no empirical field calibration trial has been certified by regional agricultural extension authorities, the confidence threshold is unconfigured (`null`). The application truth-telling policy marks all predictions as `LOW_CONFIDENCE`.
- **Agronomic Rate Approvals:** While calculation algorithms and unit conversion algebra are fully verified, production fertilizer dosing requires formally reviewed regional nutrient rate tables.

---

## 22. Roadmap & Future Work

- [ ] **Phase 26:** Authoritative multi-region agronomic rate tables reviewed by certified agronomists.
- [ ] **Field Evaluation:** Independent real-world farm calibration trials across diverse soil and lighting environments.
- [ ] **Offline Edge Inference:** On-device TensorFlow Lite / ONNX model execution within the Flutter app for zero-connectivity zones.
- [ ] **Multi-Lingual Localization:** Swahili, French, Hausa, and Hindi translations of curated extension literature.
- [ ] **IoT Sensor Integration:** Integrating soil moisture and temperature telemetry into expected yield forecasts.

---

## 23. License and Acknowledgements

- **Software Codebase:** Copyright © 2026 MAIZEDOCTOR Contributors. Released under the MIT License.
- **Typography:** Plus Jakarta Sans is licensed under the [SIL Open Font License 1.1](mobile/assets/fonts/plus_jakarta_sans/OFL.txt).
- **Academic Research Acknowledgement:** Developed as an applied machine learning and agricultural informatics research platform. Sourced disease references are adapted from standard agricultural university extension publications.

---

<div align="center">
  <sub>Engineered with precision for smallholder farmers and sustainable agriculture worldwide.</sub>
</div>
