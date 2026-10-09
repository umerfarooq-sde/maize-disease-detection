"""Bounded raw-image internal contract; Node owns orchestration in Phase 12."""

from __future__ import annotations

import asyncio
from threading import BoundedSemaphore
from typing import TYPE_CHECKING, Annotated, cast

from fastapi import APIRouter, Depends, Query, Request, Response
from pydantic import BaseModel, ConfigDict, Field
from starlette.concurrency import run_in_threadpool
from starlette.requests import ClientDisconnect

from app.api.security import require_service_authentication
from app.config.settings import Settings
from app.schemas.common import ResponseMetadata
from app.schemas.errors import ErrorResponse
from app.schemas.health import HealthQuery
from app.schemas.model_health import ModelHealthData, ModelHealthResponse
from app.schemas.prediction import PredictionResponse
from app.utils.errors import AppError, ErrorCode, request_id

if TYPE_CHECKING:
    from app.inference.service import InferenceService

router = APIRouter(
    prefix="/api/v1",
    tags=["internal inference"],
    dependencies=[Depends(require_service_authentication)],
    responses={
        401: {"model": ErrorResponse},
        413: {"model": ErrorResponse},
        415: {"model": ErrorResponse},
        503: {"model": ErrorResponse},
    },
)


class PredictionQuery(BaseModel):
    model_config = ConfigDict(extra="forbid")

    top_k: int = Field(default=4, ge=1, le=4)


def get_inference_service(request: Request) -> InferenceService:
    service = cast("InferenceService | None", request.app.state.inference_service)
    if not request.app.state.running or service is None:
        raise AppError(ErrorCode.MODEL_UNAVAILABLE)
    return service


async def read_image(request: Request, maximum: int, timeout_seconds: float) -> tuple[bytes, str]:
    types = request.headers.getlist("content-type")
    if len(types) != 1:
        raise AppError(ErrorCode.IMAGE_UNSUPPORTED)
    media_type = types[0].split(";", 1)[0].strip().lower()
    if media_type not in {"image/jpeg", "image/png", "image/webp"}:
        raise AppError(ErrorCode.IMAGE_UNSUPPORTED)
    encodings = request.headers.getlist("content-encoding")
    if encodings and (len(encodings) != 1 or encodings[0].strip().lower() != "identity"):
        raise AppError(ErrorCode.IMAGE_UNSUPPORTED)
    lengths = request.headers.getlist("content-length")
    if lengths:
        if (
            len(lengths) != 1
            or len(lengths[0]) > 10
            or not lengths[0].isascii()
            or not lengths[0].isdecimal()
        ):
            raise AppError(ErrorCode.VALIDATION_ERROR)
        if int(lengths[0]) > maximum:
            raise AppError(ErrorCode.REQUEST_TOO_LARGE)
    data = bytearray()
    try:
        async with asyncio.timeout(timeout_seconds):
            async for chunk in request.stream():
                if len(data) + len(chunk) > maximum:
                    raise AppError(ErrorCode.REQUEST_TOO_LARGE)
                data.extend(chunk)
    except TimeoutError:
        raise AppError(ErrorCode.REQUEST_TIMEOUT) from None
    except ClientDisconnect:
        raise AppError(ErrorCode.IMAGE_INVALID) from None
    return bytes(data), media_type


@router.post(
    "/predict",
    response_model=PredictionResponse,
    responses={408: {"model": ErrorResponse}},
    openapi_extra={
        "requestBody": {
            "required": True,
            "content": {
                kind: {"schema": {"type": "string", "format": "binary"}}
                for kind in ("image/jpeg", "image/png", "image/webp")
            },
        }
    },
)
async def predict(
    request: Request, query: Annotated[PredictionQuery, Query()]
) -> PredictionResponse:
    service = get_inference_service(request)
    slots = cast(BoundedSemaphore, request.app.state.prediction_slots)
    if not slots.acquire(blocking=False):
        raise AppError(ErrorCode.INFERENCE_BUSY)
    try:
        settings = cast(Settings, request.app.state.settings)
        data, media_type = await read_image(
            request,
            service.loaded_model.config.max_bytes,
            settings.inference_upload_timeout_seconds,
        )
        result = await run_in_threadpool(
            service.predict, data, mime_type=media_type, top_k=query.top_k
        )
        return PredictionResponse(
            data=result, meta=ResponseMetadata(request_id=request_id(request))
        )
    finally:
        slots.release()


@router.get(
    "/model-health",
    response_model=ModelHealthResponse,
    responses={503: {"model": ModelHealthResponse}},
)
async def model_health(
    request: Request, response: Response, _query: Annotated[HealthQuery, Query()]
) -> ModelHealthResponse:
    service = cast("InferenceService | None", request.app.state.inference_service)
    loaded = service.loaded_model if service is not None and request.app.state.running else None
    if loaded is None:
        response.status_code = 503
    return ModelHealthResponse(
        data=ModelHealthData(
            status="ready" if loaded is not None else "not_loaded",
            model_version=loaded.model_version if loaded is not None else None,
            preprocessing_version=loaded.preprocessing_version if loaded is not None else None,
            class_mapping={name: index for index, name in enumerate(loaded.class_names)}
            if loaded is not None
            else {},
            confidence_threshold=loaded.confidence_threshold if loaded is not None else None,
            confidence_policy="VALIDATION_BASED"
            if loaded is not None and loaded.confidence_threshold is not None
            else "UNCONFIGURED",
            calibration="temperature"
            if loaded is not None and loaded.calibration_temperature != 1
            else "none",
        ),
        meta=ResponseMetadata(request_id=request_id(request)),
    )
