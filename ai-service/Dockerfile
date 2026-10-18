# syntax=docker/dockerfile:1.7
FROM python:3.11.17-slim-bookworm AS build
COPY --from=ghcr.io/astral-sh/uv:0.12.23 /uv /usr/local/bin/uv
ENV UV_PYTHON_DOWNLOADS=never UV_COMPILE_BYTECODE=1
WORKDIR /app/ai-service
COPY shared/preprocessing /app/shared/preprocessing
COPY ai-service/pyproject.toml ai-service/uv.lock ./
RUN uv sync --locked --no-dev --no-editable

FROM python:3.11.17-slim-bookworm AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends libgomp1 ca-certificates && rm -rf /var/lib/apt/lists/* && useradd --uid 10001 --create-home service
ENV PATH=/app/ai-service/.venv/bin:$PATH PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 ENVIRONMENT=production HOST=0.0.0.0 PORT=8000
WORKDIR /app/ai-service
COPY --from=build --chown=service:service /app/ai-service/.venv ./.venv
COPY --chown=service:service ai-service/app ./app
RUN mkdir /logs && chown service:service /logs
USER service
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 CMD ["python", "-m", "app.healthcheck"]
CMD ["python", "-m", "app.server"]
