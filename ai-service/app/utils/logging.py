"""Allowlisted JSON fields: never serialize arbitrary messages or exception text."""

import json
import logging
from datetime import UTC, datetime
from logging.config import dictConfig

LOGGER_NAME = "maizedoctor.ai"
SAFE_FIELDS = ("request_id", "method", "route", "status_code", "duration_ms", "error_code")


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
