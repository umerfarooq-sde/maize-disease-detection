"""Opt-in real PostgreSQL/pgvector checks in a fresh, owned, disposable schema."""

import os
import re
from collections.abc import Iterator
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit
from uuid import uuid4

import psycopg
import pytest
from psycopg import sql
from pydantic import SecretStr

from app.config.settings import load_settings
from app.rag.chunking import content_hash
from app.rag.repository import KnowledgeRepository
from app.rag.schemas import Corpus, RetrievalRequest
from app.rag.service import RetrievalService, retrieval_identity
from app.utils.errors import AppError, ErrorCode

pytestmark = pytest.mark.skipif(
    os.getenv("RUN_RAG_DATABASE_TESTS") != "1",
    reason="Opt-in PostgreSQL test; never uses production knowledge fixtures",
)
ROOT = Path(__file__).resolve().parents[2]


class TestEmbedder:
    __test__ = False

    def __init__(self) -> None:
        self.calls = 0
        self.fail = False

    def embed(self, text: str, *, title: str | None = None) -> list[float]:
        self.calls += 1
        if self.fail:
            raise AppError(ErrorCode.EMBEDDING_UNAVAILABLE)
        index = int(content_hash(text)[:4], 16) % 127
        vector = [0.0] * 128
        vector[index] = 1.0
        return vector


@pytest.fixture(scope="module")
def service() -> Iterator[RetrievalService]:
    schema = "phase14_rag_" + uuid4().hex
    assert re.fullmatch(r"phase14_rag_[a-f0-9]{32}", schema)
    settings = load_settings().model_copy(
        update={
            "inference_enabled": False,
            "embedding_model": "synthetic-embedding-model",
            "embedding_version": "synthetic-v1",
            "embedding_dimensions": 128,
        }
    )
    repository = KnowledgeRepository(settings, retrieval_identity(settings))
    created = False
    try:
        with (
            psycopg.connect(
                repository.connection_url, connect_timeout=10, autocommit=True
            ) as connection,
            connection.transaction(),
        ):
            connection.execute(sql.SQL("CREATE SCHEMA {}").format(sql.Identifier(schema)))
            created = True
            connection.execute("SELECT set_config('search_path',%s,true)", (schema + ",public",))
            for path in sorted((ROOT / "backend/prisma/migrations").glob("*/migration.sql")):
                migration = path.read_text(encoding="utf-8")
                # Replay all committed SQL atomically in one owned schema.
                # File-level transaction boundaries are redundant here.
                migration = re.sub(r"(?m)^BEGIN;\s*$|^COMMIT;\s*$", "", migration)
                connection.execute(migration, prepare=False)
        parsed = urlsplit(settings.database_url.get_secret_value())
        query = dict(parse_qsl(parsed.query))
        query["schema"] = schema
        settings = settings.model_copy(
            update={"database_url": SecretStr(urlunsplit(parsed._replace(query=urlencode(query))))}
        )
        repository = KnowledgeRepository(settings, retrieval_identity(settings))
        repository.ping()
        yield RetrievalService(settings, repository, TestEmbedder())
    finally:
        if created:
            with psycopg.connect(
                repository.connection_url, connect_timeout=10, autocommit=True
            ) as connection:
                # Name is independently generated and regex verified above.
                connection.execute(
                    sql.SQL("DROP SCHEMA IF EXISTS {} CASCADE").format(sql.Identifier(schema))
                )


def corpus(version: int = 1) -> Corpus:
    return Corpus.model_validate(
        {
            "version": "SYNTHETIC-TEST-v" + str(version),
            "diseases": [
                {
                    "label": "Common_Rust",
                    "slug": "synthetic-test-rust",
                    "name": "Synthetic test only",
                    "description": "Not agricultural knowledge.",
                }
            ],
            "documents": [
                {
                    "documentKey": "synthetic-test-document",
                    "version": version,
                    "diseaseLabel": "Common_Rust",
                    "knowledgeType": "SYMPTOMS",
                    "title": "Synthetic fixture",
                    "content": "SYNTHETIC DATABASE FIXTURE, NOT AGRICULTURAL KNOWLEDGE. "
                    + str(version),
                    "source": {
                        "url": "https://example.invalid/synthetic-test",
                        "title": "Synthetic fixture",
                        "publisher": "Test only",
                        "authors": [],
                        "publishedAt": None,
                        "retrievedAt": "2026-10-12",
                        "rights": "Synthetic fixture in disposable schema only.",
                    },
                    "metadata": {"review": "TEST_ONLY", "language": "en"},
                }
            ],
        }
    )


