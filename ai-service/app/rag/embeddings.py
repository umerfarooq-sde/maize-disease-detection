"""Google embedContent task-type API. Fixed origin, bounded responses, no text generation."""

import math
from typing import Protocol

import httpx

from app.config.settings import Settings
from app.utils.errors import AppError, ErrorCode
from app.utils.operations import provider_operation

EMBEDDING_API_VERSION = "embed-content-task-fields-v1"
MAX_EMBEDDING_INPUT_BYTES = 1800


class Embedder(Protocol):
    def embed(self, text: str, *, title: str | None = None) -> list[float]: ...


def validated_vector(values: object, dimensions: int) -> list[float]:
    if not isinstance(values, list) or len(values) != dimensions:
        raise AppError(ErrorCode.EMBEDDING_INVALID_RESPONSE)
    if any(isinstance(item, bool) or not isinstance(item, int | float) for item in values):
        raise AppError(ErrorCode.EMBEDDING_INVALID_RESPONSE)
    vector = [float(item) for item in values]
    if any(not math.isfinite(item) for item in vector):
        raise AppError(ErrorCode.EMBEDDING_INVALID_RESPONSE)
    norm = math.hypot(*vector)
    if not math.isfinite(norm) or norm <= 1e-12:
        raise AppError(ErrorCode.EMBEDDING_INVALID_RESPONSE)
    return [item / norm for item in vector]


class GoogleEmbedder:
    def __init__(self, settings: Settings, *, transport: httpx.BaseTransport | None = None) -> None:
        self.settings = settings
        self.client = httpx.Client(
            timeout=settings.embedding_timeout_seconds,
            follow_redirects=False,
            trust_env=False,
            transport=transport,
            limits=httpx.Limits(max_connections=settings.rag_max_concurrency),
        )
        self.endpoint = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            + settings.embedding_model
            + ":embedContent"
        )

    def close(self) -> None:
        self.client.close()

    def embed(self, text: str, *, title: str | None = None) -> list[float]:
        if (
            len(text.encode("utf-8")) + len((title or "").encode("utf-8"))
            > MAX_EMBEDDING_INPUT_BYTES
        ):
            raise AppError(ErrorCode.VALIDATION_ERROR)
        with provider_operation("EMBEDDING"):
            return self._embed(text, title=title)

    def _embed(self, text: str, *, title: str | None = None) -> list[float]:
        # Use the documented task fields supported by the selected text-only
        # endpoint. The live API ignored nested embedContentConfig and returned
        # 3072 values; this explicit protocol is verified with real 768 responses.
        if (
            len(text.encode("utf-8")) + len((title or "").encode("utf-8"))
            > MAX_EMBEDDING_INPUT_BYTES
        ):
            raise AppError(ErrorCode.VALIDATION_ERROR)
        body: dict[str, object] = {
            "content": {"parts": [{"text": text}]},
            "taskType": "RETRIEVAL_DOCUMENT" if title is not None else "RETRIEVAL_QUERY",
            "outputDimensionality": self.settings.embedding_dimensions,
        }
        if title is not None:
            body["title"] = title
        try:
            with self.client.stream(
                "POST",
                self.endpoint,
                json=body,
                headers={
                    "x-goog-api-key": self.settings.gemini_api_key.get_secret_value(),
                    "Accept-Encoding": "identity",
                },
            ) as response:
                if response.status_code != 200:
                    raise AppError(ErrorCode.EMBEDDING_UNAVAILABLE)
                if (
                    response.headers.get("content-type", "").split(";")[0].lower()
                    != "application/json"
                ):
                    raise AppError(ErrorCode.EMBEDDING_INVALID_RESPONSE)
                payload = bytearray()
                for part in response.iter_bytes(chunk_size=8192):
                    if len(payload) + len(part) > 128 * 1024:
                        raise AppError(ErrorCode.EMBEDDING_INVALID_RESPONSE)
                    payload.extend(part)
                import json

                parsed = json.loads(payload)
                values = parsed["embedding"]["values"]
                return validated_vector(values, self.settings.embedding_dimensions)
        except AppError:
            raise
        except (httpx.HTTPError, OSError):
            raise AppError(ErrorCode.EMBEDDING_UNAVAILABLE) from None
        except (ValueError, KeyError, TypeError, OverflowError):
            raise AppError(ErrorCode.EMBEDDING_INVALID_RESPONSE) from None
