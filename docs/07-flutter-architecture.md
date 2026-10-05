# Flutter Architecture

> **Status:** Target mobile architecture; implementation details remain to be confirmed.

## Pattern

Use MVVM with Provider and `ChangeNotifier`, following:

```text
View -> ViewModel -> Repository -> API client -> Backend
```

Widgets render state and dispatch intent. ViewModels coordinate screen state and presentation logic. Repositories expose typed operations and isolate remote data sources. The API client owns serialization, headers, and transport behavior.

## Feature organization

Organize by feature where it fits existing conventions, for example:

```text
features/
  scan/
    view/
    view_model/
    repository/
    models/
  history/
  auth/
shared/
  api/
  widgets/
  theme/
```

This is illustrative; avoid creating layers that add no value to the current app.

## Scan experience

Make scanning the primary farmer action. Provide clear camera/gallery selection, upload/progress state, validation errors, retry behavior, and an accessible result view. Communicate model uncertainty and distinguish model prediction from knowledge-grounded recommendations. Do not present missing AI/RAG information as a confident factual answer.

## State and errors

Represent loading, success, empty, and failure states explicitly in ViewModels. Avoid unnecessary `setState` and do not perform network calls directly inside widgets. Prevent duplicate submissions while a request is active and ensure users can recover from transient failures without losing needed input.

## Authentication and privacy

Store tokens using platform-appropriate secure storage. Never embed backend, Cloudinary, or Gemini secrets in the app. Avoid persisting sensitive image data or tokens in logs. Clear session-specific state on sign-out and apply server-side authorization regardless of client navigation.

## Accessibility and UX

Use readable typography, strong contrast, localized and plain-language labels, large touch targets, and layouts that adapt to device size. Include semantics for controls and meaningful progress/error announcements. Preserve offline/error feedback even when server-side scan analysis requires connectivity.

## Tests

Test ViewModels and repositories independently, including loading/error transitions, anonymous scan submission, authenticated history access, and serialization. Add widget tests for high-value flows and accessibility-sensitive states.
