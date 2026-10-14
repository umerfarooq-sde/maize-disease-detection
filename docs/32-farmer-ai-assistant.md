# Phase 16 — farmer AI assistant

Implemented 2026-10-13; verified 2026-10-14 (Asia/Karachi). Flutter presents the Phase 14 retrieval and Phase 15
grounded-generation contracts as a scoped farmer assistant. It supports reviewed
maize disease questions and authorized scan explanations. Factual content remains
the server's verified knowledge excerpts with citations; Flutter adds presentation,
bounded conversation state and safe recovery, without changing the ML classifier.

## Entry points and domain

Open **Tools → Ask your assistant** at `/tools/assistant`. Questions are available
to guests and signed-in farmers. Suggested questions cover symptoms, management and
prevention. Optional condition/topic selectors provide explicit focus for short
follow-ups, such as “What are the symptoms?” with `Common_Rust` selected.

The four literal labels remain `Common_Rust`, `Gray_Leaf_Spot`, `Healthy` and
`Northern_Corn_Leaf_Blight`. Supported topics are overview, symptoms, causes,
favorable conditions, management, prevention and references, when reviewed knowledge
exists. Healthy has scouting context only; missing Healthy disease treatment/causes
are reported as insufficient information. Unsupported general questions, numerical
prescriptions and recognized instruction injection receive the existing honest scope
or evidence abstention, rather than an unrestricted chatbot response.

FastAPI now recognizes an explicitly validated disease-label filter as a maize-domain
hint. This enables focused follow-ups without requiring the user to repeat “maize”
in every question. It does not bypass unsupported-topic/instruction checks, conflicting
label checks, reviewed-context admission, provider abstention or source validation.
An explicit filter is not proof that a factual answer exists.

## MVVM and responsibilities

```text
AssistantView / reusable assistant widgets
  → route-local AssistantViewModel (Provider / ChangeNotifier)
  → AssistantRepository / ApiAssistantRepository
  → AssistantDatasource → shared ApiClient
  → Node generation route → controller → service
  → authenticated internal FastAPI → retrieval → reviewed context → Gemini
  → verified excerpts / citations → Node validation → typed Flutter answer
```

Widgets render state and dispatch intent. Only the draft controller and scrolling
remain local UI state. The ViewModel coordinates turns, loading, retries, selected
scope and scan context; no widget makes HTTP calls. The app provides the repository
dependency globally, while conversation state is created only for the assistant route.

Important files:

```text
mobile/lib/data/
  models/assistant_answer.dart       strict immutable response/evidence/provenance
  models/assistant_question.dart     shared Unicode/UTF-8 input validation
  datasources/assistant_datasource.dart
  repositories/assistant_repository.dart
mobile/lib/features/ai_assistant/
  view_models/assistant_view_model.dart
  views/assistant_view.dart
  views/assistant_scan_picker.dart
  widgets/assistant_answer_card.dart
  widgets/assistant_source_card.dart
  widgets/assistant_turn_card.dart
  widgets/assistant_scan_context.dart
  widgets/assistant_composer.dart
  widgets/assistant_empty_state.dart
```

The answer parser rejects unknown fields/statuses, unsupported policy versions,
malformed source provenance, missing/duplicate/unresolved citations, nonfinite values
and suppressed low-confidence warnings. Lists and nested evidence/reference data are
immutable. A general question cannot return classifier context, and a scan explanation
must preserve all seven fields of the original typed prediction.

## Conversation and privacy

The screen retains at most **12 turns**, including failures. Older turns are removed
from local memory; no full chat transcript, prior answer text or private conversation
is submitted with subsequent requests. Follow-ups send the current question and only
the explicitly selected disease/topic filters. The assistant does not infer hidden
conversation history or summarize previous messages.

There is no conversation database write, new table/migration or persistent chat
storage. Existing `ai_queries`/`ai_responses` tables remain unused by this baseline.
Guests' questions are not stored under an account. Signed-in farmers' conversation
turns are likewise temporary; their existing owned scan history is separate.

Closing/popping the assistant route disposes its ViewModel and draft controller.
**Clear conversation** also clears scope/scan selection and may be used while a
request is pending. The generation fence prevents a delayed reply from restoring
cleared turns; clearing does not promise cancellation of an already running provider
worker. Switching bottom-navigation tabs can retain the mounted tool route in the
existing indexed shell; use Clear or close the assistant to discard it.

Route state is keyed by the farmer identity revision. Sign-in, sign-out or account
change remounts the assistant and removes the previous draft/turns/scan context.
Stale route extras are ignored, and the shared API client discards responses from a
previous session. Operational backend/AI logging retains metadata rather than private
questions, prompts, credentials or scan capabilities, as defined in Phase 15.

## Questions and network contract

Flutter calls only the configured Node `API_BASE_URL`. It sends:

| Operation | Node request |
|---|---|
| Question | `POST /api/v1/knowledge/ask`, `{question, diseaseLabel?, knowledgeType?}` |
| Farmer scan explanation | `POST /api/v1/scans/:scanId/explanation`, `{}` with access-token authentication |

Questions are trimmed and validated at **3–1,000 Unicode code points** and at most
**1,800 UTF-8 bytes**. C0 controls except newline/tab and malformed surrogate input
are rejected. Client validation is shared by the ViewModel and datasource; Node and
FastAPI remain authoritative and reject unexpected body/query fields. No arbitrary
context text, image URL, source URL, user ID or client prediction is accepted.

