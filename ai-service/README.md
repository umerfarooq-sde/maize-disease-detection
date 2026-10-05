# AI service

Phase 1 configures an isolated Python 3.11 environment for FastAPI, Uvicorn,
CPU PyTorch/torchvision, NumPy, OpenCV 4.13, and Pillow. Windows uses `opencv-python`;
Linux uses the matching headless package. `pyproject.toml` declares
dependencies and `uv.lock` locks the full resolution. No production API, image
pipeline, inference, RAG, or Gemini implementation exists yet.

Training and production inference must import the exact same preprocessing
implementation. Its package location and version contract must be settled before
implementation; do not create independent pipelines in this directory and `ml-training/`.
Gemini must explain retrieved agricultural evidence and report insufficient information.

See [AI architecture](../docs/08-ai-architecture.md), [ML pipeline](../docs/09-ml-pipeline.md),
and [RAG architecture](../docs/10-rag-architecture.md). `.env.example` contains proposed
server settings only; blank model settings require a real versioned artifact later.

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-python.ps1 -Component ai-service
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component AI
```

Tests verify a temporary in-memory FastAPI app, image-library imports, and compatible
compiled CPU torch/torchvision operators. The test route is not a deployed endpoint.
See the [development setup](../docs/15-development-environment.md).
