"""Authenticated internal generation; no user-supplied source URLs or knowledge bodies."""

from typing import TYPE_CHECKING, Annotated, cast

from fastapi import APIRouter, Depends, Request
from fastapi.concurrency import run_in_threadpool

from app.api.json_body import read_json_body
from app.api.security import require_service_authentication
from app.generation.schemas import ExplanationRequest, GenerationResponse, QuestionRequest
from app.schemas.common import ResponseMetadata
from app.utils.errors import AppError, ErrorCode, request_id

if TYPE_CHECKING:
    from app.generation.service import GenerationService

router = APIRouter(prefix="/api/v1", tags=["generation"])


def ready_service(request: Request) -> "GenerationService":
    service = cast("GenerationService | None", request.app.state.generation_service)
    if service is None:
        raise AppError(ErrorCode.GENERATION_UNAVAILABLE)
    return service


@router.post("/generate", response_model=GenerationResponse)
async def generate(
    request: Request, _auth: Annotated[None, Depends(require_service_authentication)]
) -> GenerationResponse:
    service = ready_service(request)
    if not service.slots.acquire(blocking=False):
        raise AppError(ErrorCode.RATE_LIMITED)
    try:
        body = await read_json_body(request, QuestionRequest)
        data = await run_in_threadpool(service.ask, body)
        return GenerationResponse(data=data, meta=ResponseMetadata(request_id=request_id(request)))
    finally:
        service.slots.release()


@router.post("/explain", response_model=GenerationResponse)
async def explain(
    request: Request, _auth: Annotated[None, Depends(require_service_authentication)]
) -> GenerationResponse:
    service = ready_service(request)
    if not service.slots.acquire(blocking=False):
        raise AppError(ErrorCode.RATE_LIMITED)
    try:
        body = await read_json_body(request, ExplanationRequest)
        data = await run_in_threadpool(service.explain, body.prediction)
        return GenerationResponse(data=data, meta=ResponseMetadata(request_id=request_id(request)))
    finally:
        service.slots.release()
