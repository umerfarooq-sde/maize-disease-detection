# Mobile

Phase 1 contains a minimal Flutter 3.41.9 / Dart 3.11.5 Android scaffold, Provider,
Flutter lint rules, a dependency lockfile, and one scaffold widget test. The single
development label is a scaffold placeholder; farmer/admin screens and a design
system are not implemented.

Use MVVM with Provider/ChangeNotifier and the repository pattern:
`View -> ViewModel -> Repository -> API client -> Backend`.
Keep network calls and business logic out of widgets. Disease scanning is the
primary farmer action; include accessible loading, error, and empty states.

[Architecture](../docs/07-flutter-architecture.md) describes the target design.
The environment example contains public configuration only and is not loaded yet.

```powershell
flutter pub get
flutter analyze
flutter test
flutter doctor -v
```

The Android namespace/application ID is currently `com.maizedoctor.maizedoctor`;
confirm the organization ID before release. Only Android platform files were generated.
Android command-line tools are installed on this workstation; some SDK licenses
still require interactive review before Android builds. See the
[development setup](../docs/15-development-environment.md).
