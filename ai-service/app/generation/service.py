"""Controlled question/explanation orchestration on the existing retrieval service."""

import logging
from threading import BoundedSemaphore
from time import perf_counter
from typing import Protocol

from app.config.settings import Settings
from app.generation.context import ReviewedContext
from app.generation.prompts import EXPLANATION_QUESTION, build_prompt
from app.generation.provider import Generator
from app.generation.schemas import (
    AnswerSection,
    AnswerSource,
    ClassifierContext,
    GenerationData,
    GenerationStatus,
    QuestionRequest,
    Statement,
)
from app.generation.scope import resolve_scope
from app.rag.schemas import Corpus, DiseaseLabel, KnowledgeType, RetrievalData, RetrievalRequest
from app.utils.errors import AppError, ErrorCode
from app.utils.logging import LOGGER_NAME

HEADINGS: dict[KnowledgeType, str] = {
    "OVERVIEW": "Overview",
    "SYMPTOMS": "Symptoms",
    "CAUSES": "Causes",
    "CONDITIONS": "Favorable conditions",
    "MANAGEMENT": "Management",
    "PREVENTION": "Prevention",
    "REFERENCES": "References",
}


class Retriever(Protocol):
    def retrieve(self, request: RetrievalRequest) -> RetrievalData: ...


class GenerationService:
    def __init__(
        self, settings: Settings, retrieval: Retriever, corpus: Corpus, generator: Generator
    ) -> None:
        self.settings = settings
        self.retrieval = retrieval
        self.context = ReviewedContext(
            corpus,
            max_chars=settings.generation_context_chars,
            max_chunks=settings.generation_max_chunks,
        )
        self.generator = generator
        self.slots = BoundedSemaphore(settings.generation_max_concurrency)

    def close(self) -> None:
        self.generator.close()

    def ask(self, request: QuestionRequest) -> GenerationData:
        started = perf_counter()
        scope = resolve_scope(request)
        if scope.reason:
            return self._result(
                "OUT_OF_SCOPE" if scope.out_of_scope else "INSUFFICIENT_INFORMATION",
                scope.reason,
                started,
                None,
            )
        if scope.label is None or scope.topic is None:
            raise AppError(ErrorCode.GENERATION_INVALID_RESPONSE)
        return self._generate(request.question, scope.label, scope.topic, None, started)

    def explain(self, prediction: ClassifierContext) -> GenerationData:
        return self._generate(
            EXPLANATION_QUESTION, prediction.predicted_class, None, prediction, perf_counter()
        )

    def _result(
        self,
        status: GenerationStatus,
        reason: str,
        started: float,
        prediction: ClassifierContext | None,
        *,
        provider_used: bool = False,
        sections: list[AnswerSection] | None = None,
        sources: list[AnswerSource] | None = None,
    ) -> GenerationData:
        warnings = [
            "This is sourced educational information, not a confirmed diagnosis or a replacement "
            "for a qualified local agricultural expert.",
            "Sources describe U.S. regional conditions; local applicability and source freshness "
            "require review.",
        ]
        if prediction is not None:
            warnings.append(
                "The classifier result is an unconfirmed research-model suggestion and is "
                "separate from the knowledge sources."
            )
            if prediction.prediction_status == "LOW_CONFIDENCE":
                warnings.append(
                    "The classifier result is LOW_CONFIDENCE. A high score does not resolve "
                    "its uncertainty; inspect the leaf with an agricultural expert."
                )
        message = (
            "Gemini organized the reviewed evidence below; factual text is verified "
            "reviewed corpus excerpts."
            if status == "GROUNDED"
            else "There is insufficient verified evidence for this request. Please "
            "consult a qualified local agricultural expert."
        )
        if status == "OUT_OF_SCOPE":
            message = "This request is outside the supported maize-disease knowledge scope."
        if status == "CONFLICTING_EVIDENCE":
            message = (
                "Retrieved evidence is ambiguous or conflicting. No guidance was generated; "
                "source review is required."
            )
        result = GenerationData(
            status=status,
            reason=reason,
            message=message,
            sections=sections or [],
            sources=sources or [],
            classifier_prediction=prediction,
            warnings=warnings,
            provider_used=provider_used,
            generation_model=self.settings.gemini_model,
            review_set_version=self.context.version,
            duration_ms=round((perf_counter() - started) * 1000, 3),
        )
        logging.getLogger(LOGGER_NAME).info(
            "grounded_generation_completed",
            extra={
                "event": "grounded_generation_completed",
                "duration_ms": result.duration_ms,
                "generation_model": result.generation_model,
                "prompt_version": result.prompt_version,
                "context_version": result.review_set_version,
                "evidence_count": len(result.sources),
                "provider_used": result.provider_used,
                "generation_status": result.status,
            },
        )
        return result

    def _generate(
        self,
        question: str,
        label: DiseaseLabel,
        topic: KnowledgeType | None,
        prediction: ClassifierContext | None,
        started: float,
    ) -> GenerationData:
        retrieval = self.retrieval.retrieve(
            RetrievalRequest(
                query=question
                if prediction is None
                else f"{label.replace('_', ' ')} maize overview symptoms management prevention",
                disease_label=label,
                knowledge_type=topic,
                top_k=self.settings.generation_max_chunks,
            )
        )
        context = self.context.build(retrieval.chunks, label, topic)
        if context.reason:
            return self._result(
                "CONFLICTING_EVIDENCE" if context.conflict else "INSUFFICIENT_INFORMATION",
                context.reason,
                started,
                prediction,
            )
        draft = self.generator.generate(build_prompt(question, context.evidence, prediction))
        if draft.status != "GROUNDED":
            return self._result(
                draft.status, "MODEL_ABSTAINED", started, prediction, provider_used=True
            )
        lookup = {item.id: item for item in context.evidence}
        if any(identity not in lookup for identity in draft.evidence_ids):
            raise AppError(ErrorCode.GENERATION_INVALID_RESPONSE)
        sections: dict[KnowledgeType, list[Statement]] = {}
        sources: list[AnswerSource] = []
        for identity in draft.evidence_ids:
            item = lookup[identity]
            sections.setdefault(item.knowledge_type, []).append(
                Statement(text=item.content, source_ids=[identity])
            )
            chunk = item.chunks[0]
            sources.append(
                AnswerSource(
                    id=identity,
                    document_id=chunk.document_id,
                    document_key=chunk.document_key,
                    document_version=chunk.document_version,
                    chunk_ids=[member.chunk_id for member in item.chunks],
                    source=chunk.source,
                )
            )
        result = self._result(
            "GROUNDED",
            "EVIDENCE_SELECTED",
            started,
            prediction,
            provider_used=True,
            sections=[
                AnswerSection(knowledge_type=topic, heading=HEADINGS[topic], items=items)
                for topic, items in sections.items()
            ],
            sources=sources,
        )
        return result


def create_generation_service(settings: Settings, retrieval: Retriever) -> GenerationService:
    from app.generation.provider import GeminiGenerator
    from app.rag.corpus import load_corpus

    if settings.generation_corpus_path is None or settings.generation_review_path is None:
        raise AppError(ErrorCode.GENERATION_UNAVAILABLE)
    corpus = load_corpus(settings.generation_corpus_path, settings.generation_review_path)
    return GenerationService(settings, retrieval, corpus, GeminiGenerator(settings))
