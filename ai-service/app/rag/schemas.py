"""Bounded corpus and wire contracts. Only operator-reviewed local files are ingested."""

from datetime import date
from typing import Annotated, Literal, Self
from uuid import UUID

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    HttpUrl,
    JsonValue,
    field_validator,
    model_validator,
)

from app.schemas.common import ResponseMetadata

DiseaseLabel = Literal["Common_Rust", "Gray_Leaf_Spot", "Healthy", "Northern_Corn_Leaf_Blight"]
KnowledgeType = Literal[
    "OVERVIEW", "SYMPTOMS", "CAUSES", "CONDITIONS", "MANAGEMENT", "PREVENTION", "REFERENCES"
]


class Contract(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)


class Source(Contract):
    url: HttpUrl
    title: str = Field(min_length=1, max_length=255)
    publisher: str = Field(min_length=1, max_length=255)
    authors: list[Annotated[str, Field(min_length=1, max_length=160)]] = Field(max_length=16)
    published_at: date | None = Field(alias="publishedAt")
    retrieved_at: date = Field(alias="retrievedAt")
    rights: str = Field(min_length=1, max_length=1000)

    @field_validator("url")
    @classmethod
    def source_is_https(cls, value: HttpUrl) -> HttpUrl:
        if value.scheme != "https" or value.username or value.password:
            raise ValueError("Source references must be HTTPS without credentials")
        if len(str(value)) > 2048:
            raise ValueError("Source URL is too long")
        return value


class DiseaseInput(Contract):
    label: DiseaseLabel
    slug: str = Field(pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$", max_length=120)
    name: str = Field(min_length=1, max_length=160)
    description: str = Field(min_length=1, max_length=2000)
    scientific_name: str | None = Field(default=None, alias="scientificName", max_length=200)
    status: Literal["ACTIVE"] = "ACTIVE"


class DocumentInput(Contract):
    document_key: str = Field(
        alias="documentKey", pattern=r"^[a-z0-9][a-z0-9._-]*$", max_length=160
    )
    version: int = Field(strict=True, ge=1, le=2147483647)
    disease_label: DiseaseLabel = Field(alias="diseaseLabel")
    title: str = Field(min_length=1, max_length=255)
    knowledge_type: KnowledgeType = Field(alias="knowledgeType")
    content: str = Field(min_length=1, max_length=20000)
    source: Source
    metadata: dict[str, JsonValue] = Field(default_factory=dict)


class Corpus(Contract):
    version: str = Field(min_length=1, max_length=160)
    diseases: list[DiseaseInput] = Field(min_length=1, max_length=4)
    documents: list[DocumentInput] = Field(min_length=1, max_length=500)

    @model_validator(mode="after")
    def unique_entries(self) -> Self:
        labels = [item.label for item in self.diseases]
        slugs = [item.slug for item in self.diseases]
        keys = [item.document_key for item in self.documents]
        if (
            len(set(labels)) != len(labels)
            or len(set(slugs)) != len(slugs)
            or len(set(keys)) != len(keys)
        ):
            raise ValueError("Corpus identities must be unique")
        if any(item.disease_label not in labels for item in self.documents):
            raise ValueError("Document disease must be present in corpus")
        return self


class RetrievalRequest(Contract):
    query: str = Field(min_length=3, max_length=1000)
    disease_label: DiseaseLabel | None = Field(default=None, alias="diseaseLabel")
    knowledge_type: KnowledgeType | None = Field(default=None, alias="knowledgeType")
    document_version: int | None = Field(
        default=None, alias="documentVersion", strict=True, ge=1, le=2147483647
    )
    top_k: int = Field(default=3, alias="topK", strict=True, ge=1, le=10)

    @field_validator("query")
    @classmethod
    def meaningful_query(cls, value: str) -> str:
        value = value.strip()
        if len(value) < 3 or any(ord(char) < 32 and char not in "\n\t" for char in value):
            raise ValueError("Query must contain readable text")
        if len(value.encode("utf-8")) > 1800:
            raise ValueError("Query exceeds provider text limit")
        return value


class RetrievedChunk(Contract):
    document_id: UUID = Field(alias="documentId")
    document_key: str = Field(alias="documentKey")
    document_version: int = Field(alias="documentVersion", ge=1)
    chunk_id: UUID = Field(alias="chunkId")
    chunk_index: int = Field(alias="chunkIndex", ge=0)
    content: str
    title: str
    disease_label: DiseaseLabel = Field(alias="diseaseLabel")
    knowledge_type: KnowledgeType = Field(alias="knowledgeType")
    source: Source
    similarity: float = Field(ge=-1, le=1, allow_inf_nan=False)
    metadata: dict[str, JsonValue]


class RetrievalData(Contract):
    status: Literal["MATCHES", "NO_MATCHES"]
    chunks: list[RetrievedChunk]
    embedding_model: str = Field(alias="embeddingModel")
    embedding_version: str = Field(alias="embeddingVersion")
    embedding_dimensions: int = Field(alias="embeddingDimensions")
    retrieval_version: Literal["cosine-exact-v1"] = Field(
        default="cosine-exact-v1", alias="retrievalVersion"
    )
    # Similarity is a ranking score, not calibrated evidence confidence.
    evidence_policy: Literal["CANDIDATES_ONLY"] = Field(
        default="CANDIDATES_ONLY", alias="evidencePolicy"
    )


class RetrievalResponse(Contract):
    success: Literal[True] = True
    data: RetrievalData
    meta: ResponseMetadata
