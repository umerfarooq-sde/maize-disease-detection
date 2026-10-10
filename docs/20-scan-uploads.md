# Phase 7: leaf image upload and pending scans

This document records the original Phase 7 contract. Phase 12 preserves the upload
journal/storage foundation and adds compatible admission, inference, prediction
persistence, owned reads and failed-analysis retry. Current response/lifecycle
behavior is documented in [Node/FastAPI integration](28-node-fastapi-integration.md).

Implemented on 2026-10-06. This phase saves a leaf image and a PENDING scan only.
There is no leaf/disease classifier, ML preprocessing, inference, prediction,
AI/RAG call, scan polling/history API or completed diagnosis. Phase 6 was not
implemented implicitly; mobile sign-in and secure session persistence remain deferred.

## Flow and ownership

1. Flutter's image datasource uses image_picker for gallery or supported camera
   capture. Selection can be cancelled. Android lost picker results are recovered
   when the Scan route opens and displayed for review; recovery never uploads automatically.
2. The datasource reads at most 5 MiB, detects the format and decodes a bounded
   preview. The Scan ViewModel holds original image bytes, selection/loading/error
   state, transfer progress and a cryptographically random UUIDv4 request key.
3. View -> scoped ChangeNotifier -> ScanRepository -> ScanDatasource -> ApiClient
   sends one multipart image to Node. Provider owns stateless dependencies; widgets
   never call HTTP or perform image/upload business logic.
4. Node's route applies rate limits, optional live-session authentication, request
   validation, a two-upload process limit and bounded multipart parsing. The service
   verifies signatures, claimed MIME, extension, dimensions and complete pixel decoding.
   This is upload-security decoding; bytes are not resized, segmented, normalized,
   re-encoded or converted into an ML tensor. Python retains all future ML processing.
5. Before the provider call, a repository claims a durable upload journal record.
   Cloudinary receives the unchanged file through its server SDK under a generated
   `maizedoctor/scans/<server-UUID>` public ID with overwrite disabled.
6. After upload confirmation, a short Prisma transaction locks the active journal
   entry, inserts a PENDING scan and marks the journal COMPLETED. PostgreSQL stores
   HTTPS image URL, unique public ID, detected MIME, byte count, upload/creation
   timestamps and optional farmer ID. It stores no binary image.
7. The safe API response lets Flutter show "Photo saved" while clearly stating
   that disease analysis is not available. Transfer reaching 100% changes the label
   to "Saving your scan" until Cloudinary/database completion returns.

Without Authorization, `scans.user_id` is NULL. A supplied bearer token must pass
the existing active-session/account checks; missing/invalid/expired/revoked credentials
in authenticated mode are never downgraded to anonymous. FARMER owns its scan through
the middleware principal. ADMIN is denied on the farmer upload route. User ID, role,
image URL, public ID, status and provider options cannot be supplied in multipart fields.

The default app currently uploads as a guest. `MainApp.tokenSource` accepts the
existing AccessTokenSource interface for a securely supplied farmer access token;
when supplied, a missing/invalid token fails closed. This phase does not invent a
login screen, store tokens in preferences or embed server credentials in Flutter.

## API

`POST /api/v1/scans`

| Request | Contract |
|---|---|
| Content-Type | multipart/form-data with a valid boundary; no content compression |
| File | Exactly one file named `image`; no text fields or extra files |
| Idempotency-Key | Required lowercase random UUIDv4; reuse only for retries of the same photo/account |
| X-Auth-Request | Required `1`; forces browser preflight together with the idempotency header |
| Authorization | Omit for guest; Bearer access token for FARMER |
| Params/query | No additional parameters |

201 means a new scan was stored; 200 returns the same saved scan for a completed
same-key retry. The response is a single existing envelope:

```json
{
  "success": true,
  "data": {
    "id": "<scan UUID>",
    "status": "PENDING",
    "createdAt": "<UTC timestamp>",
    "image": {
      "url": "<signed HTTPS image delivery URL>",
      "mimeType": "image/jpeg",
      "bytes": 12345,
      "uploadedAt": "<Cloudinary upload timestamp>"
    }
  },
  "requestId": "<server-generated UUID>"
}
```

Owner IDs, journal IDs/hashes, Cloudinary public IDs/credentials/configuration and
raw provider errors are excluded from JSON. Responses use Cache-Control: no-store.
Existing health and five auth endpoints are preserved. No GET scan endpoint is added.

