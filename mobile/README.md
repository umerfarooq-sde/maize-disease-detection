# Mobile

Phase 23.6 completes farmer registration from Profile → Sign in and replaces the
Knowledge placeholder with the real sourced catalogue, semantic search and detail
pages. Both use route-scoped MVVM and existing Node contracts; registration leads
to explicit sign-in. See [current contracts](../docs/40-farmer-registration-knowledge.md)
and [verification report](../docs/phase-23-6-remediation-report.md). No model, corpus,
session-persistence or provider-secret changes are included.

Phase 22 adds `/admin/model-health` via the Admin overview health icon. Scoped MVVM
shows offline evaluation separately from live request/latency/uncertainty/output
signals, with retry and explicit research/drift limits. See
[model health](../docs/38-model-health-dashboard.md).

Phase 21 adds `/admin/manage` through the Admin overview settings icon. Named
forms manage sourced document revisions, fixed-context display metadata and
reviewed fertilizer/yield drafts, with validation, indexing, confirmed publication/
deactivation, loading/errors and session fencing. Model class mappings stay
read-only and rates start blank. See [Admin management](../docs/37-admin-management.md).

Phase 20 adds `/admin` outside the farmer shell: separate volatile Admin sign-in,
overview cards/charts, real account/scan aggregates, model registry/configuration,
recent activity and loading/retry/empty states. Shared rotation/revocation code
keeps Admin and Farmer credential stores, cookies and clients separate. See
[Admin dashboard](../docs/36-admin-dashboard.md).

Phase 19 replaces the Field insights placeholder with private saved-scan cards,
label distribution, UTC activity periods and recent activity pagination. Date
presets/custom filters, guest/empty/loading/retry states and uncertainty wording
use the existing design system. A route-local Provider/ViewModel and repository
use the shared authenticated Node API client; account changes fence old results.
These are usage/prediction statistics, not measured accuracy. See
[farmer analytics](../docs/35-farmer-analytics.md).

Phase 18 replaces Tools → Yield with a scoped planning form using the same area/unit
components as fertilizer. It displays reviewed scenario/source/assumptions and exact
server results with versions, loading/retry and stale-configuration handling.
Production calculation stays disabled until authoritative yield configuration is
approved. No client yield arithmetic or Gemini call is added. See
[expected yield](../docs/34-expected-yield-calculator.md).

Phase 17 replaces Tools → Fertilizer with a scoped MVVM form for explicit area/units,
reviewed rule selection, deterministic results, source/assumption/version display and
loading/error/retry. Real recommendations remain pending; no sample rate or client
fertilizer arithmetic is bundled. See [fertilizer calculator](../docs/33-fertilizer-calculator.md).

Phase 16 adds the farmer assistant at Tools → Ask your assistant. Guests can ask
scoped maize questions; farmers can choose a completed private scan or open an
explanation from its result screen. Reviewed answers show citations, source provenance
and honest uncertainty, with loading, retry and empty/error states. At most 12 local
turns are retained; no transcript or conversation is stored under an account. Explicit
condition/topic filters support bounded follow-ups. See
[farmer AI assistant](../docs/32-farmer-ai-assistant.md).

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
Farmer sign-in/results/history, the grounded assistant and fertilizer/yield calculator
foundations, farmer registration, disease-knowledge browsing/search/details and Admin
dashboard/management/model health are implemented. Approved agronomic calculator
content and profile customization remain pending.
The assistant calls Node only; Gemini/provider secrets stay server-side. Camera uses
the configured platform picker; unsupported
platforms hide that action. Only Android platform scaffolding currently exists.

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
flutter doctor -v
```

Assistant data/ViewModel/widget/navigation tests run with `flutter test`. The opt-in
real Flutter → Node → FastAPI/retrieval/Google contract is launched from the repository
root with `node --env-file=backend/.env scripts/check-assistant.mjs`; it needs the
configured Phase 14/15 services and approved model record, and removes only its own
throwaway account/scan fixtures. See the assistant guide for scope and results.

Release API URLs must use HTTPS. HTTP permissions are debug-only. Do not use backend
environment files or provider/signing secrets in Dart defines or Flutter assets.

The Android namespace/application ID is currently `com.maizedoctor.maizedoctor`;
confirm the organization ID before release. Only Android platform files were generated.
Android debug APK packaging is verified with the installed SDK. Kotlin incremental
caching is disabled to avoid the Windows C:/E: plugin-path cache failure. Physical
devices, release signing and other platforms remain future checks. See the
[development setup](../docs/15-development-environment.md).
