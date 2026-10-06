# AI service

Phase 8 implements an internal FastAPI application with validated settings, typed
health/error schemas, JSON request/lifecycle logs, safe errors and a reusable internal
authentication dependency. `GET /health` reports process status separately from the
unloaded model and unavailable AI capabilities. No preprocessing, classification,
model training, RAG, Gemini or Node orchestration is implemented.

The isolated Python 3.11 environment and existing locked CPU/image dependencies are
preserved. `pyproject.toml` and `uv.lock` additionally configure Pydantic settings,
Ruff formatting/lint and strict mypy for application source.

Training and production inference must import the exact same preprocessing
implementation. Its package location and version contract must be settled before
implementation; do not create independent pipelines in this directory and `ml-training/`.
Gemini must explain retrieved agricultural evidence and report insufficient information.

See [AI architecture](../docs/08-ai-architecture.md), [ML pipeline](../docs/09-ml-pipeline.md),
and [RAG architecture](../docs/10-rag-architecture.md). The
[AI foundation guide](../docs/21-ai-service-foundation.md) describes the structure,
contracts, network/auth policy, tests and future boundaries.

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-python.ps1 -Component ai-service
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component AI
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/start-ai.ps1
```

Or from `ai-service/`, run `.venv/Scripts/python.exe -m app.server`. It listens on
`127.0.0.1:8000` by default; Ctrl+C drains/shuts down through Uvicorn and the lifespan.
`Invoke-RestMethod http://127.0.0.1:8000/health` checks the running service.

Settings come from OS environment over the ignored service-local `.env`, independent
of launcher directory. `.env.example` leaves credentials blank. Loopback development
health needs no secrets. Production or non-loopback binding requires a random
base64url `AI_SERVICE_TOKEN` (43-256 characters); future protected routes fail closed
if authentication is unconfigured. No browser CORS access is enabled: Flutter talks
to Node, and Node will call FastAPI over a private network. Production docs are disabled.
Database/Gemini/model template values are reserved and unused in this phase.

Tests cover the actual app foundation plus preserved image/CPU operator dependency
probes. No model or external provider is called. See the
[development setup](../docs/15-development-environment.md) for bootstrap tooling.
