# R-06D — Accounts, Audit History and Model Health

Frontend release built on `657e1c8` (`main`). No backend, database, repository,
wire DTO, authentication, model, scientific-policy or deployment changes.
R-01 through R-06C remain in place; R-07 is outside this release.

## Farmer accounts

`/admin/farmers` uses collapsible, explicitly applied exact-email and status
filters. Typing/selecting a pending filter does not make a request. Clear resets
the existing query. The repository still normalizes email, requests 20 records
and uses the existing cursor. Counts describe loaded records, not database totals.

Lazy, width-constrained cards show the returned name/email, status and UTC
registration time. Account details disclose the loaded ID, revision and exact
timestamp without a second request. No address, telephone, password, role,
impersonation, deletion or credential controls have been introduced.

The confirmation names the account, current loaded status and requested status.
Existing backend policy revokes sessions on a committed status change, preserves
records and writes its audit entry. Flutter sends the existing status/revision
request and waits for acknowledgement. Pending work disables duplicate actions;
an error disables status actions until a successful authoritative refresh. A
timeout is not called success and retry refreshes via GET rather than replaying
the status mutation. Conflict guidance likewise requires reviewing current state.

Confirmations use the protected child Navigator, so account information disappears
with that Admin session. Short-window/keyboard confirmations scroll their title,
message and actions. Signed-out Android Back is handled at the mounted parent
Navigator instead of traversing the deliberately unmounted private Navigator.
Neither change grants access or changes session business logic.

## Audit history

`/admin/audit` retains action, affected area, exact actor ID and literal UTC
`YYYY-MM-DD` bounds. Filters apply together; both dates are required when either
is used, and the existing repository enforces a span shorter than 366 days.
The existing inclusive through-date semantics are unchanged (Node uses an
exclusive next-day UTC bound). No local timezone conversion is introduced.

Chronological lazy cards translate existing codes without asserting an outcome:
CREATE/UPDATE/ACTIVATE/DEACTIVATE/DELETE/MODEL_PROMOTION become recorded-event
labels. Farmer status-change metadata gets a more specific heading. Expansion
retains original action/entity codes, event/target/actor identifiers and exact UTC
timestamp. Only the existing DTO's allowed metadata is rendered. No event editing,
deletion, clearing or export is offered, and existence/action alone is not proof
of completion.

Presentation mapping has an unknown-code fallback, covered with a typed fixture.
The unchanged wire DTO intentionally rejects unknown action codes and private or
unrecognized fields. A future API contract expansion still requires coordinated
typed-contract work; this release does not weaken parsing to accept arbitrary data.

Both list ViewModels now remove overlapping IDs when appending and reject a
non-advancing cursor as an invalid response before changing the loaded page.
Regression tests first reproduced both duplicate rows and the repeated-cursor
problem. Refresh/filter reset, bounded page requests and session fences remain.

## Model health

`/admin/model-health` is read-only and makes only the existing health request:

| Section | Actual evidence and limitations |
| --- | --- |
| Deployed model | Returned loaded/configured versions, architecture from matching evidence/registry, preprocessing, service status, production-registry alignment. Readiness is reported status, not a new inference test. |
| Confidence policy | UNCONFIGURED, VALIDATION_BASED or unavailable. Unconfigured means successful results are treated as low confidence; raw scores do not establish diagnostic confidence. |
| Offline evaluation — research evidence | Saved test accuracy, macro precision/recall/F1, unique support, expandable per-class metrics, confusion matrix and experiment/index provenance. These are not live production or independent field accuracy. |
| Runtime operational statistics | One FastAPI process since startup: admitted handler attempts, in flight, successes, failures, mean completed-request latency in ms, low-confidence fraction of successes and expandable actual class-output counts. |
| Technical details and registry | Returned class labels, versions, dataset/preprocessing metadata and latest 50 registrations. Registration timestamps are not training dates. |

Numeric confidence threshold, temperature, artifact hashes, specific integrity
failure reasons, evaluation date and calibration results are not exposed by this
Admin DTO; the UI does not fill them from historical settings. The existing
approved model and policy are unchanged. INCOMPATIBLE does not invent a hash error.
Missing means unavailable, while a supplied zero remains zero. Runtime latency
includes failed handler requests and excludes Node/Cloudinary/database time.
Runtime output distribution is neither prevalence nor accuracy. No ground-truth
feedback means no drift-detection claim. The AI Operations link opens the existing
`/admin/ai-operations` page rather than duplicating its telemetry or provider work.
Malformed encoding in the prior presentation is corrected.

## Reuse, navigation and accessibility

- Reuses the Admin workspace/sidebar/drawer, Provider/ChangeNotifier, GoRouter,
  shared cards, semantic status panels, metric grid, fields, state views and
  confirmation component. Default metric-grid behavior for other screens is unchanged.
