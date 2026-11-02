# R-06B — Admin content management

Frontend-only release on `main` at
`07f3f302b8a0ca8c74df4912e94f0e23dce93e58`, building on the 33 existing,
uncommitted R-06A paths. R-01 through R-05 and the R-06A workspace are preserved.
No backend, AI, database, API contract, repository, domain ViewModel, source
content, model, calculator engine or deployment configuration changes.

## Disease catalogue

The Diseases destination remains `/admin/manage?area=diseases`. Compact cards
show the returned display name, scientific name when present, description,
visibility, literal classifier identity or informational identity, protected slug
and available metadata counts. Missing metadata counts remain unavailable.
The UI never invents catalogue totals or treats informational entries as trained
outputs. Healthy is explicitly a scouting context, not a field-health guarantee.

The existing field definitions and write serializer drive grouped sections:
display identity, optional reviewed growth stages, optional reviewed severity,
source/applicability and source review. Existing classifier labels and slugs have
no rename controls. New informational entries retain the existing create flow.
No disease facts, pathogens, grades or recommendations are supplied by this work.
Existing conditional source validation, approval, revision checks and hide
confirmation remain authoritative. The save notification follows the completed
mutation and successful reload; no optimistic publication is introduced.

## Knowledge documents and version lifecycle

`/admin/manage` and `?area=knowledge` remain compatible. Cards display returned
title, context, section, series, version, status, stored embedding readiness and
source identity. Active versions are explicitly scoped to loaded records; absence
from a page is not presented as proof that a series has no active version.

Title/context/series/section filtering and status chips operate only on loaded
records. They never send invented server search parameters. The original cursor
and Load more versions action remain available even when a filter matches nothing.
Disease/Knowledge area chips synchronize the existing query parameter. Other
management destinations remain available through the unchanged workspace menu.

The dedicated editor retains the original fields, limits and immutable-version
write path. Sections separate identity, reviewed text, source/applicability and
review. Existing series/context/section locks are retained when creating a new
version from a returned document. Reviewer identity is never editable or supplied
by the UI. Approval is fresh and explicit; it is not independent scientific or
legal certification. Dates, authors, rights and source scope stay with the version.

Publication remains **Save Draft → Build Embeddings → Activate**, three separate
server operations. Indexing uses the existing timeout, busy/error/reload behavior
and no simulated progress. Activation remains readiness-dependent, confirmed and
server-validated. Deactivate retains the existing ARCHIVED transition and history;
no document deletion or combined Publish operation is added.

Conflicts preserve the editor and entered text. Refresh requires discarding a dirty
draft deliberately, then reviewing current server state. No forced overwrite is
offered. Validation retains inline errors and adds a live summary and first-invalid
field focus/scroll for content forms.

## Reference media

`/admin/reference-images` uses the existing Admin management ViewModel/repository
to load friendly catalogue choices. Requests retain exact slugs. The initial page
load is bounded, further catalogue pages require explicit action, and failure has
a retry state. Upload is unavailable without a returned catalogue association.
An existing media list is not represented as empty when its request failed.

Media cards show actual protected previews, status, context, order, alt text,
credit, attribution, license and rights-confirmation state. Source disclosure
reuses `SourceReferenceCard`. Distinct expansion/content storage keys prevent
scroll offsets from being mistaken for disclosure state after editing. Cards use
an image/detail arrangement when local width allows and a vertical layout on
phones/large text. At most four loaded media cards are rendered per local page.

Previews reuse `PrivateImage` and the existing bounded `PrivateImageRepository`,
scoped to the **Admin API client**, not Farmer credentials. Existing authenticated
delivery, image validation, session revision checks, in-memory lifetime, retry and
decode bounds remain in place. No Cloudinary URL or disk image cache is added.

New draft and metadata/reorder/replace editors have identity, source and rights
sections, an actual selected-image preview and a fresh rights checkbox. Existing
picker, MIME/size/dimension validation and multipart metadata are unchanged.
Picking never uploads. Replacement remains a new draft referencing the existing
asset; it does not delete the published asset. Authors, publication date and
synthetic-test identity from existing media are retained by the original serializer.

Upload/save, Publish, Hide, and Retire and clean remain distinct. Lifecycle actions
require confirmation and use original revision-bearing API calls. The backend owns
rights/publication authorization, audit and durable cleanup. No direct Cloudinary
delete action exists. Unknown upload outcomes advise refreshing/reviewing stored
media before repeating a request. No auto-publish or automatic rights approval.

## Navigation, draft and session safety

`AdminDraftGuard` is workspace/session-scoped presentation coordination. It stores
callbacks, not form text. Dirty content/media forms guard drawer/sidebar changes,
area changes, app-bar Back, Android Back, Farmer return and Admin sign-out.
Cancel preserves the draft. A confirmed leave disposes it. Active form operations
prevent navigation until completion, avoiding an ambiguous local outcome.
External session invalidation still unmounts the private route subtree immediately;
the existing repositories/ViewModels reject stale completions.