Assistant requests use a **40-second whole-call client deadline**, allowing the
existing Node **30-second** generation deadline to return its safe error. The shared
client's ordinary 15-second deadline and 90-second image-upload deadline remain
unchanged. Assistant-specific 504 errors become a clear timeout; 502 errors become
invalid-response feedback. Network, 401/403/404, rate-limit and provider failures use
safe application messages. No raw provider exception or internal URL is displayed.

The response remains the single Node `{success, data, requestId}` envelope. The UI
handles `GROUNDED`, `INSUFFICIENT_INFORMATION`, `OUT_OF_SCOPE` and
`CONFLICTING_EVIDENCE` as distinct results. HTTP/provider failures are retryable errors,
not invented answers. Retrying the latest failed turn reuses its frozen question,
filters or selected scan instead of duplicating the turn.

## Private scan explanations

Signed-in farmers can select a completed scan from the private, paginated history
picker. A completed result/detail screen also opens the assistant with an explicit
scan navigation context bound to the current session revision. There is no manual
scan-ID input and no guest scan-explanation control in this phase.

The datasource requires an authenticated session, a valid UUID and compatible completed
prediction metadata before sending the scan ID and `{}`. Node independently reads the
persisted scan using the existing FARMER owner policy. A different farmer's scan is
404; a missing/invalid access token fails authentication. A scan identifier is never
treated as authorization. The underlying Phase 15 private-key guest API is preserved,
but Phase 16 guest UI supports questions only.

Node sends only its persisted seven-field classifier context to FastAPI. Neither the
scan image/Cloudinary URL nor the caller's proposed prediction is sent to Gemini.
Returned label, score, model/preprocessing versions and uncertainty must match the
selected prediction exactly. Explanations do not rerun inference or mutate the scan.

The UI separates **Model prediction / Model score** from cited knowledge. Current
predictions remain `LOW_CONFIDENCE` with `THRESHOLD_UNCONFIGURED` and a null cutoff,
even at a high numerical score. The assistant displays the uncertainty warning and
educational/local-expert boundary; it does not call this a confirmed diagnosis.

## Presentation and recovery

Reusable widgets use the existing typography, spacing, colors, radii and responsive
utilities. The screen includes suggested-question empty state, question/answer cards,
visible progress, validation errors, safe failure/retry controls and Clear conversation.
Duplicate submissions and focus changes are disabled while a request is active.

Reviewed paragraphs and reference URLs use plain `SelectableText`, not interpreted
HTML/Markdown or executable links. Reference cards show evidence ID, title, publisher,
authors, known publication date, source-check date and rights. Citation IDs connect
each factual item to its returned references. No URL launcher dependency or automatic
external browsing is introduced. Scrolling/safe areas support the keyboard, long
text, narrow phones and increased text scale; local widget tests exercise these cases.

## Setup and verification

Use the existing [Phase 14 knowledge setup](30-knowledge-retrieval.md) and
[Phase 15 server-only generation configuration](31-grounded-generation.md). Flutter
needs only the public Node URL; provider keys, service tokens and model names stay
in backend/AI configuration. No new mobile environment secret or dependency is added.
Service readiness at startup does not guarantee an upstream provider call will succeed.

```powershell
# From mobile/:
dart format lib test
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1

# From the repository root, after backend build and configured FastAPI startup:
node --env-file=backend/.env scripts/check-assistant.mjs
```

The opt-in live check runs `mobile/test/integration/assistant_test.dart` through a
temporary Node server using real configured PostgreSQL/FastAPI/retrieval/Google.
It creates only two throwaway accounts and a synthetic persisted scan/prediction;
these exercise authorization and explanation, not ML accuracy or image upload.
Only those fixture rows are removed afterwards. No source dataset or Cloudinary
asset is used. The harness passes the child Flutter process only system tooling
settings and its disposable credentials, not backend/provider secrets.

Focused verification covers 36 model/repository tests, 10 ViewModel tests, 15 widget
tests, three navigation/privacy/pagination tests and the shared request-timeout regression.
Coverage includes normal questions, deliberate unsupported/missing/conflicting evidence,
provider failure, injection handling, Unicode/long input, citations, low confidence,
scan ownership contracts, retry, clear/dispose fences and account/draft isolation.
Complete regression and live results are recorded in [project state](PROJECT_STATE.md).

Final verification passes 175 isolated Flutter tests, 202 backend tests and 325 AI
tests, with analyzer/formatting/lint/type/build checks. The four Flutter and three
AI database opt-in tests default-skip; the assistant live contract is separately
enabled and passes through actual Node/FastAPI/Google/PostgreSQL. Initial Gemini
503 responses recovered on October 14; the successful run uses the original model.
[Saved metadata-only evidence](../ai-service/evaluation/results/farmer-assistant-contract-v1-20261014.json)
records six outcomes/three provider calls and clean fixture/lifespan cleanup. Synthetic
persisted scan scores test authorization and parity, not classifier or field accuracy.

## Limits and phase boundary

The small curated English corpus and Phase 15 scope/review limitations remain.
Independent/local agronomic review, broader retrieval evaluation and source freshness
are pending; lexical injection/scope checks are not comprehensive semantic safety.
Network/provider outages produce safe errors. This phase adds neither chat retention
nor local-language support, offline factual generation, calculators, full admin tools,
new knowledge ingestion or changes to approved ML artifacts. Stop after Phase 16.
