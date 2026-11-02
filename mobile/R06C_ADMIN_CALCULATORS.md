# R-06C — Admin calculator management

Frontend-only work on the existing FIELD INTELLIGENCE workspace. The starting
branch is `main`, HEAD `07f3f302b8a0ca8c74df4912e94f0e23dce93e58`, with 54
uncommitted R-06A/B paths preserved. The user explicitly authorized relevant
commits and pushes at completion, superseding the earlier no-push instruction.

## Existing feature-parity map (inspected before implementation)

All four areas use `AdminManagementView` → `ManagementEditorForm` →
`AdminManagementViewModel` → `ApiAdminManagementRepository`. No replacement
repository or calculator engine is required.

| Area / existing query | Input contract and validation | Mutations / state / tests |
| --- | --- | --- |
| Fertilizer catalogue / `area=fertilizers` | Product slug/name/description; N/P₂O₅/K₂O decimal strings, 0–100, up to 2 decimals; optional method/precautions/type/stages/conditions/rate text; source title/publisher/HTTPS/citation; review note; explicit approval; DRAFT/ACTIVE/INACTIVE | Create POST, edit PATCH with expectedRevision; referenced products return contentEditable=false; copy clears slug and creates a new product; status PATCH with revision. Existing `admin/predeployment_test.dart`, management tests. |
| Fertilizer rules / `area=fertilizer` | Rule key/version/title, product mass rate kg/ha (0–1,000,000, up to 6 decimals), applicability, assumptions; source/citation/review; full product snapshot; config version and output decimal places 0–6 | POST new draft containing rule/product/config; separate confirmed ACTIVE/INACTIVE status; ready flag remains server-derived; immutable snapshots retained. Existing management and Farmer fertilizer tests. |
| Yield rules / `area=yieldRules` | New version/title, reviewed reference kg/ha, applicability, assumptions, source/citation/review, output decimal places 0–6. No editable config key, season or independent forecast coefficient field exists | POST draft then confirmed ACTIVE/INACTIVE; source-backed area × reference-rate planning only. Existing management and Farmer yield tests. |
| Model specifications / `area=modelSpecifications` | Fixed modelKey/kind on new versions; title/formula text/applicability/assumptions; inputs/outputs arrays of key/unit/description (1–16); coefficient arrays of key/value/unit/sourceSection (0–32); coefficient values remain signed decimal strings ≤64 chars; source/review/approval | POST immutable specification with expectedVersion. Server returns DRAFT, execution DISABLED, domainApproval PENDING_DOMAIN_APPROVAL, validForActivation=false. No status/execution control. Existing predeployment source-intake and management tests. |

Sources have no additional manufacturer, publication-date or rights fields in
these calculator write contracts. No such inputs are invented. Reviewer identity
is server-generated. Existing field limits, stable identifiers, URL validation,
version conflict handling, busy protection, cursor rules and session fencing
remain the authority. Frontend tests use synthetic in-memory records only.

## Implemented presentation

The existing `AdminContentManagement` list/editor surface now also serves the four
calculator areas. Domain-specific `AdminCalculatorCard` presentation retains exact
returned strings and distinguishes unknown values from zero. Cards show product
identity/composition or rule/configuration identity, versions, rate units,
applicability, assumptions, source and server-reported activation eligibility.
Local filtering covers loaded records only; existing cursor actions are retained.
The non-paginated rule/specification APIs explicitly disclose their latest-100
window. No unsupported server search or extra catalogue request is introduced.

`ManagementEditorForm` still owns the original controllers, field definitions and
save callback. `calculatorEditorSections` groups every original field exactly once
into identity, composition/product snapshot, product context, application rate or
reference yield, applicability, assumptions, source, and review/status sections.
Numeric keyboards and wrapping required/optional labels improve entry without
parsing, rounding or replacing decimal-string values. Original validation remains;
API/source/revision errors preserve input and support deliberate refresh/review.

### Product information versus recommendations

N, P₂O₅ (P2O5) and K₂O (K2O) are explicitly percentages by mass. Their accessible
descriptions do not describe kg/ha. Product rate-reference text remains descriptive
information and never enables a calculation. No manufacturer, brand, source date
or separate license field is invented where the current write contract has none.

