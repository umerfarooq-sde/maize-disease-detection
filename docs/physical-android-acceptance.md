# Physical Android USB launch and acceptance

The root [run-on-phone.ps1](../run-on-phone.ps1) runs the existing native
development services and staging debug application. It is not a deployment,
production-readiness claim, or automatic acceptance of agricultural guidance.
Docker, Wi-Fi IP changes and public tunnels are unnecessary.

## Connect and launch

1. On the phone enable Developer options (tap Build number seven times), then
   USB debugging. Connect a **data-capable USB cable**, unlock the phone, accept
   the RSA authorization for this trusted computer and install its OEM USB driver
   on Windows if ADB does not detect it. File-transfer USB mode can help detection.
2. From PowerShell, using the repository root:

   ```powershell
   .\run-on-phone.ps1 -Help
   .\run-on-phone.ps1 -Action Check
   .\run-on-phone.ps1 -DeviceId YOUR_ADB_SERIAL
   ```

   From another directory use `& E:\MAIZEDOCTOR\run-on-phone.ps1 -Action Check`.
   If script policy blocks execution, use a process-only invocation:
   `powershell -NoProfile -ExecutionPolicy Bypass -File E:\MAIZEDOCTOR\run-on-phone.ps1`.
   No persistent execution-policy change is required.
3. Use `-DeviceId` when more than one USB device is connected. The launcher rejects
   emulators, wireless ADB and unauthorized/offline devices. Flutter must also
   identify the selected physical device as supported.
4. The terminal remains attached to Flutter: **r** hot reload, **R** restart,
   **q** quit. Quitting or Ctrl+C runs cleanup. Device acceptance still requires
   the manual observations below; launching an APK does not prove every feature.

```powershell
.\run-on-phone.ps1 -Action Status
.\run-on-phone.ps1 -Action Stop
.\run-on-phone.ps1 -DeviceId YOUR_ADB_SERIAL -StartupTimeoutSeconds 300 -Verbose
```

`Check` reads prerequisites/configuration, runs `flutter doctor`, `flutter devices`
and `adb devices`, verifies configured SQL/pgvector/model registry and configured
Redis, and inspects forwarding. It does not start application services, alter
environment files, install packages, migrate databases or change ADB reverse rules.
SDK tools may maintain their own caches and ADB server as usual. `Status` does
not start application services or forwarding. `Stop` sends requests only to this
launcher's recorded supervisors and removes only its exact owned reverse mapping.
Logs remain for diagnosis. No cleanup CLI or provider/database deletion is invoked.

## What runs

Configuration is loaded by the existing Node `loadEnvironment()` and AI
`load_settings()` loaders. Their OS-environment/mounted-secret/dotenv precedence
is preserved; conflicting inherited `PORT`, `HOST` or service settings fail clearly
rather than silently overriding saved configuration. Server values never become
Flutter dart-defines. Both native services must use development, loopback settings.

- Node: the project-selected Node runtime, `npm run dev` in `backend/`.
- FastAPI: `scripts/start-ai.ps1`, its existing AI Python environment and
  `python -m app.server`. The approved classifier loads once in its lifespan.
- PostgreSQL/pgvector: existing configured service, read-only startup probes. No
  local database is provisioned. Both Node and RAG database access are checked.
- Redis: checked **if configured**, never silently disabled. A missing configured
  Redis service must be restored through the existing development setup.
- Cloudinary/Google/Gemini: server configuration checked; no upload, embedding or
  generation request is made by ordinary startup. Provider/network/quota availability
  remains a real manual scan/assistant acceptance check, not a mock pass.
- Flutter: existing secret-isolating `scripts/run-flutter.mjs` wrapper,
  `run --debug --flavor staging -d SERIAL --dart-define=API_BASE_URL=.../api/v1`.
  Existing `lib/main.dart`, routes, Provider/MVVM and API client remain in use.

The launcher discovers the Node and AI ports from validated configuration.
For the configuration inspected on 2026-10-28 they are 3000 and 8000 respectively.
Only Node is forwarded: `adb -s SERIAL reverse --no-rebind tcp:3000 tcp:3000`.
Flutter uses `http://127.0.0.1:3000/api/v1` on the phone. The AI service, DB and
provider secrets remain private to the host. The existing Android **debug-only**
cleartext exception is used; release cleartext rejection is unchanged.

Preflight pins the selected model/version, checkpoint/metadata/calibration digests,
class mapping, shared full-frame preprocessing 1.0.0 and T=1/null threshold.
Actual authenticated model health must agree; a request without authentication
must be rejected. Node's own configured AI credential must also work. Model loading
and DB query failures block Flutter startup. No threshold/model is invented.

## Ownership and recovery

Every Start holds an exclusive session lock. Owned service trees run in hidden
consoles under Windows Job Objects; state includes creation-time identities and
session IDs. A launcher-only Node preload asks the existing application SIGBREAK
handler to drain before terminating npm/tsx watchers, and acknowledges only a
successful application exit. Existing Node options are preserved; no shutdown HTTP
endpoint is added. FastAPI receives CTRL+C in its own console. Shutdown allows a
bounded drain before the job removes remaining descendants; a forced deadline is
recorded and warned, never called a successful application drain. Reused healthy services
and preexisting identical ADB mappings are never claimed. Port conflicts are errors.
PID reuse cannot cause a saved PID to terminate an unrelated process.

