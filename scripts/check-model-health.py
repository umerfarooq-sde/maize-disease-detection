"""Read-only registry + real pinned-model + Node/Flutter dashboard contract.

Uses a private loopback AI instance, synthetic image bytes and in-memory auth.
No raw dataset, production account write, model promotion or final-test evaluation.
"""

import base64
import io
import os
import secrets
import shutil
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "ai-service"))
os.chdir(ROOT / "ai-service")

import uvicorn  # noqa: E402
from PIL import Image  # noqa: E402
from pydantic import SecretStr  # noqa: E402

from app.config.settings import load_settings  # noqa: E402
from app.main import create_app  # noqa: E402


def main() -> None:
    settings = load_settings()
    flutter = shutil.which("flutter")
    if flutter is None:
        raise RuntimeError("Flutter SDK is required for the live contract")
    flutter_cache = Path(flutter).resolve().parent / "cache"
    dart = flutter_cache / "dart-sdk" / "bin" / ("dart.exe" if os.name == "nt" else "dart")
    assert settings.inference_enabled and settings.database_url
    token = secrets.token_urlsafe(48)
    isolated = settings.model_copy(
        update={
            "environment": "test",
            "ai_service_token": SecretStr(token),
            "rag_enabled": False,
            "generation_enabled": False,
        }
    )
    app = create_app(isolated)
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    listener.listen()
    server = uvicorn.Server(
        uvicorn.Config(
            app,
            log_config=None,
            log_level="error",
            access_log=False,
        )
    )
    thread = threading.Thread(target=lambda: server.run(sockets=[listener]), daemon=True)
    image = io.BytesIO()
    Image.new("RGB", (64, 96), (80, 130, 60)).save(image, format="PNG")
    try:
        thread.start()
        deadline = time.monotonic() + 60
        while not server.started and thread.is_alive() and time.monotonic() < deadline:
            time.sleep(0.1)
        if not server.started:
            raise RuntimeError("Pinned model did not start")
        parsed = urlsplit(settings.database_url.get_secret_value())
        query = dict(parse_qsl(parsed.query))
        # Enforce read-only even when the local configured account has write privileges.
        query["options"] = "-c default_transaction_read_only=on"
        database_url = urlunsplit(parsed._replace(query=urlencode(query)))
        result = subprocess.run(
            [
                "node",
                "--env-file=backend/.env",
                "backend/node_modules/tsx/dist/cli.mjs",
                "scripts/check-model-health.mjs",
            ],
            cwd=ROOT,
            check=False,
            timeout=240,
            env={
                **os.environ,
                "DATABASE_URL": database_url,
                "AI_SERVICE_URL": f"http://127.0.0.1:{listener.getsockname()[1]}",
                "AI_SERVICE_TOKEN": token,
                "AI_MODEL_VERSION": settings.model_version,
                "AI_PREPROCESSING_VERSION": settings.preprocessing_version,
                "MODEL_HEALTH_DART": str(dart),
                "MODEL_HEALTH_FLUTTER_TOOLS": str(flutter_cache / "flutter_tools.snapshot"),
                "MODEL_HEALTH_IMAGE": base64.b64encode(image.getvalue()).decode("ascii"),
            },
        )
        if result.returncode:
            raise RuntimeError("Dashboard live contract failed")
    finally:
        server.should_exit = True
        thread.join(timeout=10)
        listener.close()


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("Phase 22 live check failed; private configuration is not printed.", file=sys.stderr)
        raise SystemExit(1) from None
