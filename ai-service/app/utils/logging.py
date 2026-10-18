"""Allowlisted JSON fields: never serialize arbitrary messages or exception text."""

import json
import logging
import os
from contextvars import ContextVar
from datetime import UTC, datetime
from logging.config import dictConfig
from pathlib import Path

LOGGER_NAME = "maizedoctor.ai"
REQUEST_ID: ContextVar[str | None] = ContextVar("request_id", default=None)
SAFE_FIELDS = (
    "request_id",
    "method",
    "route",
    "status_code",
    "duration_ms",
    "error_code",
    "database_stage",
    "database_failure_kind",
    "generation_model",
    "prompt_version",
    "context_version",
    "evidence_count",
    "provider_used",
    "generation_status",
    # Only the executable's safe ConfigurationError supplies this diagnostic.
    "configuration_hint",
)


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, object] = {
            "timestamp": datetime.fromtimestamp(record.created, UTC).isoformat(),
            "level": record.levelname,
            "service": "maizedoctor-ai-service",
            "event": getattr(record, "event", "server_event"),
        }
        for field in SAFE_FIELDS:
            value = getattr(record, field, None)
            if isinstance(value, (str, int, float)):
                payload[field] = value
        return json.dumps(payload, ensure_ascii=True, allow_nan=False)


def configure_logging(level: str) -> None:
    """Used by the executable; app factories do not mutate global log handlers."""
    dictConfig(
        {
            "version": 1,
            "disable_existing_loggers": False,
            "formatters": {"json": {"()": JsonFormatter}},
            "handlers": {
                "json": {
                    "class": "logging.StreamHandler",
                    "stream": "ext://sys.stdout",
                    "formatter": "json",
                }
            },
            "root": {"handlers": ["json"], "level": level},
            "loggers": {
                LOGGER_NAME: {"handlers": ["json"], "level": level, "propagate": False},
                "uvicorn": {"handlers": ["json"], "level": level, "propagate": False},
                "uvicorn.error": {"handlers": ["json"], "level": level, "propagate": False},
                "uvicorn.access": {"handlers": [], "level": "CRITICAL", "propagate": False},
            },
        }
    )
    directory = os.environ.get("LOG_DIRECTORY")
    if directory:
        from logging.handlers import RotatingFileHandler

        Path(directory).mkdir(parents=True, exist_ok=True, mode=0o750)
        handler = RotatingFileHandler(
            Path(directory) / "ai.jsonl", maxBytes=10485760, backupCount=1
        )
        handler.setFormatter(JsonFormatter())
        # Named loggers do not propagate; attach the same safe handler once.
        logging.getLogger().addHandler(handler)
        for name in (LOGGER_NAME, "uvicorn", "uvicorn.error"):
            logging.getLogger(name).addHandler(handler)
