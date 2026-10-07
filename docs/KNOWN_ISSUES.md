# Known issues

Updated: 2026-10-07 (Asia/Karachi), after the Phase 0–9 audit. See the
[complete audit](23-pre-phase-10-audit.md), [project state](PROJECT_STATE.md) and
[shared preprocessing contract](22-shared-preprocessing.md) for verification evidence.

**Phase 10 is not ready to start:** raw sourced images, confirmed taxonomy and
representative real-image preprocessing review are pending. No new P0 issue or P1
code defect was established. Current backend, database, uploads, Flutter foundation,
FastAPI and shared preprocessing checks pass. Future feature absence is not a
regression in the implemented phases.

## P0 — project, data-loss or serious security blockers

None found in the reviewed implementation and executed checks. This finding does
not certify production security or prove field-image/model accuracy.

## P1 — external inputs required before Phase 10

| Issue | Evidence | Required action |
|---|---|---|
| No raw maize dataset or authoritative classes | `ml-training/dataset/` contains documentation scaffolding only. Workspace inspection found launcher/UI graphics, not maize photos, labels, splits or models. | Supply the actual raw-image path, exact class labels and source/license information. Prefer originals; disclose augmentation and duplicate provenance. |
| Dataset independence and split provenance unknown | No plant/capture/source grouping, original-parent mapping, official split manifest or class mapping has been supplied. | Provide available grouping/source metadata and any official partitions. Preserve duplicates until analysis. The future pipeline must split before augmentation and keep test data out of model selection. |
| Shared preprocessing lacks empirical leaf validation | All 78 shared tests and eight parity cases use synthetic inputs. Exterior tissue resembling background can be removed; small lesions may be lost through reduction/resize. Six audit stress probes verify mechanics, not field robustness. | Supply representative healthy/diseased originals, non-green tissue, edges/tips and field backgrounds. Inspect debug masks and select the evaluated configuration before training. |

These blockers need data and review. The training dependency environment and single
shared package already work. Training/splitting/augmentation/checkpoint/metrics
implementation remains the authorized scope of a future Phase 10.

## P2 — code/configuration and dependency work before related later phases

| Issue | Current behavior / risk | Boundary and action |
|---|---|---|
| Node upload acceptance differs from shared preprocessing | Real probes show Node accepts a 1×1 PNG and a PNG with trailing bytes; shared preprocessing rejects them as `INVALID_DIMENSIONS` and `INVALID_IMAGE`. Normal PNG passes both. | Current scans remain pending without inference, so this does not block local training. Before Phase 11/12, agree inference eligibility and align validation or explicitly handle preprocessing failure. Keep all ML transforms in Python. |
| Native Flutter authentication lifecycle is deferred | Upload transport can use an injected bearer token. Mobile login, secure token persistence, HttpOnly refresh-cookie handling and serialized refresh are not implemented. | Add the native session/cookie lifecycle when mobile authentication is authorized. Backend auth is verified; this is future client work, not an existing login regression. |
| Node/FastAPI integration is deferred | Configuration placeholders and the FastAPI internal-token dependency exist; Node does not call inference and FastAPI exposes no inference operation. | Define typed image/result/error contracts, private URL/authentication and bounded calls in the integration phase. Flutter continues to call Node. No integration is invented during this audit. |
| Four high npm advisory entries remain | Fresh full and omit-dev audits report `deepmerge-ts` 7.1.5 and `mysql2` 3.15.3, plus propagated `@prisma/config`/`prisma` 7.10.0 entries. PostgreSQL application paths do not use MySQL or recursively merge client object graphs. | Track a compatible remediation for Prisma's dependency/optional-peer graph. Do not apply npm's suggested Prisma 6 downgrade or an unverified transitive override. |
| Python patch baseline is old | Both environments run Python 3.11.0 and pass the configured `>=3.11,<3.12` constraints/tests. Installed PyTorch is CPU-only. | Provision a maintained compatible 3.11 patch for a new/production environment and revalidate parity. GPU/CUDA is an explicit later environment choice, not a required local-training credential. |

