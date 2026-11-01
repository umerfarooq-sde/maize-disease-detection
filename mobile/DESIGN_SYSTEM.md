# FIELD INTELLIGENCE — R-01

Frontend-only design foundations based on the approved audit at `453e631`.
No routes, API contracts, account rules, domain content or calculator arithmetic
change. R-02 navigation and individual screen redesigns are not part of this release.

## Theme and typography

`core/theme/design_tokens.dart` contains the raw palette, explicit Material 3 light/
dark schemes, semantic colors, geometry, typography and motion. Widgets consume
`Theme.of(context).colorScheme` and `context.semanticColors`; raw colors belong here.
System/Light/Dark selection and its existing preference store are unchanged.

Light: forest `#174C38`, leaf `#287551`, highlight `#E4F09A`, canvas `#F7F8F3`,
surface `#FFFFFF`, raised `#EFF3EC`, ink `#172B22`, secondary ink `#4B6255`, info
`#2563A6`, warning `#795A12`, error `#B42333`, success `#246442`.
Dark: primary `#8AD5AC`, canvas `#101A15`, surface `#18251D`, raised `#223329`,
ink `#E5EFE8`, secondary ink `#BACBBF`. Semantic container/foreground pairs are
explicitly defined and tested, including success/info/warning/error.
Earth `#B67A49` is decorative: white body text on it fails AA. A successful upload
or completed analysis must never be restyled to imply a confirmed diagnosis.

Plus Jakarta Sans upright/italic variable fonts are bundled locally, explicitly
mapped to weights 400/500/600/700, with Roboto/system sans-serif fallback. See
`assets/fonts/plus_jakarta_sans/README.md` for pinned source, byte hashes and OFL.
The license is bundled and lazily registered with Flutter's license registry.
No network fonts or new package dependency is introduced.

| Role | Size / line height | Weight |
|---|---|---|
| Hero | 32 / 1.20 | 700 |
| Screen title | 28 / 1.25 | 700 |
| Compact title | 24 / 1.25 | 700 |
| Section | 20 / 1.35 | 600 |
| Card title | 18 / 1.35 | 600 |
| Body | 16 / 1.50 | 400 |
| Supporting | 14 / 1.50 | 400 |
| Label | 13 / 1.35 | 600 |
| Metadata | 12 / 1.40 | 500 |
| Metric | 28 / 1.20 | 700, tabular figures |

Spacing is 4/8/12/16/24/32/48. Radii: small10, input14, card20, hero/sheet24.
Primary buttons are at least56dp; secondary/icon controls at least48dp. These are
minimums, not fixed heights. Text scale is not clamped.
Page width defaults to the existing1120dp dashboard maximum; opt-in `maxWidth`
supports reading720, authentication480 and forms760. Existing screen widths and
navigation breakpoints remain unchanged. Do not apply every narrow width globally.

## Shared components

- Existing Material buttons, inputs, app bars, cards, navigation, dialogs and sheets
  inherit the new themes. Existing screen actions and callbacks are unchanged.
- `AppButton`: primary, outline secondary, tonal, destructive, disabled and explicit
  loading presentation. The caller owns state/callbacks. Loading disables repeat
  taps; reduced motion uses a static indicator. No simulated progress is added.
- `AppField`: persistent wrapping label with required/optional indication, around
  an existing Material field. Omit the child's `decoration.labelText`. The child
  retains focus, numeric keyboard, password visibility, units, validators and
  callbacks. This is the option for long labels at large text sizes; legacy Material
  floating labels remain single-line and will be migrated with their screen release.
- `AppMetricCard`: display-only value/unit/note. Null displays Unavailable, never0.
- `AppStatusPanel`: neutral, information, warning, error and success tones selected
  explicitly by the caller. No business-status inference. Works in plain Material
  hosts as well as the application theme.
- `AppLoadingState`: existing section state and opt-in `inline: true`; functional
  progress announcements. `AppEmptyState` also supports an explicit tone: use
  information for unavailable content and warning for pending approved configuration.
  Error retry callbacks and success messages retain their existing contracts.
- Existing `FeatureCard`, `SourceReferenceCard`, confirmation dialog, protected
  `PrivateImage`, scroll surfaces and horizontal data scroll are reused. Source
  URLs stay selectable; removing the misleading underline does not add external
  navigation, citations or change provenance. Protected image transport is untouched.

Motion tokens: button100ms, navigation180ms, reveal220ms, theme240ms.
`AppMotion.resolve` respects reduced-motion settings. Theme transition consumes it;
existing feature transitions already use matching180/220ms and keep their existing
reduced-motion handling. No new screen animation is added.

## Verification and visual baselines

Use the repository's Node wrapper from `mobile/` so server secrets do not reach
Flutter. Standard commands:

```powershell
& '..\.cache\node\node-v24.22.0-win-x64\node.exe' '..\scripts\run-flutter.mjs' analyze --no-pub
& '..\.cache\node\node-v24.22.0-win-x64\node.exe' '..\scripts\run-flutter.mjs' test --no-pub test/theme test/widgets test/responsive
```

`test/support/design_fonts.dart` loads actual bundled fonts for component renders.
Token tests validate text/container contrast, control contrast, asset font faces,
license availability, geometry, motion and theme roles. Shared widget tests cover
callbacks, unavailable versus zero, plain-Material compatibility, long labels,
validation, confirmation and narrow/large-text layouts.

Three test-only golden specimens cover light360, dark360, light320 at200% text.
They contain clearly labelled fixture data, never real knowledge or telemetry.
The large-text image captures the viewport; the test also scrolls to the source
below it. Review images before explicitly updating goldens; normal runs compare
without `--update-goldens`. SDK/OS/font changes can require a reviewed baseline
update. No physical-device accessibility/performance certification is implied.

Native debug and unsigned release verification builds must contain both unchanged
font files, matching weight/style manifests and the license. Unsigned verification
artifacts are not distributable releases. No signing/deployment policy changes.

### R-01 local verification — 2026-11-01

- Dart format check and `git diff --check`: pass; analyzer: no issues.
- Focused theme/shared/responsive and affected Farmer/Admin UI regressions:
  **176 passed, 0 failed, 0 skipped**, including three non-update golden comparisons.
- Initial wider regressions exposed a new status-panel dependency on a custom theme
  extension; fixed with explicit light/dark fallback and a plain-Material regression.
  Existing privacy/error tests now pass without changing their assertions.
- Goldens generated then visually inspected in light/dark360dp and light320dp at
  200% text. A wrapping label specimen replaces the legacy single-line label where
  large text would ellipsize; helper/error text wraps and below-viewport source
  content remains scrollable. No live agricultural/telemetry data is used.
- Staging ARM64 debug APK and unsigned release APK: build pass. Both ZIPs verified
  for exact font bytes, weights400/500/600/700, upright/italic styles and OFL notice.
  Release command uses the existing `-PallowUnsignedVerification=true` build gate.
- Release tree-shaking logs an optional `packages/cupertino_icons/CupertinoIcons`
  font warning. No application source references that family; no dependency added.
  Material icon processing and the bundled Plus Jakarta fonts verify successfully.
- No physical-device/TalkBack/profile-mode acceptance or Linux golden comparison
  is claimed. No backend/AI/provider tests, signing, deployment, commit or push.

R-01 foundations are ready for separately authorized R-02. Bottom-navigation
destinations and existing Farmer/Admin feature layouts remain unchanged.
