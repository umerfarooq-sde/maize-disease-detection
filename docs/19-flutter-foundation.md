# Flutter foundation

Phase 5 implements the farmer application shell and reusable UX/engineering foundation.
Flutter 3.41.9 / Dart 3.11.5 and Provider 6.1.5+1 are preserved. The resolver added
compatible go_router 17.5.0 and http 1.6.0; the lockfile records exact versions.
Phase 7 extends the Scan branch with scoped MVVM selection/preview/upload state and
multipart transport; see [scan uploads](20-scan-uploads.md) for current behavior.

## Important structure

```text
mobile/lib/
  main.dart                         entry point
  app.dart                          dependency composition and router lifecycle
  core/
    constants/app_constants.dart    app name and transport bounds
    theme/                          design_tokens.dart, app_theme.dart
    routes/                         app_routes.dart, app_router.dart
    network/                        app_config.dart, api_client.dart, api_response.dart
    storage/access_token_source.dart
    exceptions/app_exception.dart
    utils/responsive.dart
    widgets/                        page, cards, loading/empty/error, feature intro
  data/
    models/backend_health.dart
    datasources/backend_datasource.dart
    repositories/backend_repository.dart
  features/
    home/{views,view_models}/
    shell/views/farmer_shell.dart
    tools/views/tools_view.dart
    auth/views/
    disease_detection/views/
    disease_knowledge/views/
    ai_assistant/views/
    fertilizer_calculator/views/
    yield_calculator/views/
    scan_history/views/
    analytics/views/
    profile/views/
    admin/views/
```

Every feature directory contains a meaningful routed foundation view. Additional
models/ViewModels/repositories are created when real workflows require them.

## MVVM and Provider

```text
HomeView / ConnectionCard
  -> HomeViewModel.checkConnection()
  -> BackendRepository / ApiBackendRepository
  -> BackendDatasource
  -> ApiClient
  -> GET Node /api/v1/health
```

Views render state and forward intent; widgets never call HTTP. The feature-scoped
HomeViewModel owns loading, typed health/errors, duplicate-request suppression and
retry. Completion after disposal cannot notify listeners. Launch makes no automatic
network request. Root Provider registrations contain stateless configuration/client/
datasource/repository dependencies; ChangeNotifierProvider belongs at the Home route.
The indexed shell preserves it across tab changes. Future state stays feature-scoped.
The application owns and disposes its router/client. StatefulWidget is used for
resource lifecycle; business state does not use setState.

## Design system and responsiveness

design_tokens.dart centralizes forest scan accents, warm ivory/white surfaces, dark
ink, muted slate, blue knowledge accents and wheat/amber tools. Roboto is explicitly
selected for the Android baseline. Typography defines display/title/body/label scales
and readable line heights. Spacing uses 4/8/12/16/24/32/40 points; radii use 12/20/28;
minimum interactive targets are 48 points. Material 3 light themes cover cards,
buttons, inputs, app bars, navigation, progress, dividers and snackbars.

Shared widgets provide scrolling safe-area pages, navigation cards, progress
announcements, empty states and safe errors with retry. Foundation screens clearly
show unavailable functionality; diagnoses, advice, charts and account state are never
simulated. Scan Leaf is visible at 320x568. Text wraps and scales without a global
clamp; scroll surfaces respond to keyboard insets and long content.

Phones use a five-area bottom bar; 840-point layouts use a scrollable navigation
rail, including short landscape screens. Content is constrained to 1120 points;
paired cards become columns below 620 available points or with large text. Large-text
rails retain tooltips/semantic destination names while omitting visual labels.

## Routes and current availability

| Area | Route | Current behavior |
|---|---|---|
| Home | /home | Scan action, exploration cards, optional connection check |
| Scan | /scan | Gallery/supported camera, review, secure upload, progress/error/retry and pending confirmation; no analysis |
| Knowledge | /knowledge | Reviewed-library-unavailable state |
| Tools | /tools | Navigation to prepared tool areas |
| Profile | /profile | Guest foundation and navigation to account/history/insights |
| Fertilizer, yield, assistant | /tools/fertilizer, /tools/yield, /tools/assistant | Foundation views; no computation/AI |
| Sign-in, history, analytics | /profile/sign-in, /profile/history, /profile/analytics | Foundation views; no auth, records or charts |
| Admin | /admin | Reserved access boundary; no privileged UI/data |

StatefulShellRoute.indexedStack preserves main-area navigation/scroll state. Nested
routes support back; unknown routes provide a safe return-home state. Admin sits
outside the farmer shell. Its unavailable page is not authorization: future
session-aware routing and backend RBAC must precede privileged requests/rendering.

## Public API configuration

From mobile:

```powershell
flutter pub get
flutter run
# Android emulator; start the Node backend separately:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
# A local file containing only public mobile configuration is also supported:
flutter run --dart-define-from-file=.env
```

API_BASE_URL is public build configuration, never a secret. No production URL is
hardcoded. Omission leaves an offline shell; checking connection shows a safe
unavailable message. Explicit malformed values fail without echoing input. URLs must
end in /api/v1, omit credentials/query/fragment, and use HTTPS in release. Never pass
backend/AI .env files or signing/provider keys as Dart defines. The public template
is not bundled as an asset or automatically loaded.

The API client owns JSON/UTF-8 handling, one-envelope parsing, safe HTTP/error
mapping and bounded correlation IDs. It applies a 15-second whole-request timeout,
aborts supported transports and limits responses to 1 MiB. Relative resource paths
cannot escape the configured origin; redirects are disabled. Access headers are
explicitly opt-in through AccessTokenSource; there is no plaintext implementation,
token persistence or mobile auth flow. Write requests include the backend JSON/
custom-header contract. Refresh-cookie storage/rotation belongs to a later mobile
authentication phase.

The health datasource explicitly accepts HTTP 503 reports and checks status/time/
database consistency. Ordinary non-success responses become application errors.
Raw server messages, transport failures, URLs, bodies or credentials are never
displayed/logged. Android INTERNET permission is present in the main manifest;
cleartext permission is debug-only. For a physical device use a reachable LAN URL
and explicit backend HOST configuration. Emulator/LAN access may also require host
firewall/network setup; this phase changes no deployment/firewall settings.

## Verification and boundaries

```powershell
dart format lib test
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
# Optional read-only live check against an already running development backend:
flutter test --no-pub test/integration/backend_connection_test.dart --dart-define=RUN_LIVE_API_CHECK=true --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

Tests cover transport/auth-header boundaries, JSON/errors/timeouts/response bounds,
repository health contracts, ViewModel transitions/retry/disposal, navigation/back/
unknown/admin, seven phone/landscape/tablet sizes, 200% text, keyboard/safe insets and
long content, plus Android tap/label/contrast guidelines. Widget tests load SDK Roboto
and Material icon fonts for realistic layout. Rendered 320/360/1024 previews are
written to ignored mobile/build for review. The live test is skipped unless enabled.

Phase 5 did not include APK/device verification. Phase 7 subsequently verified the
debug Android APK and implemented camera/gallery uploads; interactive picker checks
remain blocked by emulator System UI errors. See [scan uploads](20-scan-uploads.md).
Only Android platform scaffolding exists. Localization, dark theme, secure mobile
auth, persistence, complete business/admin workflows and AI/ML/RAG remain future work.

References: [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide),
[stateful routing](https://pub.dev/documentation/go_router/17.5.0/go_router/StatefulShellRoute-class.html),
[http client/abort support](https://pub.dev/packages/http).