Quitting normally stops owned services and removes the owned tunnel. If the terminal
is forcibly closed, supervisors detect owner death or released lock and stop their
children; run Stop afterward to reconcile USB state. Stop from a second terminal
does not kill the foreground Flutter tool: use q/Ctrl+C in its original terminal.
If USB cleanup cannot be confirmed, state is retained for another Stop.
Only acknowledged created mappings are claimed. An interrupted/uncertain creation
is preserved. A changed ADB transport means the original tunnel was lost: any
externally recreated rule is unowned and is retained.

USB reset drops reverse rules. Quit Flutter, reconnect/unlock/authorize the same
phone, run Stop if a session remains, and rerun Start. This rechecks dependencies
and reinstates the device-specific tunnel; no unrelated rule is removed. Do not
use `adb reverse --remove-all`, kill every Node/Python process or reset the database.

Logs/state: `.cache/phone/<session>/node.log`, `ai.log`, supervisor logs/state;
`.cache/phone/session.json` identifies the active session. Only owned services have
launcher logs. Flutter/hot reload output remains in the active terminal; record
manual evidence locally with credentials and personal data redacted. All cache
contents are ignored by Git. Logs can contain private application information;
do not publish them unreviewed. The launcher prints safe probe codes, not raw errors
or connection strings.

## Manual acceptance record

**All rows start NOT RUN.** Fill each Result with PASS, FAIL or BLOCKED, plus an
evidence identifier, timestamp, app commit/build, phone model/Android version and
observed behavior. Keep screenshots/logs locally; redact accounts, JWTs, private
photos and provider keys. Record actual failures; do not replace them with later
passes. Synthetic generated test images are transport fixtures, never disease
reference photos or model-accuracy evidence. Use a real maize photograph you are
authorized to upload for subjective scan UX testing; no training/test-set scoring.

| ID | Action | Expected observation | Result / evidence |
|---|---|---|---|
| G01 | Open staging app; Home and main navigation | Correct app, responsive layout, scan action discoverable | NOT RUN |
| G02 | Gallery selection; preview; cancel/reselect | Correct preview/orientation; no upload before submit | NOT RUN |
| G03 | Camera capture and permission denial/retry | System capture where available; usable denial/cancel state | NOT RUN |
| G04 | Submit authorized maize photo as guest | Loading/progress ends with real Node→FastAPI prediction or honest retryable error | NOT RUN |
| G05 | Inspect result image/time/model status/class/confidence | “Model prediction”; LOW_CONFIDENCE/THRESHOLD_UNCONFIGURED; no certainty claim | NOT RUN |
| G06 | Open sourced guidance | Curated disease knowledge, reference attribution, honest missing evidence | NOT RUN |
| G07 | Guest history | No personal account history fabricated or retrospectively attached | NOT RUN |
| F01 | Register disposable FARMER; duplicate/invalid input | FARMER only; useful errors; no Admin self-registration | NOT RUN |
| F02 | Login/logout; wrong password | Intended session/validation; no leaked credentials | NOT RUN |
| F03 | Edit own profile | Saved projection and validation; no access to another account | NOT RUN |
| F04 | Upload/change/remove own avatar | Protected display; committed outcome visible; retry reconciles state | NOT RUN |
| F05 | Farmer scan, result, paginated history/detail | Scan saved to current farmer, correct prediction/time/image | NOT RUN |
| F06 | Open protected saved image | Owner access succeeds; other user/guest denied | NOT RUN |
| F07 | Farmer analytics with new and scanned accounts | Honest empty/usage statistics; no model-accuracy claim | NOT RUN |
| F08 | Browse four supported Knowledge entries | Real catalogue with reviewed content/optional metadata only when returned | NOT RUN |
| F09 | Search disease documents; source/details/back navigation | Relevant sourced content, loading/error/empty states | NOT RUN |
| F10 | Ask relevant AI question; inspect sources | Grounded response or explicit insufficient evidence; bounded request | NOT RUN |
| F11 | Ask unrelated/injected/overlong question | Scope/validation/grounding preserved | NOT RUN |
| F12 | Explain owned scan, then attempt other-account context | Original classifier/uncertainty unchanged; ownership enforced | NOT RUN |
| F13 | Fertilizer and yield calculators | Pending when no approved configuration; deterministic quantities/version/source only for approved rules | NOT RUN |
| A01 | Intended Admin login/navigation | Separate ADMIN workspace/session, Farmer denied | NOT RUN |
| A02 | Dashboard, AI operations and model health | Real aggregates; offline evaluation separate from runtime; unavailable distinct from zero | NOT RUN |
| A03 | Farmer management and audits | Paginated, authorized; inspect only real users, mutate only disposable fixtures | NOT RUN |
| A04 | Catalogue metadata with reviewed disposable fixture | Source/revision/audit validation; immutable four model labels | NOT RUN |
| A05 | Knowledge version/reindex/review | Old embeddings not silently active; sourced historical references retained | NOT RUN |
| A06 | Media draft/review/publication/ordering/delete | Rights/provenance required; protected delivery; clean only owned test fixture | NOT RUN |
| A07 | No approved reference images | Honest empty gallery; no dataset/synthetic photo published as real reference | NOT RUN |
| E01 | Disconnect/reconnect USB and restore tunnel | Meaningful error/retry; Stop/Start restores forwarding to same phone | NOT RUN |
| E02 | Corrupt/unsupported/oversized image | Validated rejection; no false success or stuck loading | NOT RUN |
| E03 | Simulated network timeout/service unavailability | Loading finishes with meaningful error; retry safe, not false empty data | NOT RUN |
| E04 | Navigate during loading; rapid repeat actions | No stale overwrite, duplicate destructive mutation or stuck busy state | NOT RUN |
| E05 | Logout/change account during private requests | No previous account image/history/profile leaks | NOT RUN |
| E06 | Restart app / expired session | Current intentional volatile-session behavior; sign in again, no false persistent login claim | NOT RUN |
| E07 | q / Ctrl+C / Stop / Start again | Only owned processes/rule stop; reused services and unrelated mappings survive | NOT RUN |
| E08 | Camera unavailable / long text / keyboard / orientation | Safe areas, scrolling, validation and responsive controls remain usable | NOT RUN |

