"""Offline local-file admission and immutable review checksum verification."""

import json
from pathlib import Path

from app.rag.chunking import content_hash
from app.rag.schemas import Corpus


def read_json(path: Path, *, max_bytes: int = 2 * 1024 * 1024) -> object:
    with path.open("rb") as stream:
        payload = stream.read(max_bytes + 1)
    if len(payload) > max_bytes:
        raise ValueError("Local knowledge file exceeds the size limit")

    def unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("Duplicate JSON keys are not allowed")
            result[key] = value
        return result

    return json.loads(payload.decode("utf-8"), object_pairs_hook=unique_object)


def load_corpus(path: Path, review_path: Path) -> Corpus:
    raw = read_json(path)
    review = read_json(review_path)
    canonical = json.dumps(raw, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    if (
        not isinstance(review, dict)
        or review.get("canonicalCorpusSha256") != content_hash(canonical)
        or review.get("reviewStatus") != "INTENTIONALLY_CURATED_AUTHORITATIVE"
    ):
        raise ValueError("Knowledge review ledger does not match the corpus")
    corpus = Corpus.model_validate(raw)
    if review.get("version") != corpus.version:
        raise ValueError("Knowledge review version does not match")
    for document in corpus.documents:
        if (
            document.metadata.get("review") != "INTENTIONALLY_CURATED_AUTHORITATIVE"
            or document.metadata.get("language") != "en"
        ):
            raise ValueError("Documents need explicit reviewed English provenance")
    return corpus
