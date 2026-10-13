"""Admit pinned reviewed evidence, merge overlap and never fill unretrieved gaps."""

import re
from dataclasses import dataclass
from typing import cast

from app.generation.prompts import Evidence
from app.rag.chunking import canonical_content, content_hash
from app.rag.schemas import Corpus, DiseaseLabel, DocumentInput, KnowledgeType, RetrievedChunk

INSTRUCTION_PATTERN = re.compile(
    r"ignore\s+(?:all\s+)?(?:previous|prior|system)\s+(?:instructions|prompts)|"
    r"(?:system|developer)\s*(?:prompt|message)\s*:|"
    r"(?:reveal|print|expose)\s+(?:the\s+)?(?:api.?key|secret|password)|"
    r"(?:you are now|override\s+(?:the\s+)?instructions)|<\s*/?\s*(?:system|assistant)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class ContextResult:
    evidence: list[Evidence]
    reason: str | None = None
    conflict: bool = False


class ReviewedContext:
    def __init__(self, corpus: Corpus, *, max_chars: int, max_chunks: int) -> None:
        self.version = corpus.version
        self.documents = {(item.document_key, item.version): item for item in corpus.documents}
        self.max_chars = max_chars
        self.max_chunks = max_chunks

    def _verified(self, chunk: RetrievedChunk, document: DocumentInput) -> bool:
        start, end = chunk.metadata.get("start"), chunk.metadata.get("end")
        content = canonical_content(document.content)
        curation = chunk.metadata.get("curation")
        return (
            type(start) is int
            and type(end) is int
            and 0 <= start < end <= len(content)
            and content[start:end] == chunk.content
            and chunk.metadata.get("contentHash") == content_hash(chunk.content)
            and isinstance(curation, dict)
            and curation == document.metadata
            and curation.get("review") == "INTENTIONALLY_CURATED_AUTHORITATIVE"
            and chunk.source == document.source
            and chunk.disease_label == document.disease_label
            and chunk.knowledge_type == document.knowledge_type
            and not INSTRUCTION_PATTERN.search(chunk.content)
        )

    def build(
        self, chunks: list[RetrievedChunk], label: DiseaseLabel, topic: KnowledgeType | None
    ) -> ContextResult:
        grouped: dict[tuple[str, int], list[RetrievedChunk]] = {}
        identities: dict[str, RetrievedChunk] = {}
        for chunk in chunks[: self.max_chunks]:
            identity = str(chunk.chunk_id)
            if identity in identities and identities[identity] != chunk:
                return ContextResult([], "UNTRUSTED_EVIDENCE")
            identities[identity] = chunk
            if chunk.disease_label != label or (
                topic is not None and chunk.knowledge_type != topic
            ):
                return ContextResult([], "UNTRUSTED_EVIDENCE")
            if topic is None and chunk.knowledge_type not in {
                "OVERVIEW",
                "SYMPTOMS",
                "MANAGEMENT",
                "PREVENTION",
            }:
                continue
            key = (chunk.document_key, chunk.document_version)
            document = self.documents.get(key)
            if document is None or not self._verified(chunk, document):
                return ContextResult([], "UNTRUSTED_EVIDENCE")
            grouped.setdefault(key, []).append(chunk)
        if not grouped:
            return ContextResult([], "NO_EVIDENCE")
        topic_contents: dict[str, set[str]] = {}
        evidence: list[Evidence] = []
        consumed = 0
        for key, records in grouped.items():
            document = self.documents[key]
            canonical = canonical_content(document.content)
            topic_contents.setdefault(document.knowledge_type, set()).add(canonical)
            if len(topic_contents[document.knowledge_type]) > 1:
                # Different approved documents for the same class/topic are
                # unresolved competing evidence in this conservative baseline.
                return ContextResult([], "AMBIGUOUS_EVIDENCE", conflict=True)
            if len({str(item.document_id) for item in records}) != 1:
                return ContextResult([], "UNTRUSTED_EVIDENCE")
            intervals = sorted(
                (cast(int, item.metadata["start"]), cast(int, item.metadata["end"]))
                for item in records
            )
            covered = 0
            for start, end in intervals:
                if start > covered:
                    break
                covered = max(covered, end)
            # Render complete reviewed paragraphs only; do not manufacture a
            # full paragraph from the pinned file when retrieval omitted a gap.
            if covered != len(canonical) or len(canonical) > 4000:
                continue
            if consumed + len(canonical) > self.max_chars:
                continue
            if any(item.content == canonical for item in evidence):
                continue
            consumed += len(canonical)
            unique = {item.chunk_id: item for item in records}
            evidence.append(
                Evidence(
                    f"e{len(evidence) + 1}",
                    canonical,
                    document.knowledge_type,
                    tuple(unique.values()),
                )
            )
        return ContextResult(evidence, None if evidence else "CONTEXT_LIMIT")
