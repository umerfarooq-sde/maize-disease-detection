"""Internal retrieval accepts bounded JSON, protected before buffering/network access."""

import asyncio
from typing import TYPE_CHECKING, Annotated, cast

from fastapi import APIRouter, Depends, Request
from fastapi.concurrency import run_in_threadpool
from fastapi.exceptions import RequestValidationError
from pydantic import ValidationError

from app.api.security import require_service_authentication
from app.rag.schemas import RetrievalRequest, RetrievalResponse
from app.schemas.common import ResponseMetadata
from app.utils.errors import AppError, ErrorCode, request_id

router = APIRouter(prefix="/api/v1", tags=["knowledge"])

if TYPE_CHECKING:
    from app.rag.service import RetrievalService


@router.post("/retrieve", response_model=RetrievalResponse)
async def retrieve(
    request: Request, _auth: Annotated[None, Depends(require_service_authentication)]
) -> RetrievalResponse:
    service = cast("RetrievalService | None", request.app.state.retrieval_service)
    if service is None:
        raise AppError(ErrorCode.RETRIEVAL_UNAVAILABLE)
    if (
        request.headers.get("content-type", "").split(";")[0].lower() != "application/json"
        or request.headers.get("content-encoding", "identity") != "identity"
    ):
        raise AppError(ErrorCode.VALIDATION_ERROR)
    if not service.slots.acquire(blocking=False):
        raise AppError(ErrorCode.RATE_LIMITED)
    try:
        body = bytearray()
        try:
            async with asyncio.timeout(5):
                async for part in request.stream():
                    if len(body) + len(part) > 8192:
                        raise AppError(ErrorCode.REQUEST_TOO_LARGE)
                    body.extend(part)
        except TimeoutError:
            raise AppError(ErrorCode.REQUEST_TIMEOUT) from None
        try:
            payload = RetrievalRequest.model_validate_json(bytes(body))
        except ValidationError as error:
            raise RequestValidationError(error.errors()) from None
        data = await run_in_threadpool(service.retrieve, payload)
        return RetrievalResponse(data=data, meta=ResponseMetadata(request_id=request_id(request)))
    finally:
        service.slots.release()
