# Phase 14 — sourced knowledge and retrieval

Implemented 2026-10-12. No answer generation or Flutter knowledge content is added.
This document records the Phase 14 boundary. Phase 15 subsequently adds
[grounded Gemini generation](31-grounded-generation.md) above these preserved
retrieval/ingestion contracts.
The skipped Phase 6 database/backend foundation was inspected: disease, source,
document and chunk tables existed but were empty, with no knowledge APIs or ingestion.
This phase completes the foundations needed for retrieval using those same tables.

Phase 23.6 subsequently connects the farmer Knowledge tab to the preserved catalogue,
detail and semantic-search contracts. See [Flutter library](40-farmer-registration-knowledge.md)
and [remediation evidence](phase-23-6-remediation-report.md). Search returns passages,
not generated answers; no corpus or embedding policy change accompanies that UI.

## Flow and endpoints

`Flutter -> Node route/controller/service -> knowledge repository/Prisma -> PostgreSQL`
serves the disease catalogue. Semantic search follows
`Flutter -> Node route/controller/service -> internal FastAPI -> Google embedding -> pgvector`.
Flutter never receives service/provider credentials or calls FastAPI directly.

- `GET /api/v1/diseases`: active summaries (`data.items`).
- `GET /api/v1/diseases/:slug`: active English disease sections, document identity/version,
  original content and complete attributable source. Unknown/inactive diseases return 404.
- `POST /api/v1/knowledge/search`: public bounded, rate-limited semantic retrieval.
- FastAPI `POST /api/v1/retrieve`: internal equivalent; existing Bearer service token required.
- `GET /health`: RAG capability is `ready` only after configured retrieval startup;
  generation remains `not_implemented`. Classifier readiness is independent.

Search JSON accepts `query` (3–1,000 Unicode code points after trimming, at most
1,800 UTF-8 bytes; no C0 controls except tab/newline), optional `diseaseLabel`,
`knowledgeType`, positive `documentVersion`, and `topK` (1–10, default 3).
Unknown fields and invalid Unicode are rejected. Literal labels remain
`Common_Rust`, `Gray_Leaf_Spot`, `Healthy`, `Northern_Corn_Leaf_Blight`.
Topics: `OVERVIEW`, `SYMPTOMS`, `CAUSES`, `CONDITIONS`, `MANAGEMENT`, `PREVENTION`, `REFERENCES`.
No arbitrary URL, image or document ingestion is accepted through these routes.

Node responses use one `{success, data, requestId}` envelope; internal FastAPI uses
`{success, data, meta: {requestId}}`. Node unwraps the internal envelope before using
its standard public format. Search data contains
`status: MATCHES | NO_MATCHES`, `chunks`, `embeddingModel`, `embeddingVersion`,
`embeddingDimensions`, `retrievalVersion: cosine-exact-v1`, and
`evidencePolicy: CANDIDATES_ONLY`. Each chunk retains document ID/key/version,
chunk ID/index/content/title, literal disease label, topic, original source,
cosine `similarity` and allowlisted provenance/lineage metadata.
The score is a ranking value in [-1,1], not a probability or calibrated evidence confidence.
`MATCHES` means candidates exist, not that a generated answer is justified.
No relevance cutoff is claimed validated, and no answers are generated.

Internal JSON is limited to 8 KiB before buffer copying, with a five-second upload
deadline and configured concurrency (default 4). Node validates the returned contract,
requested filters, rank order, unique chunk identities and result count. Its entire
request/response deadline uses `AI_SERVICE_TIMEOUT_MS` (default 10 seconds; max 20),
response is capped at 128 KiB, redirects are rejected, and private metadata is stripped.
Routed knowledge responses use no-store; global parsing/CORS/rate failures follow
the existing centralized backend policy. Public search has its own per-IP limit plus the existing
global limiter. Provider/DB failures return safe 503, malformed responses 502, Node
deadline failures 504; no provider text, internal origins, keys or stack traces escape.

## Corpus and provenance