No real-user suspension, bulk deletion, production credential changes, schema resets
or provider asset deletion belongs in this acceptance run. For Admin mutation tests
use explicitly approved disposable accounts/content/media and record their safe cleanup.
Physical acceptance and public release remain separate from launcher verification.

## Engineering verification

Run offline decisions and generated Windows service-process tests:

```powershell
.\scripts\test-phone-launcher.ps1
ai-service\.venv\Scripts\python.exe scripts/test_phone_service.py
.\scripts\use-project-node.ps1
node --test scripts/phone-stop-hook.test.mjs scripts/flutter-test-environment.test.mjs scripts/flutter-release-environment.test.mjs
```

### Executed 2026-10-28 (Windows PowerShell 5.1)

| Verification | Actual result |
|---|---|
| PowerShell parser, device/reverse decisions, real occupied port, argv quoting, bounded tool descendants (including actual timeout-child removal), safe Stop/transport reset | 30 passed / 0 failed |
| Generated real Windows console/Job Object fixtures: graceful/forced shutdown, PID fencing, owner-lock release, new-session restart | 5 passed / 0 failed / 0 skipped |
| Node shutdown acknowledgement and SDK/release environment isolation | 5 passed / 0 failed / 0 skipped |
| Strict TypeScript compilation of launcher backend helper | Passed |
| Ruff lint/format using AI project's rules | Passed |
| Actual native Node + FastAPI startup/reuse identification, internal authentication/model health, Node→AI authentication, SQL health | Passed; final verified service session `874c84c64ae9405297d7a9986a5d29d0` |
| Actual backend graceful shutdown | `Stopping backend (SIGBREAK)` → `Backend stopped`; applicationDrained=true, forced=false; npm watcher exit1 after CTRL+C is distinguished from successful application drain |
| Actual AI graceful shutdown | service_stopped; exit0/forced=false; both configured listening ports released |
| Controlled partial-start failure | Real AI starts; next-service port conflict rejected; AI cleaned, unrelated generated listener preserved. Session `9daa1c6c725340ff9b887f8c61ae21c6` |
| Real PostgreSQL/pgvector/model registry and separate Python RAG SQL | Passed with configured credentials; Redis not configured, not disabled by launcher |
| Actual Help/Status/Stop; Check from outside repository | Help/Status/Stop succeed; Check reaches valid dependencies and then correctly fails for absent USB phone |
| Flutter doctor/devices/ADB | Flutter3.41.9/Dart3.11.5 and Android SDK36.1 detected; standard Program Files paths restored to SDK-only allowlist so doctor no longer crashes |
| Physical phone discovery | CPH2365 was briefly authorized, then disconnected before launch; final ADB list empty |
| Live ADB reverse, APK launch/hot reload, manual feature acceptance | **NOT VERIFIED**; no physical-device pass claimed |
| Cloudinary/Google/Gemini availability | Configuration present; provider operations deliberately not called by preflight |

Outstanding Android SDK licenses require user review through
`node scripts/run-flutter.mjs doctor --android-licenses` after selecting project
Node. Missing Visual Studio concerns Windows desktop development, not Android.
An earlier real database readiness probe failed; later authenticated checks and
native starts passed. Its exact historical subtype is not established. No timeout,
TLS, database role or environment setting was weakened to obtain a pass.

Earlier SDK-probe and watcher-shutdown issues found during implementation were
repaired and rechecked; cache evidence is retained. Existing private environment
files and preexisting user-edited files match the captured baseline. No database
migration, provider asset deletion, model change, training or public deployment ran.
Historical Phase 24/25 reports are preserved; this checklist does not replace them.
