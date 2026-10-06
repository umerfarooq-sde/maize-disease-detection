"""Attach this dependency to future /api/v1 internal operation routers."""

import hmac
from typing import Annotated, cast

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config.settings import Settings
from app.utils.errors import AppError, ErrorCode

bearer = HTTPBearer(auto_error=False)


def require_service_authentication(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> None:
    settings = cast(Settings, request.app.state.settings)
    expected = settings.ai_service_token.get_secret_value()
    if not expected:
        raise AppError(ErrorCode.SERVICE_UNAVAILABLE)
    if (
        credentials is None
        or len(credentials.credentials) > 256
        or not hmac.compare_digest(
            credentials.credentials.encode("utf-8"), expected.encode("ascii")
        )
    ):
        raise AppError(ErrorCode.AUTHENTICATION_ERROR)
