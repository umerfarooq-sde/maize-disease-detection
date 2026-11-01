# FIELD INTELLIGENCE — R-02

Frontend-only navigation, authentication presentation and Android identity.
Baseline: `main` at `453e631ddd4cfff3c3ba563785396433aa521b82` with the existing
uncommitted R-01 foundations. No commit, push, backend, API, model, or deployment
change is part of this release. R-03 has not started.

## Navigation and lifetime

`StatefulShellRoute.indexedStack` retains these branches, in order:

| Index | Destination | Route |
|---|---|---|
| 0 | Home | `/home` |
| 1 | Learn | `/knowledge` (existing catalogue/detail routes) |
| 2 | Scan | `/scan` (existing result routes) |
| 3 | AI Assistant | `/assistant` |
| 4 | Tools | `/tools` (fertilizer/yield children) |

The old `/tools/assistant` URL redirects to `/assistant`, preserving query
parameters. Internal scan-result actions switch to the single Assistant branch
with a typed, session-revision-bound handoff, rather than pushing another instance.
Tools no longer presents Assistant as a nested tool.

Tab reselection is a no-op: it preserves drafts and nested stacks. Android Back
pops detail routes first, then returns a non-Home primary branch to Home. Profile
is a separate root route, pushed from the shell header so Back returns to its
origin. All `/profile/*` URLs, including sign-in, registration, profile editing,
privacy, history/results and analytics, are retained. Direct Profile entry has a
visible Back action with a Home fallback. Admin remains outside the Farmer shell.
Home also offers a Scan History shortcut; there is no new recent-scans dashboard.

The header uses the existing account initial or a guest icon. SessionAccount does
not contain an avatar or display name; no decorative profile/image fetch or new
profile cache is introduced. Existing protected avatar editing/delivery is intact.

Assistant's ViewModel remains scoped to its branch and keyed by identity revision.
Ordinary tab changes preserve its draft and at most 12 temporary turns. Sign-in,
sign-out and account changes dispose that state, including while offstage. Late
responses remain fenced by the existing ViewModel generation checks. No transcript
storage, conversation-history payload, or repository/DTO change is introduced.

A distinct scan handoff is consumed once by the mounted Assistant view. It clears
the old draft/conversation before explaining the new scan. If an old request is
pending, its late response cannot overwrite the new context. Reselecting the tab
or rebuilding with the same handoff does not resend it. Ownership remains verified
by Node; guest users cannot receive authenticated route handoffs. The authenticated
scan picker retains its existing paginated, ownership-bound workflow.

## Authentication and accessibility

Farmer login, registration and Admin login reuse R-01 `AppPage`, `AppField`, theme,
fonts and geometry, plus shared `AuthHeader` and `BrandMark` presentation. Forms
have a 480dp maximum reading width, persistent wrapping required-field labels,
password visibility controls, scroll/keyboard handling and busy guards. Admin
adds local empty/invalid email and empty-password feedback; session/role checks
stay in the existing repositories. There is no public Admin registration.

Farmer registration remains 6–128 Unicode code points. Login validates nonempty
passwords without imposing new-registration length rules. No confirmation field,
new backend requirement, remember-me setting, or session persistence is added.

Phones always show all five captions. Narrow layouts use `AI`, with an explicit
`AI Assistant` spoken icon label and tooltip, plus the full page heading. Material
3's built-in navigation-caption scaling is retained; body/form text is not globally
clamped. The Scan icon has a 48dp primary container. Navigation uses 180ms timing
and resolves to zero for reduced motion. The existing rail starts at 840dp.

## Original Android identity

`assets/branding/maizedoctor-mark.svg` is the original maize/leaf vector source.
`core/widgets/brand_mark.dart` paints the same geometry without a runtime SVG
package. All five legacy launcher PNG densities replace the Flutter artwork.
Android 26+ uses a forest background plus vector foreground; Android 33+ also has
a monochrome layer. Native launch resources use light/dark canvases and the mark,
including Android 12+ splash attributes. No artificial launch delay, package-ID
change, permissions, signing change or branding dependency is introduced.

## Verification — 2026-11-01

- Flutter analyze: no issues.
- Dart format: 17 changed/new Dart files, zero pending formatting changes.
- Focused Flutter run: **246 passed / 0 failed / 0 skipped**.
- Seven golden comparisons pass: four visually reviewed R-02 snapshots and the
  three unchanged R-01 component baselines. Golden assets are host-rendered test
  evidence, not physical-device acceptance.
- Light and dark layout checks cover 320, 360, 412, 480, 600, 840 and 1024dp at
  100%, 150% and 200% text, including keyboard-open auth forms.
