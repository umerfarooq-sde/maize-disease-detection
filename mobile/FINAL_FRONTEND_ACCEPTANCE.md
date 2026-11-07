# Final frontend acceptance and release handoff

Date: 2026-11-02. Reviewed revision: `714f02c3b921457447ab6bed84e6897746f3e61b` on `main`.

**Verdict: frontend implementation and automated verification PASS; practical acceptance PARTIAL; public production release NOT READY.**

This handoff supplements [R-07B](R07_FINAL_FRONTEND_RELEASE.md). It does not redesign the application, supersede failed integration evidence, approve scientific content, or authorize deployment. The user explicitly selected **Guest/read-only checks only**; no Farmer/Admin credentials or mutations were used.

## Readiness matrix

| Gate | Result | Evidence and limit |
|---|---|---|
| Frontend implementation | **PASS** | R-01 through R-07B committed; no new confirmed blocking frontend defect reproduced in this acceptance session. This is not complete live feature acceptance. |
| Automated Flutter tests | **PASS** | Retained complete run: **882 passed, 0 failed, 14 opt-in live skips**. Fresh focused run: **42 passed, 0 failed, 0 skipped**. Counts are separate, not additive coverage claims. |
| Goldens | **PASS** | 68 passing comparisons in retained accepted suite; all 68 tracked baseline PNGs have distinct hashes. No baseline regenerated here. |
| Flutter analysis | **PASS** | Fresh `analyze`: no issues, 6.0 seconds. |
| Android compilation | **PASS** | Fresh staging debug build/install/launch succeeded. Retained ARM64 staging debug/release compilation passed; release remains unsigned. |
| Physical-device acceptance | **NOT VERIFIED in full; PARTIAL observations recorded below** | Authorized CPH2365 detected, installed and launched; device disconnected before the checklist could be completed. |
| TalkBack | **NOT VERIFIED** | Package installed; no enabled accessibility service reported at initial inspection. No spoken/focus traversal acceptance performed. |
| Live backend integration | **NOT VERIFIED; preflight FAILED** | Existing launcher dependency probe timed out at `DATABASE_QUERY`, category `TIMEOUT`, elapsed **10365 ms**. No full-stack readiness established. |
| Live AI inference | **NOT VERIFIED** | Offline approved-artifact/configuration probe passed; no running inference endpoint or image prediction verified here. |
| Scientific/domain approvals | **NOT VERIFIED** | Existing licensed-media, agronomic model/data, confidence/field claims and research/commercial-use gates remain. |
| Signed production distribution | **NOT VERIFIED** | Staging release APK fails signature verification as expected for unsigned-verification output. No production package/signing/distribution acceptance. |

## Git and deliverable review

The reported 91 dirty paths had already been committed before this task. Initial working tree was clean, with no staged or untracked files. `git diff --stat` was empty. The current remote `main` was read back with `git ls-remote` and matched `714f02c`; local tracking comparison was 0 ahead / 0 behind.

| Commit | Related deliverable |
|---|---|
| `279f329` | Admin records and management workflows |
| `ff92e80` | Assistant sessions, photo drafts and protected-image failures |
| `a5a43f6` | Farmer action hierarchy and result visibility |
| `714f02c` | Frontend audit and verification reports |

The range `657e1c8..714f02c` contains **91 paths, 4503 insertions and 988 deletions**, entirely under `mobile/`. Source, tests, reviewed golden assets and mobile documentation are included. No backend, AI, database, model or deployment changes were found in that range. No existing changes were reset, cleaned, stashed, reverted or overwritten.

Read-only artifact checks covered all **453 tracked mobile paths**:

- No tracked APK/AAB, keystore, `.env`, Android `local.properties`, build/cache directory, or golden-failure directory found.
- No high-confidence API-token/private-key/credentialed-PostgreSQL-URL pattern candidates found. This bounded pattern check is not a comprehensive secret-audit certification.
- No absolute Windows drive-path candidates found in runtime `mobile/lib/` source.
- All 68 tracked golden PNGs are distinct; no duplicate golden-content groups found.
- Plus Jakarta Sans upright/italic variable assets and **SIL Open Font License 1.1**, copyright 2020 the Plus Jakarta Sans Project Authors, are tracked and bundled in both APKs. No runtime font download was added.
- Original launcher/adaptive assets, native vector brand mark and light/dark launch resources are present. Compiled release resource inspection confirms `mipmap/ic_launcher`, `drawable/brand_mark`, and both launch-background colors; optimized release ZIP filenames are not reliable resource names.
- Existing generated golden failure images remain under ignored `build/r07-golden-failures/`. Nothing was deleted or staged automatically.

