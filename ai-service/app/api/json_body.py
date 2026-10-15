"""Shared bounded JSON admission for protected internal operations."""

import asyncio
from typing import TypeVar

from fastapi import Request
from fastapi.exceptions import RequestValidationError
from pydantic import BaseModel, ValidationError

from app.utils.errors import AppError, ErrorCode

Payload = TypeVar("Payload", bound=BaseModel)


async def read_json_body(
    request: Request, model: type[Payload], *, max_bytes: int = 8192
) -> Payload:
    types = request.headers.getlist("content-type")
    encodings = request.headers.getlist("content-encoding")
    if (
        len(types) != 1
        or types[0].split(";")[0].strip().lower() != "application/json"
        or (encodings and (len(encodings) != 1 or encodings[0].strip().lower() != "identity"))
    ):
        raise AppError(ErrorCode.VALIDATION_ERROR)
    body = bytearray()
    try:
        async with asyncio.timeout(5):
            async for part in request.stream():
                if len(body) + len(part) > max_bytes:
                    raise AppError(ErrorCode.REQUEST_TOO_LARGE)
                body.extend(part)
    except TimeoutError:
        raise AppError(ErrorCode.REQUEST_TIMEOUT) from None
    try:
        return model.model_validate_json(bytes(body))
    except ValidationError as error:
        raise RequestValidationError(error.errors()) from None