Referenced products remain frozen according to `contentEditable`; Edit is disabled
and the reason is visible. Copy uses the existing ViewModel action, clears the
slug, retains the source/product snapshot and requires fresh review. Product save
is labelled **Save product metadata**, since the existing visibility field can
request DRAFT/ACTIVE/INACTIVE; it does not misleadingly promise a draft-only write.
Separate existing activation/deactivation controls retain revision and readiness
checks. No existing product identifier or immutable rule snapshot is overwritten.

### Fertilizer and yield

Fertilizer rules retain the complete existing product snapshot fields. The API has
no separate product-picker workflow, so the UI does not invent one. Reviewed
product kg/ha is visually separated from nutrient composition. The Farmer engine
still scales area by the reviewed product rate; no N/P/K needs, soil optimization,
prescription or application schedule is added.

Yield uses the reviewed reference kg/ha value and existing output precision. It
remains conditional area × reference-rate planning, not an AI forecast, guaranteed
harvest, or minimum/expected/potential field prediction. Those output names may be
stored in a disabled source-intake specification but are not executable outputs.

For both, Save draft and confirmed Activate/Deactivate remain separate original
operations. No live calculation preview, automatic activation, new rounding policy
or default agronomic number is introduced. Historical versions remain intact.

## Agronomic specifications and JSON fidelity

`SpecificationArrayEditor` adapts the original JSON-string controllers to bounded
repeatable row controls. Inputs/outputs expose key, unit, description; coefficients
expose key, signed decimal **string**, unit and source section. There are no invented
required/type flags. Add/remove operations retain all untouched row values.
Variable counts, unique keys, unit enum, required output names, coefficient format
and original 12,000-character JSON form limit are validated before save.

Viewing a row or switching to Advanced JSON does not rewrite its text or make the
form dirty. Structured changes serialize strings without numeric coercion; trailing
zeros and long coefficient precision are retained. Unknown keys/structures cannot
be represented losslessly by the supported row controls, so the UI keeps the
original text in Advanced JSON and disables the structured switch. It never drops
unknown fields or claims the backend will accept an unsupported future schema.
The original serializer and server remain authoritative at save.

The interface states **Pending domain approval / Disabled**, shows returned
execution/approval state, and offers neither activation nor execution controls.
Formula text is never interpreted. The server remains responsible for version
allocation and reviewer identity. No scientific model approval is fabricated.

## Navigation, state, security and reuse

Existing `/admin/manage?area=fertilizers|fertilizer|yieldRules|modelSpecifications`
locations remain unchanged. Calculator area chips synchronize those existing
queries. The R-06A phone drawer/expanded sidebar is retained; no new routes or
navigation package is introduced. Separate Farmer/Admin authentication remains.

R-06B `AdminDraftGuard` now covers all management editors: Android/header Back,
drawer/sidebar, area changes, Farmer return and Admin sign-out. Cancel preserves
input; confirmed leave disposes it. Unchanged viewing produces no unnecessary
warning. Existing session revision fencing discards delayed responses after logout.
No private draft is saved in ordinary preferences. Controller disposal, busy
guards, server-confirmed save notices and independent editor/list scroll positions
remain in the shared implementation.

Reused: `AdminContentManagement`, `AdminEditorSection`, `AdminContentStatus`,
`AdminDraftGuard`, `AppPage`, `AppField`, loading/error/empty states, confirmation
dialog, FIELD INTELLIGENCE fonts/themes/geometry and existing Provider/MVVM.
New: `AdminCalculatorCard`, calculator section presentation, specification row
adapter/validation helpers. No packages, backend contracts, repository or domain
ViewModel changes. R-06D and R-07 are not started.

## Verification — 2026-11-02

- Final combined focused run: **770 passed / 0 failed / 0 skipped**. This includes
  the retained R-01–R-06B selection and 61 new R-06C checks. All **59 golden
  comparisons** pass: 51 retained, eight new R-06C images visually inspected in
  light/dark phone/tablet states. No earlier-release baseline was regenerated.
