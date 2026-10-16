# Phase 24.5 — fresh execution and real-versus-mock evidence

Baseline HEAD `840f7fd`; all evidence below is fresh for this audit unless explicitly
called historical. Private logs/proofs remain ignored in `.cache/phase245` and new
owned `.cache/phase23/<run>` directories. No assertions were weakened. No raw dataset,
fitting, final-test reevaluation, model promotion or real-user mutation occurred.

## Component execution

Project Node selected with `. ./scripts/use-project-node.ps1`. Component command:
`powershell -NoProfile -File scripts/check-development.ps1 -Component <name>`.
Individual child exit codes were recorded rather than relying on the last shell
command. Formatting is check-only; no unrelated source was autoformatted.

| Exact check / command | Fresh result | Scope / skips |
|---|---|---|
| `-Component Backend` → `npm run check`, environment sentinel tests | PASS: formatting/lint/strict TypeScript/build, 322 backend tests +2 subprocess tests | No default backend skips; existing informational lint notices only |
| `-Component AI` → Ruff format/check, mypy, pytest | PASS:46 typed source files, 356 tests |3 explicit opt-in SQL skips, 1 existing Starlette TestClient deprecation warning; live SQL enabled separately |
| `-Component Training` → Ruff/mypy/pytest | PASS:219 fixture/tooling tests | No real fit, raw dataset read or final-test scoring |
| `-Component Preprocessing` | PASS:78 tests in AI env, 78 in training env;12 exact synthetic config/image parity cases | Shared masks/CHW/tensor/provenance equal; does not claim current raw-image reinventory |
| `-Component Flutter` → `flutter analyze`, `flutter test` | PASS: analyzer, 374 tests |13 explicit default live opt-in skips; host-widget targets only |
| `dart format --output=none --set-exit-if-changed mobile/lib mobile/test` | PASS:219 files, zero changes | No widget source rewrite |
| `node ../scripts/run-flutter.mjs build apk --debug --target-platform android-arm64` from mobile | PASS: fresh APK;53.05s wrapper | Gradle 8.14.6; packaging only, not emulator/phone acceptance |
| `-Component Prisma` → validate/generate/typecheck/integration/status | PASS: valid schema/generated7.10 client, 13 rollback tests, nine migrations up to date | Existing pg client.query concurrency deprecation warning; no reset/migration mutation |
| `-Component Database` → `npm run check:database` | PASS: authenticated PostgreSQL 18.6 temporary SQL round trip | Bounded actual DB probe |
| `npm run db:diff` | PASS: no difference | Existing datasource versus committed schema |
| `-Component Docker` | PASS: Compose configuration | Does not prove Docker daemon or production Node/AI images |
| `powershell -File scripts/check-repository.ps1` | PASS: structure/templates/blank secrets/ignore rules | Current foundation; not feature completeness |
| Read-only catalog probe | PASS:21 tables, 9 migrations, 27 checks, 27FKs, 38 triggers, 84 indexes, vector0.8.6 | Four diseases/four sources/25 active docs/25 READY chunks; user/scan/rule/image tables empty |
| Runtime Express stack / FastAPI factory OpenAPI inventory | PASS:44 Node and 10 AI operations | Excludes all-method profile middleware and framework implicit HEAD/OPTIONS |
| Immutable manifest/checkpoint audit | PASS:4162 unique/4121 groups;2911/627/624;zero group overlap;171 frozen file hashes | Excludes preserved pre-existing ML README edit; raw images not read |
| Current known-secret/path/link check | PASS before final document reconciliation; final check recorded on completion | Configured values only, no claim of detecting every unknown historical secret |
| `npm audit --json` | PASS:0 vulnerabilities in all installed dependency audit | Actual lock/current advisory database; not just production-only audit |
| `python scripts/audit-flutter-dependencies.py --output <ignored>` | PASS:47 hosted Pub packages, 0 affected | SDK/OS/JDK not exhaustively certified |
| `uvx --from pip-audit pip-audit --path <actual site-packages> --skip-editable --format json --progress-spinner off` | AI/training/tooling generic audits PASS, 0 mapped findings | Editable shared package and CPU Torch/Torchvision wheels explicitly skipped; tools3 mapped |
| Supplemental normalized CPU requirements OSV audit | Exit1:2 known Torch advisories, retained | PYSEC-2025-194/JIT and PYSEC-2026-139/PT2; unused restricted paths; no package/model changes authorized |
| `python scripts/check-image-admission-contract.py` | PASS:56 synthetic cases,21 accepted/35 rejected; original admitted bytes unchanged | Node and exact shared preprocessing agree; no dataset/model/provider used |
| Read-only Node/AI runtime privilege and TLS probes | PASS: real current roles rejected for production; Node runtime/direct TLS encrypted and certificate authorized; AI client TLS enabled | No role/grant/credential changes; provider-side SSL view is a separate termination boundary |
| Actual registry versus approved metadata/checkpoint | PASS: version/architecture/preprocess/dataset/classes/checkpoint hash/status match | Registry remains VALIDATED; no promotion |
| Audit-only delayed profile-cleanup fixture | REPRODUCED AUD-16:16.52s service duration after successful DB-association mock, response still pending beyond15s | Controlled16.5s storage-delete delay; no real DB/Cloudinary used; package tests unchanged |