| Rejection | Status/code |
|---|---|
| Missing/empty/malformed multipart, wrong field count, invalid key/query | 400 VALIDATION_ERROR |
| Invalid, damaged, animated or excessive-dimension image | 400 INVALID_IMAGE |
| Invalid supplied bearer token | 401 AUTHENTICATION_ERROR |
| ADMIN upload / missing browser-preflight header | 403 AUTHORIZATION_ERROR |
| Same key reused with different bytes | 409 CONFLICT |
| Same upload still active or awaiting recovery | 409 UPLOAD_IN_PROGRESS |
| Image exceeds 5 MiB | 413 PAYLOAD_TOO_LARGE |
| Unsupported/spoofed MIME/extension, compressed/non-multipart request | 415 UNSUPPORTED_MEDIA_TYPE |
| Rate limit | 429 RATE_LIMITED |
| Failed provider/database completion | 502 UPLOAD_FAILED |
| Upload disabled or process upload slots occupied | 503 UPLOAD_UNAVAILABLE |

Unexpected database/application errors still use the centralized safe 500 envelope.

## Validation and bounds

- JPEG (`.jpg`, `.jpeg`), PNG (`.png`), WebP (`.webp`) only. Extension comparison
  is case-insensitive. Canonical MIME must match magic bytes; names are never used
  as storage paths. SVG, GIF, HEIC, TIFF and other formats are rejected.
- Nonempty original image, maximum 5 MiB (5,242,880 bytes), maximum 16,000,000
  pixels, one still frame. Sharp/libvips rejects malformed/truncated content after
  complete decoding, with a five-second processing timeout.
- Preserve valid EXIF orientation. Cloudinary consistency checks accept an authorized
  width/height swap for portrait JPEGs without rotating or re-encoding original bytes.
- Multipart accepts one part/file and no text fields, with bounded field/header
  parsing. Two simultaneous uploads per Node process bound buffers/decoder work;
  disconnected clients do not release a slot while provider/storage work continues.
- Per-IP scan attempts default to 10 per 15 minutes, before parsing. The existing
  general request limit and exact-origin CORS/security/error middleware still apply.
- HTTP body receipt is bounded at 60 seconds; Cloudinary calls at 45 seconds;
  Flutter's complete upload at 90 seconds. The API client supports transport abortion,
  disables redirects, bounds response bytes and emits safe local error messages.
- Flutter validates before preview/upload, but backend checks remain authoritative.
  Client validation is never evidence that an image is a maize leaf.

## Retries and cleanup

The additive fifth migration introduces only `scan_uploads` and `scans.uploaded_at`.
Existing scan ownership, image immutability, statuses, prediction models and applied
migrations are preserved. Historical scans backfill uploaded_at from created_at;
new scans store the provider's actual upload time. The complete database now has
21 application tables, 21 CHECK constraints and 37 custom triggers.

The journal stores a SHA256 of owner scope + random request key, a SHA256 of image
bytes, generated public ID, state and optional unique scan link. Raw keys/bytes are
not persisted. Unique request-key hash plus conditional writes prevent parallel
uploaders; replay is scoped to the same farmer or guest key and exact image bytes.
Keep guest keys private: they are an upload-replay capability. Flutter retains the
key through retries in the current ViewModel; retry identity is not persisted across
app restarts. New selection creates a new key and never triggers automatic upload.

- Confirmed upload + failed scan transaction: mark CLEANING, destroy the exact
  project asset, and mark FAILED only after deletion/not-found is confirmed.
- Lost database commit acknowledgement: reread journal completion; a committed
  scan's image is preserved and the saved scan returned.
- Unknown provider outcome/timeout: mark CLEANUP_PENDING and wait a 15-minute
  grace period before attempting deletion, allowing an in-flight provider operation
  to settle. Database outage or process crash leaves a durable UPLOADING record.
- Cleanup claims stale UPLOADING/CLEANUP_PENDING/CLEANING records atomically.
  Completion and cleanup compete on the same row; completed scans are never claimed.
  Failed destruction stays retryable. A crashed cleanup is reclaimable after the grace.
- Successfully cleaned FAILED journals remain available for same-key retry for
  24 hours, then are pruned. Completed scans/journals are retained. Actual retention
  or deletion of saved scans remains a later policy decision.

Run from `backend/`:

```powershell
npm.cmd run scans:cleanup
```

