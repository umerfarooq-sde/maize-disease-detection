# Phase 24 â€” security hardening and verification

Updated: 2026-10-16, Asia/Karachi. Baseline: `73a9ad0` on `main`.
Scope: Phase 24 only. No deployment, training, model promotion, dataset access,
agronomic content change, credential rotation, account erasure or retention job.

**Phase 24 complete: PASS WITH DOCUMENTED LIMITATIONS.** All final checks below
passed within their stated scope; public hosting remains subject to release gates.
See the final ledger for multiple-run results and retained failures.

## Threat model and risk matrix

Likelihood/impact describe the original exposure before this phase's mitigation.
P0 means critical/data loss, P1 high/release prerequisite, P2 moderate, P3 low.

| Actor/threat and trust boundary | Likelihood | Impact | Priority | Mitigation / residual |
|---|---|---|---|---|
| Malicious guest â†’ Node, expensive password/upload/AI requests | High | Availability | P1/P2 | IP limits, four concurrent Argon2 operations, two uploads, bounded bodies/decode; distributed enforcement and edge limits required before multi-instance hosting |
| Stolen refresh credential â†’ session store | Medium | Account takeover | P1 | Digests, bounded expiry, atomic rotation, replay/race family revocation; volatile native storage retained |
| Farmer/guest â†’ another farmer's scans/profile/explanation | Medium | Private-data disclosure | P1 | Live principal/role checks, repository owner predicates, non-enumerating 404, no Admin bypass |
| Copied Cloudinary URL â†’ private photos | High | Privacy | P1 | Approved protected Node byte delivery, account/capability authorization on every request; old disclosed links require legacy review |
| Forged camera file â†’ Node/Cloudinary/FastAPI | High | DoS/location disclosure | P1/P2 | Signature/container/decode/size/dimension/frame checks, metadata-free storage copy and legacy delivery; ML original bytes preserved |
| DB-commit acknowledgement lost â†’ profile cleanup | Medium | Saved-image loss | P1 | Lock/fence exact upload intent, reread committed association, never delete an uncertain/current asset |
| Node â†’ PostgreSQL; shared owner/migration credential compromise | Medium | Broad DB modification | P1 | Production runtime gates reject elevated/owning/DDL roles; separate credentials/grants remain mandatory before hosting |
| Node â†’ PostgreSQL; TLS alias/configuration downgrade | Medium | Credential/data interception | P1 | Normalize require/prefer/verify-ca to verify-full, no compatibility bypass; remote production unverified TLS rejected |
| Test parent â†’ Flutter child, inherited server credentials/hooks | High | Secret disclosure | P1 | Explicit OS/SDK allowlist; actual child-process sentinel tests; no NODE_OPTIONS/proxy/server keys inherited |
| Malicious API caller â†’ internal FastAPI | Medium | Provider cost/model abuse | P1 | Configured service bearer, loopback default, token required for production/non-loopback; private network isolation still required |
| Artifact tampering â†’ model loader/filesystem | Medium | Code execution/wrong predictions | P1 | Approved local metadata/config/checkpoint hashes and weights_only state-dict loading; no upload/path/model-selection API |
| Compromised curator/provider â†’ pgvector/Gemini | Medium | Poisoned guidance | P1 | Reviewed immutable versions/source hashes/lineage, stale exclusion, bounded context, evidence-ID selection and server-rendered citations |
| Prompt injection inside question/chunk â†’ Gemini | High | Ungrounded facts/secrets | P1 | Retrieved text is data, no tools, strict evidence membership/output validation, abstention, no classifier/numeric override |
| External-provider timeout/malformed reply â†’ Node/FastAPI | High | Availability/false success | P2 | Deadlines, bounded responses, safe errors, failed lifecycle, durable cleanup; real failures simulated locally, no provider load attack |
| Dependency/runtime compromise â†’ developer/application | Medium | Code execution/availability | P1/P2 | Scoped audited transitive upgrades, patched Node/Python/tooling, hash-pinned Gradle; CPU Torch advisories explicitly restricted below |
| Compromised provider keys/Admin credentials â†’ cloud/knowledge | Medium | Data/cost/poisoning | P1 | Server-only keys, scoped namespaces, audit/RBAC; provider scoping/rotation/secret manager/incident procedure before hosting |

## Findings, fixes and verification

