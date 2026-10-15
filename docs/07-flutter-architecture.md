# Flutter Architecture

> **Status:** Phase 16 adds the scoped farmer assistant with cited reviewed answers,
> bounded local conversation and private scan explanations. Phase 13 completes selection/preview/upload, real model results,
> minimal farmer sign-in/logout and private paginated history. See
> [farmer workflow](29-farmer-detection-history.md), [foundation](19-flutter-foundation.md)
> [farmer assistant](32-farmer-ai-assistant.md) and [uploads](20-scan-uploads.md).
> Fertilizer/yield frameworks, farmer analytics and Admin dashboard/management/model
> health are now wired to Node repositories. Full farmer knowledge browsing and
> registration UI remain missing; approved calculator content remains pending. Read
> the [Phase 23.5 audit](phase-23-5-completeness-audit.md) for the current inventory.

## Pattern

Use MVVM with Provider and `ChangeNotifier`, following:

```text
View -> ViewModel -> Repository -> API client -> Backend
```

Widgets render state and dispatch intent. ViewModels coordinate screen state and presentation logic. Repositories expose typed operations and isolate remote data sources. The API client owns serialization, headers, and transport behavior.

## Feature organization

The current implementation uses:

```text
core/               constants, theme, routes, network, storage contract, errors, responsive utilities, widgets
data/               typed models, remote datasources, repository interfaces/implementations
features/
  home/             views and scoped ChangeNotifier ViewModel
  shell/            farmer navigation shell
  tools/            tool navigation hub
  auth/             farmer sign-in and app identity ChangeNotifier
  disease_detection/
  disease_knowledge/
  ai_assistant/
  fertilizer_calculator/
  yield_calculator/
  scan_history/
  analytics/
  profile/
  admin/            separate Admin session, dashboard, management and model health
```

Home, Scan, Result, History and Assistant have concrete scoped ViewModels, repositories and
datasources. Home calls the Node health API on intent; Scan uploads to the real
inference API. Result and History read only the public owned/private-key Node
contracts. Farmer identity is app-scoped; route state is keyed by identity revision
and late previous-session responses are discarded. Calculators, analytics and Admin
features have concrete scoped state/repositories; Knowledge retains its foundation view. Add
ViewModels/models/repositories when their workflows exist; do not create empty layers.

## Scan experience

Make scanning the primary farmer action. Provide clear camera/gallery selection, upload/progress state, validation errors, retry behavior, and an accessible result view. Communicate model uncertainty and distinguish model prediction from knowledge-grounded recommendations. Do not present missing AI/RAG information as a confident factual answer.

## Farmer assistant

The route-local `AssistantViewModel` owns at most 12 temporary turns, selected condition/
topic and an optional explicit completed scan. The globally provided repository is
a dependency, not shared chat state. `AssistantDatasource` sends only the current
question plus enum filters, or the owned scan ID with an empty explanation body;
widgets never call HTTP, FastAPI or Gemini. Node verifies scan ownership and obtains
its persisted classifier context before invoking the internal AI service.

No chat transcript or conversation database write is introduced. Closing the route,
clearing conversation or changing identity discards state; the indexed tab shell may
keep the mounted route alive until closed. Identity-revision keys and generation
fences prevent stale account or cleared-request data from reappearing. Strict immutable
models validate sources/citations and preserve the scan's seven classifier fields.
Plain selectable source URLs and reviewed evidence remain distinct from model scores
and low-confidence warnings. See [Phase 16 contracts](32-farmer-ai-assistant.md).

## State and errors

Represent loading, success, empty, and failure states explicitly in ViewModels. Avoid unnecessary `setState` and do not perform network calls directly inside widgets. Prevent duplicate submissions while a request is active and ensure users can recover from transient failures without losing needed input.

## Authentication and privacy

Current native sign-in keeps access credentials and the restricted refresh cookie
only in app memory; app restart requires sign-in. Persistent sessions must use
platform-appropriate secure storage in a separately authorized change. Never embed
backend, Cloudinary or Gemini secrets. No credentials/images are written to logs.
Clear session-specific state on sign-out and enforce authorization on the server.

## Accessibility and UX

Use readable typography, strong contrast, localized and plain-language labels, large touch targets, and layouts that adapt to device size. Include semantics for controls and meaningful progress/error announcements. Preserve offline/error feedback even when server-side scan analysis requires connectivity.

## Tests

Test ViewModels and repositories independently, including loading/error transitions, anonymous scan submission, authenticated history access, and serialization. Assistant tests cover source/citation validation, scope/abstention, provider failure, bounded input/turns, authorized scan explanation, retries and session privacy. Add widget tests for high-value flows and accessibility-sensitive states.
