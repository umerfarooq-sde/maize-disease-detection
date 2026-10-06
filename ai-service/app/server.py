"""Run with python -m app.server; Ctrl+C uses Uvicorn's bounded shutdown."""

import logging
import sys

import uvicorn

from app.config.settings import ConfigurationError, load_settings
from app.main import create_app
from app.utils.logging import LOGGER_NAME, configure_logging


def main() -> None:
    try:
        settings = load_settings()
    except ConfigurationError:
        configure_logging("ERROR")
        logging.getLogger(LOGGER_NAME).error(
            "configuration_invalid", extra={"event": "configuration_invalid"}
        )
        sys.exit(1)

    configure_logging(settings.log_level)
    uvicorn.run(
        create_app(settings),
        host=settings.host,
        port=settings.port,
        log_config=None,
        log_level=settings.log_level.lower(),
        access_log=False,
        server_header=False,
        proxy_headers=False,
        timeout_keep_alive=5,
        timeout_graceful_shutdown=10,
        limit_concurrency=100,
    )


if __name__ == "__main__":
    main()
