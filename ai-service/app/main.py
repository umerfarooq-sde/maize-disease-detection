"""Load one verified classifier in the lifespan; keep the factory side-effect free."""

from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from dataclasses import replace
from pathlib import Path
from threading import BoundedSemaphore
from time import perf_counter
from typing import TYPE_CHECKING, Protocol

from fastapi import FastAPI

from app import SERVICE_NAME, SERVICE_VERSION
from app.api.middleware import RequestContextMiddleware
from app.api.routes.health import router as health_router
from app.api.routes.prediction import router as prediction_router
from app.config.settings import Settings, load_settings
from app.schemas.errors import ErrorResponse
from app.utils.errors import install_exception_handlers
from app.utils.logging import LOGGER_NAME

if TYPE_CHECKING:
    from app.model_management.artifacts import LoadedModel


class ModelLoader(Protocol):
    def __call__(
        self,
        *,
        checkpoint_path: Path,
        metadata_path: Path,
        metadata_sha256: str,
        model_version: str,
        preprocessing_version: str,
        threads: int,
    ) -> LoadedModel: ...


def create_app(
    settings: Settings | None = None, *, model_loader: ModelLoader | None = None
) -> FastAPI:
    configuration = settings if settings is not None else load_settings()
    logger = logging.getLogger(LOGGER_NAME)

    @asynccontextmanager
    async def lifespan(application: FastAPI) -> AsyncIterator[None]:
        if configuration.inference_enabled:
            from app.inference.service import InferenceService
            from app.model_management.artifacts import ModelStartupError, load_model
            from app.model_management.confidence import load_confidence_policy

            try:
                if not configuration.ai_service_token:
                    raise ModelStartupError("SERVICE_AUTHENTICATION_REQUIRED")
                if (
                    configuration.model_path is None
                    or configuration.model_metadata_path is None
                    or not configuration.model_metadata_sha256
                    or not configuration.model_version
                    or not configuration.preprocessing_version
                ):
                    raise ModelStartupError("MODEL_CONFIGURATION_INCOMPLETE")
                if bool(configuration.confidence_policy_path) != bool(
                    configuration.confidence_policy_sha256
                ):
                    raise ModelStartupError("CONFIDENCE_POLICY_INVALID")
                loader = model_loader if model_loader is not None else load_model
                loaded = loader(
                    checkpoint_path=configuration.model_path,
                    metadata_path=configuration.model_metadata_path,
                    metadata_sha256=configuration.model_metadata_sha256,
                    model_version=configuration.model_version,
                    preprocessing_version=configuration.preprocessing_version,
                    threads=configuration.inference_threads,
                )
                if configuration.confidence_policy_path is not None:
                    threshold = load_confidence_policy(
                        configuration.confidence_policy_path,
                        configuration.confidence_policy_sha256,
                        loaded,
                    )
                    loaded = replace(loaded, confidence_threshold=threshold)
                application.state.inference_service = InferenceService(
                    loaded, max_concurrency=configuration.inference_max_concurrency
                )
            except ModelStartupError as error:
                logger.error(
                    "model_startup_failed",
                    extra={"event": "model_startup_failed", "error_code": error.code},
                )
                raise
            except Exception:
                logger.error(
                    "model_startup_failed",
                    extra={"event": "model_startup_failed", "error_code": "MODEL_STARTUP_FAILED"},
                )
                raise ModelStartupError("MODEL_STARTUP_FAILED") from None
        application.state.started_at = perf_counter()
        application.state.running = True
        logger.info("service_started", extra={"event": "service_started"})
        try:
            yield
        finally:
            application.state.running = False
            application.state.inference_service = None
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
    app.state.inference_service = None
    app.state.prediction_slots = BoundedSemaphore(configuration.inference_max_concurrency)
    install_exception_handlers(app)
    app.add_middleware(RequestContextMiddleware)
    app.include_router(health_router)
    app.include_router(prediction_router)
    return app
