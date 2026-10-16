# Admin management — Phase 21

**Phase24.6 current addendum (2026-10-17):** Informational disease creation/optional sourced stage/severity, complete reference-media review/publication/gallery lifecycle, independent fertilizer product metadata and disabled richer-model review intake are connected. The four classifier mappings are immutable. Rights/content approval remains mandatory.

See [remediation and current evidence](phase-24-6-pre-deployment-remediation.md). Historical phase details follow.

**Later Phase 23.7 extension:** the original-required farmer account list/status
management and read-only audit viewer are now implemented outside the knowledge
editor, using the same ADMIN session/RBAC. No arbitrary privilege changes or audit
mutations are exposed. Licensed disease-reference media is still pending. See
[accounts/audit/media boundaries](41-profile-accounts-audit.md) and the
[current original-requirement matrix](phase-23-7-requirements-completion.md).

The Admin workspace manages display metadata, reviewed knowledge versions and
source snapshots, plus immutable fertilizer/yield calculator drafts. Model class
mappings, trained artifacts and numerical calculator algorithms are not editable.
No agricultural fact, dosage, yield rate or commercial-use permission is invented.

## Knowledge lifecycle

1. An ADMIN supplies a document series key, fixed disease context/section, title,
   reviewed content, full source metadata, applicability/region, source section and
   a fresh source/applicability review note. Approval is explicit.
2. Node validates the input and expected base version. Internal FastAPI preparation
   applies the existing canonical-content function and records the configured
   chunker/embedding identity. No embedding/provider call is made by preparation.
3. Node atomically creates a new immutable DRAFT, source snapshot/catalogue record
   and CREATE audit events. The version is server-assigned as latest+1; stale bases
   and attempts to move a series to another disease/section conflict. Existing
   active knowledge remains the current version.
4. **Build embeddings** calls protected FastAPI indexing for the stored draft ID.
   The same chunker, Google embedder, normalization/vector validation and retrieval
   identity used by existing ingestion are reused. All vectors are prepared before
   a short locked transaction inserts READY chunks and an index audit event.
   Failure leaves the draft inactive and old active content untouched. A complete
   identical index is reused without duplicate rows/provider calls.
5. **Activate** requires confirmation and a fresh index check against the currently
   configured embedding/chunking policy. Node rechecks immutable document hash,
   identity, chunk count/readiness, latest version and disease visibility under the
   shared ingestion lock. One transaction archives the prior active version,
   changes source visibility, activates the new version and records audit lineage.
6. **Deactivate** archives the selected version after confirmation. Historical
   documents/chunks/source snapshots are retained. Archived versions cannot be
   casually reactivated; create a reviewed new version instead.

No content or READY embedding is rewritten in place. Changing the embedding model,
version, dimensions or chunking configuration requires a new document version and
rebuild. Old chunks remain immutable historical records; retrieval joins ACTIVE
documents and ACTIVE diseases and matches the current retrieval identity, so
archived vectors do not remain silently searchable. Drafts never become public or
searchable merely because indexing completes. A timed-out index may finish as a
ready **draft**; refresh/check and retry safely rather than publishing automatically.

Content is bounded to 4,000 characters for this reviewed-paragraph generation
baseline; chunking is limited to 32 chunks under configured windows. Preparation
accepts at most 32 KiB JSON; index/check identity bodies retain the normal 8 KiB
limit. Internal routes require the existing service token and bounded retrieval
capacity. No source URL is fetched. Obvious instruction-injection text is rejected
before embedding, and generation retains its separate evidence checks.

## Sources and grounded generation

Sources belong to immutable document versions: HTTPS URL without credentials,
title, publisher, authors, publication/retrieval dates and rights/use restrictions.
Editing source information means creating a new reviewed document version. Each
Admin draft has a source catalogue record linked by immutable metadata; source
activation/retirement is audited with the parent document. Existing shared source
records and historical citation snapshots are not rewritten. There is no separate
global source edit that silently changes old documents' attribution.

Original corpus versions still require their pinned reviewed-file identity. Newly
published Admin documents supplement that context only through a request-local
database lookup of current ACTIVE records with server-stamped creator/review,
current retrieval identity and an ACTIVATE audit event. The context builder still
verifies canonical content hash, complete chunk offsets/coverage, source equality,
literal class, knowledge type, curation metadata and injection/conflict policies.
It never overwrites an existing pinned identity or retains retired Admin versions
in a global mutable context cache. Missing/retired/untrusted evidence abstains.
Gemini still selects verified excerpts; it cannot silently change classifier output.
An authorized Admin's source review is a human trust boundary, not automatic proof
of agronomic correctness or legal clearance.

## Disease display metadata and classifier classes

The four supported classifier contexts/slugs remain fixed. Admin may change a
disease's display name, scientific name, display description and catalogue
ACTIVE/INACTIVE status. An optimistic revision hash covers mutable fields and
timestamp; stale edits return 409. The edit and previous/new revision identities
are audited. Hiding a disease hides its public catalogue entry and its retrieval
knowledge; it does not rename a model class, remove old predictions or retrain a
classifier. No classifier-class rename/delete/training endpoint is added.