## Unmodified startup failure and explicit alternate configuration

`python scripts/check-e2e.py` under the original configured environment **FAILS**:
`CONFIDENCE_POLICY_INVALID` before categories. Run
`20261016T002510Z-95e26c92`:0 checks; owned schema removed, public counts unchanged,
no cloud assets created. Local dotenv has a nonempty optional policy hash but no
policy file (lines19/20). The service correctly refuses inconsistent configuration.
Component settings fixtures do not detect this local environment mismatch.

An attempted PowerShell empty-variable override also fails before categories:
`20261016T002751Z-adc09c2a`. On this PowerShell/Windows environment assigning an empty
environment variable removes it, allowing dotenv's stale value to remain. That
attempt is retained, not called successful verification.

Further isolated evidence uses an explicit **Python-process-only** empty policy-hash
override, with the absent policy path asserted. This matches the already approved
null-threshold policy. No dotenv/model/metadata/shared config file is edited; all
checkpoint/metadata integrity and startup pairing guards still execute. It is **not
an unmodified-environment pass** and does not close AUD-01. The exact ignored wrapper
sets `os.environ['CONFIDENCE_POLICY_SHA256']=''` then runs the existing harness with
`runpy.run_path(..., run_name='__main__')` in that same Python process.

The resulting run `20261016T003135Z-29c79c02` completes in 1,555.45s:
**19/19 categories plus schema preflight PASS in one uninterrupted invocation under
the explicit policy override**, zero selected live skips. Owned schema removed,
generated Cloudinary assets reconciled, and all 21 public table counts unchanged.
The three opt-in RAG SQL tests and selected Flutter live gates execute. This is not
an unmodified default-environment pass; neither earlier startup failure is erased.
No historical category is substituted as fresh evidence.

## Feature evidence quality

| Feature | Unit/repository/widget | Actual SQL / external-provider integration | E2E / limitation |
|---|---|---|---|
| Registration/auth | Credentials, duplicate, role injection, JWT integrity/expiry/rotation/replay/logout/session UI | Real users/session fixtures | Actual registration/login/widget flow; no persistent named account |
| Profile/photo | Revision conflict, fields, disposal, queue, commit-ack/provider cleanup failures | Real PostgreSQL and generated Cloudinary photos/protected delivery | Relogin/reconstructed app tree; no phone-process acceptance |
| Guest/Farmer scan | Multipart/container/admission/HTTP/lease/retry/ownership tests | Actual Cloudinary + FastAPI approved checkpoint + PostgreSQL | Host-widget/API chain, not field classification accuracy |
| History/private images | Cursor ownership, nulls, current-session fences/queued thumbnails | Real saved rows/protected image bytes | Cross-owner/Admin/key denial; no exhaustive legacy-provider inventory |
| Knowledge | Four-class pages/search, sources, rendering/errors | Real PostgreSQL docs and Google/pgvector | Separate farmer-remediation gate proves UI; old placeholder labels do not |
| RAG ingestion/index | Chunk boundaries, replay/version/source metadata and fake-embedder failures | Real SQL opt-in tests plus Google indexing/retrieval |25 reviewed documents; no unapproved corpus expansion |
| Gemini/assistant | Scope/empty/conflict/injection/citation/replay/provider-failure mocks | Actual configured Google generation/retrieval | Evidence selection/excerpts, not unchecked general chatbot |
| Scan explanation | Ownership, preserved label/confidence/model, low-confidence rendering | Real stored prediction and Gemini; some explanation-specific scans are controlled DB fixtures | Actual uploaded pinned-model scan tested separately and in journey |
| Fertilizer/yield | Exact conversion/precision/rounding/limits/versions and UI pending states | Actual transactions and intentionally synthetic reviewed rule/config | No real agronomic recommendation/forecast content |
| Farmer/Admin analytics | Counts/status/latest predictions/dates/empty/filter/RBAC/charts | SQL synthetic volume and real fixture aggregate checks | Local plan checks are not production-scale load/SLO proof |
| Admin account/audit | Farmer denial, filters, confirmation/conflict/redaction | Real transactional revocation/audit rollback/immutability | No real user suspension/deletion |
| Admin knowledge | Strict review/forms/version/archival/index-provider-failure mocks | Actual isolated Google/SQL indexing/publication/retrieval | A human review attestation is not automatic agricultural/legal validation |
| Model health | Registry/readiness/offline confusion/per-class/runtime/counter tests | Actual approved checkpoint/DB/AI probe | Offline benchmark versus runtime is explicit; no field accuracy/drift |
| Security | TLS/privilege/env/Argon2/rate-limit/redirect/metadata/capability tests | Actual generated private-media probes and DB/client TLS | Production roles are rejected, not silently provisioned |

