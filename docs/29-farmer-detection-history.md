# Farmer disease detection and history

Phase 13 completes the farmer scan experience using the existing Node/FastAPI
inference flow. No RAG, Gemini, treatment recommendations, training or model-policy
changes are included. Read [inference integration](28-node-fastapi-integration.md)
for authoritative image, persistence, retry and uncertainty contracts.

## Farmer flow

Select a gallery image or use the supported platform camera, review the preview,
then choose **Analyze leaf**. Upload progress measures transfer; after transfer the
screen shows **Waiting for analysis** without inventing an inference percentage.
The existing API uploads unchanged image bytes to Cloudinary, creates the durable
scan, calls private FastAPI and persists the validated outcome in PostgreSQL.
Flutter calls only Node. A completed scan opens its result screen; interrupted or
failed analysis remains explicit and offers a safe retry or a fresh scan.

Results show the leaf image, friendly class label, model score, scan and inference
time in device-local time, lifecycle status, model version and preprocessing version.
Literal API class labels remain unchanged. The UI says **Model prediction** and
explains that the score is classifier output, not a probability that a diagnosis is
correct. Healthy does not rule out other problems. No agricultural guidance is invented.

The approved model remains `mobilenet-v3-small-v2-20261009` with shared full-frame
preprocessing `1.0.0`. With no approved operational confidence threshold, every
current result is `LOW_CONFIDENCE/THRESHOLD_UNCONFIGURED`, including high scores.
The UI explicitly explains this. Future configured thresholds remain qualified
model predictions rather than confirmed diagnoses.

## Identity and privacy

Guest scans remain `user_id = null`. Guests never query personal history. The
original private upload key permits reading/retrying that guest scan, retained
only in the active local flow. It is never included in a URL, log or `toString`.
After navigation data is lost or the app closes, a guest UUID alone cannot retrieve
the result. Signing in does not assign old guest scans to the account.

Minimal farmer sign-in/sign-out uses the existing backend auth endpoints. Registration,
password recovery, persistent sign-in and an admin dashboard are not added.
JWT access credentials and the refresh cookie stay in app memory only. There are
no preference/file token stores or plaintext fallbacks. Restarting requires sign-in.
The native transport admits only the backend's narrowly scoped HttpOnly/Strict refresh
cookie, requires Secure/HTTPS for `__Host-` cookies, rejects Domain cookies and sends
it only to configured-origin refresh/logout routes. Redirects remain disabled.
This implementation targets the existing native Android application; browser cookie
handling and additional platform scaffolding require separate verification.

The API client renews nearly expired access tokens through one serialized refresh
operation. A network failure fails closed rather than changing an authenticated
submission into a guest scan. Current authenticated 401s clear the session. Identity
revisions fence late HTTP bodies/refresh failures and remount scoped scan/history/result
ViewModels. Route extras are bound to their original revision, preventing a cached
result from appearing after logout/account change. Offline logout forgets local
credentials immediately and explains that server revocation could not be confirmed;
the existing server's bounded session expiry still applies.

History ownership is enforced by Node/Prisma, regardless of navigation. The existing
signed Cloudinary image URL remains a bearer capability: do not publish it. This
phase does not change image delivery, retention, EXIF stripping or deletion policy.

## Public APIs

| Method and route | Behavior |
|---|---|
| `POST /api/v1/scans` | Existing anonymous/farmer multipart image upload and inference; 201 new scan, 200 same-key replay; explicit saved FAILED outcomes |
| `GET /api/v1/scans/:scanId` | Existing owned farmer read or anonymous original private-key read |
| `GET /api/v1/scans?limit=20&cursor=<UUID>` | New FARMER-only paginated personal history |
| `POST /api/v1/auth/login` | Existing normalized farmer login consumed by the mobile session repository |
| `POST /api/v1/auth/refresh` | Existing cookie rotation; serialized by the native client |
| `POST /api/v1/auth/logout` | Existing server revocation and local credential clearing |