- New tests cover product composition/frozen-copy behavior, exact decimal strings,
  required/numeric/source validation, source retention, conflicts, draft save and
  separate status actions, unsaved navigation, no-op viewing, logout/late responses,
  duplicate-submit protection, empty versus unavailable data, and complete field
  coverage. Structured/JSON round trips retain coefficient precision; unknown
  structures stay unchanged in Advanced JSON, malformed JSON is rejected, and the
  original JSON character limit remains enforced.
- Layout matrix: 320/360/412/480/600/840/1024/1280dp, 100/150/200% text, both themes,
  all four areas, long titles, large decimal values, JSON controls, reduced motion
  and portrait/landscape keyboard layouts. Labelled controls and Android touch-target
  guidelines pass. No RenderFlex overflow was reported in the final run.
- Final analyzer: **no issues**. Formatter check: **15 related Dart files, zero
  pending changes**. Git whitespace check passes.
- ARM64 staging debug APK compilation: **passed**, 59.4 seconds.
- ARM64 staging release compilation: **passed**, 176.2 seconds, 19.0 MB, using
  the existing unsigned-verification gate. This is compilation evidence, not a
  signed release. The pre-existing nonfatal CupertinoIcons font warning remains;
  no dependency or deployment configuration is changed to suppress it.
- An intermediate combined run reported 745 passed / 25 failed while verification
  updates were in progress: 24 old generic-heading assertions and the new JSON-limit
  assertion. The heading expectations now preserve route/layout checks using the
  new title; the limit has an explicit validator and passing regression. The final
  settled-source run above is the acceptance evidence.
- No real account/content/database mutation, paid provider call, backend/AI test,
  model evaluation or infrastructure change was performed. All new records and
  coefficients are synthetic in-memory frontend fixtures, never recommendations.
- ADB reports no connected Android device. Physical-device/TalkBack acceptance is
  **NOT VERIFIED**; automated accessibility and native compilation are distinct.

Commands from `mobile/`:

```powershell
$node = '..\.cache\node\node-v24.22.0-win-x64\node.exe'
$runner = '..\scripts\run-flutter.mjs'
& $node $runner analyze --no-pub
& $node $runner test --no-pub test/redesign test/features/home_view_model_test.dart test/scans test/history test/knowledge test/security/private_image_test.dart test/navigation test/assistant test/auth test/farmer_flow_test.dart test/theme test/widgets test/responsive test/profile test/admin test/fertilizer test/yield test/analytics
& $node $runner build apk --debug --flavor staging --target-platform android-arm64 --no-pub
& $node $runner build apk --release --flavor staging --target-platform android-arm64 --no-pub -PallowUnsignedVerification=true
```

## Related files and remaining limits

R-06C touches 24 paths: seven library files, eight tests/helpers, eight new golden
images and this guide. The only five overlaps with the 54 incoming dirty paths are
the shared management view/form/list and R-06A navigation/layout test expectations.
The other 49 incoming paths remain byte-identical. No existing path is deleted.

New library files: `admin_calculator_card.dart`, `calculator_editor_sections.dart`,
`specification_array_editor.dart`, `specification_rows.dart`. Existing shared
management files are extended; original `management_fields.dart`, DTOs, repositories,
domain ViewModels, Farmer calculator screens and business engines are unchanged.
New `r06c_*` fixtures/specification/management/layout/golden tests accompany them;
old label assertions in the existing predeployment/navigation/layout tests are
updated for the new wrapping labels and dedicated titles, without removing checks.

Real scientific sources and domain approvals remain prerequisites for legitimate
recommendations. No richer fertilizer/yield engine is introduced. Unsupported JSON
structures remain Advanced-only and subject to server validation. Local filters
cover loaded pages; existing latest-100 API windows remain unchanged. Physical
acceptance and live provider/content workflows are separate from frontend fixture
verification. No new scientific or operational capability is claimed by this UI.

## Git closeout

The authorized closeout preserves the exact incoming R-06A/B snapshot in one
relevant commit, then records the verified R-06C delta in a second commit on `main`.
Both are pushed normally to the configured `origin/main`, without force-pushing.
The chat completion report records exact commit hashes and verified remote status.
