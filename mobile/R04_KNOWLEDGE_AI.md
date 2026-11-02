# FIELD INTELLIGENCE — R-04

Knowledge Library, disease reading, Assistant conversation and protected reference
gallery presentation. Verified locally on 2026-11-02. Baseline: `main` at
`6cf1cbff9a8d927baacaf105f5c99883723dcecf`, with the existing uncommitted R-03
implementation. R-01/R-02 and all R-03 work remain intact; no commit/push is part
of R-04. R-05 and later releases have not started.

## Knowledge and navigation

- The existing `KnowledgeCatalogueCard` is refined and connected to the Library.
  Cards show actual names, descriptions and optional scientific names. Healthy is
  labelled as a scouting context, rather than a fungal disease. Narrow layouts
  stack; wider layouts can show two columns without fixed card heights.
- Explicit semantic search still calls the existing ViewModel/repository. Typing
  does not send requests. Editing invalidates old results through the existing
  revision fence; loading, validation, no matches and service failure remain
  distinct from catalogue loading/empty/unavailable states. There are no new
  filters, provider calls, DTO fields or hardcoded record counts.
- Disease detail uses the 720dp reading width. Available sections alone generate
  the contents chips. Tapping a chip scrolls to its actual document and marks that
  selection; it does not imply automatic scroll-position tracking. Anchors are
  pruned when documents change. Scientific text is rendered unchanged, selectable
  and with readable line height. Document versions, optional sourced metadata and
  Healthy's missing sections retain their original meaning.
- Existing `/knowledge/*`, `/assistant`, legacy Assistant redirect and five
  persistent navigation branches are unchanged.

## Assistant architecture and lifecycle

The screen has a compact header, an expanded conversation viewport and a separate
pinned multiline composer. The existing shell's Scaffold handles keyboard
resizing. The composer remains outside conversation scrolling; Enter inserts a
line break and the accessible Send action submits. Full validation feedback is
placed in the scrollable conversation immediately above the composer, retaining
the draft and avoiding keyboard/large-text overflow.

`AssistantFocusPanel` presents only existing condition/topic filters and privacy
information in a scrollable sheet with a pinned Close action. Controls reuse
`AppField` and the existing selection methods. The selected focus is shown in the
conversation. Clear uses the existing confirmation dialog and can invalidate a
pending request through the unchanged ViewModel generation fence.

The existing Assistant ViewModel, datasource and repository are unchanged:

- At most 12 temporary local turns; no transcript persistence or full-history
  requests. Only the current question and supported explicit scope are sent.
- Guest questions remain allowed. Saved-scan explanations require the existing
  authenticated ownership checks.
- The R-02 identity-keyed Provider and once-only handoff remain in place. Ordinary
  tab changes retain draft, conversation and scroll controller. Account changes
  dispose that state and reject late replies.
- No simulated streaming, thinking transcript, invented provider-error category
  or new request/retry semantics.

Conversation content remains mounted within its bounded 12-turn scroll region,
preserving selectable text, source anchors and the selected thumbnail. Draft edits
do not rebuild the conversation. Explicit submission moves to the latest message.
Replies follow only when the reader remains near the bottom; otherwise an
explicit Latest response action appears. Scroll work is coalesced per frame and
uses the R-01 navigation duration, or a direct jump for reduced motion. Controllers
are disposed with the route state.

## Scan selection and context

The existing authenticated paginated History ViewModel still supplies only owned,
completed scans with predictions. Compact tiles show real dates, model output and
protected thumbnails, with a selected indicator. Guest requests remain blocked.
The selected scan ID is passed to the picker for presentation only; no request
payload changes. The context card keeps its explicit Explain/Remove controls and
uncertainty label. Repeated handoffs, pending-response replacement, logout and
offstage account changes retain their existing regression coverage.

## Sources and citations

`SourceReferenceCard` keeps the actual title, publisher, authors, available
publication date, checked date and rights statement. Optional document version is
supplied for Assistant citations; Knowledge sections retain their own version
label without duplicating it. No unsupported page numbers or dates are invented.

The URL stays selectable with an explicit Copy source URL action and confirmation.
No browser-opening dependency or unsafe scheme handling is introduced. Existing
DTO validation continues to accept only valid HTTPS source URLs. Assistant
citation buttons scroll to the corresponding validated source card within that
answer. Copy answer with sources retains original evidence, warnings, citation
identifiers, document versions and source URLs. Complete responses are not live
regions: loading/error status remains available without repeatedly announcing
every paragraph.

## Protected gallery

`ReferenceGallery` uses the existing repository and ViewModel. Only active,
rights-confirmed records are displayed. Missing, loading, failed and empty
galleries are distinct; unavailable images are never replaced with photographs.
At most four thumbnails are mounted per local page, preventing a large metadata
collection from eagerly scheduling every protected-image reader. Paging does
not refetch metadata and scrolls back to the gallery heading.

Tap a thumbnail to open `ReferenceImageViewer`, a fullscreen contain-fit
InteractiveViewer with pinch/pan, a scaled accessible app bar/Close action and a
scrollable attribution panel. Alt text, credit, license, attribution and source
are preserved. It uses the same bounded, in-memory PrivateImage transport, with
no Cloudinary URL exposure, new cache or authorization change. Zoom inspects the
existing preview representation; it does not request a new full-resolution API.