def test_real_ingestion_idempotency_source_and_vector_persistence(
    service: RetrievalService,
) -> None:
    assert service.ingest(corpus()) == {"created": 1, "unchanged": 0}
    embedder = service.embedder
    assert isinstance(embedder, TestEmbedder)
    calls = embedder.calls
    assert service.ingest(corpus()) == {"created": 0, "unchanged": 1}
    assert embedder.calls == calls
    result = service.retrieve(
        RetrievalRequest(
            query="Synthetic symptoms", disease_label="Common_Rust", knowledge_type="SYMPTOMS"
        )
    )
    assert len(result.chunks) == 1 and result.chunks[0].source.publisher == "Test only"
    assert result.chunks[0].document_version == 1
    repository = service.repository
    assert isinstance(repository, KnowledgeRepository)
    with repository.connection() as connection:
        row = connection.execute(
            "SELECT public.vector_dims(embedding) AS dims,embedding_model,"
            "embedding_version,metadata FROM knowledge_chunks"
        ).fetchone()
        assert row and row["dims"] == 128 and row["embedding_version"] == "synthetic-v1"
        assert row["metadata"]
        assert connection.execute("SELECT count(*) AS count FROM disease_sources").fetchone() == {
            "count": 1
        }


def test_real_version_archiving_conflict_filters_immutable_lineage_and_provider_failure(
    service: RetrievalService,
) -> None:
    service.ingest(corpus())
    repository = service.repository
    embedder = service.embedder
    assert isinstance(repository, KnowledgeRepository) and isinstance(embedder, TestEmbedder)
    original = service.retrieve(RetrievalRequest(query="Synthetic symptoms")).chunks[0]
    changed = corpus().model_copy(
        update={
            "documents": [
                corpus()
                .documents[0]
                .model_copy(update={"content": "Unapproved same-version modification"})
            ]
        }
    )
    with pytest.raises(AppError) as conflict:
        service.ingest(changed)
    assert conflict.value.code == ErrorCode.CONFLICT
    embedder.fail = True
    with pytest.raises(AppError):
        service.ingest(corpus(2))
    embedder.fail = False
    assert (
        service.retrieve(RetrievalRequest(query="Synthetic symptoms")).chunks[0].chunk_id
        == original.chunk_id
    )
    assert service.ingest(corpus(2)) == {"created": 1, "unchanged": 0}
    current = service.retrieve(RetrievalRequest(query="Synthetic symptoms")).chunks[0]
    assert current.document_version == 2 and current.chunk_id != original.chunk_id
    for request in [
        RetrievalRequest(query="query", disease_label="Healthy"),
        RetrievalRequest(query="query", knowledge_type="PREVENTION"),
        RetrievalRequest(query="query", document_version=1),
    ]:
        assert service.retrieve(request).status == "NO_MATCHES"
    with pytest.raises(AppError):
        service.ingest(corpus(1))
    # Rolling the corpus release forward carries unchanged doc versions without
    # rewriting original provenance or re-embedding them.
    carried = corpus(2).model_copy(update={"version": "SYNTHETIC-TEST-v3"})
    assert service.ingest(carried) == {"created": 0, "unchanged": 1}
    with repository.connection() as connection:
        old = connection.execute(
            "SELECT status::text FROM knowledge_documents WHERE id=%s", (original.document_id,)
        ).fetchone()
        assert old == {"status": "ARCHIVED"}
        assert connection.execute(
            "SELECT id FROM knowledge_chunks WHERE id=%s", (original.chunk_id,)
        ).fetchone()
        for statement, parameters in [
            (
                "UPDATE knowledge_chunks SET embedding_version='overwrite' WHERE id=%s",
                (original.chunk_id,),
            ),
            ("UPDATE knowledge_chunks SET content='overwrite' WHERE id=%s", (original.chunk_id,)),
            (
                "UPDATE knowledge_documents SET metadata='{}'::jsonb WHERE id=%s",
                (original.document_id,),
            ),
        ]:
            with pytest.raises(psycopg.errors.CheckViolation), connection.transaction():
                connection.execute(statement, parameters)


def test_missing_configured_schema_never_falls_back_to_public(service: RetrievalService) -> None:
    parsed = urlsplit(service.settings.database_url.get_secret_value())
    parameters = dict(parse_qsl(parsed.query))
    parameters["schema"] = "phase14_missing_" + uuid4().hex
    settings = service.settings.model_copy(
        update={"database_url": SecretStr(urlunsplit(parsed._replace(query=urlencode(parameters))))}
    )
    repository = KnowledgeRepository(settings, retrieval_identity(settings))
    with pytest.raises(AppError) as failure:
        repository.ping()
    assert failure.value.code == ErrorCode.RETRIEVAL_UNAVAILABLE
