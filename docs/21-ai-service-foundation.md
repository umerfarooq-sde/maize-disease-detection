# AI service foundation

> Historical Phase 8/9 guide. Phase 11 now loads the approved classifier at startup
> and adds authenticated prediction/model-health routes. Read
> [the current inference guide](27-production-ml-inference.md) for active settings,
> startup prerequisites, contracts and verification; the earlier boundaries below
> describe what existed when this foundation was introduced.

Phase 9 adds the [shared preprocessing library](22-shared-preprocessing.md). The
`app.preprocessing` module re-exports its exact functions; health reports library
availability without claiming a ready model. No preprocessing/inference HTTP route
is introduced; the Phase 8 service foundation below remains in place.

Phase 8 implements the internal Python/FastAPI service foundation only. No model
weights, preprocessing implementation, predictions, retrieval, Gemini requests,
database connection or Node service call is added. The intended production flow is
Flutter -> Node.js -> private FastAPI; mobile has no AI service credentials or URL.

## Structure

```text
ai-service/
  pyproject.toml, uv.lock, .python-version, .env.example
  app/
    __init__.py                   service name/version
    main.py                       app factory and lifespan
    server.py                     configured Uvicorn executable
    api/
      middleware.py               correlation, request log and safe 500 boundary
      security.py                 future internal bearer dependency
      routes/health.py            typed process-health report
    config/settings.py            validated operational settings
    schemas/                      metadata, health/query, error/validation contracts
    utils/                        safe errors and JSON logging
    preprocessing/                shared API re-export and boundary README
    inference/README.md           future classifier boundary
    rag/README.md                 future retrieval/generation boundary
    model_management/README.md    immutable artifacts and readiness boundary
  tests/                          app foundation plus dependency smoke checks
```

Inference, RAG and model-management directories contain ownership documentation,
without placeholder model loaders or clients. Preprocessing imports the installed
package from `shared/preprocessing`; there is no separate serving transform. No new
layer mirrors Node's repositories where there is no database work.

## Install and run

