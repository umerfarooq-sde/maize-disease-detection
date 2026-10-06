"""App factory: no model loading, provider calls or database connections."""

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from time import perf_counter

from fastapi import FastAPI

from app import SERVICE_NAME, SERVICE_VERSION
from app.api.middleware import RequestContextMiddleware
from app.api.routes.health import router as health_router
from app.config.settings import Settings, load_settings
from app.schemas.errors import ErrorResponse
from app.utils.errors import install_exception_handlers
from app.utils.logging import LOGGER_NAME


def create_app(settings: Settings | None = None) -> FastAPI:
    configuration = settings if settings is not None else load_settings()
    logger = logging.getLogger(LOGGER_NAME)

    @asynccontextmanager
    async def lifespan(application: FastAPI) -> AsyncIterator[None]:
        application.state.started_at = perf_counter()
        application.state.running = True
        logger.info("service_started", extra={"event": "service_started"})
        try:
            yield
        finally:
            application.state.running = False
            logger.info("service_stopped", extra={"event": "service_stopped"})

    development = configuration.environment != "production"
    app = FastAPI(
        title=SERVICE_NAME,
        version=SERVICE_VERSION,
        debug=False,
        lifespan=lifespan,
        docs_url="/docs" if development else None,
        redoc_url=None,
        openapi_url="/openapi.json" if development else None,
        responses={422: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
    )
    app.router.redirect_slashes = False
    app.state.settings = configuration
    app.state.started_at = None
    app.state.running = False
    install_exception_handlers(app)
    app.add_middleware(RequestContextMiddleware)
    app.include_router(health_router)
    return app
