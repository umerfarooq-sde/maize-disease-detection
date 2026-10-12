"""Isolated retrieval contracts, genuine provider boundaries and atomic admission."""

import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from uuid import uuid4

import httpx
import pytest
from fastapi.testclient import TestClient
from pydantic import SecretStr, ValidationError

from app.config.settings import Settings
from app.main import create_app
from app.rag.chunking import Chunk, canonical_content, chunk_document, content_hash
from app.rag.corpus import load_corpus, read_json
from app.rag.embeddings import GoogleEmbedder, validated_vector
from app.rag.schemas import Corpus, DocumentInput, RetrievalRequest, RetrievedChunk
from app.rag.service import RetrievalService, retrieval_identity
from app.utils.errors import AppError, ErrorCode

ROOT = Path(__file__).resolve().parents[2]
TOKEN = "fixture_" + "T" * 50


def configured_settings(**updates: object) -> Settings:
    return Settings(
        _env_file=None,
        **{
            "environment": "test",
            "inference_enabled": False,
            "rag_enabled": True,
            "database_url": SecretStr("postgresql://synthetic:fixture@localhost/fixture"),
            "gemini_api_key": SecretStr("synthetic-provider-secret"),
            "ai_service_token": SecretStr(TOKEN),
            "embedding_model": "fixture-embedding-model",
            "embedding_version": "fixture-v1",
            "embedding_dimensions": 128,
            **updates,
        },
    )


class MemoryRepository:
    def __init__(self) -> None:
        self.persist_calls = 0
        self.requests: list[RetrievalRequest] = []
        self.records: list[RetrievedChunk] = []
        self.skip = False

    def ping(self) -> None:
        return None

    def existing(self, document: DocumentInput, corpus_version: str) -> bool:
        return self.skip

    def persist(
        self, corpus: Corpus, prepared: dict[str, list[tuple[Chunk, list[float]]]]
    ) -> dict[str, int]:
        self.persist_calls += 1
        return {"created": len(prepared), "unchanged": len(corpus.documents) - len(prepared)}

    def retrieve(self, request: RetrievalRequest, vector: list[float]) -> list[RetrievedChunk]:
        self.requests.append(request)
        return self.records[: request.top_k]


class FixedEmbedder:
    def __init__(self) -> None:
        self.calls: list[tuple[str, str | None]] = []
        self.failure: ErrorCode | None = None

    def embed(self, text: str, *, title: str | None = None) -> list[float]:
        self.calls.append((text, title))
        if self.failure:
            raise AppError(self.failure)
        return [1.0] + [0.0] * 127


def curated_corpus() -> Corpus:
    return load_corpus(
        ROOT / "backend/knowledge/maize-extension-20261012-v1.json",
        ROOT / "backend/knowledge/maize-extension-20261012-v1.review.json",
    )


def result_chunk() -> RetrievedChunk:
    document = curated_corpus().documents[0]
    return RetrievedChunk(
        document_id=uuid4(),
        document_key=document.document_key,
        document_version=1,
        chunk_id=uuid4(),
        chunk_index=0,
        content=document.content,
        title=document.title,
        disease_label=document.disease_label,
        knowledge_type=document.knowledge_type,
        source=document.source,
        similarity=0.8,
        metadata={"corpusVersion": "fixture"},
    )


@pytest.mark.parametrize("content", ["  a\r\nb\r c  ", "é" * 603, "e\u0301" * 510, "word " * 400])
def test_chunks_are_deterministic_preserve_content_and_overlap(content: str) -> None:
    canonical = canonical_content(content)
    chunks = chunk_document(content, size=200, overlap=40)
    assert chunks == chunk_document(content, size=200, overlap=40)
    reconstructed = chunks[0].content
    for index, chunk in enumerate(chunks):
        assert chunk.index == index and canonical[chunk.start : chunk.end] == chunk.content
        assert chunk.sha256 == content_hash(chunk.content) and len(chunk.content) <= 200
        if index:
            assert chunk.start == chunks[index - 1].end - 40
            reconstructed += chunk.content[40:]
    assert reconstructed == canonical


@pytest.mark.parametrize("size,overlap", [(100, 0), (200, 200), (1501, 40), (200, -1)])
def test_invalid_chunk_configuration_rejected(size: int, overlap: int) -> None:
    with pytest.raises(ValueError):
        chunk_document("x", size=size, overlap=overlap)


