"""Conservative English maize scope; no semantic score is treated as authorization."""

import re
from dataclasses import dataclass

from app.generation.context import INSTRUCTION_PATTERN
from app.generation.schemas import QuestionRequest
from app.rag.schemas import DiseaseLabel, KnowledgeType

ALIASES: dict[DiseaseLabel, tuple[str, ...]] = {
    "Common_Rust": ("common rust",),
    "Gray_Leaf_Spot": ("gray leaf spot", "grey leaf spot"),
    "Northern_Corn_Leaf_Blight": ("northern corn leaf blight",),
    "Healthy": ("healthy maize", "healthy corn"),
}
TOPICS: tuple[tuple[KnowledgeType, str], ...] = (
    ("MANAGEMENT", r"\b(treat\w*|manage\w*|control\w*|fungicide\w*)\b"),
    ("PREVENTION", r"\b(prevent\w*|precaution\w*|avoid\w*|resistan\w*)\b"),
    ("SYMPTOMS", r"\b(symptom\w*|lesion\w*|pustule\w*|spot\w*|look like|identify\w*)\b"),
    ("CAUSES", r"\b(cause\w*|fungus|fungi|pathogen\w*)\b"),
    ("CONDITIONS", r"\b(weather|condition\w*|humidity|favo[u]?r\w*)\b"),
    ("REFERENCES", r"\b(source\w*|reference\w*|citation\w*)\b"),
    ("OVERVIEW", r"\b(what is|what are|overview|describe|information|about)\b"),
)
UNSUPPORTED = re.compile(
    r"\b(dosage|dose|fertili[sz]\w*|yield|calculate|pesticide rate|kg|kilogram|"
    r"litre|liter|tomato|banana|potato|wheat|soybean|president|stock price)\b",
    re.I,
)


@dataclass(frozen=True)
class Scope:
    label: DiseaseLabel | None
    topic: KnowledgeType | None
    reason: str | None = None
    out_of_scope: bool = False


def resolve_scope(request: QuestionRequest) -> Scope:
    question = request.question.lower().replace("_", " ")
    if INSTRUCTION_PATTERN.search(question) or UNSUPPORTED.search(question):
        return Scope(None, None, "UNSUPPORTED_TOPIC", True)
    recognized = [
        label
        for label, aliases in ALIASES.items()
        if any(re.search(r"\b" + re.escape(alias) + r"\b", question) for alias in aliases)
    ]
    if len(recognized) > 1 or (
        request.disease_label and recognized and recognized[0] != request.disease_label
    ):
        return Scope(None, None, "MISSING_SCOPE", True)
    label = request.disease_label or (recognized[0] if recognized else None)
    maize_scope = bool(recognized or re.search(r"\b(maize|corn)\b", question))
    if not maize_scope:
        return Scope(None, None, "MISSING_SCOPE", True)
    topic = request.knowledge_type
    if topic is None:
        topic_question = question
        for aliases in ALIASES.values():
            for alias in aliases:
                topic_question = re.sub(r"\b" + re.escape(alias) + r"\b", " ", topic_question)
        matched = [topic for topic, pattern in TOPICS if re.search(pattern, topic_question)]
        specific = [topic for topic in matched if topic != "OVERVIEW"]
        if len(specific) > 1:
            return Scope(label, None, "MULTIPLE_TOPICS")
        topic = next(iter(specific or matched), None)
    if label is None or topic is None:
        return Scope(label, topic, "MISSING_SCOPE")
    if label == "Healthy" and topic in {"CAUSES", "CONDITIONS", "MANAGEMENT"}:
        return Scope(label, topic, "NO_EVIDENCE")
    return Scope(label, topic)
