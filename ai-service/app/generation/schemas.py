"""Separate provider selection from public sourced text and immutable classifier output."""

from typing import Literal, Self
from uuid import UUID

from pydantic import Field, model_validator

from app.rag.schemas import Contract, DiseaseLabel, KnowledgeType, RetrievalRequest, Source
from app.schemas.common import ResponseMetadata

GenerationStatus = Literal[
    "GROUNDED", "INSUFFICIENT_INFORMATION", "OUT_OF_SCOPE", "CONFLICTING_EVIDENCE"
]


class QuestionRequest(Contract):
    question: str = Field(min_length=3, max_length=1000)
    disease_label: DiseaseLabel | None = Field(default=None, alias="diseaseLabel")
    knowledge_type: KnowledgeType | None = Field(default=None, alias="knowledgeType")

    @model_validator(mode="after")
    def validate_question(self) -> Self:
        self.question = RetrievalRequest(query=self.question).query
        return self


class ClassifierContext(Contract):
    predicted_class: DiseaseLabel = Field(alias="predictedClass")
    confidence: float = Field(ge=0, le=1, allow_inf_nan=False, strict=True)
    model_version: str = Field(alias="modelVersion", pattern=r"^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$")
    preprocessing_version: str = Field(
        alias="preprocessingVersion", pattern=r"^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$"
    )
    prediction_status: Literal["CONFIDENT", "LOW_CONFIDENCE"] = Field(alias="predictionStatus")
    uncertainty_reason: Literal["BELOW_VALIDATION_THRESHOLD", "THRESHOLD_UNCONFIGURED"] | None = (
        Field(alias="uncertaintyReason")
    )
    confidence_threshold: float | None = Field(
        alias="confidenceThreshold", gt=0, lt=1, allow_inf_nan=False, strict=True
    )

    @model_validator(mode="after")
    def coherent_uncertainty(self) -> Self:
        if self.confidence_threshold is None:
            valid = (
                self.prediction_status == "LOW_CONFIDENCE"
                and self.uncertainty_reason == "THRESHOLD_UNCONFIGURED"
            )
        elif self.confidence < self.confidence_threshold:
            valid = (
                self.prediction_status == "LOW_CONFIDENCE"
                and self.uncertainty_reason == "BELOW_VALIDATION_THRESHOLD"
            )
        else:
            valid = self.prediction_status == "CONFIDENT" and self.uncertainty_reason is None
        if not valid:
            raise ValueError("Classifier uncertainty must be preserved coherently")
        return self


class ExplanationRequest(Contract):
    prediction: ClassifierContext


class EvidenceSelection(Contract):
    """The provider may select evidence or abstain; it cannot author unchecked facts."""

    status: GenerationStatus
    evidence_ids: list[str] = Field(alias="evidenceIds", max_length=10)

    @model_validator(mode="after")
    def coherent_selection(self) -> Self:
        if len(set(self.evidence_ids)) != len(self.evidence_ids):
            raise ValueError("Duplicate evidence selections are not allowed")
        if (self.status == "GROUNDED") != bool(self.evidence_ids):
            raise ValueError("Grounded selections need evidence; abstentions must be empty")
        return self


class Statement(Contract):
    text: str
    source_ids: list[str] = Field(alias="sourceIds", min_length=1)


class AnswerSection(Contract):
    knowledge_type: KnowledgeType = Field(alias="knowledgeType")
    heading: str
    items: list[Statement] = Field(min_length=1)


class AnswerSource(Contract):
    id: str
    document_id: UUID = Field(alias="documentId")
    document_key: str = Field(alias="documentKey")
    document_version: int = Field(alias="documentVersion")
    chunk_ids: list[UUID] = Field(alias="chunkIds", min_length=1)
    source: Source


class GenerationData(Contract):
    status: GenerationStatus
    reason: str
    message: str
    sections: list[AnswerSection]
    sources: list[AnswerSource]
    classifier_prediction: ClassifierContext | None = Field(alias="classifierPrediction")
    warnings: list[str]
    provider_used: bool = Field(alias="providerUsed")
    generation_model: str = Field(alias="generationModel")
    prompt_version: Literal["grounded-evidence-selection-v1"] = Field(
        default="grounded-evidence-selection-v1", alias="promptVersion"
    )
    context_policy_version: Literal["reviewed-excerpts-v1"] = Field(
        default="reviewed-excerpts-v1", alias="contextPolicyVersion"
    )
    review_set_version: str = Field(alias="reviewSetVersion")
    duration_ms: float = Field(alias="durationMs", ge=0, allow_inf_nan=False)


class GenerationResponse(Contract):
    success: Literal[True] = True
    data: GenerationData
    meta: ResponseMetadata
