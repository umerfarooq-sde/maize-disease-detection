"""One reusable retrieval/ingestion service for the API and controlled operator CLI."""

import json
from threading import BoundedSemaphore
from typing import Protocol

from app.config.settings import Settings
from app.rag.chunking import CHUNKING_VERSION, Chunk, chunk_document, content_hash
from app.rag.embeddings import EMBEDDING_API_VERSION, Embedder, GoogleEmbedder, validated_vector
from app.rag.repository import KnowledgeRepository
from app.rag.schemas import Corpus, DocumentInput, RetrievalData, RetrievalRequest, RetrievedChunk
from app.utils.operations import service_operation


def retrieval_identity(settings: Settings) -> str:
    return content_hash(
        json.dumps(
            {
                "chunker": CHUNKING_VERSION,
                "size": settings.rag_chunk_chars,
                "overlap": settings.rag_chunk_overlap,
                "provider": "google",
                "model": settings.embedding_model,
                "version": settings.embedding_version,
                "dimensions": settings.embedding_dimensions,
                "normalization": "l2",
                "api": EMBEDDING_API_VERSION,
                "retrieval": "cosine-exact-v1",
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )


class Repository(Protocol):
    def ping(self) -> None: ...
    def existing(self, document: DocumentInput, corpus_version: str) -> bool: ...
    def persist(
        self, corpus: Corpus, prepared: dict[str, list[tuple[Chunk, list[float]]]]
    ) -> dict[str, int]: ...
    def retrieve(self, request: RetrievalRequest, vector: list[float]) -> list[RetrievedChunk]: ...


class RetrievalService:
    def __init__(self, settings: Settings, repository: Repository, embedder: Embedder) -> None:
        self.settings = settings
        self.repository = repository
        self.embedder = embedder
        self.slots = BoundedSemaphore(settings.rag_max_concurrency)

    def ingest(self, corpus: Corpus) -> dict[str, int]:
        # Validate/prepare every embedding first: provider failure leaves both
        # original active versions and database counts untouched.
        prepared: dict[str, list[tuple[Chunk, list[float]]]] = {}
        for document in corpus.documents:
            if self.repository.existing(document, corpus.version):
                continue
            chunks = chunk_document(
                document.content,
                size=self.settings.rag_chunk_chars,
                overlap=self.settings.rag_chunk_overlap,
            )
            prepared[document.document_key] = [
                (
                    chunk,
                    validated_vector(
                        self.embedder.embed(chunk.content, title=document.title),
                        self.settings.embedding_dimensions,
                    ),
                )
                for chunk in chunks
            ]
        return self.repository.persist(corpus, prepared)

    @service_operation("RETRIEVAL")
    def retrieve(self, request: RetrievalRequest) -> RetrievalData:
        vector = validated_vector(
            self.embedder.embed(request.query), self.settings.embedding_dimensions
        )
        chunks = self.repository.retrieve(request, vector)
        return RetrievalData(
            status="MATCHES" if chunks else "NO_MATCHES",
            chunks=chunks,
            embedding_model=self.settings.embedding_model,
            embedding_version=self.settings.embedding_version,
            embedding_dimensions=self.settings.embedding_dimensions,
        )

    def close(self) -> None:
        if isinstance(self.embedder, GoogleEmbedder):
            self.embedder.close()


def create_retrieval_service(settings: Settings) -> RetrievalService:
    repository = KnowledgeRepository(settings, retrieval_identity(settings))
    repository.ping()
    return RetrievalService(settings, repository, GoogleEmbedder(settings))
