"""Pure ASGI request context with safe logs and safe unexpected responses."""

import logging
from time import perf_counter
from uuid import uuid4

from starlette.datastructures import MutableHeaders
from starlette.requests import Request
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.utils.errors import unexpected_error_handler
from app.utils.logging import LOGGER_NAME


class RequestContextMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        correlation_id = str(uuid4())
        scope.setdefault("state", {})["request_id"] = correlation_id
        started_at = perf_counter()
        status_code = 500
        response_started = False

        async def send_response(message: Message) -> None:
            nonlocal status_code, response_started
            if message["type"] == "http.response.start":
                response_started = True
                status_code = message["status"]
                headers = MutableHeaders(scope=message)
                headers["X-Request-Id"] = correlation_id
                headers["Cache-Control"] = "no-store"
                headers["X-Content-Type-Options"] = "nosniff"
            await send(message)

        try:
            await self.app(scope, receive, send_response)
        except Exception as exception:
            response = await unexpected_error_handler(Request(scope), exception)
            if response_started:
                # A started stream cannot be replaced with a JSON error response.
                raise
            await response(scope, receive, send_response)
        finally:
            route = getattr(scope.get("route"), "path", "unmatched")
            method = scope["method"]
            if method not in {"GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"}:
                method = "OTHER"
            logging.getLogger(LOGGER_NAME).info(
                "request_completed",
                extra={
                    "event": "request_completed",
                    "request_id": correlation_id,
                    "method": method,
                    "route": route,
                    "status_code": status_code,
                    "duration_ms": round((perf_counter() - started_at) * 1000, 3),
                },
            )
