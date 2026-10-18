"""Container readiness checks configured inference availability without provider calls."""

import json
import sys
import urllib.request

from app.config.settings import load_settings

try:
    settings = load_settings()
    request = urllib.request.Request(
        f"http://127.0.0.1:{settings.port}/api/v1/model-health",
        headers={"Authorization": "Bearer " + settings.ai_service_token.get_secret_value()},
    )
    with urllib.request.urlopen(request, timeout=8) as response:
        result = json.load(response)
    sys.exit(0 if result["data"]["status"] == "ready" else 1)
except Exception:
    sys.exit(1)