No real reference photos, licenses or domain facts are added in this release.
Test images and provenance are explicitly synthetic and never published.

## Components and file inventory

Reused/refined: AppPage, R-01 themes/tokens, AppField, confirmation dialog,
AppLoadingState/AppErrorState/AppEmptyState, KnowledgeCatalogueCard,
KnowledgeSectionCard, SourceReferenceCard, PrivateImage, HistoryScanTile,
AssistantComposer/EmptyState/TurnCard/AnswerCard/ScanContext/SourceCard.

New application widgets: `assistant_focus_panel.dart` and
`reference_image_viewer.dart`. Existing files updated:

- `lib/core/routes/app_router.dart` (selected picker ID only, preserving R-03).
- `lib/core/widgets/source_reference_card.dart`.
- `lib/features/ai_assistant/views/{assistant_view,assistant_scan_picker}.dart`.
- `lib/features/ai_assistant/widgets/{assistant_answer_card,assistant_composer,
  assistant_empty_state,assistant_scan_context,assistant_source_card,
  assistant_turn_card}.dart`.
- `lib/features/disease_knowledge/views/{knowledge_view,knowledge_detail_view}.dart`.
- `lib/features/disease_knowledge/widgets/{knowledge_catalogue_card,
  knowledge_section_card,reference_gallery}.dart`.

Tests: `test/assistant/widget_test.dart` follows the new Focus sheet and confirms
clear rather than weakening its existing assertions. New R-04 files are
`test/redesign/r04_{assistant,knowledge,layout,golden}_test.dart` and
`r04_fixtures.dart`, plus eight goldens. Two existing 360dp R-01 component goldens
are updated after reviewing the added source-copy control. The large-text R-01,
all R-02 and all R-03 golden baselines remain unchanged from the starting tree.

## Verification and limits

- Combined focused regression: **411 passed / 0 failed / 0 skipped**, including
  23 golden comparisons (eight R-04 and 15 prior-release comparisons).
- Flutter analyze: no issues. Dart formatting and Git whitespace checks pass.
- Android ARM64 staging debug APK: PASS (47.2s Gradle task).
- Android ARM64 staging release compilation: PASS (114.6s Gradle task), using
  `-PallowUnsignedVerification=true`. The pre-existing optional CupertinoIcons
  font tree-shaking warning remains nonfatal. No signing or dependency changes.
- The responsive matrix covers 320/360/412/480/600/840/1024dp, 100%/150%/200% text,
  both themes, keyboard-open multiline composer, Focus sheet, detail navigation,
  gallery viewer and reduced motion.
- Tests cover source copying/citation navigation, gallery page bounds, image
  denial/list failure, actual returned section navigation/versioning, read-position
  preservation, explicit jump-to-latest, clear/cancel, rate limits and validation.
  Existing tests retain semantic search/stale response, 12-turn/request payload,
  protected scan picker/pagination, session isolation and one-shot handoff checks.
- All eight R-04 renders and the two changed component renders were visually
  inspected. Fixture shapes explicitly say UI TEST/SYNTHETIC. Golden comparison
  evidence is host-rendered; no live provider test or agricultural approval is
  claimed. Initial comparison artifacts are retained under the ignored
  `build/r04-golden-review-20261102/` directory.
- ADB reports no device: physical-device/TalkBack acceptance is NOT VERIFIED.
- No backend, AI-service, database, model, scientific data, dependency, native
  Android, authentication, repository, datasource or domain ViewModel changes.
- Final Git state: `main` remains at `6cf1cbff9a8d927baacaf105f5c99883723dcecf`.
  There are 71 changed/untracked related paths under `mobile/`, including the 38
  starting R-03 paths. R-04 touches 34 paths, with the router shared by the two
  releases. Zero staged files; no commit/push. R-04 engineering is complete;
  physical acceptance remains separate and R-05 needs a new instruction.

Commands from `mobile/`, using the existing environment-isolating wrapper:

```powershell
$node = '..\.cache\node\node-v24.22.0-win-x64\node.exe'
$flutterRunner = '..\scripts\run-flutter.mjs'
& $node $flutterRunner analyze --no-pub
& $node $flutterRunner test --no-pub test/redesign test/features/home_view_model_test.dart test/scans test/history test/knowledge test/security/private_image_test.dart test/navigation test/assistant test/auth test/farmer_flow_test.dart test/theme test/widgets test/responsive test/profile/widget_test.dart test/profile/privacy_test.dart test/admin/widget_test.dart test/admin/accounts_widget_test.dart
& $node $flutterRunner build apk --debug --flavor staging --target-platform android-arm64 --no-pub
& $node $flutterRunner build apk --release --flavor staging --target-platform android-arm64 --no-pub -PallowUnsignedVerification=true
```

The recorded test count uses Flutter's JSON reporter and nonhidden test results.
No live Gemini/Cloudinary request, database mutation or unrelated service test is
part of R-04. Release compilation uses the existing unsigned-verification gate;
it is not a signed distributable release.
