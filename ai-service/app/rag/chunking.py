"""Deterministic character windows with auditable offsets into canonical content."""

import hashlib
import unicodedata
from dataclasses import dataclass

CHUNKING_VERSION = "unicode-char-window-v1"


def canonical_content(content: str) -> str:
    result = unicodedata.normalize("NFC", content.replace("\r\n", "\n").replace("\r", "\n")).strip()
    if not result:
        raise ValueError("Knowledge content must not be blank")
    return result


def content_hash(content: str) -> str:
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


@dataclass(frozen=True)
class Chunk:
    index: int
    start: int
    end: int
    content: str
    sha256: str


def chunk_document(content: str, *, size: int, overlap: int) -> list[Chunk]:
    if not 200 <= size <= 1500 or not 0 <= overlap < size:
        raise ValueError("Invalid chunk window")
    canonical = canonical_content(content)
    result: list[Chunk] = []
    start = 0
    while start < len(canonical):
        end = min(start + size, len(canonical))
        text = canonical[start:end]
        if text.strip():
            result.append(Chunk(len(result), start, end, text, content_hash(text)))
        if end == len(canonical):
            break
        start = end - overlap
    return result