[The curated corpus](../backend/knowledge/README.md) contains 25 independently worded
documents and four disease/label catalogue entries. Sources are three University of
Minnesota Extension disease pages and Iowa State Extension's early-season scouting page.
Each document stores source URL/title/publisher/authors, known review date,
retrieval date, unknown publication date as null, rights and U.S. regional scope.
The review ledger pins canonical corpus/content/provenance SHA-256 identities.
Publisher images/HTML/full-page text are not redistributed; unavailable publisher-file
hashes are explicitly null. No open licence, publisher endorsement or independent
agronomist approval is inferred. Minnesota pages were reviewed in 2018: freshness and
regional/local agronomic review remain limitations.

Seven sections exist for each actual disease. Healthy supplies overview/scouting
concerns/prevention/references only. Healthy cause, favorable disease conditions and
treatment are intentionally absent; no synthetic recommendations fill these gaps.
There are no pesticide rates or model-generated facts in the corpus.

## Storage, versions and chunking

The seventh additive migration extends existing knowledge tables with nullable
`KnowledgeType` for honest legacy compatibility, JSON metadata and embedding version.
JSON objects, embedding dimensions/status/version and content SHA-256 are enforced.
Existing one-active-version uniqueness and immutable content/provenance remain;
READY vectors cannot be replaced. An eighth corrective migration compares canonical
vector text in the guard so restricted schemas need no public operator fallback.
No tables are added and six old migrations are unchanged.
Disease catalogue/source records support future controlled admin management. The current
operator CLI is the only ingestion mechanism; no full admin editing UI/API is introduced.

Chunker `unicode-char-window-v1` canonicalizes NFC and line endings, trims outer
whitespace and uses deterministic character windows: default 1,000 characters with
120-character overlap. Configuration is explicit and hashed with provider/model/version,
dimensions, L2 normalization, task protocol and retrieval version. Documents record the
complete chunk/embedding configuration, corpus attribution and source. Chunks record
exact canonical-content offsets and hashes. Token count remains null rather than
misrepresenting character or word counts as provider tokens. Embedding admission caps
combined content/title UTF-8 bytes at 1,800 to avoid provider truncation; larger Unicode
chunks must use smaller configured windows. The initial short sections each produce one chunk.

Ingestion verifies the local review ledger and bounded JSON, precomputes all embeddings
before writing, then publishes in one transaction under an advisory lock. Failure leaves
old active versions intact. Identical re-ingestion skips embeddings and preserves IDs.
Changed same-version content/source/config is a conflict. Higher versions archive the
old document without deleting its chunks or provenance. Older archived versions cannot
be resurrected by rerunning ingestion. Unchanged document versions may be carried into
a later corpus release while retaining original attribution. Catalogue identity changes
require deliberate maintenance rather than being silently overwritten by ingestion.

Only active English DISEASE documents linked to active catalogue entries and READY
vectors with the exact runtime model/version/dimensions/config identity are searched.
Optional filters cannot retrieve inactive historical versions. Parameterized SQL uses
exact cosine pgvector search, with stable key/chunk tie order. With 25 chunks no approximate
index is justified; the existing relation/status indexes plus disease/status/topic index
are sufficient. ANN indexing must follow actual corpus growth and measurements.

## Configuration and commands