def test_reviewed_corpus_has_literal_labels_sources_and_real_absent_healthy_topics(
    tmp_path: Path,
) -> None:
    corpus = curated_corpus()
    assert len(corpus.documents) == 25
    assert {item.label for item in corpus.diseases} == {
        "Common_Rust",
        "Gray_Leaf_Spot",
        "Healthy",
        "Northern_Corn_Leaf_Blight",
    }
    assert {
        item.knowledge_type for item in corpus.documents if item.disease_label == "Healthy"
    } == {"OVERVIEW", "SYMPTOMS", "PREVENTION", "REFERENCES"}
    assert all(
        item.source.publisher and item.source.rights and item.source.retrieved_at
        for item in corpus.documents
    )
    altered = json.loads((ROOT / "backend/knowledge/maize-extension-20261012-v1.json").read_text())
    altered["documents"][0]["content"] = "Unreviewed replacement."
    file = tmp_path / "altered.json"
    file.write_text(json.dumps(altered))
    with pytest.raises(ValueError, match="ledger"):
        load_corpus(file, ROOT / "backend/knowledge/maize-extension-20261012-v1.review.json")


def test_local_json_is_bounded_and_rejects_duplicate_keys(tmp_path: Path) -> None:
    file = tmp_path / "file.json"
    file.write_text('{"version":1,"version":2}')
    with pytest.raises(ValueError, match="Duplicate"):
        read_json(file)
    file.write_bytes(b"x" * 101)
    with pytest.raises(ValueError, match="size"):
        read_json(file, max_bytes=100)


@pytest.mark.parametrize(
    "values",
    [[0.0] * 128, [True] * 128, [float("nan")] * 128, [float("inf")] * 128, [1.0] * 127, "wrong"],
)
def test_embedding_shape_finiteness_and_norm_are_authoritative(values: object) -> None:
    with pytest.raises(AppError) as failure:
        validated_vector(values, 128)
    assert failure.value.code == ErrorCode.EMBEDDING_INVALID_RESPONSE


def test_google_document_and_query_task_contract_and_normalization() -> None:
    seen = []

    def transport(request: httpx.Request) -> httpx.Response:
        seen.append(json.loads(request.content))
        assert request.url.host == "generativelanguage.googleapis.com"
        assert "synthetic-provider-secret" not in str(request.url)
        assert request.headers["x-goog-api-key"] == "synthetic-provider-secret"
        return httpx.Response(200, json={"embedding": {"values": [2.0] + [0.0] * 127}})

    provider = GoogleEmbedder(configured_settings(), transport=httpx.MockTransport(transport))
    try:
        assert provider.embed("reviewed document", title="Source title")[0] == 1
        assert provider.embed("query")[0] == 1
    finally:
        provider.close()
    assert seen[0] == {
        "content": {"parts": [{"text": "reviewed document"}]},
        "taskType": "RETRIEVAL_DOCUMENT",
        "outputDimensionality": 128,
        "title": "Source title",
    }
    assert seen[1]["taskType"] == "RETRIEVAL_QUERY" and "title" not in seen[1]


@pytest.mark.parametrize(
    "kind", ["unavailable", "redirect", "timeout", "malformed", "wrong-size", "zero", "oversize"]
)
def test_provider_failures_are_safe_and_do_not_fallback(kind: str) -> None:
    def transport(request: httpx.Request) -> httpx.Response:
        if kind == "timeout":
            raise httpx.ReadTimeout("synthetic-provider-secret internal details", request=request)
        if kind == "unavailable":
            return httpx.Response(429, json={"error": "synthetic-provider-secret"})
        if kind == "redirect":
            return httpx.Response(302, headers={"location": "https://evil.invalid/"})
        if kind == "malformed":
            return httpx.Response(
                200, content=b"invalid secret", headers={"content-type": "application/json"}
            )
        if kind == "oversize":
            return httpx.Response(
                200, content=b"x" * 131073, headers={"content-type": "application/json"}
            )
        return httpx.Response(
            200,
            json={"embedding": {"values": [1.0] * 127 if kind == "wrong-size" else [0.0] * 128}},
        )

    provider = GoogleEmbedder(configured_settings(), transport=httpx.MockTransport(transport))
    try:
        with pytest.raises(AppError) as error:
            provider.embed("query")
        assert "secret" not in str(error.value) and error.value.__cause__ is None
    finally:
        provider.close()


def test_input_limit_prevents_provider_silent_truncation() -> None:
    provider = GoogleEmbedder(
        configured_settings(), transport=httpx.MockTransport(lambda _: pytest.fail("must not send"))
    )
    try:
        with pytest.raises(AppError) as error:
            provider.embed("x" * 1800, title="a")
        assert error.value.code == ErrorCode.VALIDATION_ERROR
    finally:
        provider.close()


def test_ingestion_provider_failure_cannot_persist_or_archive_anything() -> None:
    repository = MemoryRepository()
    provider = FixedEmbedder()
    provider.failure = ErrorCode.EMBEDDING_UNAVAILABLE
    service = RetrievalService(configured_settings(), repository, provider)
    with pytest.raises(AppError):
        service.ingest(curated_corpus())
    assert repository.persist_calls == 0


