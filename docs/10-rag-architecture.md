# RAG Architecture

> **Status:** Phase 14 implements sourced/versioned knowledge, configured Google embeddings and PostgreSQL/pgvector retrieval. Phase 15 adds bounded reviewed context, official Gemini SDK evidence selection and server-verified corpus excerpts with citations. Read [knowledge/retrieval](30-knowledge-retrieval.md) and [grounded generation](31-grounded-generation.md) for contracts, sources, setup and limitations.

## Grounding flow

```text
Reviewed agricultural knowledge
  -> source document and provenance
  -> chunking
  -> embedding
  -> indexed storage / vector retrieval
  -> relevance filtering
  -> grounded context
  -> Gemini evidence selection
  -> verified reviewed-corpus excerpts and source citations
  -> response with evidence or insufficient-information state
```

Use PostgreSQL with `pgvector` where appropriate and operationally supported. The exact embedding model, dimensions, distance metric, chunking strategy, and index must be selected together and versioned.

## Knowledge quality

Maintain curated and attributable sources with metadata such as title, publisher/author, publication or review date, language, topic, and review status. Track document and chunk versions. Define who may add, edit, approve, and retire knowledge. Do not treat arbitrary user input or model-generated text as authoritative corpus content.

## Retrieval and generation

Retrieve only relevant material, apply appropriate filters, and retain source references for the response. Pass clear instructions that generation must remain within provided evidence. If evidence is missing, conflicting, or below a validated relevance criterion, report that the system cannot provide a grounded answer and direct the user to an appropriate expert/source.

The current baseline has no calibrated retrieval cutoff. It instead admits pinned,
reviewed content with complete retrieved coverage, scoped disease/topic filters and
honest abstention. General questions support one known English label/topic; scan
explanations preserve the trusted model result and uncertainty separately. Gemini
returns a structured status/evidence selection; arbitrary factual paraphrases are
not published. Exact excerpt/citation checks do not establish local agronomic truth
or comprehensive semantic relevance and injection safety.

Do not rely on Gemini for deterministic fertilizer or yield arithmetic. A deterministic calculator should produce numerical results; retrieved knowledge and Gemini may explain those results.

## Evaluation

Evaluate retrieval relevance/recall on a reviewed query set and answer faithfulness, citation correctness, language quality, and insufficient-evidence behavior. Include adversarial and out-of-domain questions. Re-run evaluations when corpus, chunking, embedding, retrieval, or prompt versions change.

## Privacy and operations

Minimize personal or image data sent to the language-model provider. Protect provider credentials server-side. Log retrieval identifiers and version metadata rather than full sensitive prompts or documents unless a controlled retention policy permits them.