The guard is disposed on Admin identity/revision changes. Controllers and selected
bytes are not saved in preferences. Drawer re-selection does not reset the current
editor. Pushed routes return to their originating screen after a confirmed Back.
Independent list/editor scroll keys open new editors at the top and preserve list
position on return. All existing Farmer and Admin route contracts are retained.

## Components and scope

New: `AdminContentManagement`/`AdminContentEntryCard`, `AdminEditorSection`,
`AdminContentStatus`, `AdminDraftGuard`, `AdminReferenceCard`.

Refined: `AdminManagementView`, `ManagementEditorForm`, `ReferenceManagementView`,
`ReferenceEditor`; small integration changes to `AdminAccessView` and the existing
`AdminWorkspaceShell`. Calculator/people/audit/model-health content is not redesigned.

Reused: FIELD INTELLIGENCE tokens/fonts, `AppPage`, `AppField`, existing Material
controls, state components, confirmation dialog, protected-image reader and source
card. No new package, color system, API adapter or state framework is introduced.
Labels wrap and retain required/optional semantics; source text is selectable.
Controls use existing 48dp/56dp minimums. Disclosures respect reduced motion.

## Verification — 2026-11-02

- Combined focused regression: **707 passed / 0 failed / 0 skipped**, including
  all retained release selections and **51 golden comparisons** (eight new R-06B
  captures, 43 retained). Eight new captures were visually reviewed. No prior
  release golden was regenerated for this release.
- Two additional expanded-sidebar/header-Back dirty-navigation tests:
  **2 passed / 0 failed / 0 skipped**, run separately after the combined selection.
  These are separate evidence, not a fictional combined 709-test run.
- Responsive checks: 320/360/412/480/600/840/1024/1280dp, 100/150/200% text,
  both themes, all three lists/editors, long titles, source disclosures, portrait
  and landscape keyboards, long HTTPS references and reduced motion. Labelled
  controls and Android tap-target guidelines pass.
- In-memory tests cover immutable identities, Healthy context, source validation,
  draft creation, fresh review, new version, cursor/filter behavior, conflict
  preservation, separate index/activate/archive, duplicate action prevention,
  stale completion/logout, protected media failures/retry, draft upload,
  replacement preservation, rights metadata, reorder, publish/hide/retirement,
  catalogue selection/retry and cancelled navigation retaining input.
- Final Flutter analyzer: **no issues**. Formatting check: **17 Dart files, zero
  pending changes**. Git whitespace check passes.
- Android ARM64 staging debug compilation: **passed**, 21.3 seconds.
- Android ARM64 staging release compilation: **passed**, 101.0 seconds, 19.0 MB,
  using the existing `-PallowUnsignedVerification=true` gate. This is unsigned
  compilation evidence, not a signed distribution. The pre-existing nonfatal
  CupertinoIcons font warning remains; no dependency/configuration is changed.
- ADB has no connected device. Physical Android/TalkBack acceptance is
  **NOT VERIFIED**. Tests use synthetic, in-memory fixtures only. No actual source
  document, account, provider asset, embedding or scientific dataset was changed.

Use the existing environment-isolating Node wrapper from `mobile/`:

```powershell
$node = '..\.cache\node\node-v24.22.0-win-x64\node.exe'
$runner = '..\scripts\run-flutter.mjs'
& $node $runner analyze --no-pub
& $node $runner test --no-pub test/redesign test/features/home_view_model_test.dart test/scans test/history test/knowledge test/security/private_image_test.dart test/navigation test/assistant test/auth test/farmer_flow_test.dart test/theme test/widgets test/responsive test/profile test/admin test/fertilizer test/yield test/analytics
& $node $runner test --no-pub test/redesign/r06b_content_test.dart --name 'dirty document guards (sidebar|header-back)'
& $node $runner build apk --debug --flavor staging --target-platform android-arm64 --no-pub
& $node $runner build apk --release --flavor staging --target-platform android-arm64 --no-pub -PallowUnsignedVerification=true
```

## Remaining acceptance

Physical-device acceptance and live provider testing remain separate. No live
content was edited/published for a styling test. Metadata/publication rights still
require real reviewed sources; no licensed disease photographs are fabricated.
Local filters cover loaded pages only. Existing backend capabilities and timeout/
reconciliation limitations remain unchanged. R-06C/D and R-07 are not started.
No commit or push is authorized by R-06B.

R-06B touches 26 paths: ten library files, seven tests/helpers, eight new golden
images and this document. Five pre-existing R-06A files receive the necessary
shell/provider/navigation-test integration; the other 28 baseline paths remain
byte-identical. All 33 pre-existing paths are retained. Final working tree has
54 changed/untracked paths, all under `mobile/`, with nothing staged. HEAD remains
`07f3f302b8a0ca8c74df4912e94f0e23dce93e58`.
