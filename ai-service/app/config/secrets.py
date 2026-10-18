"""Allowlisted runtime-mounted JSON. Never include invalid values in errors."""

import json
import os
from pathlib import Path
from typing import cast

KEYS = {"DATABASE_URL", "GEMINI_API_KEY", "AI_SERVICE_TOKEN", "OPERATIONS_TOKEN"}


def runtime_secrets() -> dict[str, str]:
    location = os.getenv("MAIZEDOCTOR_SECRETS_FILE")
    if not location:
        return {}
    try:
        path = Path(location)
        if path.stat().st_size > 32768:
            raise ValueError()
        result = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(result, dict) or not all(
            key in KEYS
            and isinstance(value, str)
            and value
            and (not os.getenv(key) or os.getenv(key) == value)
            for key, value in result.items()
        ):
            raise ValueError()
        return cast(dict[str, str], result)
    except (OSError, ValueError, UnicodeError):
        raise ValueError("Invalid runtime secret file") from None