## Calculator management

The existing Phase 17/18 calculator services and publication APIs are reused.
Admin lists now expose admitted draft input projections and created/updated times
for form prefilling. Creating a revision copies values into a **new** version,
requires fresh source review and leaves historical rule/configuration payloads
immutable. Activation/deactivation requires confirmation and server validation.
Publication audit events now also identify automatically retired rule/configuration
IDs and versions, so replacements are traceable without rewriting old results.

Fertilizer forms collect product information/composition/source, explicit product
kg/ha rate, rule/config versions, rounding and applicability/assumptions. A product
snapshot cannot change under an existing slug; revised product information needs
a new slug, preserving old rule snapshots. Yield forms collect the existing
approved-template kg/ha scenario/configuration fields. Rates start blank; no
default recommendation, arbitrary formula, ML class edit or Gemini arithmetic is
introduced. Sources, exact decimal bounds, N/P/K percentages, versions, precision
and activation admission remain authoritative on Node. Existing returned calculator
results retain their pinned IDs/versions; no new calculator-history store is added.

## Routes and access

All new Node routes require a live ADMIN session; guest/invalid/revoked sessions
receive 401 and FARMER receives 403 before validation/provider/database work.
They retain single response envelopes, no-store, JSON-only writes, bounded rate
limiting and safe centralized errors. Actor, request ID, timestamps and actual
next document version come from the server, never client-supplied impersonation.

| Node route | Purpose |
|---|---|
| `GET /api/v1/admin/knowledge/diseases` | Fixed class context plus editable display metadata/revision token |
| `PATCH /api/v1/admin/knowledge/diseases/:slug` | Audited optimistic display/visibility edit |
| `GET /api/v1/admin/knowledge/documents` | 50 version summaries, optional UUID cursor, nextCursor |
| `GET /api/v1/admin/knowledge/documents/:id` | Reviewed content/source/curation for a new-version form |
| `POST /api/v1/admin/knowledge/documents` | Create inactive immutable version/source snapshot |
| `POST /api/v1/admin/knowledge/documents/:id/index` | Explicit rebuild/check of stored draft chunks |
| `PATCH /api/v1/admin/knowledge/documents/:id/status` | Latest ready draft activation or archive, with expectedStatus |

Existing calculator Admin GET/POST/PATCH routes remain at
`/api/v1/admin/calculators/fertilizer/rules` and
`/api/v1/admin/calculators/yield/configurations` (status actions append `/:id/status`).
Their management lists show the latest 100 bounded stored versions.

FastAPI has internal POST `/api/v1/knowledge/prepare`, `/index` and `/check`.
Only Node calls them. Index/check use stored document/actor/request UUIDs, never
arbitrary URL fetching or client-provided vectors. The backend's new server-only
`KNOWLEDGE_INDEX_TIMEOUT_MS` defaults to 120,000 (1,000–120,000 permitted). Flutter
allows 150 seconds for explicit indexing/activation and shows safe timeout/retry.
No secret or provider configuration is exposed to Flutter.

## Flutter

Admin overview → settings icon → `/admin/manage` stays outside farmer navigation
and uses the separate Admin credential store. Management View → scoped ChangeNotifier
ViewModel → repository → Admin ApiClient → Node. Sections contain knowledge,
disease display metadata, fertilizer rules and yield rules. Forms use named fields,
fixed context selectors, field/source/date/decimal validation, explicit approval,
loading/errors, cursor pagination, confirmation and the existing design tokens.
There is no raw JSON editor, numerical calculation or HTTP call in a widget.
Account changes/disposal fence delayed reads and writes; draft form controllers
are removed with the Admin session. Retry refreshes state rather than silently
repeating publication. Narrow screens, keyboard insets and large text scroll.

## Verification and remaining boundaries

Run backend `npm run check`, Prisma validation/status, Flutter format/analyze/tests,
and AI Ruff format/lint, strict mypy and pytest using their existing environments.
The opt-in live contract is:

```powershell
# Root, after backend build; existing AI Google/Gemini settings must be configured.
ai-service/.venv/Scripts/python.exe scripts/check-admin-management.py
```

It creates only a generated, verified disposable schema, replays existing migrations,
starts private loopback FastAPI/Node, uses existing reviewed project source text
with real Google embeddings/Gemini, and verifies drafts/indexing/replacement,
retrieval exclusion, disease visibility/revisions, audit lineage, calculator
version controls and enabled Flutter management transport. Synthetic calculator
values are labelled protocol fixtures and never approve real agronomic rates.
The owned schema is dropped and production counts must remain unchanged.
No raw dataset, ML training/evaluation, classifier promotion or model overwrite
occurs. Final results are recorded in [project state](PROJECT_STATE.md).

Independent source freshness/local agronomic review and commercial licensing,
durable/browser Admin sessions, distributed rate limits and production workload
measurement remain existing requirements. Stop after Phase 21; detailed model
health and later deployment/security phases do not begin automatically.
