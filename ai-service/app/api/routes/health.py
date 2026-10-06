from time import perf_counter
from typing import Annotated, cast

from fastapi import APIRouter, Query, Request, Response

from app import SERVICE_NAME, SERVICE_VERSION
from app.schemas.common import ResponseMetadata
from app.schemas.health import HealthData, HealthQuery, HealthResponse
from app.utils.errors import request_id

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse, responses={503: {"model": HealthResponse}})
async def health(
    request: Request, response: Response, _query: Annotated[HealthQuery, Query()]
) -> HealthResponse:
    running = cast(bool, request.app.state.running)
    started_at = cast(float | None, request.app.state.started_at)
    if not running:
        response.status_code = 503
    return HealthResponse(
        data=HealthData(
            service=SERVICE_NAME,
            version=SERVICE_VERSION,
            status="ok" if running else "starting",
            uptime_seconds=round(max(0, perf_counter() - started_at), 3) if started_at else 0,
        ),
        meta=ResponseMetadata(request_id=request_id(request)),
    )