- Tests cover ordered branches, central Scan, selected tab semantics, reduced
  motion, Android Back, retained Tools stacks, Profile origin, legacy Assistant
  links, chat/draft retention, one-shot/repeated scan handoffs, pending-response
  replacement, offstage account changes, existing short-password login, registration
  boundaries, Admin role denial, separate sessions, profile/history and protected
  images. The compact Assistant also passes tap-target and label guidelines.
- Initial old route/copy assertions were reconciled with the primary Assistant
  destination; assertions of retention, privacy and access were preserved.
- Android ARM64 staging debug APK: PASS (65.0s Gradle task).
- Android ARM64 staging release compilation: PASS (172.4s Gradle task), using the
  existing explicit `-PallowUnsignedVerification=true` gate. This unsigned artifact
  is compilation evidence, not a signed release for distribution.
- AAPT2 verifies the existing `com.maizedoctor.maizedoctor.staging` identity,
  launcher resources, and light/dark/API-31 launch attributes. Both APKs contain
  the five exact launcher raster images, adaptive/themed resources, brand vectors,
  and unchanged bundled font/license bytes.
- The pre-existing R-01 CupertinoIcons tree-shaking warning also appears during
  release compilation; it does not fail either build. No dependency is added to
  suppress it.
- ADB reports no device: physical acceptance is NOT VERIFIED.

Focused test command, from `mobile/` (the existing wrapper resolves Flutter):

```powershell
& '..\.cache\node\node-v24.22.0-win-x64\node.exe' '..\scripts\run-flutter.mjs' test --no-pub `
  test/navigation test/auth test/assistant test/farmer_flow_test.dart `
  test/responsive test/theme test/widgets test/profile/widget_test.dart `
  test/profile/privacy_test.dart test/security/private_image_test.dart `
  test/admin/widget_test.dart test/admin/accounts_widget_test.dart `
  test/history/widget_test.dart test/scans/result_widget_test.dart `
  test/scans/ui_remediation_test.dart
```

R-02 implementation paths: `core/routes/`, `features/shell/`, the Assistant view,
the three authentication views, Home/Tools views, two new shared presentation
widgets, Android `src/main/res/`, original branding SVG, and focused tests/goldens.
The only shared R-01 path additionally edited is `test/widgets/foundation_test.dart`
for the new branch expectations. All other R-01 files and font assets are retained.

Build commands from `mobile/`:

```powershell
& '..\.cache\node\node-v24.22.0-win-x64\node.exe' '..\scripts\run-flutter.mjs' build apk --debug --flavor staging --target-platform android-arm64 --no-pub
& '..\.cache\node\node-v24.22.0-win-x64\node.exe' '..\scripts\run-flutter.mjs' build apk --release --flavor staging --target-platform android-arm64 --no-pub -PallowUnsignedVerification=true
```

R-02 engineering acceptance: COMPLETE. R-03 implementation can begin only on a
separate instruction. Physical navigation/authentication/TalkBack/launcher review
remains an explicit acceptance step when an authorized device is available. No
live account creation or provider operation was performed by these mocked tests.

## R-02 file inventory

### Existing files updated (19)

- `android/app/src/main/res/drawable-v21/launch_background.xml`
- `android/app/src/main/res/drawable/launch_background.xml`
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
- `android/app/src/main/res/values-night/styles.xml`
- `android/app/src/main/res/values/styles.xml`
- `lib/core/routes/app_router.dart`
- `lib/core/routes/app_routes.dart`
- `lib/features/admin/views/admin_sign_in_view.dart`
- `lib/features/ai_assistant/views/assistant_view.dart`
- `lib/features/auth/views/auth_intro_view.dart`
- `lib/features/auth/views/registration_view.dart`
- `lib/features/home/views/home_view.dart`
- `lib/features/shell/views/farmer_shell.dart`
- `lib/features/tools/views/tools_view.dart`
- `test/widgets/foundation_test.dart`

### New files (21)

- `R02_NAVIGATION.md`
- `android/app/src/main/res/drawable/brand_foreground.xml`
- `android/app/src/main/res/drawable/brand_mark.xml`
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- `android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml`
- `android/app/src/main/res/values-night-v31/styles.xml`
- `android/app/src/main/res/values-night/colors.xml`
- `android/app/src/main/res/values-v31/styles.xml`
- `android/app/src/main/res/values/colors.xml`
- `assets/branding/maizedoctor-mark.svg`
- `lib/core/widgets/auth_header.dart`
- `lib/core/widgets/brand_mark.dart`
- `test/auth/r02_auth_test.dart`
- `test/navigation/goldens/admin-dark-360.png`
- `test/navigation/goldens/navigation-light-320-2x.png`
- `test/navigation/goldens/register-dark-360.png`
- `test/navigation/goldens/sign-in-light-360.png`
- `test/navigation/r02_branding_test.dart`
- `test/navigation/r02_navigation_test.dart`
- `test/navigation/r02_visual_test.dart`
- `test/responsive/r02_layout_test.dart`
