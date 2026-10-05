# System Overview

> **Status:** Architecture baseline. This document describes the intended system, not verified production behavior. See [project state](PROJECT_STATE.md) for the current development scaffold and checks.

## Purpose

MAIZEDOCTOR is an AI-assisted maize disease detection and agricultural decision-support platform. It helps farmers submit crop images, receive disease predictions and grounded guidance, and retain scan history. Administrative users manage platform and knowledge-base operations.

## Users

- **Farmer:** scans maize leaves, reviews results and guidance, and accesses prior scans when signed in.
- **Administrator:** manages users and curated agricultural knowledge, subject to authorization.
- **Anonymous visitor:** may perform a disease scan without creating an account. Anonymous scans are not associated with a user.

## System context

```text
Farmer / Administrator
          |
          v
Flutter mobile application
          |
          v
Node.js + TypeScript REST API (/api/v1)
    |          |             |
    v          v             v
PostgreSQL  Cloudinary   Python FastAPI AI service
                            |       |        |
                            v       v        v
                       Preprocess  PyTorch  RAG + Gemini
```

The backend owns product workflows and orchestration. The AI service owns image processing, inference, retrieval, and model/AI health. PostgreSQL is the system of record; Cloudinary stores image objects.

## Primary workflow

1. The farmer captures or selects a maize image in Flutter.
2. The app submits it to the versioned backend API.
3. The backend validates the request, stores the image through Cloudinary, and requests analysis from the AI service.
4. The AI service validates and preprocesses the image, runs disease inference, and retrieves relevant agricultural knowledge for an explanation where available.
5. The backend persists the scan and returns a stable result to the app.
6. The app presents the result, uncertainty or unavailable-information messaging, and any relevant next steps.

Exact payloads, disease classes, confidence thresholds, and endpoints remain to be confirmed during implementation.

## Architectural principles

- Keep mobile, business orchestration, persistence, and ML responsibilities separate.
- Use one shared image-preprocessing implementation for training and production inference.
- Ground agricultural explanations in the maintained knowledge base; Gemini is not an authoritative source.
- Perform fertilizer and yield calculations deterministically; AI may explain but must not calculate critical quantities.
- Support anonymous scans with a nullable user reference and associate signed-in scans with their farmer.
- Treat this document set as a design baseline until the implementation is available for verification.

## Document map

- [HLA](./02-hla.md) and [HLD](./03-hld.md): system structure and interactions.
- [LLD](./04-lld.md), [database](./05-database-design.md), and [API](./06-api-design.md): implementation contracts.
- [Flutter](./07-flutter-architecture.md), [AI](./08-ai-architecture.md), [ML pipeline](./09-ml-pipeline.md), and [RAG](./10-rag-architecture.md): component designs.
- [Security](./11-security.md), [testing](./12-testing.md), and [deployment](./13-deployment.md): cross-cutting requirements.
