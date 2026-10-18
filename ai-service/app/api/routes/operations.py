"""Internal operational metrics use the existing service authentication boundary."""

import hmac
import mmap
import os
import time
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, Request
from fastapi.responses import PlainTextResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.utils.errors import AppError, ErrorCode
from app.utils.metrics import render


def authenticate_metrics(
    request: Request,
    credentials: Annotated[
        HTTPAuthorizationCredentials | None, Depends(HTTPBearer(auto_error=False))
    ],
) -> None:
    expected = request.app.state.settings.operations_token.get_secret_value()
    if not expected:
        raise AppError(ErrorCode.SERVICE_UNAVAILABLE)
    if credentials is None or not hmac.compare_digest(
        credentials.credentials.encode(), expected.encode()
    ):
        raise AppError(ErrorCode.AUTHENTICATION_ERROR)


router = APIRouter(dependencies=[Depends(authenticate_metrics)], include_in_schema=False)


@router.get("/internal/metrics", response_class=PlainTextResponse)
def metrics(request: Request) -> PlainTextResponse:
    recorder = request.app.state.operational_recorder
    extra = ""
    if recorder is not None:
        extra = (
            f"maizedoctor_ai_telemetry_pending {recorder.events.qsize()}\n"
            f"maizedoctor_ai_telemetry_dropped {recorder.dropped}\n"
        )
    ready = request.app.state.running and request.app.state.inference_service is not None
    extra += f"maizedoctor_ai_process_cpu_seconds_total {time.process_time()}\n"
    if os.name == "posix" and Path("/proc/self/statm").exists():
        pages = int(Path("/proc/self/statm").read_text().split()[1])
        extra += f"maizedoctor_ai_resident_bytes {pages * mmap.PAGESIZE}\n"
    return PlainTextResponse(
        render() + extra + f"maizedoctor_ai_model_ready {int(ready)}\n",
        media_type="text/plain; version=0.0.4",
    )