- New reusable pieces: `AdminRecordPage` (lazy slivers), `FarmerAccountCard`,
  record/date/action presentation helpers, `AdminSelectableText` and small model
  identity/confidence/runtime panels. Technical selection targets have a 48dp minimum.
- Existing three routes, five Farmer branches, independent Admin session,
  revision-keyed access gate, management draft guards and AI Operations are preserved.
  Logout disposes private content; late responses cannot enter a subsequent identity.
- Local width controls layout. Long values wrap; wide content remains constrained.
  Model grids expand for text scaling; the matrix scrolls horizontally and each
  count has actual/predicted class semantics. Section headings, explicit status
  icons/text, live feedback, labelled actions and reduced-motion timings use R-01.

## Verification

Tests use isolated in-memory HTTP fixtures only. No real Farmer mutations, audit
writes, providers, inference, model evaluation or agricultural-data changes occur.
The R-06D matrix covers 320/360/412/480/600/840/1024/1280dp, 100/150/200% text,
both themes, long records/large metadata, reduced motion, keyboard/landscape,
target labels, class-cell semantics and phone/tablet navigation.

Nine new goldens cover accounts, a status confirmation, audit cards/details,
model identity, research evidence/matrix, runtime operations and unavailable state.
All were opened and reviewed; existing release baselines are not regenerated.

Verification commands use the repository Node launcher for Flutter:

```powershell
# From mobile/, using the existing cached Node executable:
$flutterNode = '..\.cache\node\node-v24.22.0-win-x64\node.exe'
& $flutterNode ../scripts/run-flutter.mjs analyze --no-pub
& $flutterNode ../scripts/run-flutter.mjs test --no-pub test/redesign test/features/home_view_model_test.dart test/scans test/history test/knowledge test/security/private_image_test.dart test/navigation test/assistant test/auth test/farmer_flow_test.dart test/theme test/widgets test/responsive test/profile test/admin test/fertilizer test/yield test/analytics
& $flutterNode ../scripts/run-flutter.mjs build apk --debug --flavor staging --target-platform android-arm64 --no-pub
& $flutterNode ../scripts/run-flutter.mjs build apk --release --flavor staging --target-platform android-arm64 --no-pub -PallowUnsignedVerification=true
```

Final verification on 2026-11-02:

| Check | Result |
| --- | --- |
| Focused R-01–R-06D regression command above | **835 passed / 0 failed / 0 skipped**, one settled run, 213.859 seconds. Includes 65 new R-06D tests. |
| Golden comparisons within that run | **68 passed**: 59 existing baselines plus nine new, visually reviewed R-06D baselines. |
| Formatting | All 23 changed/new Dart files formatted; final check made zero changes. |
| Flutter analyze | No issues found. |
| ARM64 staging debug APK | Passed, 36.8 seconds. |
| ARM64 staging release compilation | Passed, 101.0 seconds; 19.0 MB. Existing unsigned-verification gate. |
| Whitespace/scope review | `git diff --check` passed; all 33 changed/new paths are under `mobile/`. No dependency, wire-contract, route-definition or backend/AI changes. |
| Physical Android | ADB listed no device: **NOT VERIFIED**. |

Release compilation is not signed-release or deployment approval. It emits the
previously recorded, non-blocking CupertinoIcons font warning; this release adds
no icon/font dependency and uses Material icons. Historical backend/AI evidence
is not represented as a new live test. No current R-06D automated failures remain.
APK inspection confirmed ARM64 Flutter engine code (and ARM64 release app code)
and the two bundled Jakarta font assets in both outputs. The existing datastore
dependency also packages small counter libraries for other ABIs; these are not
additional Flutter app targets.

## Changed-file map and closeout

- Three existing views: `farmer_management_view.dart`, `audit_log_view.dart`,
  `model_health_view.dart`.
- Two existing ViewModels: `farmer_management_view_model.dart`,
  `audit_log_view_model.dart` (pagination presentation guards only).
- Existing shared pieces: `app_confirmation_dialog.dart`,
  `admin_workspace_shell.dart`, `admin_metric_grid.dart`, `audit_entry_card.dart`,
  `offline_model_metrics.dart`.
- Five new widgets/helpers: `admin_record_page.dart`,
  `admin_record_presentation.dart`, `admin_selectable_text.dart`,
  `farmer_account_card.dart`, `model_health_panels.dart`.
- Existing account/model widget tests updated for actual disclosure/heading and
  real sliver scrolling; original safety assertions retained. New pagination
  regression tests plus R-06D accounts/audit, model, responsive and golden tests
  use a shared isolated fixture. Nine new PNG baselines and this document.

Branch remains `main`, HEAD `657e1c8bbca6b6916a565da39ff36409ca36b069`.
Working tree was clean before this release; the 33 R-06D paths remain unstaged
and uncommitted. No commit/push was performed. R-06D implementation and automated
verification are complete; physical acceptance remains pending. R-07 may be
planned separately but has not been started.
