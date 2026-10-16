"""Official Google GenAI SDK, one owned client, bounded one-attempt structured call."""

from time import perf_counter
from typing import Protocol

import httpx
from google import genai
from google.genai import errors, types
from pydantic import ValidationError

from app.config.settings import Settings
from app.generation.prompts import SYSTEM_PROMPT
from app.generation.schemas import EvidenceSelection
from app.utils.errors import AppError, ErrorCode
from app.utils.operations import provider_operation


class Generator(Protocol):
    def generate(self, prompt: str) -> EvidenceSelection: ...
    def close(self) -> None: ...


class BoundedTransport(httpx.BaseTransport):
    """Bound raw provider bytes before the SDK buffers/parses them.

    HTTPX enforces network I/O timeouts; the elapsed check bounds a dripping
    response between reads. An in-progress read can still consume its I/O timeout.
    """

    def __init__(self, inner: httpx.BaseTransport, timeout: float) -> None:
        self.inner = inner
        self.timeout = timeout

    def close(self) -> None:
        self.inner.close()

    def handle_request(self, request: httpx.Request) -> httpx.Response:
        request.headers["accept-encoding"] = "identity"
        started = perf_counter()
        response = self.inner.handle_request(request)
        try:
            if (
                response.is_redirect
                or response.headers.get("content-encoding", "identity").lower() != "identity"
                or response.headers.get("content-type", "").split(";")[0].strip().lower()
                != "application/json"
            ):
                raise AppError(ErrorCode.GENERATION_INVALID_RESPONSE)
            declared = response.headers.get("content-length")
            if declared is not None and (not declared.isdecimal() or int(declared) > 131072):
                raise AppError(ErrorCode.GENERATION_INVALID_RESPONSE)
            body = bytearray()
            parts = (
                [response.content]
                if response.is_stream_consumed
                else response.iter_raw(chunk_size=8192)
            )
            for part in parts:
                if perf_counter() - started > self.timeout:
                    raise httpx.ReadTimeout("Generation response deadline.", request=request)
                if len(body) + len(part) > 131072:
                    raise AppError(ErrorCode.GENERATION_INVALID_RESPONSE)
                body.extend(part)
            return httpx.Response(
                response.status_code,
                headers=response.headers,
                content=bytes(body),
                extensions=response.extensions,
                request=request,
            )
        finally:
            response.close()


class GeminiGenerator:
    def __init__(self, settings: Settings, *, transport: httpx.BaseTransport | None = None) -> None:
        self.settings = settings
        limits = httpx.Limits(max_connections=settings.generation_max_concurrency)
        bounded = BoundedTransport(
            transport or httpx.HTTPTransport(retries=0, trust_env=False, limits=limits),
            settings.generation_timeout_seconds,
        )
        self.http_client = httpx.Client(
            timeout=settings.generation_timeout_seconds,
            trust_env=False,
            follow_redirects=False,
            transport=bounded,
            limits=limits,
        )
        try:
            self.client = genai.Client(
                api_key=settings.gemini_api_key.get_secret_value(),
                vertexai=False,
                enterprise=False,
                http_options=types.HttpOptions(
                    base_url="https://generativelanguage.googleapis.com",
                    api_version="v1beta",
                    timeout=int(settings.generation_timeout_seconds * 1000),
                    retry_options=types.HttpRetryOptions(attempts=1),
                    httpx_client=self.http_client,
                ),
            )
        except Exception:
            self.http_client.close()
            raise

    def close(self) -> None:
        # The SDK deliberately leaves caller-supplied transports open.
        try:
            self.client.close()
        finally:
            self.http_client.close()

    def generate(self, prompt: str) -> EvidenceSelection:
        with provider_operation("GEMINI"):
            return self._generate(prompt)

    def _generate(self, prompt: str) -> EvidenceSelection:
        try:
            response = self.client.models.generate_content(
                model=self.settings.gemini_model,
                contents=prompt,
                config=types.GenerateContentConfig(
                    system_instruction=SYSTEM_PROMPT,
                    temperature=0,
                    max_output_tokens=512,
                    candidate_count=1,
                    response_mime_type="application/json",
                    response_json_schema=EvidenceSelection.model_json_schema(),
                    automatic_function_calling=types.AutomaticFunctionCallingConfig(disable=True),
                ),
            )
            if not response.candidates or len(response.candidates) != 1:
                raise AppError(ErrorCode.GENERATION_INVALID_RESPONSE)
            candidate = response.candidates[0]
            parts = candidate.content.parts if candidate.content is not None else None
            if (
                candidate.finish_reason != types.FinishReason.STOP
                or not parts
                or len(parts) != 1
                or parts[0].thought
                or parts[0].text is None
                or len(parts[0].text.encode("utf-8")) > 8192
            ):
                raise AppError(ErrorCode.GENERATION_INVALID_RESPONSE)
            return EvidenceSelection.model_validate_json(parts[0].text)
        except AppError:
            raise
        except httpx.TimeoutException:
            raise AppError(ErrorCode.GENERATION_TIMEOUT) from None
        except errors.APIError as error:
            code = (
                ErrorCode.GENERATION_TIMEOUT
                if error.code in {408, 504}
                else ErrorCode.GENERATION_UNAVAILABLE
            )
            raise AppError(code) from None
        except (httpx.HTTPError, OSError):
            raise AppError(ErrorCode.GENERATION_UNAVAILABLE) from None
        except (ValidationError, ValueError, TypeError):
            raise AppError(ErrorCode.GENERATION_INVALID_RESPONSE) from None