The dependency findings correspond to the primary advisories for
[recursive merging](https://github.com/advisories/GHSA-ggr8-5vv4-36mx),
[MySQL authentication](https://github.com/advisories/GHSA-3f6p-5ww8-9rcr) and
[MySQL decompression](https://github.com/advisories/GHSA-rgwj-5xj2-c3m3).
Four aggregate package entries do not mean four separate vulnerable application paths.

## P2 — deployment, privacy and operating decisions

| Requirement | Why it remains open | When / verification |
|---|---|---|
| Least-privilege database/provider roles, HTTPS and private AI networking | Development connectivity is verified; production roles/topology/TLS/token rotation are not selected. | Before deployment; verify scoped privileges, encrypted transport and blocked public AI access. |
| Shared rate-limit storage and proxy policy | Counters are currently per process; proxy trust requires the actual deployment topology. | Before multiple replicas/proxy deployment; verify limits across replicas and trusted client-IP handling. |
| Scheduled scan cleanup | Durable cleanup CLI exists, but no OS/deployment schedule is installed. | Before persistent hosting; schedule `npm run scans:cleanup` every five minutes and verify recovery of abandoned attempts. |
| Signed-image delivery, retention and EXIF privacy | Signed Cloudinary URLs are bearer capabilities; uploaded originals may retain EXIF/location metadata. Completed-scan retention/deletion and owner-checked future delivery need a policy. | Before broad distribution/production; approve policy and test access, retention and deletion without publishing signed URLs. |
| Measured preprocessing/inference resource limits | Byte/pixel caps bound individual images; no model-specific worker memory/time/concurrency measurements exist. Windows parity does not establish Linux codec parity. | Before inference deployment; profile representative maximum inputs and validate target-platform outputs. |
| Docker runtime/native pgvector | Compose configuration validates; Docker Engine is absent, and preserved native Windows PostgreSQL lacks pgvector binaries. Configured Neon works. | Only if choosing those alternative environments; verify pgvector and migrations there. Not required for local CPU training with the current database. |

## P3 — maintenance and coverage

- Starlette 1.7.0 emits its HTTPX TestClient deprecation warning; all 50 AI tests pass.
  Migrate the test client deliberately with lock/compatibility checks. The existing
  pg query-queue deprecation warning also remains a dependency-maintenance item.
- `npm ls --all` exits successfully but labels three installed, lock-matching Sharp
  optional/WASM packages extraneous. Native JPEG/PNG/WebP checks pass; this does not
  establish an application or lock defect. Reconcile during planned dependency setup.
- Provider WebP was verified with a fresh authenticated farmer audit probe, alongside
  checked-in PNG/oriented-JPEG integration coverage. Some SDK malformed-result branches,
  individual JWT claim rejection branches and the real admin CLI entrypoint lack
  dedicated automated cases; expand coverage when those areas change.
- Physical-device gallery/camera, iOS permissions/scaffolding and release signing remain
  unverified. Android build/plugin checks and 52 isolated plus two live Flutter tests
  pass. An interactive emulator/device check remains manual platform verification.
- `uv` is not on the current PATH. The documented repository fallback executable and
  setup script work; optional PATH configuration is not a blocker.

## Configuration, credentials and user responsibilities

Current development PostgreSQL, JWT and Cloudinary settings are configured and were
verified live without exposing their values. All audit-created database fixtures and
provider assets were removed; before/after database checks match. **No new service
secret is needed for local CPU Phase 10.** Local loopback FastAPI health needs no token.

Before Phase 10, the user must provide raw-image access, exact labels/taxonomy,
licensing/provenance, available grouping/official split information, and representative
photos for preprocessing review. The audit specifies an acceptable folder/manifest
layout; no dataset path or disease list is invented.

Later phases require deliberate choices for model/artifact compatibility, native mobile
authentication, production deployment/privacy, reviewed agricultural knowledge,
embeddings and Gemini. Gemini credentials, embedding services and production hosting
are **not required now**. No unresolved choice is recorded as an architectural decision.

## Verified baseline

- Backend: all **77 checked-in test cases** pass, supplemented by the farmer WebP probe;
  Prisma validation/generation, five applied migrations, catalog/invariant checks,
  replay, database diff, actual auth and pending-scan storage pass.
- Flutter: **52 isolated and two live tests** pass with formatting/analyzer checks.
- Python: AI **50**, training **5**, shared **78 in each environment** and **eight parity
  cases** pass; locked dependency checks, Ruff/strict mypy, compilation/package builds
  and live FastAPI startup/shutdown pass.

Stop at this checkpoint. Resolve the P1 external inputs and real-image policy before
explicitly authorizing Phase 10; no model training or later feature implementation
occurred during the audit.
