"""Node-authorized Admin orchestration; never reachable directly from Flutter."""

from typing import TYPE_CHECKING, Literal, cast

from fastapi import APIRouter, Depends, Request
from fastapi.concurrency import run_in_threadpool

from app.api.json_body import read_json_body
from app.api.security import require_service_authentication
from app.utils.errors import AppError, ErrorCode, request_id

if TYPE_CHECKING:
    from app.rag.service import RetrievalService

router = APIRouter(
    prefix="/api/v1/knowledge",
    tags=["knowledge-management"],
    dependencies=[Depends(require_service_authentication)],
)


async def manage(
    operation: Literal["prepare", "index", "check"],
    request: Request,
) -> dict[str, object]:
    service = cast("RetrievalService | None", request.app.state.retrieval_service)
    if service is None:
        raise AppError(ErrorCode.RETRIEVAL_UNAVAILABLE)
    if not service.slots.acquire(blocking=False):
        raise AppError(ErrorCode.RATE_LIMITED)
    try:
        # Keep app/route discovery free of provider and numeric-library imports.
        from app.rag.management import (
            DocumentIdentity,
            PrepareDocument,
            index_draft,
            prepare_document,
        )

        if operation == "prepare":
            document = await read_json_body(request, PrepareDocument, max_bytes=32768)
            data = await run_in_threadpool(prepare_document, service, document)
        else:
            identity = await read_json_body(request, DocumentIdentity)
            indexed = await run_in_threadpool(
                index_draft, service, identity, check_only=operation == "check"
            )
            data = indexed.model_dump(mode="json", by_alias=True)
        return {"success": True, "data": data, "meta": {"requestId": request_id(request)}}
    finally:
        service.slots.release()


@router.post("/prepare")
async def prepare(request: Request) -> dict[str, object]:
    return await manage("prepare", request)


@router.post("/index")
async def index(request: Request) -> dict[str, object]:
    return await manage("index", request)


@router.post("/check")
async def check(request: Request) -> dict[str, object]:
    return await manage("check", request)
