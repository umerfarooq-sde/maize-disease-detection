"""Reviewed Admin drafts use the same chunker, embedder and retrieval identity."""

from typing import TYPE_CHECKING, Protocol, cast
from uuid import UUID

from pydantic import Field, JsonValue

from app.generation.context import INSTRUCTION_PATTERN
from app.rag.chunking import Chunk, canonical_content, chunk_document, content_hash
from app.rag.embeddings import validated_vector
from app.rag.schemas import Contract, DocumentInput
from app.utils.errors import AppError, ErrorCode

if TYPE_CHECKING:
    from app.rag.service import RetrievalService


class PrepareDocument(DocumentInput):
    content: str = Field(min_length=1, max_length=4000)


class DocumentIdentity(Contract):
    document_id: UUID = Field(alias="documentId")
    actor_id: UUID = Field(alias="actorId")
    request_id: UUID = Field(alias="requestId")


class IndexedDraft(Contract):
    document_id: UUID = Field(alias="documentId")
    content_hash: str = Field(alias="contentHash", pattern=r"^[a-f0-9]{64}$")
    retrieval_identity: str = Field(alias="retrievalIdentity", pattern=r"^[a-f0-9]{64}$")
    chunk_count: int = Field(alias="chunkCount", ge=1, le=32)
    ready: bool


class DraftRepository(Protocol):
    def metadata(self, document: DocumentInput, corpus_version: str) -> dict[str, object]: ...
    def draft(self, document_id: UUID) -> tuple[DocumentInput, dict[str, object]]: ...
    def draft_indexed(self, document_id: UUID, chunks: list[Chunk]) -> bool: ...
    def save_draft_index(
        self,
        document_id: UUID,
        chunks: list[tuple[Chunk, list[float]]],
        actor_id: UUID,
        request_id: UUID,
    ) -> None: ...


def prepare_document(service: "RetrievalService", document: PrepareDocument) -> dict[str, object]:
    content = canonical_content(document.content)
    if INSTRUCTION_PATTERN.search(content):
        raise AppError(ErrorCode.VALIDATION_ERROR)
    chunks = chunk_document(
        content, size=service.settings.rag_chunk_chars, overlap=service.settings.rag_chunk_overlap
    )
    if len(chunks) > 32:
        raise AppError(ErrorCode.VALIDATION_ERROR)
    repository = cast(DraftRepository, service.repository)
    return {
        "content": content,
        "contentHash": content_hash(content),
        "metadata": repository.metadata(
            document, f"admin-{document.document_key}-v{document.version}"
        ),
    }


def index_draft(
    service: "RetrievalService", identity: DocumentIdentity, *, check_only: bool = False
) -> IndexedDraft:
    document_id = identity.document_id
    repository = cast(DraftRepository, service.repository)
    document, metadata = repository.draft(document_id)
    prepared = prepare_document(service, PrepareDocument.model_validate(document.model_dump()))
    expected = prepared["metadata"]
    if not isinstance(expected, dict) or any(
        metadata.get(key) != value for key, value in expected.items()
    ):
        # A different chunker/embedding policy needs a new immutable document version.
        raise AppError(ErrorCode.CONFLICT)
    chunks = chunk_document(
        document.content,
        size=service.settings.rag_chunk_chars,
        overlap=service.settings.rag_chunk_overlap,
    )
    ready = repository.draft_indexed(document_id, chunks)
    if not ready and not check_only:
        vectors = [
            (
                chunk,
                validated_vector(
                    service.embedder.embed(chunk.content, title=document.title),
                    service.settings.embedding_dimensions,
                ),
            )
            for chunk in chunks
        ]
        repository.save_draft_index(document_id, vectors, identity.actor_id, identity.request_id)
        ready = True
    return IndexedDraft(
        document_id=document_id,
        content_hash=content_hash(document.content),
        retrieval_identity=cast(str, expected["retrievalIdentity"]),
        chunk_count=len(chunks),
        ready=ready,
    )


def document_from_row(row: dict[str, object]) -> DocumentInput:
    """Only server-stamped reviewed records may supplement the pinned corpus."""
    metadata = row.get("metadata")
    if not isinstance(metadata, dict):
        raise AppError(ErrorCode.CONFLICT)
    review = metadata.get("adminReview")
    curation = metadata.get("curation")
    if (
        not isinstance(review, dict)
        or review.get("status") != "PROJECT_APPROVED_SOURCE"
        or not isinstance(curation, dict)
        or curation.get("review") != "INTENTIONALLY_CURATED_AUTHORITATIVE"
        or not row.get("created_by_id")
        or review.get("reviewedBy") != str(row["created_by_id"])
    ):
        raise AppError(ErrorCode.CONFLICT)
    document = DocumentInput.model_validate(
        {
            "documentKey": row["document_key"],
            "version": row["version"],
            "diseaseLabel": metadata.get("literalLabel"),
            "title": row["title"],
            "knowledgeType": row["knowledge_type"],
            "content": row["content"],
            "source": metadata.get("source"),
            "metadata": cast(dict[str, JsonValue], curation),
        }
    )
    if content_hash(canonical_content(document.content)) != row.get("content_hash"):
        raise AppError(ErrorCode.CONFLICT)
    return document
