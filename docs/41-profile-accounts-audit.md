# Farmer profiles, Admin accounts and audit history

**Phase24.6 current addendum (2026-10-17):** Committed avatar mutations now return before obsolete Cloudinary cleanup; existing durable journal/cleanup CLI owns retry. Lost acknowledgement/client timeout/server errors reconcile with a state reread, preserving current/uncertain assets and idempotency. The default Flutter deadline is unchanged.

See [remediation and current evidence](phase-24-6-pre-deployment-remediation.md). Historical phase details follow.

**Phase 24:** `avatarUrl` is `profile/avatar?v=<opaque-64-hex-version>`, relative
to Node `/api/v1/`, or null. FARMER-only GET requires Authorization and
`X-Auth-Request: 1`; it returns private/no-store bytes without a provider redirect.
New storage copies and legacy delivery strip metadata. Cleanup fences exact
pending attempts and preserves committed photos after lost acknowledgement.
Deactivation still retains data; no retention/erasure policy was enacted.
See [security verification](phase-24-security-hardening.md).

Phase 23.7 completes the original profile-customization, Admin farmer-management
and audit-viewer requirements. See [verification and requirement matrix](phase-23-7-requirements-completion.md).
Existing authentication, immutable knowledge/calculator workflows, ML and RAG remain intact.

## Private farmer profile

Profile → Personalize your profile opens `/profile/edit`. Guests receive a sign-in
state; a signed-in FARMER loads the saved profile. Data persists in the existing
`farmer_profiles` table, independently of volatile native credentials. After logout
or restart, sign in again to retrieve it. No second user/profile architecture or
plaintext credential persistence is introduced.

| API, relative to `/api/v1` | Contract |
|---|---|
| `GET /profile` | FARMER only; `{profile:null}` until first save, otherwise the seven-field projection below |
| `PATCH /profile` | FARMER only; JSON/custom-header contract, `expectedRevision` plus at least one editable field |
| `POST /profile/avatar` | FARMER only; multipart `image` and 64-character `expectedRevision` field |
| `DELETE /profile/avatar` | FARMER only; JSON `{expectedRevision}`; removes the current association and schedules/attempts cloud cleanup |

The projection is `{displayName, region, countryCode, fieldAreaHectares, avatarUrl,
updatedAt, revision}` inside `data.profile`. It exposes no user/profile ID, phone,
Cloudinary public ID, pending-upload state or cleanup identifiers. Ownership always
comes from the authenticated principal; no caller-supplied farmer ID is accepted.
Guests receive 401, Admin receives 403, and strict body/query validation rejects
role/password/email/account-ID/storage-field attempts. Responses use `no-store`.

Editable metadata:

- `displayName`: required on first save; trimmed, 1–120 readable Unicode code points.
- `region`: optional, nullable, trimmed 1–120 readable code points when supplied.
- `countryCode`: optional/null, two alphabetic characters normalized to uppercase;
  this is format validation, not an externally verified address/country catalogue.
- `fieldAreaHectares`: optional/null positive decimal string, at most eight integer
  and four fractional digits, stored exactly with the existing PostgreSQL decimal.
  The form explicitly labels hectares; this metadata performs no agronomic calculation.

Blank optional Flutter inputs become null. PATCH leaves omitted fields unchanged.
First save requires `expectedRevision:null` and a display name. Subsequent changes
pin the returned revision; stale forms return 409 and require explicit reload/review.
The service never silently overwrites a concurrent update. The repository locks the
existing FARMER owner row, checks active status, then creates/updates the profile.
Phone and language are reserved schema fields, not additional personal-data collection
or unsupported localization controls. Account credentials/role are managed elsewhere.

Flutter uses route-local `ProfileViewModel` → `ProfileRepository` → the existing
authenticated `ApiClient`. Controllers retain form input; the ViewModel owns loading,
saving, errors, success, photo selection/progress and disposal/identity fences. A
session revision remounts the route so another farmer cannot inherit private form data.
Network/timeout/validation/conflict failures remain safe and retryable. Existing
safe-area/scrolling pages, theme, state widgets and design tokens are reused.

## Profile photo lifecycle

The original brief names farmer profile photos as a Cloudinary use. Selection uses
the existing gallery picker and image decoder, shows a preview and requires explicit
upload. There is no camera/face recognition or inference/RAG call for profile photos.
Photos must be user-owned or permission-backed; the UI explains that originals may
retain metadata. No supplied dataset image is reused as a profile/library photo.

Server admission reuses the existing authoritative file/container/decoder validator:
still JPEG/PNG/WebP, matching MIME/signature/extension, maximum 5 MiB/16 megapixels,
minimum 16 pixels per side, complete decoding and existing orientation/container
checks. Client validation is advisory. Authenticated rate limits and a two-upload
concurrency bound run before multipart allocation. Extra parts/fields fail closed.
The original scan upload transport remains the default; its only additional target
is the authenticated `profile/avatar` contract. Request-key generation is shared,
while profile POST does not claim the scan endpoint's idempotent retry semantics.