History uses the standard single envelope:

```json
{
  "success": true,
  "data": { "items": [], "nextCursor": null },
  "requestId": "server-generated-UUID"
}
```

Items are the existing safe public scan projection, including `image`, `status`,
`createdAt`, `finishedAt`, nullable `prediction` and safe `analysisError`.
No user/session IDs, raw model response, storage public ID, secret or internal path
is returned. Limit defaults to 20 and accepts integers 1–50. A cursor is the last
returned scan UUID; omit it for the newest page. Ordering is `createdAt DESC, id DESC`
using PostgreSQL's native microsecond timestamp precision and Prisma's UUID cursor.
Fetch limit+1 to determine whether another page exists; `nextCursor=null` means done.
Concurrent new scans do not shift an existing cursor page; refresh fetches the latest
first page. The list is not a database snapshot across mutations. A removed cursor
requires refreshing. Foreign, anonymous or missing cursors return 404 without revealing
ownership. Guests receive 401; ADMIN receives 403; unknown query/owner overrides
receive 400. Reads are rate limited and `Cache-Control: no-store`.

## Flutter structure and state

```text
core/network/api_client.dart           bounded JSON/multipart, volatile cookie, identity fencing
core/storage/memory_session_tokens.dart access expiry and identity revision
core/routes/app_router.dart            nested result/history, private local route extras
data/models/                          farmer account, typed scan/prediction/history page
data/datasources/scan_datasource.dart   upload/read/history API serialization
data/repositories/                    farmer session, scan upload, scan records
features/auth/                        sign-in View + app identity ChangeNotifier
features/disease_detection/            Scan/Result ViewModels, views, shared result components
features/scan_history/                 scoped list ViewModel, view, lazy history tiles
features/profile/                     current farmer/guest and sign-out/history access
```

Views dispatch intents to ChangeNotifier ViewModels. Repositories own typed remote
operations through the API client. Identity is app-scoped; feature state is scoped to
its route and identity revision. Widgets contain no raw HTTP or business `setState`.
Shared result components render fresh scans and history details consistently, using
the existing design tokens, safe scrolling, responsive widths and accessible states.

Gallery cancellation keeps a draft. Validation, permissions, offline/timeout, rate
limits and failed inference use safe messages and retry controls. Same-photo analysis
retry preserves the original private key and bytes, avoiding another Cloudinary upload.
History does not download a saved image to replay inference: when original bytes/key
are unavailable, the detail offers a new scan instead. Pending reads poll sequentially
at most six times (two-second interval, bounded elapsed time), then allow a manual
check; disposal or generation changes discard late work. There is no indefinite loop.
History supports refresh, explicit load-more, retained items on paging failure,
empty state, unavailable thumbnails and signed-out state without guest history requests.

## Verification and local commands

From `mobile`:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --no-pub
```

From `backend`:

```powershell
npm.cmd run check
npm.cmd run db:validate
npm.cmd run db:status
npx.cmd tsx --test tests/scans/history.database.integration.ts
# Configured real Cloudinary/PostgreSQL, running private FastAPI and Flutter on PATH:
node ../scripts/check-scan-upload.mjs --inference --farmer
```

From root, `scripts/check-development.ps1 -Component AI` runs all FastAPI tests,
Ruff and strict mypy. The optional real provider harness creates only two generated
farmer fixtures and one synthetic PNG, verifies real login/upload/inference/history,
cross-farmer detail/cursor denial and logout, then removes its own assets/rows/users.
It supplies throwaway credentials via the child environment and does not print them.
Dataset images and final test partitions are not read.

Results and remaining limits are recorded in [project state](PROJECT_STATE.md).
Native camera/gallery interaction on a physical device or a responsive emulator,
release packaging, browser/persistent login, independent field accuracy and commercial
dataset clearance remain separate checks. Stop after Phase 13.