Schedule this command every five minutes in the deployment job runner/Windows Task
Scheduler, with the backend working directory and server environment. This phase
provides the bounded command, not an installed operating-system task. Each run
handles at most 100 stale uploads and prunes at most 100 expired failed journals;
rerun while a backlog exists. It reports safe counts and returns nonzero on failure.
The provider adapter restricts destruction to the journal's validated project UUID
namespace. It never enumerates or deletes unrelated Cloudinary assets. Cleanup needs
the same Cloudinary account and database as upload; monitor nonzero exit/pending counts.

There is no distributed Cloudinary/PostgreSQL transaction. Recovery is eventual and
depends on this scheduled command and provider/database availability; the grace period
is deliberately much longer than a bounded upload operation. A provider operation
that completes exceptionally late after cleanup would require operator reconciliation.

## Configuration and privacy

Configure all three CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY and
CLOUDINARY_API_SECRET in the ignored backend `.env` or deployment secret store.
All blank disables uploads (503) while health/auth remain usable; partial or malformed
configuration fails startup validation without echoing supplied secrets.
SCAN_RATE_LIMIT_MAX is validated and documented in `.env.example`.
Flutter still receives only public API_BASE_URL configuration.

Assets use Cloudinary `type: authenticated`. Unsigned delivery is denied; Node
generates signed HTTPS delivery URLs without returning signing credentials. Those
URLs are bearer capabilities and do not expire automatically: do not log or publish
them. Future history/download APIs need explicit owner checks and a delivery/retention
policy. Original bytes may contain EXIF/location metadata; originals are not re-encoded
in this phase. Photograph only the leaf and avoid personal information. Per-process
rate limits need shared storage/proxy configuration when deployment topology is chosen.

Android uses system gallery/camera intents and scoped storage; no broad storage or
CAMERA permission is added. Camera is an optional hardware feature. Only Android
platform files currently exist. iOS support would require platform generation and
camera/photo usage descriptions before release; desktop camera is hidden when unsupported.
image_picker 1.2.2 is locked for this Flutter toolchain after a newer archive download
stalled; compatible cached resolution succeeded. Kotlin incremental compilation is
disabled because the Windows plugin cache and workspace occupy different drives.

## Checks and tests

```powershell
# backend/
npm.cmd run check
npm.cmd run db:validate
npm.cmd run db:generate
npm.cmd run db:check:migrations
npm.cmd run db:migrate
npm.cmd run db:status
npm.cmd run db:diff
npm.cmd run db:check
npm.cmd run test:auth:database
npm.cmd run test:scans:database
npm.cmd run check:database
# Opt-in: uploads a synthetic image; deletes only its own Cloudinary/SQL fixtures.
$env:RUN_LIVE_SCAN_UPLOAD='true'
npm.cmd run test:scans:live
# Complete Flutter MVVM upload chain; private test server and exact fixture cleanup:
npm.cmd run test:scans:mobile
# mobile/
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

Backend isolated tests cover all formats, MIME/extension/signature spoofing, empty,
oversized, malformed, truncated, animated and excessive-pixel images, request shape,
anonymous/farmer ownership, invalid/admin tokens, rate limits, replay/payload conflict,
scan failure compensation, uncertain provider results, lost commit replies, cleanup
failure/recovery, crash recovery and expired failed-journal pruning. Real PostgreSQL
tests check metadata, null ownership, farmer references, parallel claims, transaction
rollback, cleanup exclusion and SQL invariants. Real Cloudinary tests verify upload,
signed delivery, unsigned denial, replay, and deletion of only test fixtures.
The provider integration also verifies a portrait JPEG with EXIF orientation. An
HTTP regression confirms that disconnecting a client cannot release a slot while
its upload storage work is still running.

Flutter tests cover picker routing/cancellation/permission errors, security preview
validation, multipart transport/auth/progress/timeout/error mapping, repository parsing,
scoped ViewModel state/retry keys/disposal/Android recovery and small-screen/large-text
preview/error/retry/saved states. The opt-in `test/integration/scan_upload_test.dart`
also passed through the real Node/Cloudinary/PostgreSQL chain with a synthetic image
source. The verification harness removed its own asset and SQL records. Default test
runs skip live integrations; run only against a development backend with fixture cleanup.

See [project state](PROJECT_STATE.md) for final test counts and device/build results.

Implementation references: [image_picker](https://pub.dev/packages/image_picker),
[Multer](https://expressjs.com/en/resources/middleware/multer/),
[Sharp input limits](https://sharp.pixelplumbing.com/api-constructor/),
[Cloudinary access control](https://cloudinary.com/documentation/control_access_to_media),
[Cloudinary Upload API](https://cloudinary.com/documentation/image_upload_api_reference).