Google/Gemini embeddings were explicitly approved by the user. The initial text-only
selection is `gemini-embedding-001`, explicit deployment version
`google-task-v1-20261012`, 768 dimensions and L2 normalization. Model names have no
source-code fallback. [Google's guide](https://ai.google.dev/gemini-api/docs/embeddings)
documents retrieval task types, available text-only model and normalization for reduced
dimensions. The [API reference](https://ai.google.dev/api/embeddings) documents the
task/output/title fields. Live validation pins the flat task-field embedContent protocol:
the endpoint ignored nested `embedContentConfig` and returned 3,072 values; flat fields
returned the requested 768. Wrong dimensions fail closed; there is no automatic fallback.

Populate ignored `ai-service/.env`: `RAG_ENABLED=true`, `DATABASE_URL`,
`GEMINI_API_KEY`, `AI_SERVICE_TOKEN`, `EMBEDDING_MODEL`, `EMBEDDING_VERSION`,
`EMBEDDING_DIMENSIONS`, `EMBEDDING_TIMEOUT_SECONDS`, `RAG_CHUNK_CHARS`,
`RAG_CHUNK_OVERLAP`, `RAG_MAX_CONCURRENCY`. The template leaves keys/model/version blank
and disables retrieval until explicitly configured. PostgreSQL must be the same project
database migrated by Node. Private local AI settings were corrected from an unrelated
unmigrated local database; connection values are never committed.

HTTPX and psycopg are locked runtime dependencies. TLS hostname verification stays
enabled; certifi supplies public roots for libpq on Windows. Transaction-local settings
support Neon without unsupported startup options, enforce SQL/idle timeouts and restrict
search path to the selected schema so missing schemas cannot fall back to public.
API work uses bounded threads/connections; Google clients close on lifespan shutdown.
Production should provision separate read-only retrieval and controlled ingestion roles;
local development currently reuses existing project credentials.

From `backend/` run `npm run db:migrate`. From `ai-service/`:

```powershell
.venv/Scripts/python.exe -m app.rag.cli check --corpus ../backend/knowledge/maize-extension-20261012-v1.json --review ../backend/knowledge/maize-extension-20261012-v1.review.json
.venv/Scripts/python.exe -m app.rag.cli ingest --corpus ../backend/knowledge/maize-extension-20261012-v1.json --review ../backend/knowledge/maize-extension-20261012-v1.review.json
.venv/Scripts/python.exe -m app.rag.cli evaluate --cases evaluation/rag-v1.json --output evaluation/results/new-version.json
.venv/Scripts/python.exe -m app.server
```

Evaluation output uses exclusive creation: previous runs cannot be overwritten. Ingestion
never fetches source URLs. Only intentionally reviewed local corpus/review pairs should be
passed by an authorized operator. Model/image preprocessing and the raw dataset are unchanged.

## Verification and remaining limits

[Saved real-provider evaluation](../ai-service/evaluation/results/maize-extension-v1-google-task-v1-20261012.json):
16/16 positive expected-document hits at top 3 with disease/topic filters; independently
measured 16/16 across all 25 chunks without those filters; 3/3 Healthy unavailable-topic
cases return empty. Mean embedding-plus-database retrieval was 3,899.32 ms locally.
This small curated development set measures engineering relevance, not field accuracy,
independent agronomic usefulness, out-of-domain rejection or answer faithfulness.

Backend isolated tests, real PostgreSQL constraints/migration replay, AI isolated tests,
real versioned pgvector checks, shared preprocessing and unchanged Flutter regression
checks are recorded in [PROJECT_STATE](PROJECT_STATE.md). A real owned lifespan verifies
Node -> FastAPI -> Google -> PostgreSQL for all four labels and absent Healthy management;
unauthenticated internal calls fail. The unchanged classifier predicts a generated image
in the same lifespan and startup/shutdown each occur once. No raw dataset partition is read.

Remaining work: local agronomic/source-freshness review, larger independent/out-of-domain
retrieval evaluation, calibrated relevance/insufficient-evidence policy before generation,
least-privilege production credentials and operational hosting/shared rate-limit storage.
Gemini answer generation, Flutter knowledge UI and full admin editing remain future phases.

## Phase 24.7 diagnostic and gallery lifecycle addendum

Current stabilization evidence is in [Phase 24.7](phase-24-7-integration-stability.md).
Repository errors now retain a safe connection/setup/query/commit stage, SQLSTATE,
bounded elapsed time and request correlation without dependency messages or SQL
parameters. An unavailable result alone is not evidence of a provider outage.
Connection budgets, parameterized retrieval, TLS and source/version filters are
unchanged. The missing-schema live test requires actual PostgreSQL `42P01` rather
than accepting an unrelated transport failure as a successful isolation check.

Reference-gallery state now leaves loading after an account revision changes,
discards stale content/selections and permits an explicit fresh read. Stale Admin
mutations are rejected locally and remain subject to server RBAC/review/revisions.
No write is automatically retried. Disposal suppresses late results/notifications.
Controlled tests distinguish API and DTO failures and verify optional reviewed
metadata, attribution, long text and retry. Actual acceptance outcomes remain in
the linked phase report; no new agricultural facts or media are published here.
