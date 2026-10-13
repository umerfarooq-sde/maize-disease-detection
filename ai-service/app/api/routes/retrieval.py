"""Internal retrieval accepts bounded JSON, protected before buffering/network access."""

from typing import TYPE_CHECKING, Annotated, cast

from fastapi import APIRouter, Depends, Request
from fastapi.concurrency import run_in_threadpool

from app.api.json_body import read_json_body
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
    if not service.slots.acquire(blocking=False):
        raise AppError(ErrorCode.RATE_LIMITED)
    try:
        payload = await read_json_body(request, RetrievalRequest)
        data = await run_in_threadpool(service.retrieve, payload)
        return RetrievalResponse(data=data, meta=ResponseMetadata(request_id=request_id(request)))
    finally:
        service.slots.release()
