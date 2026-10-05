# Mobile

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
No mobile authentication, camera, disease analysis, calculator, AI or admin dashboard
workflow is implemented.

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
Android command-line tools are installed on this workstation; some SDK licenses
still require interactive review before Android builds. See the
[development setup](../docs/15-development-environment.md).
