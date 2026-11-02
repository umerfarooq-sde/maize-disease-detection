# FIELD INTELLIGENCE — R-03

Frontend-only Home, leaf selection/upload presentation and model-result redesign.
Baseline: `main` at `6cf1cbff9a8d927baacaf105f5c99883723dcecf`, with a clean
working tree. R-01/R-02 were already committed at that baseline; their theme,
fonts, five persistent navigation branches, authentication presentation and
Android identity are preserved. This release does not include R-04.

## Home and real recent history

The existing shell supplies MAIZEDOCTOR identity and its Profile action. Home
adds a compact forest scan hero, Learn/Assistant/Tools shortcuts and a secondary
connection check. The shortcuts switch to existing branches; Assistant is still
the single persistent `/assistant` destination. At wider layouts the hero and
quick actions sit alongside one another, within the existing dashboard width.

Home's existing ViewModel accepts the existing `ScanRecordsRepository`. Signed-in
Farmers request at most three records through `history(limit: 3)`; guests make no
history request. This projection does not consume or replace the History page's
pagination. Tiles reuse the authorized image component, actual status, model
output and scan date. Opening a tile pushes the existing History result route.

The router keys the Home provider to Farmer session revision. Disposal fences
late requests, and private results disappear on sign-out/account changes. Initial
loading happens in the provider factory, not widget build. An actual return to
the retained Home branch refreshes the section; ordinary rebuilds, theme changes
and tab reselection do not. Explicit refresh/retry remains available. Loading,
failed retrieval, genuine empty history and populated history are separate states.

## Scan presentation and unchanged state machine

`ScanViewModel`, `ScanResultViewModel`, repositories, picker/data sources and
polling utilities are unchanged. The existing state enum still drives selection,
explicit confirmation, upload, processing, completion, failure and retry. Camera,
gallery, lost-picker recovery, guest capability, request-key reuse and bounded
polling retain their existing behavior. Starting another scan abandons local
polling; it does not claim to cancel server work.

Small presentation widgets separate photo guidance, selection/reselection actions,
actual upload progress and processing status. Selection never starts an upload.
The preview is contain-fit, 4:3, with its diagnostic image subtree selected
independently of progress updates. Progress comes from the existing upload
callback, with no simulated percentages or invented inference stages. Existing
error kinds determine retry wording; unavailable quality/format subcategories
are not invented. The displayed admission guidance remains JPEG/PNG/WebP,
5 MiB maximum and 16 megapixels. Server validation remains authoritative.

Reduced motion bypasses the scan AnimatedSize transition altogether, avoiding
zero-duration layout reentrancy. Other transitions reuse R-01 motion constants.

## Result, uncertainty and next actions

The authorized submitted image comes first, followed by actual analysis status
and time, leading model category, raw classifier score and confidence-policy
explanation. Read information, authorized Explain this scan and Scan another
leaf precede expandable all-class scores and technical details.

The existing class-to-catalogue navigation switch is shared with result actions;
the four classifier labels and DTOs are unchanged. No catalogue content is added.
The result cannot manufacture citations: it links to the existing sourced
Knowledge detail, while Assistant keeps its existing validated source behavior.

No model artifact, threshold or calibration changes. Null threshold continues to
display `LOW_CONFIDENCE` / `THRESHOLD_UNCONFIGURED`, even for a high raw score.
The UI explicitly says raw softmax output is neither diagnostic accuracy nor
the probability the label is correct. Healthy does not establish field health.
Technical details show only returned versions, status, uncertainty reason,
threshold, timestamps and inference duration. Temperature is not returned by the
public scan contract and is not invented in the UI.

The existing router still supplies Explain this scan only to an authenticated
owner. R-02's session-bound, once-only Assistant handoff is unchanged. Guest
capabilities continue to authorize only their existing scan/image operations.

`ResultDisclosure` gives each expansion its own PageStorage key. Selectable model
fields also have distinct keys, so expansion booleans and text scroll offsets
cannot collide. Protected image transport/cache authorization is unchanged;
small thumbnails now request a bounded decode width based on their display size
and device pixel ratio, capped at the existing preview limit.

