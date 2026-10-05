# RAG Architecture

> **Status:** Target knowledge-grounding design. Source corpus, embedding model, retrieval settings, and storage backend are open decisions.

## Grounding flow

```text
Reviewed agricultural knowledge
  -> source document and provenance
  -> chunking
  -> embedding
  -> indexed storage / vector retrieval
  -> relevance filtering
  -> grounded context
  -> Gemini explanation
  -> response with evidence or insufficient-information state
```

Use PostgreSQL with `pgvector` where appropriate and operationally supported. The exact embedding model, dimensions, distance metric, chunking strategy, and index must be selected together and versioned.

## Knowledge quality

Maintain curated and attributable sources with metadata such as title, publisher/author, publication or review date, language, topic, and review status. Track document and chunk versions. Define who may add, edit, approve, and retire knowledge. Do not treat arbitrary user input or model-generated text as authoritative corpus content.

## Retrieval and generation

Retrieve only relevant material, apply appropriate filters, and retain source references for the response. Pass clear instructions that generation must remain within provided evidence. If evidence is missing, conflicting, or below a validated relevance criterion, report that the system cannot provide a grounded answer and direct the user to an appropriate expert/source.

Do not rely on Gemini for deterministic fertilizer or yield arithmetic. A deterministic calculator should produce numerical results; retrieved knowledge and Gemini may explain those results.

## Evaluation

Evaluate retrieval relevance/recall on a reviewed query set and answer faithfulness, citation correctness, language quality, and insufficient-evidence behavior. Include adversarial and out-of-domain questions. Re-run evaluations when corpus, chunking, embedding, retrieval, or prompt versions change.

## Privacy and operations

Minimize personal or image data sent to the language-model provider. Protect provider credentials server-side. Log retrieval identifiers and version metadata rather than full sensitive prompts or documents unless a controlled retention policy permits them.
