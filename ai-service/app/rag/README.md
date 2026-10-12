# Retrieval and generation boundary

Phase 14 implements deterministic chunking, Google text embeddings, immutable
PostgreSQL/pgvector publication, filtered exact cosine retrieval and evaluation.
The controlled CLI verifies a local reviewed corpus/ledger before ingestion.
The internal API returns evidence candidates with original sources and versions.
No answer generation or numerical calculation occurs here. See
[the contracts and operations guide](../../../docs/30-knowledge-retrieval.md).
