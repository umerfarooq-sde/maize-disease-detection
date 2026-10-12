"""Curated development relevance evaluation; not independent agronomic validation."""

from statistics import mean
from time import perf_counter

from pydantic import Field

from app.rag.schemas import Contract, DiseaseLabel, KnowledgeType, RetrievalRequest
from app.rag.service import RetrievalService, retrieval_identity


class EvaluationCase(Contract):
    id: str
    query: str
    disease_label: DiseaseLabel = Field(alias="diseaseLabel")
    knowledge_type: KnowledgeType = Field(alias="knowledgeType")
    expected_document_keys: list[str] = Field(alias="expectedDocumentKeys")
    expected_empty: bool = Field(alias="expectedEmpty")


class EvaluationSet(Contract):
    version: str
    corpus_version: str = Field(alias="corpusVersion")
    description: str
    cases: list[EvaluationCase] = Field(min_length=1, max_length=100)


def evaluate(service: RetrievalService, cases: EvaluationSet) -> dict[str, object]:
    observations: list[dict[str, object]] = []
    times: list[float] = []
    totals = {
        "filtered": {"hits": 0, "positiveCases": 0, "emptyPasses": 0, "emptyCases": 0},
        "semanticUnfiltered": {"hits": 0, "positiveCases": 0},
    }
    # Unfiltered ranking is measured separately: disease+section filters can
    # reduce a query to a single candidate and do not demonstrate semantic quality.
    for case in cases.cases:
        for mode in ("filtered", "semanticUnfiltered"):
            if case.expected_empty and mode == "semanticUnfiltered":
                continue
            query = RetrievalRequest(
                query=case.query,
                disease_label=case.disease_label if mode == "filtered" else None,
                knowledge_type=case.knowledge_type if mode == "filtered" else None,
                top_k=3,
            )
            started = perf_counter()
            result = service.retrieve(query)
            duration = (perf_counter() - started) * 1000
            times.append(duration)
            keys = list(dict.fromkeys(chunk.document_key for chunk in result.chunks))
            hit = bool(set(keys) & set(case.expected_document_keys))
            if case.expected_empty:
                totals[mode]["emptyCases"] += 1
                totals[mode]["emptyPasses"] += int(not keys)
            else:
                totals[mode]["positiveCases"] += 1
                totals[mode]["hits"] += int(hit)
            observations.append(
                {
                    "id": case.id,
                    "mode": mode,
                    "retrievedKeys": keys,
                    "hitAt3": hit,
                    "expectedEmpty": case.expected_empty,
                    "empty": not keys,
                    "durationMs": round(duration, 2),
                }
            )
    return {
        "evaluationVersion": cases.version,
        "corpusVersion": cases.corpus_version,
        "retrievalIdentity": retrieval_identity(service.settings),
        "embeddingModel": service.settings.embedding_model,
        "embeddingVersion": service.settings.embedding_version,
        "dimensions": service.settings.embedding_dimensions,
        "totals": totals,
        "meanDurationMs": round(mean(times), 2),
        "cases": observations,
        "limitations": (
            "Small curated development queries; filtered hits are not independent semantic "
            "validation. No generation/field validation or calibrated relevance cutoff."
        ),
    }