| ID / severity | Affected files/component | Genuine issue and fix | Verification |
|---|---|---|---|
| SEC24-01 P1 | scripts/check-scan-upload.mjs, check-model-health.mjs, check-development.ps1 | Broad parent environment reached Flutter. Add flutter-test-environment.mjs and shellless run-flutter.mjs; retain only SDK/OS inputs and explicit disposable test credentials | Two actual-process/legacy-source regression tests; full Flutter suite and live helpers |
| SEC24-02 P1 | scans/scan.types.ts, profile/profile.types.ts, private-image.ts, image controllers/routes; Flutter API/repository/ViewModel/widget | API exposed reusable signed provider capabilities. Return Node-relative image locations and authorize each byte read; no redirect or user-controlled URL fetch | Backend owner/capability/Admin/revocation tests; Flutter origin/auth/identity tests; real cloud checks |
| SEC24-03 P2 | scans/image-privacy.ts, scan.storage.ts | Accepted EXIF/XMP/GPS metadata persisted. Strip metadata and orient a separate display/storage copy; sanitize legacy delivery. Inference/retry hashing retain original validated bytes | JPEG/PNG/WebP metadata/orientation tests and byte-identity inference assertion; real profile-photo fixture |
| SEC24-04 P1 | profile-media.repository.ts, profile-media.service.ts | Upload compensation could delete a committed photo after ambiguous DB acknowledgement. Fence the specific pending attempt under lock, confirm committed state and use durable cleanup | Lost-ack, DB uncertainty, replacement/removal and idempotent cleanup regressions |
| SEC24-05 P2 | auth/auth.password.ts | IP limits alone allowed concurrent expensive hashing across IPs. Limit per-process Argon2 work to four; reject excess without queuing | Concurrent hash/verify and slot-release tests; full auth regressions |
| SEC24-06 P1 | database/connection-url.ts, config/environment.ts, AI settings.py | libpq-compat query allowed SSL alias verification bypass; unsafe remote production DB/CORS settings and query-host/duplicate-option ambiguities admitted. Always verify aliases; reject unverified remote production TLS, endpoint overrides, duplicate Node URL parameters and non-HTTPS production origins | Environment negative tests; actual TLS probes and production-role rejection |
| SEC24-07 P1 release prerequisite | health.repository.ts, application.ts, AI rag/repository.py | Configured research DB role can create DBs/roles, bypass RLS and owns objects; Node/AI/migrations share it. Add fail-closed production privilege checks before serving/querying | Catalog-only inspection; safe/unsafe/malformed unit cases; actual role rejection; no grant/role change |
| SEC24-08 P2 | AI api/json_body.py | Ambiguous duplicate media/encoding headers were not explicitly rejected | Auth-before-body, malformed/oversized redaction and duplicate-header tests |
| SEC24-09 P1 dependency | backend/package*.json | Prisma-transitive deepmerge-ts/mysql2 advisories | Scoped exact overrides, zero npm findings, Prisma generation/SQL/migration regressions; Prisma stays 7.10.0 |
| SEC24-10 P2/P3 tooling | backend/.node-version, runtime guards, scripts/setup-python.ps1/use-project-node.ps1/requirements-tools.txt, Gradle wrapper | Old runtime patch levels and vulnerable bootstrap packaging tools; checksum hardening, plus separate Gradle advisory fix below | Node 24.22.0 verified archive, CPython 3.11.17 launchers, unchanged app distribution versions, tooling audit and Android build |
| SEC24-11 P1 build tool | mobile/android/gradle/wrapper/gradle-wrapper.properties | Five upstream HIGH Gradle advisories affect 8.14, including local daemon deserialization and unsafe repository fallback. Upgrade 8.14.6 with official checksum; stop old daemon | Maintainer advisory/version review; patched Android rebuild PASS |

## Authentication and sessions

Argon2id uses 64 MiB, three iterations and parallelism one; passwords require
15â€“128 Unicode code points. Unknown-email login performs comparable hashing.
Four concurrent expensive operations per process are admitted, including verification.
Email normalization and strict registration schema reject public ADMIN enrollment.
Login errors are generic. Registration intentionally retains the existing 409
duplicate-account contract: account-existence enumeration remains a documented P2
tradeoff, bounded by rate limiting. No recovery/persistent-login feature was added.

JWTs restrict HS256, issuer/audience/purpose and expiry; independent environment
keys sign access and refresh credentials. Default access life is 15 minutes; refresh
life seven days (validated upper bounds 15 minutes/30 days). A live active account
and non-revoked DB session are required, so stale role claims cannot grant access.
Only refresh digests are stored. Compare-and-swap rotation rejects concurrent/replayed
credentials and revokes the family. Logout revokes the family, including after
suspension; reactivation requires a new login. No password/token/hash is returned
in public DTOs or operational logs.

Native Flutter credentials stay memory-only. Refresh is single-flight; identity
revision fences discard responses from a previous account. App restart requires
login. This is intentionally secure volatile login, not persistent authentication.
Browser refresh uses HttpOnly, production Secure/__Host, SameSite Strict cookies,
exact CORS origins and the JSON/custom-header CSRF contract. Cross-site browser
hosting would require a separately reviewed cookie/origin design.

## Authorization, RBAC and data isolation

FARMER/ADMIN admission is server-side. Farmer history, result, scan explanation,
profile and image delivery derive ownership from the current principal. A guest
may create a scan but requires its random original request capability for subsequent
record/image access; anonymous scans are never retroactively attached to accounts.
Capabilities are headers, never URLs/log fields. Admin cannot read unrelated
farmer-private scans/photos. Admin management, calculator edits, account status,
publication/indexing and audit history reject guests/FARMER. No role editor exists.
Account status, revocation and audit append share a locked transaction; rollback
and immutable audit/metadata projection are verified with disposable fixtures.

## Protected image contract and cleanup

New GET endpoints, relative to `/api/v1`:

| Endpoint | Authorization | Public representation |
|---|---|---|
| `/scans/:scanId/image` | Owner FARMER bearer, or anonymous `Idempotency-Key` capability for that anonymous scan | JPEG/PNG/WebP bytes |
| `/profile/avatar?v=<64-hex-version>` | Current FARMER bearer and `X-Auth-Request: 1` | Own current photo bytes; version is an opaque cache key, not an access credential |