## Physical device and actual observations

Device: **CPH2365 / OP4F11L1, Android 13 API 33, ARM64**, connected over authorized USB at the start. Physical display 1080 x 2400, density 480 dpi (nominal 360dp width). Initial system font scale was 0.9. Installed package: `com.maizedoctor.maizedoctor.staging`, label **MAIZEDOCTOR Staging**, version `0.1.0-staging` / code 1. Existing installation was updated without uninstalling or clearing app data.

The normal launcher was inspected before execution. Its read-only `Check` failed before service startup. For device-only acceptance the existing isolated Flutter wrapper was then used with a loopback API URL. **No reverse tunnel was created and no backend/AI service started**; connection-error UI is expected in this limited run, not evidence of a successful live flow.

```powershell
# Actual configured full-stack preflight: failed at database query.
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-on-phone.ps1 -Action Check -DeviceId 9035ae2a

# Actual device-only command, run from mobile/.
node ../scripts/run-flutter.mjs run --no-pub --debug --flavor staging -d 9035ae2a --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

The fresh debug Gradle build took 26.8 seconds; installation took 8.7 seconds. The app became the resumed Android activity and rendered Home. These are tooling durations, **not measured cold-start performance**. The debug connection later ended after the app left the foreground; the installed activity was relaunched once. This evidence does not establish an application crash cause. Subsequently `adb devices -l` was empty and Flutter listed only Windows/Chrome/Edge. Checks stopped rather than inferring passes.

| Requested physical check | Actual result |
|---|---|
| Launcher icon and splash | **PARTIAL**: original branding rendered in app; native/compiled launcher and splash resources verified. Launcher/splash transition not visually accepted on device. |
| Farmer login/registration | **PARTIAL**: blank Farmer sign-in layout visually reviewed. No registration or successful login attempted; no account data changed. |
| Five-tab navigation | **PARTIAL**: Home/Learn/Scan/AI/Tools order and central Scan visibly present; Assistant and Learn screens observed. All branch stacks/reselection/Back journeys not physically completed. |
| Profile entry | Home Guest profile/sign-in action visible with an accessible label; complete Profile journey **NOT VERIFIED**. |
| Assistant Focus sheet | Targeted opening attempted; observation interrupted/unreliable after device/foreground changes. **NOT VERIFIED**, not counted as passed. |
| Keyboard-aware pinned composer | Composer rendered at screen bottom. Keyboard-open usability **NOT VERIFIED**. |
| Conversation retention | **NOT VERIFIED** on device. Existing automated retention/session regressions remain separate evidence. |
| Camera and gallery | **NOT VERIFIED**; no personal gallery opened or photo captured. |
| Image preview | **NOT VERIFIED**. |
| Result and uncertainty | **NOT VERIFIED** on device; no inference performed. |
| Knowledge and citations | **PARTIAL**: library heading and explicit network-error state observed. No successful content/citation retrieval. |
| Reference-image viewer | **NOT VERIFIED**. |
| Fertilizer/yield presentation | **NOT VERIFIED** on device. No configurations changed. |
| History and Analytics | **NOT VERIFIED**; Guest/read-only scope excluded private account journeys. |
| Profile/avatar draft protection | **NOT VERIFIED** on device. Fresh automated photo-draft regressions passed. |
| Admin sign-in/navigation | **NOT VERIFIED**; no Admin login performed. |
| Admin management forms | **NOT VERIFIED** on device; no mutations. |
| Reference date validation | **NOT VERIFIED** on device. Fresh automated calendar-validation regression passed. |
| Admin model health | **NOT VERIFIED** on device. |
| Android system Back | Back input was exercised, but the complete expected route/draft/modal matrix was not observed reliably: **NOT VERIFIED**. |

Home, Assistant connection-error UI and empty Farmer sign-in screenshots were opened and visually inspected. No overflow was visible in those specific portrait captures. Screenshots/XML are local, ignored evidence under `build/final-acceptance/`, not committed public assets. Use `01-launch.png` for Home, `02-assistant.png` for the connection-error state, and `04-focus.png` for the **sign-in screen actually captured**. The last filename reflects the attempted action, not the screen observed; it is not Focus-sheet evidence. No passwords, account details or private scans were captured. Screenshots retain device status-bar indicators and an ordinary Guest question; review/redact separately before sharing externally.

Portrait was observed at the initial device settings. Landscape, large-text, dark-theme, TalkBack, camera/gallery and the remaining flows are **not physically accepted**. No global phone font, rotation, theme or accessibility setting was changed by this task.

## Live integration and security boundaries

The existing `run-on-phone.ps1 -Action Check` returned exit 1:

```text
node dependencies check failed: BACKEND_PROBE_FAILED.
Stage=DATABASE_QUERY, category=TIMEOUT, elapsed=10365ms.
```

This identifies the failing application probe, not a proven DNS/TCP/TLS/provider root cause. No connection string, SQL parameter or credential was printed. There was no repeated startup loop or timeout/URL/TLS/security workaround. No configured Node/AI listener was found; bounded loopback TCP attempts timed out. Therefore no HTTP success/readiness status is claimed for Node `/api/v1/health`, FastAPI `/health` or authenticated model health.

Backend health, AI health, Farmer authentication, Guest/owner scan submission, actual inference, result retrieval, sourced Knowledge, Assistant answers, saved-scan explanation, history persistence, profile retrieval and read-only Admin dashboard access are all **NOT VERIFIED in this session**. Failed connection UI is useful negative-path evidence, not successful server integration. No service credentials were sent to Flutter. No real database/content/provider mutations or paid-provider calls were intentionally initiated.

The current project documents retain a later Phase 25 normal E2E result of **19 PASS / 2 FAIL / 0 selected skips**, with Management connection setup and Farmer Knowledge failures. Earlier 21/21 evidence is historical. This frontend handoff neither erases those failures nor treats Flutter tests as a substitute for a fresh configured full-stack acceptance run.

Offline `ai-service/.venv/Scripts/python.exe -B scripts/phone-ai.py config` passed using existing configuration:

- Model: `mobilenet-v3-small-v2-20261009`.
- Classes: `Common_Rust=0`, `Gray_Leaf_Spot=1`, `Healthy=2`, `Northern_Corn_Leaf_Blight=3`.
- Shared full-frame preprocessing `1.0.0`; temperature 1; confidence threshold null.
- Checkpoint SHA-256: `e95a2e83262637fc1a08b919e6003bddb2fe70664b9c51418f059b7c8287dc66`.
- Metadata SHA-256: `a831116fe1ff8b915543991412f4ab6b334736e8eaca376fab8db3b57e5b263d`.

This is **artifact/configuration integrity**, not model loading, online inference, field validation or confidence approval. No artifacts, dataset splits, formulas, policies or hashes were modified.

Existing HTTPS enforcement in release Flutter configuration, protected-image transport, independent sessions, role guards and backend ownership behavior were not changed. Read-only artifact review is not a new penetration-test certification.

## Automated, build and performance evidence

No source change required another full 882-test run or golden update. The original complete run remains attributable to the unchanged sources, and a focused independent acceptance regression was run now:

```powershell
# From mobile/; existing environment-isolating wrapper.
node ../scripts/run-flutter.mjs analyze
node ../scripts/run-flutter.mjs test --no-pub test/redesign/r07_lifecycle_test.dart test/redesign/r07_media_test.dart test/redesign/r07_presentation_test.dart test/widgets/foundation_test.dart test/widgets/design_system_test.dart --reporter json
```

| Evidence | Pass / fail / skip | Provenance |
|---|---|---|
| Complete retained Flutter suite | **882 / 0 / 14** | `build/r07-suite-accepted.jsonl`, runner success true, 269.665 s; 183 hidden loader events excluded from test counts |
| Goldens, subset of complete suite | **68 / 0 / 0** | No additional golden run or baseline changes in this task |
| Fresh focused suite | **42 / 0 / 0** | `build/final-acceptance/focused-regression.jsonl`, success true, 22.525 s; stderr empty |
| Fresh analysis | PASS | No issues, 6.0 s |
| Fresh staging debug build/install/run | PASS | Real CPH2365; attached Flutter output, 26.8 s build, 8.7 s install |
| Retained ARM64 debug/release compilation | PASS / PASS | `build/r07-android-debug.log` and `build/r07-android-release.log`; 85.8 s / 158.6 s |
| Whitespace/scope | PASS | `git diff --check`; only this handoff added by the acceptance task |

The focused tests cover modal/session lifetime, photo-only dirty drafts, safe protected-image failures, strict dates, action/result visibility, reduced motion, foundational tap/label/contrast checks and large-text component layouts. Existing R-07/R-06D automated layouts include 320/360/412/480/600/840/1024/1280dp and 100/150/200% text. These tests do not establish TalkBack usability on this phone.

APK inventory after the device build:

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `build/app/outputs/flutter-apk/app-staging-debug.apk` | 113389212 | `9ab6ff93bdf5dc8ffec1dcac57b41d8b01da6841e1baf4bf481c1b87982f712b` |
| `build/app/outputs/flutter-apk/app-staging-release.apk` | 19948915 | `8b52f72a44c924a87b3c2767dff4b5641cbca30dedaab0ce4a13fa8023cfef72` |

Both contain ARM64 Flutter engine and the two local fonts/license; some plugin native libraries include other ABIs. The retained release was compiled through the existing unsigned-verification gate, not with an approved production identity. Android `apksigner` verifies the debug certificate; release verification reports `DOES NOT VERIFY / Missing META-INF/MANIFEST.MF`, consistent with unsigned output. Do not distribute it as a production-signed APK.

Tooling note: direct `apksigner.bat` initially failed because inherited `JAVA_HOME` points to a nonexistent `Android Studio1/jbr` directory. Calling its existing JAR with the installed Java 17 executable completed the signature inspections without changing environment files/settings. Flutter's build itself succeeded. Correct Java selection remains a local standalone-tooling consideration, not a reason to alter application code.

No profile-mode performance measurement was completed before device loss. Debug output included startup skipped-frame warnings (including 497 and 161 frames); these are retained as observations, **not a release FPS benchmark or a diagnosed production regression**. Cold-start latency, sustained frame time, memory, chat scrolling and image-decode performance remain unmeasured. No performance acceptance pass is claimed.

## Remaining gates and next actions

1. Reconnect the same authorized phone using a data cable, unlock it, enable USB debugging and accept this trusted PC's RSA prompt. If missing, check Windows Device Manager/OEM USB driver and USB file-transfer mode. Use the full SDK ADB path below when ADB is not on PATH. Do not revoke other authorizations or clear application data unnecessarily.
2. Restore normal configured database/service reachability; diagnose the retained query timeout without weakening TLS/authentication or blindly changing deadlines. Run the existing launcher `Check` once, then start the full stack only after it passes. No database reset, migration or credential rewrite is required by this handoff.
3. Complete the physical checklist with Guest flows first, then separately authorize designated Farmer/Admin test accounts. Complete keyboard, landscape, large-text and TalkBack checks, plus profile-mode frame/memory observations. This task's Guest-only scope does not authorize future private-account mutations.
4. Perform a fresh normal-configuration live acceptance with approved test image/accounts. Verify the selected model, protected images, sourced Knowledge, Assistant, history and Admin read-only views. Keep prior failures and report exact new run identities.
5. Close independent release gates: authorized private deployment host/topology, least-privilege DB identities, HTTPS/private AI networking, shared quotas, monitoring, cleanup, backup/recovery, CI/CD/release provenance, privacy/retention approval, licensed reference media, approved agronomic rules/models and appropriate scientific/licensing claims. An unsigned staging APK cannot close these gates.

```powershell
# From E:\MAIZEDOCTOR; after reconnecting and authorizing USB.
$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
& $adb devices -l
node scripts/run-flutter.mjs devices
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-on-phone.ps1 -Action Check -DeviceId 9035ae2a
# Only after Check passes:
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-on-phone.ps1 -DeviceId 9035ae2a
# In the attached terminal: r = hot reload, R = restart, q = quit.
# Ctrl+C also stops the attached launcher and its owned services/tunnel.
```

No owned backend/AI processes or USB reverse mappings were created in this task. The Flutter debug session ended when its device connection was lost; the installed staging app was retained. No phone settings, real assets, accounts, provider objects or database records were deleted. Local screenshots, test logs, SDK/build caches and compiled artifacts are incidental ignored runtime evidence, not a claim of zero filesystem writes.

## Exact staging recommendation

**Only new deliverable:** `mobile/FINAL_FRONTEND_ACCEPTANCE.md`. All other frontend work is already committed and pushed at the reviewed revision. Do not stage ignored screenshots/logs/APKs, environments, signing material or unrelated future edits.

Suggested review/staging commands, **not executed by this task**:

```powershell
git status --short
Get-Content -Encoding UTF8 mobile/FINAL_FRONTEND_ACCEPTANCE.md
git add -- mobile/FINAL_FRONTEND_ACCEPTANCE.md
git diff --cached --check
git diff --cached --stat
```

Suggested single focused commit, only after explicit authorization: `docs(mobile): record final frontend acceptance and release handoff`. No new application change exists to justify splitting this one report into artificial commits. Recheck remote state before any later push; do not force-push.

**Commit readiness:** report ready for review, left untracked/unstaged. **Push readiness:** existing frontend commits already on remote; this report requires explicit commit/push authorization. **Production-release verdict:** **NOT READY** until the outstanding device, live integration, performance, content/policy and signed-distribution gates are accepted. Stop here; no additional redesign or deployment started.