## Error/recovery matrix

| Scenario | Evidence / expected result | Real outage? |
|---|---|---|
| API/no network/slow timeout | ApiClient/repository/ViewModel/widget simulations; safe error/retry, no stale success | Mock/local controlled |
| DB unavailable/startup query failure | Foundation/dependency/repository failure tests; no listen/false persistence, cleanup uncertainty retained | Simulated; live successful SQL separately |
| FastAPI unavailable/timeout/malformed response | Dedicated Node client tests; FAILED scan/error, original record retained | Local/mocked; no sabotage of real service |
| Cloudinary unavailable/upload failure | Storage/service tests; durable journal/compensation and retry | Mocked failure; actual owned upload/delete separately |
| Gemini unavailable/timeout/bad IDs | Bounded transport/context/selection tests; safe mapped errors, no invented factual answer | Mocked failure; actual provider success separately |
| Invalid/expired/replayed JWT/refresh | Auth API/session tests;401, revoked family, cleared UI session | Unit/API fixtures |
| Suspended/deactivated user | Accounts/auth tests; locked status+revoke+audit transaction, subsequent auth/refresh denied | Real generated-user SQL fixture |
| Wrong owner/Admin/guest key | Profile/scan/image/assistant contracts;403/404/401 as appropriate | Real fixtures plus unit negative cases |
| Invalid/corrupt/unsupported/animated/oversized/small image | Node/shared/AI admission tests; rejected before success/persistence | Synthetic container fixtures |
| Low confidence | Approved null threshold retained; explicit LOW_CONFIDENCE and warning | Actual selected model plus schema/widget fixtures |
| Missing/corrupt/incompatible model | Artifact/startup tests; fail closed, no fake classifier | Synthetic corrupt/missing fixtures; approved artifact separately hashed |
| Inconsistent optional policy config | Fresh actual baseline startup fails CONFIDENCE_POLICY_INVALID | Actual local configuration failure, AUD-01 |
| Stale/archived knowledge | Version/index/context tests and management fixture; excluded or explicit conflict | Real disposable versions plus mocks |
| Missing calculator rules/config | Actual catalogues empty; pending states, no fabricated quantity | Real configured DB |
| Invalid/negative calculator input | Exact-unit/service/API/ViewModel tests reject invalid/bounded input | Synthetic reviewed fixtures |
| Duplicate account | Real registered fixture duplicate409, UI clean handling | Real disposable account |
| Profile/Admin optimistic conflict | Revision-pinned requests, reload required; no overwrite | Unit + real fixture transaction |
| Upload interruption/ack loss/cleanup failure | Scan/profile journal tests; current/possibly committed assets not deleted, retry CLI retained | Mocked failure plus actual rollback/cleanup fixtures |
| Slow avatar deletion after successful mutation | AUD-16 local fixture reproduces response pending past15s after removal commits; eventual success at16.52s | Simulated provider delay, not a real provider outage; deadline mismatch is open |
| Navigation/disposal/account switch during work | Scoped providers/session revisions fence late results/images/chat | Host-widget/repository tests, not native app-background proof |

## Coverage cautions and false-positive evidence