Scan JSON `image.url` is `scans/<scanId>/image`; profile `avatarUrl` is the relative
profile path or null. This intentional security contract change is implemented in
Flutter DTOs/API/repository/scoped ViewModel and reusable PrivateImage widget.
There are no image HTTP calls in widgets and no Image.network Cloudinary delivery.
Requests bind to the configured Node origin, refuse redirects, bound time/bytes,
attach the appropriate authorization, and clear stale account results. A bounded repository queue admits two active
thumbnail reads and at most 32 waiters, rejecting queued work after identity changes. Private
responses use `Cache-Control: private, no-store` and `Referrer-Policy: no-referrer`.
Images may remain transiently in process/Flutter memory; secure memory erasure is
not claimed. Authorized screenshots/copies cannot be prevented by this design.

The reader accepts only the configured Cloudinary HTTPS host/cloud, authenticated
signed delivery path and generated purpose/UUID namespace. It fetches stored URLs,
never caller URLs, rejects redirects, bounds network time to ten seconds and bytes
to 16 MiB, and validates actual image decoding (16 MP, one frame, minimum 16 px).
Only the historical SDK `_a` analytics query is recognized and removed; other query
parameters are rejected. New storage URLs disable analytics. Two shared concurrent
provider reads and 60 image requests/IP/minute apply; Flutter has a bounded deadline.

Uploads retain the existing 5 MiB, 16 MP, minimum 16Ã—16, still JPEG/PNG/WebP
admission contract. MIME, container, extension when present, complete decode and
multipart fields are checked. Server UUIDs replace filenames. Authenticated cloud
assets remain private; no credentials/public IDs/provider URLs are returned.
Sharp removes metadata and creates only a display copy, without implementing ML
resize/normalization. Lossy JPEG display copies must not later replace original
inference inputs without a separately approved parity policy. Raw datasets and
shared preprocessing are untouched.

Completed originals previously disclosed by signed URLs are not automatically
revoked by a proxy. Read-only inventory found zero stored scans and zero saved
profile photos in the configured public schema; this does not prove there are no
provider-only/previously copied assets. Before public release, inventory legacy
assets/disclosures and approve invalidation/migration if any exist. No existing
user asset was renamed/deleted in this phase.

Durable upload journals and profile intents precede provider work. Failures retain
recoverable state; exact-attempt locking and committed-association checks prevent
cleanup deleting current/pending photos. Confirmed obsolete assets use idempotent
deletion with invalidation. Ambiguous uploads wait for stale recovery. Existing
`scans:cleanup`/`profiles:cleanup` CLIs remain; actual scheduling belongs to Phase 25.

## API, abuse, logging and subprocess boundaries

Node uses strict Zod schemas, simple query parsing, 100 KiB uncompressed strict JSON,
bounded memory multipart, parameterized Prisma/pgvector queries, cursor/limit/date
bounds, Helmet and centralized redacted errors. Stored/retrieved text renders as
text, not executable HTML. No untrusted merge or unsafe dynamic SQL was found in
application paths. Test-only raw SQL uses owned schemas/savepoints/constant statements.
Request logs omit query strings, bodies, cookies, Authorization, capability keys,
provider payloads and personal content. Errors expose safe codes, not causes/paths.

Default per-process/IP controls: global 120/minute, combined register/login 10/15min,
refresh/logout 30/minute, uploads 10/15min, knowledge 20/minute, generation 5/minute,
calculators/analytics 30/minute; Admin/image limits are route-specific. Scans admit
two simultaneous uploads; Argon2 four; FastAPI inference one, retrieval four,
generation two by default. These are local controls, not a distributed quota.
`trust proxy` stays false; do not place a proxy in front and blindly trust headers.
Phase 25 must establish exact proxy hops, edge limits, shared store/quotas and
provider budgets before multiple instances or unrestricted anonymous exposure.

Every Flutter test subprocess was reviewed. The old scan/model-health runners and
development checks now use explicit OS/SDK allowlists; other live runners already
allowlist, with only generated disposable account credentials where needed.
This is environment isolation, not an OS/filesystem sandbox.
The shellless SDK runner reconstructs FLUTTER_ROOT from the resolved SDK; it does
not inherit Node/Python preload hooks, proxies or backend/AI secrets. Two regression
tests execute a child with secret sentinels and inspect legacy helper code. No real
credential values are printed or committed.

## FastAPI, artifacts and RAG/Gemini

All protected internal operations require the configured constant-time bearer
token; production/non-loopback configurations require a token. Loopback is default,
proxy headers are disabled, browser CORS is absent and production docs are disabled.
Node uses fixed configured endpoints and bytes/JSON, no arbitrary image URLs.
Input/body/response bounds, concurrency and deadlines apply. Duplicate ambiguous
JSON media/encoding headers fail closed before decoding; errors redact input.

Model startup verifies the approved local checkpoint, metadata, class mapping,
preprocessing version/full-frame policy, normalization/input size, dependency
versions and calibration state. The model is loaded once. No user-supplied path,
TorchScript, PT2 package or model upload is accepted. Model-health authorization
and repeated/concurrent startup/inference regressions are retained. No model,
mapping, threshold or training/test artifact was altered/recomputed. Existing
threshold-unconfigured output remains honestly LOW_CONFIDENCE.

