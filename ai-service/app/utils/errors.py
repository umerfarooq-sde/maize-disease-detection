"""Central error contracts; omit raw validation values and exception details."""

import logging
from enum import StrEnum
from typing import cast

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException
from starlette.responses import JSONResponse

from app.schemas.common import ResponseMetadata
from app.schemas.errors import ErrorDetails, ErrorResponse, ValidationIssue, ValidationSource
from app.utils.logging import LOGGER_NAME


class ErrorCode(StrEnum):
    VALIDATION_ERROR = "VALIDATION_ERROR"
    AUTHENTICATION_ERROR = "AUTHENTICATION_ERROR"
    AUTHORIZATION_ERROR = "AUTHORIZATION_ERROR"
    NOT_FOUND = "NOT_FOUND"
    METHOD_NOT_ALLOWED = "METHOD_NOT_ALLOWED"
    CONFLICT = "CONFLICT"
    REQUEST_TOO_LARGE = "REQUEST_TOO_LARGE"
    RATE_LIMITED = "RATE_LIMITED"
    SERVICE_UNAVAILABLE = "SERVICE_UNAVAILABLE"
    INTERNAL_ERROR = "INTERNAL_ERROR"


ERRORS: dict[ErrorCode, tuple[int, str]] = {
    ErrorCode.VALIDATION_ERROR: (422, "The request is invalid."),
    ErrorCode.AUTHENTICATION_ERROR: (401, "Valid service authentication is required."),
    ErrorCode.AUTHORIZATION_ERROR: (403, "This operation is not allowed."),
    ErrorCode.NOT_FOUND: (404, "The endpoint was not found."),
    ErrorCode.METHOD_NOT_ALLOWED: (405, "The HTTP method is not allowed."),
    ErrorCode.CONFLICT: (409, "The request conflicts with the current state."),
    ErrorCode.REQUEST_TOO_LARGE: (413, "The request is too large."),
    ErrorCode.RATE_LIMITED: (429, "Too many requests."),
    ErrorCode.SERVICE_UNAVAILABLE: (503, "The service is unavailable."),
    ErrorCode.INTERNAL_ERROR: (500, "An internal error occurred."),
}


class AppError(Exception):
    def __init__(self, code: ErrorCode) -> None:
        self.code = code
        super().__init__(ERRORS[code][1])


def request_id(request: Request) -> str:
    return cast(str, request.state.request_id)


def error_response(
    correlation_id: str,
    code: ErrorCode,
    issues: list[ValidationIssue] | None = None,
    status_code: int | None = None,
) -> JSONResponse:
    status, message = ERRORS[code]
    body = ErrorResponse(
        error=ErrorDetails(code=code.value, message=message, issues=issues or []),
        meta=ResponseMetadata(request_id=correlation_id),
    )
    headers = {"WWW-Authenticate": "Bearer"} if code == ErrorCode.AUTHENTICATION_ERROR else None
    return JSONResponse(
        status_code=status if status_code is None else status_code,
        content=body.model_dump(mode="json", by_alias=True),
        headers=headers,
    )


async def application_error_handler(request: Request, exception: Exception) -> JSONResponse:
    if not isinstance(exception, AppError):
        return await unexpected_error_handler(request, exception)
    return error_response(request_id(request), exception.code)


async def validation_error_handler(request: Request, exception: Exception) -> JSONResponse:
    if not isinstance(exception, RequestValidationError):
        return await unexpected_error_handler(request, exception)
    issues = []
    for error in exception.errors()[:20]:
        location = error.get("loc", ())
        source = location[0] if location else "request"
        if source not in {"body", "query", "path", "header", "cookie"}:
            source = "request"
        # Field names, input, context and Pydantic's messages can contain user data.
        issues.append(
            ValidationIssue(source=cast(ValidationSource, source), code=str(error["type"]))
        )
    return error_response(request_id(request), ErrorCode.VALIDATION_ERROR, issues)


async def http_error_handler(request: Request, exception: Exception) -> JSONResponse:
    if not isinstance(exception, HTTPException):
        return await unexpected_error_handler(request, exception)
    code = next(
        (code for code, (status, _) in ERRORS.items() if status == exception.status_code),
        ErrorCode.INTERNAL_ERROR if exception.status_code >= 500 else ErrorCode.VALIDATION_ERROR,
    )
    response = error_response(request_id(request), code, status_code=exception.status_code)
    if exception.status_code == 405 and exception.headers:
        methods = exception.headers.get("Allow", "").split(", ")
        if all(
            method in {"GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"}
            for method in methods
        ):
            response.headers["Allow"] = ", ".join(methods)
    return response


async def unexpected_error_handler(request: Request, _exception: Exception) -> JSONResponse:
    logging.getLogger(LOGGER_NAME).error(
        "request_failed",
        extra={
            "event": "request_failed",
            "request_id": request_id(request),
            "error_code": ErrorCode.INTERNAL_ERROR.value,
        },
    )
    return error_response(request_id(request), ErrorCode.INTERNAL_ERROR)


def install_exception_handlers(app: FastAPI) -> None:
    app.add_exception_handler(AppError, application_error_handler)
    app.add_exception_handler(RequestValidationError, validation_error_handler)
    app.add_exception_handler(HTTPException, http_error_handler)
