# Mobile

Phase 13 completes camera/gallery preview, progress, real model results, minimal
farmer sign-in/logout and private paginated history/detail. Shared result components
show the model label/score, uncertainty, image, timestamps and lifecycle. Flutter
calls Node; it never calls FastAPI. See
[farmer detection/history](../docs/29-farmer-detection-history.md) and
[Node/FastAPI integration](../docs/28-node-fastapi-integration.md).

Phase 7 adds leaf gallery/supported camera selection, security preview validation,
photo review, upload progress, safe error/retry and PENDING scan confirmation.
See [scan uploads](../docs/20-scan-uploads.md). Guest uploads remain anonymous with
no personal history; signed-in farmers own their scans. Native access credentials
and the scoped refresh cookie stay only in app memory, with serialized renewal and
identity fencing. Restart requires login; persistent sign-in is future work.
Cloudinary credentials remain entirely in the backend.

Phase 5 provides the Flutter 3.41.9 / Dart 3.11.5 farmer foundation: Home, Scan,
Knowledge, Tools and Profile, centralized light theme/tokens, responsive shell,
reusable state UI and scoped Provider/ChangeNotifier state. go_router 17.5.0 and
http 1.6.0 are locked. Feature destinations clearly show their current availability.

Use MVVM with Provider/ChangeNotifier and the repository pattern:
`View -> ViewModel -> Repository -> API client -> Backend`.
Keep network calls and business logic out of widgets. Disease scanning is the
primary farmer action; include accessible loading, error, and empty states.

[Architecture](../docs/07-flutter-architecture.md) describes the target design.
See [implementation/setup/tests](../docs/19-flutter-foundation.md).
The environment example contains public build configuration only; it is not bundled
or loaded automatically. Omit API_BASE_URL to explore the offline shell. The existing
health API demonstrates the full MVVM data flow through an explicit connection check.
Farmer sign-in/results/history are implemented. Registration, calculators, RAG/Gemini
and admin dashboard remain future work. Camera uses the configured platform picker; unsupported
platforms hide that action. Only Android platform scaffolding currently exists.

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
flutter doctor -v
```

Release API URLs must use HTTPS. HTTP permissions are debug-only. Do not use backend
environment files or provider/signing secrets in Dart defines or Flutter assets.

The Android namespace/application ID is currently `com.maizedoctor.maizedoctor`;
confirm the organization ID before release. Only Android platform files were generated.
Android debug APK packaging is verified with the installed SDK. Kotlin incremental
caching is disabled to avoid the Windows C:/E: plugin-path cache failure. Physical
devices, release signing and other platforms remain future checks. See the
[development setup](../docs/15-development-environment.md).