RAG keeps source/document/chunk/version/hash/offset lineage. Only current reviewed
published/indexed evidence is retrieved; edits mark embeddings stale rather than
silently reusing them. Parameterized vector/filter queries and source identity
checks enforce the same evidence at generation. Questions/history/context are
bounded and overlapping chunks deduplicated. Gemini's official configured SDK
returns evidence selections under a strict schema; the server renders reviewed
text and exact citations. Fabricated references, content instructions, conflicts,
insufficient/empty grounding and provider failures abstain/fail safely. There are
no arbitrary tools or secrets in prompts; the classifier result and deterministic
calculator values cannot be overwritten. Legitimate curated knowledge is unchanged.
Human review remains necessary for malicious-but-approved factual content.

## Database security and production admission

Prisma schema and all nine migrations remain unchanged: 21 tables, 27 checks,
38 custom triggers. Immutable audit/version payloads, scan ownership, bounded
predictions, lifecycle and row-lock/CAS transactions remain intact. Sensitive
fields are projected out. No reset, real-user fixture mutation or grants executed.

Read-only catalog inspection found Node, FastAPI and migration configurations use
the same research account: not superuser, but CREATE DB/ROLE, BYPASSRLS and 106
owned public objects. This is unsuitable for production. Node production startup
and FastAPI production retrieval connections now reject roles with such inherited
privileges, object ownership, database/schema CREATE or malformed permission
evidence. Production cannot silently start with the current development identity.
Provision separate migration/owner and narrowly granted Node/AI runtime identities
before deployment; do not solve this by disabling the production guard. No credential
was rotated or replaced automatically. AI runtime currently needs only the grants
for its actual retrieval/index workflows, not global owner/admin privileges.

Read-only Node probes confirmed client TLS and certificate validation on both
configured runtime/direct connections and actual production-role rejection.
TLS aliases are normalized to verify-full even with the old compatibility flag;
remote production plaintext/unverified modes are refused. Node rejects duplicate
URL query options (first-value versus last-value driver ambiguity); production
Node/AI refuse endpoint overrides in query parameters that could disguise a remote
server behind a localhost URL. PostgreSQL's server-side
pg_stat_ssl may describe the provider proxyâ†’DB hop, not clientâ†’proxy encryption;
do not interpret the observed false backend-hop flag as proof that client TLS is off.

## Dependency audit and runtime evidence

| Environment | Actual result / scope | Remediation and limitations |
|---|---|---|
| Node all dependencies | Original four HIGH package rollups, zero critical; three unique advisories in two leaf packages. Final npm audit zero | Prisma/client/adapter stay 7.10.0; scoped overrides only |
| Node production dependency audit | Final rerun recorded in check results | Optional/peer audit classification must not hide original Prisma findings |
| AI Python actual site-packages | 60 distributions (57 mapped), zero mapped findings, three skips | Editable shared package plus CPU-local torch/torchvision are not resolved by PyPI audit |
| Training actual site-packages | 43 distributions (40 mapped), zero mapped findings, same three skips | No training/ML dependency upgrades or artifact changes |
| CPU Torch supplemental OSV | torch 2.10.0 / torchvision 0.25.0 normalized upstream versions; two Torch advisories | Explicit path restrictions below; not a clean unrestricted Torch certification |
| Flutter pubspec.lock | 47 hosted Pub versions queried against OSV, zero affected | SDK packages excluded from Pub scan; fails on incomplete/paginated query errors |
| Bootstrap tools | Original pip 22.3/setuptools 65.5.0 advisory findings; final pip 26.2.1/setuptools 84.0.0/uv 0.12.23 clean | Isolated tooling pins; service distributions unchanged |
| Node/Python runtime | Node24.12.0â†’24.22.0, CPython 3.11.0â†’3.11.17 | Verified Node archive; uv-managed Python; project-local launchers/production version guards, no system PATH change |
| Android build chain | Gradle 8.14 to 8.14.6 and checksum pinned; patched rebuild PASS | Five upstream HIGH notices reviewed below; OSV Maven query alone missed them. Not a complete JDK/OS attestation |

Node advisory triage:

| Package / relationship / original version | Advisory and path | Exposure / safe fix |
|---|---|---|
| deepmerge-ts7.1.5, transitive @prisma/config | CVE-2026-40345 / GHSA-ggr8-5vv4-36mx, recursive graph stack exhaustion | Local config merge, no caller-controlled merge input; override8.0.2. v8 Map/custom merge breaking behavior is unused; SQL/CLI regressions gate the override |
| mysql2 3.15.3, transitive Prisma optional tooling | GHSA-3f6p-5ww8-9rcr, authentication downgrade/plain-password path | No MySQL connection in this PostgreSQL app; override3.24.6 rather than Prisma downgrade |
| mysql2 3.15.3, same path | GHSA-rgwj-5xj2-c3m3, compressed-protocol inflate bomb | MySQL path unused; same patched version removes the vulnerable code |