From the root on Windows, using the existing Python 3.11 / uv 0.12.23 setup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-python.ps1 -Component ai-service
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component AI
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/start-ai.ps1
```

From `ai-service/` directly:

```powershell
.venv/Scripts/python.exe -m app.server
```

On Linux/macOS use `uv sync --locked` in this directory, then
`.venv/bin/python -m app.server` with Python 3.11. CPU dependencies remain selected by
the explicit PyTorch index; no GPU, weights or dataset downloads are initiated at startup.

Copy `.env.example` to ignored `.env` only when no local file exists. Existing local
configuration is preserved. The service resolves dotenv against its own directory;
OS variables override dotenv. Settings are loaded/validated once before HTTP listens.
Invalid configuration exits nonzero with a fixed JSON event, never rejected values.

| Active setting | Default / validation |
|---|---|
| ENVIRONMENT | development; development/test/production only |
| HOST | 127.0.0.1; IP address or localhost |
| PORT | 8000; integer 1-65535 |
| LOG_LEVEL | INFO; DEBUG/INFO/WARNING/ERROR |
| AI_SERVICE_TOKEN | Blank only for loopback development/test; otherwise required; supplied values are base64url 43-256 characters |

Generate the shared token from at least 32 cryptographically random bytes and supply
the same secret to Node and FastAPI through their server environment/secret manager.
Never put it in Flutter, shell history, request URLs or committed files. Database,
Gemini, model and preprocessing template settings are future values and unused by
this foundation; their presence does not make those capabilities ready.

The executable configures structured stdout logging, disables Uvicorn's raw access
log/server header/proxy-header trust, uses a 5-second keepalive, limits concurrent
connections/tasks to 100 and bounds graceful shutdown to 10 seconds. Ctrl+C invokes
Uvicorn shutdown and the lifespan's stopped event. There are no model/DB resources to
disconnect yet. Reload and multiple-worker deployment are not configured in this phase.

## Endpoints and contracts

`GET /health` is the sole operational endpoint. It accepts no query fields and needs
no bearer token, making local/internal process probes possible. It returns 200 after
lifespan startup; the same safe report returns 503 before startup. This is process
health, not ML readiness. Future model-dependent readiness must be separate.

```json
{
  "success": true,
  "data": {
    "service": "maizedoctor-ai-service",
    "version": "0.1.0",
    "status": "ok",
    "uptimeSeconds": 1.234,
    "capabilities": {
      "preprocessing": "library_available",
      "inference": "not_implemented",
      "rag": "not_implemented",
      "generation": "not_implemented"
    },
    "model": { "status": "not_loaded", "version": null }
  },
  "meta": { "requestId": "server-generated UUID" }
}
```

Responses include matching `X-Request-Id`, `Cache-Control: no-store` and
`X-Content-Type-Options: nosniff`. IDs are generated per request; arbitrary caller IDs
are not reflected. No credentials, environment dumps, paths or dependency internals
are returned. Development/test expose `/docs` and `/openapi.json` only as framework
documentation; they are disabled in production. `/redoc` and slash redirects are disabled.

Central errors use one `success=false`, `error={code,message,issues}` and
`meta={requestId}` envelope. Known application categories have stable HTTP statuses
and fixed safe messages. Validation issues expose bounded source/code pairs only;
no raw payload, context, rejected field name or framework exception message is echoed.
404/405 and unexpected 500 failures use the same contract. Generated OpenAPI 422/500
schemas describe this envelope rather than framework defaults. Once a streaming response
has started it cannot be replaced; future streaming endpoints require their own
completion/error contract. No streams are exposed in Phase 8.

## Network and internal authentication

Loopback binding is the local default. No CORS middleware or cross-origin browser
allowlist is enabled. This is not an authentication mechanism: originless server
clients work normally, and infrastructure must keep this service private.

Production or non-loopback binding requires a configured token even before any
business endpoint exists. `api/security.py` prepares `require_service_authentication`
for future `/api/v1` operation routers. It compares bearer credentials in constant
time and returns 401 for missing/wrong values, 503 if unconfigured; there is no silent
unauthenticated fallback. Only test applications attach a synthetic protected route
to exercise it in this phase. Health deliberately remains public and safe.

This does not implement Node/FastAPI integration, farmer JWT verification, token
issuance, mTLS, a public gateway or distributed rate limiting. Network isolation,
TLS and coordinated token rotation are required for deployment; no deployment or
firewall configuration is changed here.

## Logging and verification

Structured JSON events include UTC timestamp/level/service/event and allowlisted
request ID, known method, route template, response status, latency and error code.
They exclude request URL/query, dynamic path values, headers, body, exception text
and traceback. Lifecycle events distinguish startup/shutdown. The formatter omits
arbitrary third-party/Uvicorn messages and exception text rather than attempting to
redact unknown secret values; those entries are generic `server_event` records.

From `ai-service/`:

```powershell
.venv/Scripts/python.exe -m ruff format --check app tests
.venv/Scripts/python.exe -m ruff check app tests
.venv/Scripts/python.exe -m mypy
.venv/Scripts/python.exe -m pytest
.venv/Scripts/python.exe -m compileall -q app tests
```

`check-development.ps1 -Component AI` runs format, lint, strict application type checks
and all Python tests. Dependency smoke tests still exercise compatible image and CPU
torch/torchvision libraries; application startup does not import these heavy libraries.
Foundation tests exercise actual lifespan/health, environment precedence and safe
configuration errors, request validation, correlation, JSON/log privacy, 404/405/500
handling and the future authentication dependency. See
[project state](PROJECT_STATE.md) for executed results and live startup verification.

Reference patterns: [FastAPI settings](https://fastapi.tiangolo.com/advanced/settings/),
[error handlers](https://fastapi.tiangolo.com/tutorial/handling-errors/),
[Starlette ASGI middleware](https://starlette.dev/middleware/),
[Uvicorn options](https://uvicorn.dev/settings/) and
[Ruff configuration](https://docs.astral.sh/ruff/configuration/).

The Phase 8 foundation is preserved; Phase 9 now supplies the shared preprocessing
library described above. Stop after the Phase 0–9 audit. Model health/readiness,
immutable artifact loading, training/classification, retrieval/generation and Node
orchestration require their own explicitly authorized phases.