Legacy `e2e_test.dart:74, 136` and `check-e2e.mjs:246` describe registration/library as
missing. Those labels are false current metadata, not a failing live UI connection;
newer registration/Knowledge gates inspect the actual screens. Conversely the
`NOT_RECORDED` assertion verifies honest unavailable output, **not implemented AI
monitoring**. Empty pending-rule assertions verify safety, **not real agronomy**.
Synthetic explanation fixtures verify ownership/grounding, **not image inference**;
the actual upload-model category supplies distinct evidence. Default unit suites
use isolated settings and therefore passed despite the real dotenv startup defect.

No physical-device, release-hosted browser, destructive live outage, external field,
commercial-license or real-calculator recommendation test is claimed. Local synthetic
inference timing is not app latency or accuracy. Original Phase 24 19/19 assembled
passes remain historical; the fresh run/override and every failed attempt are explicit.

## Final per-category live ledger

All rows belong to the same explicit-policy run, not a merge of historical passes.

| Category | Result | Seconds | Selected skips |
|---|---|---:|---:|
| schema-preflight | PASS | 6.81 | 0 |
| database | PASS | 77.48 | 0 |
| migrations | PASS | 9.11 | 0 |
| rag-database | PASS | 89.91 | 0 |
| knowledge | PASS | 27.22 | 0 |
| generation | PASS | 123.89 | 0 |
| upload-api | PASS | 76.92 | 0 |
| guest-upload | PASS | 32.2 | 0 |
| guest-inference | PASS | 31.08 | 0 |
| farmer-scan | PASS | 48.77 | 0 |
| assistant | PASS | 69.67 | 0 |
| fertilizer | PASS | 62.53 | 0 |
| yield | PASS | 43.64 | 0 |
| farmer-analytics | PASS | 54.45 | 0 |
| admin-analytics | PASS | 47.73 | 0 |
| management | PASS | 309.94 | 0 |
| model-health | PASS | 33.59 | 0 |
| farmer-remediation | PASS | 45.16 | 0 |
| original-requirements | PASS | 155.0 | 0 |
| journey | PASS | 173.78 | 0 |

Actual model-only inference mean: **78.55ms across four synthetic JPEG/PNG/WebP
images**. No class-accuracy or end-to-end-latency claim. Six grounded Google calls
in the generation category average 11,807.81ms service duration (range
8,533.16–15,809.53ms), including retrieval/context. One synthetic 7,000-scan farmer
aggregate EXPLAIN reports 0.317ms execution/0.287ms planning; this is an isolated-plan
measurement, not a production SLO.

## Evidence-level assignments

| Capability | Evidence status and boundary |
|---|---|
| Registration/login/refresh/logout | REAL END-TO-END VERIFIED through actual host-widget/API/SQL fixtures |
| Profile/avatar/private delivery | REAL END-TO-END VERIFIED under normal provider behavior; AUD-16 delayed-cleanup failure separately reproduced |
| Guest/farmer scan/history | REAL END-TO-END VERIFIED with injected synthetic picker and actual Cloudinary/model/PostgreSQL |
| Knowledge catalogue/search/details | REAL END-TO-END VERIFIED; all four contexts/source sections and real vector search |
| Assistant/owned scan explanation | REAL END-TO-END VERIFIED with actual Google; safety/outage edge cases MOCK / UNIT VERIFIED ONLY |
| Ingestion/reingestion/pgvector/index/archive | REAL SERVICE INTEGRATION VERIFIED; real SQL and Google, isolated reviewed documents |
| Calculator engineering | REAL END-TO-END VERIFIED with synthetic reviewed rules/configuration only |
| Real fertilizer/yield recommendations | NOT VERIFIED / missing approved agronomic model/content and related capability |
| Farmer/Admin analytics | REAL END-TO-END VERIFIED with real fixture aggregates |
| Admin accounts/knowledge/audit/model health | REAL END-TO-END VERIFIED with disposable users/docs/configurations |
| Disease-reference media and AI-request monitoring | NOT VERIFIED / missing implementation; source inspection establishes the gap |
| Production privilege rejection / client TLS | REAL SERVICE INTEGRATION VERIFIED against current development identities |
| Corrupt-model/schema/missing-model negative cases | LOCAL INTEGRATION VERIFIED with controlled fixtures; baseline optional-policy startup FAILED in actual environment |
| Provider outages and hostile malformed provider output | MOCK / UNIT VERIFIED ONLY; live services not deliberately disrupted |
| Physical camera/device/browser release/field accuracy | NOT VERIFIED; packaging/host widgets cannot establish these |