The existing Cloudinary adapter now has an explicit typed `scans`/`profiles` purpose.
Each instance admits only its own UUID asset namespace. Profile photos use private
authenticated assets and signed HTTPS delivery URLs; credentials stay server-side.
These URLs are bearer capabilities, not a guarantee against sharing/cached copies.
Only metadata is stored in PostgreSQL. Source bytes do not enter the repository or AI.

The ninth additive migration adds three internal fields to the existing profile:
pending public ID, upload-start time and a bounded cleanup-ID array. It also adds the
global audit-history ordering index. All original eight migrations remain untouched.
No table, trained artifact, class mapping or preprocessing change is introduced.

1. Commit a fresh pending asset identity before cloud I/O. Only one upload may be pending.
2. Upload under a new `maizedoctor/profiles/<UUID>` ID; never overwrite an old asset.
3. Atomically install returned metadata, queue the old asset and clear the pending
   attempt. The owner must still be ACTIVE. A stale/interrupted writer cannot finalize
   once its pending identity has been retired.
4. Attempt old-asset deletion. Confirmed removal clears its durable intent; provider
   failure leaves it queued. A failed upload/finalization compensates the candidate;
   failed compensation retains its precommitted pending identity for recovery.
5. Explicit removal clears the current metadata and queues/attempts deletion. Cloud
   deletion/invalidation may be delayed; a removed URL is not represented as instantly
   unrecoverable everywhere. Empty/current asset identities are never guessed.

Recovery retires attempts older than two minutes and removes at most 20 queued
assets across ten candidate profiles per run. Eight retained cleanup IDs cap further
upload/removal attempts until recovery. Run from backend:

```powershell
npm.cmd run profiles:cleanup
```

Schedule this existing command alongside scan cleanup when deployment is explicitly
authorized; no deployment job is installed here. On an interrupted/ambiguous upload,
reload the saved profile before another submission. Recovery/provider/DB outages
must be resolved before abandoned attempts can disappear; intents are retained.

## Scoped Admin farmer management

Admin overview → Manage farmer accounts opens `/admin/farmers`, outside farmer
navigation and using the existing independent Admin session/API client.

| API | Contract |
|---|---|
| `GET /admin/farmers` | ADMIN only; `limit` 1–50/default20, UUID cursor, optional status and exact normalized email |
| `PATCH /admin/farmers/:id/status` | ADMIN only; `{status:ACTIVE\|SUSPENDED\|DEACTIVATED, expectedRevision}` |

The list is server-paginated in native `(createdAt DESC,id DESC)` order, includes
FARMER accounts only and returns `{id,email,status,displayName,createdAt,revision}`.
The opaque ID is needed to manage the selected account; password hashes, session
digests, phone/field metadata, provider details and Admin accounts are excluded.
Unknown/non-farmer cursor/target IDs return 404. Invalid filters return 400.

Status changes require Flutter confirmation and a fresh revision. One PostgreSQL
transaction locks the FARMER row, changes access state, revokes every unrevoked
session and appends an immutable audit record. Audit failure rolls back both status
and revocation. Suspended/deactivated users fail live access/refresh checks; activation
never revives old sessions and requires a new login. Deactivation preserves profile,
scans, ownership and history; it is not account erasure. No role change, password
editor, arbitrary account deletion or public Admin enrollment endpoint exists.

## Read-only audit viewer

Admin overview → View audit history opens `/admin/audit`.
`GET /admin/audit-logs` is ADMIN-only and supports `limit` 1–50/default20, UUID
cursor, known action/entity type, actor UUID and paired inclusive UTC `from`/`to`
dates spanning at most 366 days. Native timestamp/UUID ordering and the new index
support bounded pagination. There is no mutation endpoint and no full-table download.

Each entry projects ID, UTC timestamp, action, affected type/UUID, retained actor
UUID/current role (or null for system/removed account), and explicitly safe metadata.
Only recognized statuses, bounded counts/versions and known changed-field names are
returned. Raw `changes`, text/review/source payloads, request credentials, tokens,
IP addresses and arbitrary JSON keys are never forwarded. Unknown legacy entity types
are labeled OTHER. Actor role is current metadata, not a fabricated historical snapshot.
The existing SQL immutability guard and historical audit records remain unchanged.

Both Admin features use scoped ChangeNotifier ViewModels → shared typed repository →
the Admin API client, with pagination, filters, loading/empty/error/retry, confirmation
and identity/disposal fencing. They do not calculate system statistics in Flutter.

## Conditional content still pending

Curated disease-library media is required by the original brief, but no approved
licensed library photos are available. The current `disease_images` model stores URL,
Cloudinary ID, alt text and ordering, without a complete image-specific license/source
contract. It remains unused; Knowledge shows honest icons and actual sourced text.
Future approved media needs source/rights metadata, controlled Admin upload/publication,
delivery policy and Farmer rendering. No raw training photo is redistributed or scraped.

Fertilizer/yield engines and forms retain their explicit pending-content states. See
the separate [domain-input checklist](calculator-domain-input-checklist.md).