## Components

Reused: AppPage, R-01 Material component themes, AppLoadingState, AppEmptyState,
AppErrorState, AppSuccessState, semantic status colors, PrivateImage,
HistoryScanTile, ScanPreview, ScanResultImage, ScanResultCard and PredictionSummary.

New focused widgets: HomeScanHero, HomeQuickActions, HomeRecentScans,
ScanPhotoGuide, ScanReadyActions/ScanSelectedActions/ScanReselectActions,
ScanUploadStatus/ScanProcessingStatus and ResultDisclosure.

## Verification

The R-03 tests cover real repository contracts with local mock transports,
session isolation and pending-response fencing, no guest history fetch, bounded
recent results and retry, stable previews during actual callback progress,
all four class mappings, authorized result routes, score/policy disclosures and
Scan Again. Existing scan, picker, history, Assistant handoff, auth, navigation,
protected-image and design-foundation tests remain part of focused regression.

Responsive tests exercise 320, 360, 412, 480, 600, 840 and 1024dp, at 100%, 150%
and 200% text in both themes, including expanded results and reduced motion.
Large text can legitimately place the Home hero button below the initial fold;
the page scrolls and the persistent central Scan destination remains available.

Eight R-03 goldens cover Guest/Farmer Home, ready/selected/uploading Scan and
light/dark/expanded results. Their geometric leaf is visibly labelled
`UI TEST · SYNTHETIC`, generated only in the test, and never published as disease
media or shipped as agricultural content. Captures await actual image decoding.
The old R-02 320dp/200% navigation golden changes only because it includes Home;
the other R-02 and R-01 baselines are retained. Goldens are inspected before
approval; host screenshots are not physical-device acceptance.

No backend/AI/database/provider tests, real uploads, model evaluation or user
mutations are part of this release. Physical Android acceptance is NOT VERIFIED:
ADB reports no connected device. R-04 requires a separate instruction.

### Recorded checks — 2026-11-01

- Dart format: 28 changed/new Dart files checked; zero pending changes.
- Flutter analyze: no issues.
- Focused regression: **374 passed / 0 failed / 0 skipped**.
- Fifteen golden comparisons pass: eight new R-03, four R-02 and three R-01.
  The new R-03 baselines, the changed R-02 Home baseline and the tablet Home
  preview were visually reviewed. No blanket golden update was performed.
- Android ARM64 staging debug compilation: PASS (32.1s Gradle task).
- Android ARM64 staging release compilation: PASS (140.3s Gradle task), using
  the existing `-PallowUnsignedVerification=true` gate. This is unsigned
  compilation evidence, not authorization or signing for distribution.
- Release retains the previously documented CupertinoIcons font tree-shaking
  warning. It does not fail compilation; no dependency/configuration is changed
  to suppress it.
- Final Git review: 38 related files under `mobile/`, zero staged files. No
  backend, AI-service, database, ML, infrastructure, native Android, dependency,
  auth implementation, scan state-machine or repository changes. No commit/push.

Commands from `mobile/`, using the existing Flutter wrapper:

```powershell
$node = '..\.cache\node\node-v24.22.0-win-x64\node.exe'
$flutterRunner = '..\scripts\run-flutter.mjs'
& $node $flutterRunner analyze --no-pub
& $node $flutterRunner test --no-pub test/redesign test/features/home_view_model_test.dart test/scans test/history test/knowledge test/security/private_image_test.dart test/navigation test/assistant test/auth test/farmer_flow_test.dart test/theme test/widgets test/responsive test/profile/widget_test.dart test/profile/privacy_test.dart test/admin/widget_test.dart test/admin/accounts_widget_test.dart
& $node $flutterRunner build apk --debug --flavor staging --target-platform android-arm64 --no-pub
& $node $flutterRunner build apk --release --flavor staging --target-platform android-arm64 --no-pub -PallowUnsignedVerification=true
```

The recorded test run used Flutter's JSON reporter to count nonhidden test
results. No live-provider opt-in integration suite is included in those counts.