Primary package notices: [deepmerge advisory](https://github.com/advisories/GHSA-ggr8-5vv4-36mx),
[v8 changes](https://github.com/RebeccaStevens/deepmerge-ts/releases),
[mysql authentication](https://github.com/advisories/GHSA-3f6p-5ww8-9rcr),
[mysql decompression](https://github.com/advisories/GHSA-rgwj-5xj2-c3m3).

CPU Torch 2.10.0 retains PYSEC-2025-194/CVE-2025-3000/GHSA-rrmf-rvhw-rf47
(torch.jit.script local memory-corruption path; upstream fix2.13.0; GHSA Low (1.9))
and PYSEC-2026-139/CVE-2026-4538 (PT2 package loading/deserialization; no fixed
version listed by this audit; upstream database severity HIGH (7.8)). Neither path is called. Only the approved,
hash-verified server-owned state_dict is loaded with weights_only=True; no
untrusted model/file path is accepted. These are P2 restricted-use risks, P1 if
untrusted model/JIT/PT2 functionality were introduced. Preserve the approved pins
and require separate compatibility/parity approval for a future upgrade. The
separate weights_only advisory GHSA-63cw-57p8-fm3p affects <=2.9.1 and is fixed
in installed2.10.0; it is not an open finding here.
See [Torch advisory](https://github.com/advisories/GHSA-rrmf-rvhw-rf47),
[weights_only notice](https://github.com/pytorch/pytorch/security/advisories/GHSA-63cw-57p8-fm3p)
and [upstream security policy](https://github.com/pytorch/pytorch/security).
The [PT2 advisory record](https://osv.dev/vulnerability/PYSEC-2026-139) describes
the local deserialization path; this is a documented mitigation, not a patched
Torch installation.

Tooling details: both packages are installed bootstrap/build tools in the isolated
`.cache/tools` environment, not application HTTP dependencies. Malicious package
archives/index inputs or legacy download/build paths are the exposure. Upgrading
that environment avoids changing approved AI/training packages. Duplicate audit
records were collapsed to the eleven unique CVEs below; all are removed by the
final pip 26.2.1/setuptools 84.0.0 audit.

| Original package/version | Advisory | Affected tooling path | First listed fix |
|---|---|---|---|
| pip 22.3 | CVE-2023-5752 | Mercurial revision/options injection |23.3|
| pip 22.3 | CVE-2025-8869 | Fallback tar symlink extraction |25.3 plus patched Python tarfile|
| pip 22.3 | CVE-2026-1703 | Malicious wheel path traversal |26.0|
| pip 22.3 | CVE-2026-3219 | Concatenated tar/ZIP interpretation |26.1|
| pip 22.3 | CVE-2026-6357 | Self-update import path after install |26.1|
| pip 22.3 | CVE-2026-8643 | Console/gui script path handling |26.1.2|
| pip 22.3 | CVE-2026-13346 | Doubly encoded index/package URLs |26.2|
| setuptools 65.5.0 | CVE-2022-40897 | Legacy package-index processing/ReDoS |65.5.1|
| setuptools 65.5.0 | CVE-2025-47273 | PackageIndex download path traversal |78.1.1|
| setuptools 65.5.0 | CVE-2024-6345 | Legacy package_index download execution |70.0.0|
| setuptools 65.5.0 | CVE-2026-59890 | FileList/MANIFEST exclusion processing |83.0.0|

Runtime references: [Node 24.22.0 release](https://nodejs.org/en/blog/release/v24.22.0)
and [Python3.11.17 security release](https://www.python.org/downloads/release/python-31117/).
SDK/JDK/Android platform/OS vulnerabilities are not fully covered by npm/Pub/PyPI
audits; maintain those under the production dependency process as well.

### Gradle / SDK advisory review

Gradle 8.14 is a directly pinned build tool (gradle-core is its implementation),
not an Android app runtime library. The review identified five upstream HIGH
advisories: client/daemon pre-auth deserialization (GHSA-xwqc-3h47-hg64),
worker/daemon unauthenticated deserialization (GHSA-mvvg-497x-hmj8), SSL-failure
repository fallback (GHSA-j5m7-59rp-24f5), timeout repository fallback
(GHSA-mqwm-5m85-gmcv) and DNS-failure fallback (GHSA-w78c-w6vf-rw82).
The local socket attacks concern co-located untrusted processes/users and build
secrets; fallback issues concern poisoned artifacts after a repository failure.
The first three are fixed in 8.14.6, the latter two in 8.14.4. Select 8.14.6,
retain the 8.14 line, pin its official bin-distribution SHA256 and stop the old
8.14 daemon. The patched ARM64 debug rebuild passed (320.1s Gradle task;324.94s runner).
Only a verified extracted Node archive and one ignored, regenerable unstripped
Android library intermediate were removed to recover workspace disk space; the
APK, source, model artifacts and raw dataset were preserved.
An initial stop command found a stale JAVA_HOME; it was corrected
for that command only and confirmed one legacy daemon stopped. No machine setting
was changed. No paid subscription is required for 8.14.6.

Both Maven OSV queries (8.14 and8.14.6) returned no records; this is a coverage
limitation, not evidence the old tool was safe. Maintainer advisories govern this
triage: [client channel](https://github.com/gradle/gradle/security/advisories/GHSA-xwqc-3h47-hg64),
[worker channel](https://github.com/gradle/gradle/security/advisories/GHSA-mvvg-497x-hmj8),
[SSL fallback](https://github.com/gradle/gradle/security/advisories/GHSA-j5m7-59rp-24f5),
[timeout fallback](https://github.com/gradle/gradle/security/advisories/GHSA-mqwm-5m85-gmcv),
[DNS fallback](https://github.com/gradle/gradle/security/advisories/GHSA-w78c-w6vf-rw82).
Older pre-8.13 Gradle temporary-directory advisories do not affect the original 8.14.

Flutter 3.41.9 remains pinned. The reviewed Flutter advisory page has no published
entries; Dart's latest Pub zip-slip CVE-2026-27704 is fixed from Dart 3.11.0 /
Flutter 3.41.0 and does not affect this pin. This review supplements, rather than
replaces, the 47-package Pub audit; it is not exhaustive OS/JDK/native-library
certification. See [SDK advisory](https://github.com/dart-lang/sdk/security/advisories/GHSA-q739-79rh-vmvp).

## Privacy inventory and proposals â€” no retention policy enacted

The user approved leaving retention unchanged and documenting proposals. All
durations below are recommendations requiring separate approval, not behavior.
Provider-side retention, backups and logs also require contractual/config review.

| Data | Current behavior | Proposed default / approval required |
|---|---|---|
| Account email/password digest/status and farmer profile | Stored until explicit future erasure process; deactivation retains data | Retain while active; verified erasure workflow with a proposed 30-day completion target; approve legal/audit exceptions |
| Completed farmer scans, predictions and photos | Retained; ownership immutable; no automatic expiry/erasure job | Farmer-controlled deletion, plus proposed 12-month inactivity review; approve actual horizon and historical record semantics |
| Anonymous scan/image/capability digest | Anonymous ownership; capability allows read; no expiry policy | Proposed 30-day expiry/deletion; approve before unrestricted public anonymous service |
| Refresh session digests | Expire/revoke access; inert DB rows retained | Proposed purge 30 days after expiry/revocation, preserving separate minimal security evidence if approved |
| AI questions/conversations | Bounded transient UI/provider context; full request-history telemetry not implemented | Do not add persistence by default; approve opt-in/minimization and provider use before personal content |
| Immutable audit events | Retained indefinitely, safe metadata projection; cannot silently edit/delete | Proposed 12 months with legal review; deletion would require an explicitly designed archival/erasure policy |
| Operational logs | Redacted process/stdout events; no app rotation/expiry policy | Proposed 30 days ordinary /90 days selected security events; approve sinks/access/incident exceptions |
| Cloudinary assets and cleanup intents | Old replaced/removed/failed assets use durable cleanup; completed assets retained | Align deletion with approved scan/account policy; provider cache invalidation and backup retention must be verified |
| Temporary bytes / test fixtures | Uploads memory-only; disposable test schemas/assets cleaned; no raw dataset redistribution | Preserve minimization; no claim of secure RAM erasure or physical-device/cache deletion certification |

Account suspension/deactivation is **not erasure**. No existing account/scan/cloud
asset was deleted for a retention policy. Only generated owned test fixtures and
obsolete fixtures created by this run are eligible for verification cleanup.

## Commands and verification matrix

Actual commands use project Node selection (`. ./scripts/use-project-node.ps1`)
and the project virtual environments. `.cache/phase24/*-result.json` records exact
arguments, exit codes and durations; logs/private fixture IDs remain ignored.

| Command/check | Result |
|---|---|
| `powershell -NoProfile -File scripts/check-development.ps1 -Component Backend` | PASS: formatting, lint, strict types, build, 322 tests plus two child-environment tests; existing lint informational notices retained |
| `... -Component Flutter` | PASS: analyze, 374 tests, 13 explicit default live opt-in skips |
| `... -Component AI` | PASS: Ruff format/lint, mypy, 356 tests; three explicit opt-in SQL skips, one pre-existing TestClient warning |
| `... -Component Training` | PASS: Ruff/mypy, 219 fixture/tooling tests; no fitting or dataset read |
| `... -Component Preprocessing` | PASS: 78 tests in each Python environment, 12 exact synthetic full-frame parity cases, Ruff/mypy |
| `... -Component Prisma`, `npm run db:diff` | PASS: validation, generation, 13 rollback checks, nine migrations up to date and no drift; earlier remote connection timeouts retained |
| `node ../scripts/run-flutter.mjs build apk --debug --no-pub --target-platform android-arm64` | PASS: ARM64 debug APK; no physical device or release-signing claim |
| `dart format --output=none --set-exit-if-changed lib test` | PASS: 219 Dart files formatted, final check zero changes |
| `python scripts/check-e2e.py` | PASS:19/19 final categories across isolated runs; zero selected skips; see final ledger |
| `npm audit --json`, `npm audit --omit=dev --json` | PASS: zero production dependency findings; failed network attempt retained |
| `uvx --from pip-audit pip-audit --path <venv-site-packages> --skip-editable --format json --progress-spinner off` | AI/training/tooling actual environments audited as above |
| `uvx --from pip-audit pip-audit -r <CPU-normalized-requirements> --no-deps --disable-pip --vulnerability-service osv --format json --progress-spinner off` | Two explicitly triaged CPU Torch notices; command exits1 for findings |
| `python scripts/audit-flutter-dependencies.py` | 47 hosted packages, zero affected |
| Frozen/secret/link/repository review | PASS:171 frozen files/checkpoint, nine migrations and original user edits; source/link/known-secret checks plus 5,911 history blobs with zero configured-secret matches |

Verification classifications: component tests use deterministic mocks/local HTTP;
SQL tests use real PostgreSQL in rollback/owned schemas; live tests use configured
Cloudinary, FastAPI approved-model startup, Google embeddings/Gemini and pgvector.
Provider-unavailable/timeout/adversarial cases are local controlled simulations,
not destructive tests against real providers. Flutter E2E is host-widget/API/MVVM,
not a physical Android camera/permission/network acceptance run. No skipped test
is counted as passed, and default skips are enabled explicitly by the live harness.

Failed attempts remain recorded: stale public-image fixtures, missing SDK font
environment, SDK analytics-query admission, invalid Sharp internal import, one
incorrect PowerShell component-list invocation transient remote DB timeouts, a temporary disk-full Flutter model-health
compiler failure during the patched Gradle rebuild, and a stale profile-fixture
precondition (restored without changing the original assertion).
The shared-schema runner now checks the baseline catalogue before the Admin
journey intentionally publishes an additional document. The original 7/4 sections
and 25-document assertions remain unchanged; no production corpus is edited.
Assertions were preserved/strengthened and actual source causes corrected. No
test was disabled to obtain green results.

## Remaining risks, actions and Phase 25 boundary

| Priority | Required action / owner | Deadline |
|---|---|---|
| P0 | None discovered in the verified scope; this is not proof of absence | Reassess on material changes |
| P1 release gate | Project operator: separate owner/migration/Node/AI DB identities and narrow grants; prove production guards accept only runtime roles | Before any production startup/hosting |
| P1 release gate | Operator: private AI network, HTTPS, exact proxy trust, shared quotas/budgets, secret manager and least-privilege provider credentials | Before public exposure/multiple instances |
| P1 conditional | Owner: inspect legacy cloud assets/disclosed links, approve invalidation/migration if any exist | Before public release; no existing user-data deletion authorized here |
| P2 | Owner: approve retention/erasure/provider-processing policy; the proposed durations above are not enacted | Before collecting real personal data/public anonymous use |
| P2 | Maintainer: preserve no-untrusted-model/JIT/PT2 restriction and triage future Torch patch with approved parity validation | Every dependency/artifact change; before enabling any new model-loading path |
| P2 | Operator: backups/restore drill, secret rotation/incident runbook, log access/rotation, scheduled durable cleanup | Before production acceptance; scheduling belongs to Phase 25 |
| P2 | Tester: physical Android picker/permissions/restart/offline and TLS-hosted browser checks | Before demo/release acceptance |
| P2/P3 | Existing registration enumeration, transient memory images, process-local counters/limits, source review and limited local build-disk headroom | Revisit privacy/hosting; provide disk headroom before future clean Android builds |
| Product/content | Licensed disease-reference media and approved fertilizer/yield inputs remain pending, research-only model/data licensing unchanged | Before claiming full product/commercial readiness |

No paid service, hosting topology, retention duration or credential change was
chosen on the user's behalf. Approved final decisions are protected image
delivery and unchanged retention; see [decisions](DECISIONS.md). Phase 25 may
be planned only after this report, and must be separately authorized. No deployment
was started. Final Git inventory and verification ledger follow.

## Final verdict and live verification ledger

**PASS WITH DOCUMENTED LIMITATIONS** for Phase 24. **READY WITH DOCUMENTED
LIMITATIONS** for separately authorized Phase 25 preparation; public release is
conditional on the explicit credential/network/privacy gates above. No Phase 25/26,
deployment or full-product/commercial acceptance is implied.

Final status is **19/19 integration categories PASS, zero selected live skips**,
assembled from the isolated runs below. This is not a claim that one uninterrupted
full invocation passed. Five earlier failed run records are retained unchanged:
12 PASS/8 FAIL; startup failure with no checks; 3 PASS/17 FAIL; 2 PASS/1 FAIL; and
14 PASS/3 FAIL, respectively (preflight included in these counts). Network failures,
fixture contract/order defects and the temporary disk-full compile failure are
reported, fixed/rechecked where applicable, not suppressed.

| Integration category | Final result | Evidence run |
|---|---|---|
|admin-analytics|PASS; zero skips|`20261015T224740Z-b73eee44`|
|assistant|PASS; zero skips|`20261015T224740Z-b73eee44`|
|database|PASS; zero skips|`20261015T200338Z-534327a9`|
|farmer-analytics|PASS; zero skips|`20261015T224740Z-b73eee44`|
|farmer-remediation|PASS; zero skips|`20261015T231621Z-ea672952`|
|farmer-scan|PASS; zero skips|`20261015T224740Z-b73eee44`|
|fertilizer|PASS; zero skips|`20261015T224740Z-b73eee44`|
|generation|PASS; zero skips|`20261015T224740Z-b73eee44`|
|guest-inference|PASS; zero skips|`20261015T224740Z-b73eee44`|
|guest-upload|PASS; zero skips|`20261015T224740Z-b73eee44`|
|journey|PASS; zero skips|`20261015T231621Z-ea672952`|
|knowledge|PASS; zero skips|`20261015T224740Z-b73eee44`|
|management|PASS; zero skips|`20261015T224740Z-b73eee44`|
|migrations|PASS; zero skips|`20261015T200338Z-534327a9`|
|model-health|PASS; zero skips|`20261015T231621Z-ea672952`|
|original-requirements|PASS; zero skips|`20261015T231621Z-ea672952`|
|rag-database|PASS; zero skips|`20261015T224740Z-b73eee44`|
|upload-api|PASS; zero skips|`20261015T223959Z-4578d1dd`|
|yield|PASS; zero skips|`20261015T224740Z-b73eee44`|

The final four-category run passed all five selected checks including schema
preflight, removed its owned schema and confirmed all 21 production table counts
unchanged. The five earlier retained root schemas were separately reconciled and
removed: every remaining fixture cloud reference had confirmed provider cleanup.
Independent RAG/Admin/model-health schemas are also removed. The final catalogue
probe is recorded separately. Only generated test accounts/images/configuration
were used; no lasting test/Admin account or real-user mutation.

Real upload API suite passed both tests (four generated JPEG/PNG/WebP
inference inputs, anonymous and farmer). Representative model-only mean was 51.63ms;
this is neither end-to-end application latency nor a class-accuracy claim.
The three opt-in SQL tests and 13 Flutter live gates were enabled separately from
the default suites. The main connected host-widget journey passed two tests.
Physical Android/device/browser release-hosting checks remain unverified.
Legacy Phase 23 journey log wording still calls the Knowledge UI a placeholder;
the separate farmer-remediation gate actually verifies its completed UI, all four
details, 25 sourced sections and real semantic search. Do not use that old log label
as a current feature verdict.

Git scope: 84 reviewed related files on `main`; the security commit contains this
report. Original `.gitignore`, ML documentation/scaffolding and the unrelated
PROJECT_STATE section are preserved outside it. No generated SDK, private config,
raw dataset, checkpoint, test proof containing private fixture IDs or cloud asset
is committed. The exact commit is reported in the completion response and Git log.

## Complete file inventory

The following 84 related files are reviewed for this phase. Original user changes
in .gitignore, the ML documentation/scaffolding and unrelated PROJECT_STATE section
are preserved outside the commit. Ignored SDKs/logs/configuration/fixtures are not
committed. Nine migrations, ML/shared sources/artifacts and curated corpus are unchanged.

```text
README.md
ai-service/.env.example
ai-service/README.md
ai-service/app/api/json_body.py
ai-service/app/config/settings.py
ai-service/app/rag/repository.py
ai-service/pyproject.toml
ai-service/tests/test_security_hardening.py
backend/.env.example
backend/.node-version
backend/README.md
backend/package-lock.json
backend/package.json
backend/src/application.ts
backend/src/config/environment.ts
backend/src/database/connection-url.ts
backend/src/modules/auth/auth.password.ts
backend/src/modules/health/health.repository.ts
backend/src/modules/profile/profile-media.controller.ts
backend/src/modules/profile/profile-media.repository.ts
backend/src/modules/profile/profile-media.routes.ts
backend/src/modules/profile/profile-media.service.ts
backend/src/modules/profile/profile.types.ts
backend/src/modules/scans/image-privacy.ts
backend/src/modules/scans/private-image.ts
backend/src/modules/scans/scan.controller.ts
backend/src/modules/scans/scan.routes.ts
backend/src/modules/scans/scan.service.ts
backend/src/modules/scans/scan.storage.ts
backend/src/modules/scans/scan.types.ts
backend/src/routes/index.ts
backend/tests/auth/password-security.test.ts
backend/tests/foundation/database-security.test.ts
backend/tests/foundation/environment.test.ts
backend/tests/profile/foundation.test.ts
backend/tests/scans.inference.live.integration.ts
backend/tests/scans/privacy.test.ts
docs/11-security.md
docs/15-development-environment.md
docs/16-database-operations.md
docs/18-authentication.md
docs/20-scan-uploads.md
docs/41-profile-accounts-audit.md
docs/DECISIONS.md
docs/KNOWN_ISSUES.md
docs/PROJECT_STATE.md
docs/README.md
docs/phase-24-security-hardening.md
mobile/android/gradle/wrapper/gradle-wrapper.properties
mobile/lib/app.dart
mobile/lib/core/network/api_client.dart
mobile/lib/core/widgets/private_image.dart
mobile/lib/core/widgets/private_image_view_model.dart
mobile/lib/data/models/farmer_profile.dart
mobile/lib/data/models/scan_record.dart
mobile/lib/data/repositories/private_image_repository.dart
mobile/lib/features/disease_detection/view_models/scan_result_view_model.dart
mobile/lib/features/disease_detection/views/result_view.dart
mobile/lib/features/disease_detection/widgets/scan_result_card.dart
mobile/lib/features/disease_detection/widgets/scan_result_image.dart
mobile/lib/features/profile/widgets/profile_photo_editor.dart
mobile/lib/features/scan_history/widgets/history_scan_tile.dart
mobile/test/assistant/navigation_test.dart
mobile/test/farmer_flow_test.dart
mobile/test/history/helpers.dart
mobile/test/integration/e2e_test.dart
mobile/test/integration/requirements_test.dart
mobile/test/profile/helpers.dart
mobile/test/scans/helpers.dart
mobile/test/scans/result_view_model_test.dart
mobile/test/security/private_image_test.dart
scripts/README.md
scripts/audit-flutter-dependencies.py
scripts/check-development.ps1
scripts/check-e2e.py
scripts/check-model-health.mjs
scripts/check-requirements.mjs
scripts/check-scan-upload.mjs
scripts/flutter-test-environment.mjs
scripts/flutter-test-environment.test.mjs
scripts/requirements-tools.txt
scripts/run-flutter.mjs
scripts/setup-python.ps1
scripts/use-project-node.ps1
```