def test_ingestion_idempotency_skips_provider_and_config_identity_changes() -> None:
    repository = MemoryRepository()
    provider = FixedEmbedder()
    service = RetrievalService(configured_settings(), repository, provider)
    assert service.ingest(curated_corpus()) == {"created": 25, "unchanged": 0}
    assert all(title is not None for _, title in provider.calls)
    repository.skip = True
    provider.calls.clear()
    assert service.ingest(curated_corpus()) == {"created": 0, "unchanged": 25}
    assert not provider.calls
    initial = retrieval_identity(service.settings)
    for update in [
        {"embedding_version": "new-v2"},
        {"embedding_dimensions": 256},
        {"rag_chunk_overlap": 80},
    ]:
        assert retrieval_identity(configured_settings(**update)) != initial


@pytest.mark.parametrize(
    "update",
    [
        {"embedding_model": ""},
        {"gemini_api_key": SecretStr("")},
        {"database_url": SecretStr("https://private.invalid")},
        {"embedding_version": ""},
        {"rag_chunk_overlap": 1000},
    ],
)
def test_retrieval_configuration_fails_closed(update: dict[str, object]) -> None:
    with pytest.raises(ValidationError):
        configured_settings(**update)


@pytest.mark.parametrize(
    "input",
    [
        {"query": "ab"},
        {"query": "a\u0000b"},
        {"query": "é" * 901},
        {"query": "valid query", "topK": 11},
        {"query": "valid query", "diseaseLabel": "Other"},
        {"query": "valid query", "topK": True},
        {"query": "valid query", "url": "https://evil.invalid"},
    ],
)
def test_retrieval_input_contract_rejects_unusable_values(input: dict[str, object]) -> None:
    with pytest.raises(ValidationError):
        RetrievalRequest.model_validate(input)


def test_internal_auth_results_empty_filters_health_capacity_and_concurrency() -> None:
    repository = MemoryRepository()
    provider = FixedEmbedder()
    service = RetrievalService(configured_settings(), repository, provider)
    application = create_app(service.settings, retrieval_service=service)
    with TestClient(application) as client:
        headers = {"Authorization": "Bearer " + TOKEN}
        assert client.post("/api/v1/retrieve", json={"query": "valid query"}).status_code == 401
        assert not provider.calls
        assert client.get("/health").json()["data"]["capabilities"]["rag"] == "ready"
        result = client.post(
            "/api/v1/retrieve",
            headers=headers,
            json={
                "query": "maize symptoms",
                "diseaseLabel": "Common_Rust",
                "knowledgeType": "SYMPTOMS",
                "documentVersion": 1,
            },
        )
        assert result.status_code == 200 and result.json()["data"]["status"] == "NO_MATCHES"
        assert repository.requests[-1].knowledge_type == "SYMPTOMS"
        repository.records = [result_chunk()]

        def perform(_: int) -> httpx.Response:
            return client.post(
                "/api/v1/retrieve", headers=headers, json={"query": "maize symptoms"}
            )

        with ThreadPoolExecutor(max_workers=3) as executor:
            responses = list(executor.map(perform, range(6)))
        assert all(response.status_code == 200 for response in responses)
        assert all(
            response.json()["data"]["chunks"][0]["source"]["publisher"] for response in responses
        )
        acquired = sum(service.slots.acquire(False) for _ in range(4))
        try:
            assert acquired == 4 and perform(0).status_code == 429
        finally:
            for _ in range(acquired):
                service.slots.release()
        assert (
            client.post("/api/v1/retrieve", headers=headers, content=b"x" * 8193).status_code == 422
        )
        assert (
            client.post(
                "/api/v1/retrieve",
                headers={**headers, "Content-Type": "application/json"},
                content=b"x" * 8193,
            ).status_code
            == 413
        )
        assert (
            client.post("/api/v1/retrieve", headers=headers, json={"query": "ab"}).status_code
            == 422
        )
        provider.failure = ErrorCode.EMBEDDING_UNAVAILABLE
        failure = perform(0)
        assert (
            failure.status_code == 503
            and failure.json()["error"]["code"] == "EMBEDDING_UNAVAILABLE"
        )
        assert "synthetic-provider-secret" not in failure.text
    assert application.state.retrieval_service is None


def test_disabled_retrieval_and_startup_failure_are_clear(monkeypatch: pytest.MonkeyPatch) -> None:
    settings = configured_settings(rag_enabled=False)
    with TestClient(create_app(settings)) as client:
        assert (
            client.post(
                "/api/v1/retrieve",
                headers={"Authorization": "Bearer " + TOKEN},
                json={"query": "maize"},
            ).status_code
            == 503
        )
    monkeypatch.setattr(
        "app.rag.service.create_retrieval_service",
        lambda _: (_ for _ in ()).throw(RuntimeError("private credentials")),
    )
    with pytest.raises(AppError) as error, TestClient(create_app(configured_settings())):
        pytest.fail("startup must fail")
    assert error.value.code == ErrorCode.RETRIEVAL_UNAVAILABLE and "private" not in str(error.value)
