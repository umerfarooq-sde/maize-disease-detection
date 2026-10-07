# Known issues

Updated: 2026-10-07 (Asia/Karachi), after Phase 9.5 dataset intake and real-image
preprocessing review. See the [current dataset review](24-dataset-intake-preprocessing-review.md),
[historical Phase 0–9 audit](23-pre-phase-10-audit.md), [project state](PROJECT_STATE.md)
and [shared preprocessing contract](22-shared-preprocessing.md) for evidence.

**Phase 10 is not ready to start:** discovery and real-image validation are complete;
remaining decisions concern training-index exclusions, mixed-rights use and approval
of one evaluated preprocessing policy. The previous missing-dataset/labels and
synthetic-only review blockers are resolved. No new P0 issue or P1 application-code
defect was established. Future feature absence remains outside the implemented phases.

## P0 — project, data-loss or serious security blockers

None found in the reviewed implementation and executed checks. This finding does
not certify production security or prove field-image/model accuracy.

## P1 — dataset and preprocessing decisions before Phase 10

| Issue | Evidence | Required action |
|---|---|---|
| Contradictory supervised labels | Three visually confirmed cross-label families contain seven filenames/five byte contents assigned to Gray_Leaf_Spot and Northern_Corn_Leaf_Blight. Two families contain exact duplicates; the review also identifies a rotated member and a differently encoded shared photograph. | Approve exclusion of whole conflicting families from the future supervised index, or obtain qualified adjudication if retaining them matters. Preserve originals; never choose a class automatically. Exact paths are in the current dataset review. |
| Shared-invalid inputs | Both policies reject the same 11 files: four misleading extensions, one multi-frame MPO, two invalid color profiles and four size/dimension failures. These are admissibility failures, not eleven unreadable/corrupt images. | Approve recorded index exclusions. No automatic source rename, conversion, deletion or validation relaxation is required. Any future repair policy must retain originals and serving parity. |
| Evaluated preprocessing policy awaits approval | Both shared policies were attempted on all 8,040 images; 8,029 are accepted. Conservative extraction falls back on 8,021 (99.900%) and extracts only eight files/four unique Rust contents. The primary visual review covers 81 filenames/78 contents; no obvious tissue deletion was observed in that sample. | Recommend full-frame preprocessing through the existing shared package for the first baseline. Approve and record the same policy/configuration for training and serving. The canonical conservative default was not changed. |
| Mixed-rights intended use remains unresolved | Recovered Corn-source declarations retain original-author rights; PlantVillage declares CC BY-NC-SA 4.0. Embedded notices include non-commercial/share-alike and all-rights-reserved photographs. Download availability does not establish uniform permission. | Specify intended use and hold contrary/unclear-rights photographs out until permission is established. Source/license declarations are already recovered; do not request a manually reconstructed provenance manifest. |

The configured `DATASET_PATH` resolves to 8,040 actual images in the exact folders
`Common_Rust`, `Gray_Leaf_Spot`, `Healthy` and `Northern_Corn_Leaf_Blight`. All files
match recovered source-archive bytes. The merge has 4,186 byte-unique contents,
3,854 excess copies and ten reviewed near-content pairs/20 contents; all PlantVillage
color contents already occur in the other source. No official split exists to preserve.
Future Phase 10 must collapse copies and group recovered original identities and
confirmed derivative relatives before a reproducible stratified split. Augment only
training after splitting; never train or tune on test data. No permanent partition,
augmentation or manually preprocessed training dataset was created during Phase 9.5.

Complete independent plant/field/session mapping remains unavailable. Recovered
original filenames/UUIDs establish image identity; sparse EXIF timestamps/IDs may be
copied metadata. This is an evaluation limitation to disclose, not a demand for the
user to fabricate metadata. Folder labels, sources, existing derivative evidence and
absence of splits have already been determined from the files.

Training/splitting/augmentation/checkpoint/metrics implementation remains the scope
of a future explicitly authorized Phase 10, after the three inclusion/use/policy
decisions described in the current dataset review.

## P2 — code/configuration and dependency work before related later phases

| Issue | Current behavior / risk | Boundary and action |
|---|---|---|
| Node upload acceptance differs from shared preprocessing | Real probes show Node accepts a 1×1 PNG and a PNG with trailing bytes; shared preprocessing rejects them as `INVALID_DIMENSIONS` and `INVALID_IMAGE`. Normal PNG passes both. | Current scans remain pending without inference, so this does not block local training. Before Phase 11/12, agree inference eligibility and align validation or explicitly handle preprocessing failure. Keep all ML transforms in Python. |
| Native Flutter authentication lifecycle is deferred | Upload transport can use an injected bearer token. Mobile login, secure token persistence, HttpOnly refresh-cookie handling and serialized refresh are not implemented. | Add the native session/cookie lifecycle when mobile authentication is authorized. Backend auth is verified; this is future client work, not an existing login regression. |
| Node/FastAPI integration is deferred | Configuration placeholders and the FastAPI internal-token dependency exist; Node does not call inference and FastAPI exposes no inference operation. | Define typed image/result/error contracts, private URL/authentication and bounded calls in the integration phase. Flutter continues to call Node. No integration is invented during this audit. |
| Four high npm advisory entries remain | The Phase 0–9 full and omit-dev audits reported `deepmerge-ts` 7.1.5 and `mysql2` 3.15.3, plus propagated `@prisma/config`/`prisma` 7.10.0 entries. PostgreSQL application paths do not use MySQL or recursively merge client object graphs. | Track a compatible remediation for Prisma's dependency/optional-peer graph. Do not apply npm's suggested Prisma 6 downgrade or an unverified transitive override. |
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

The following package/platform findings and broad test counts come from the Phase
0–9 audit; unrelated backend/mobile suites were not needlessly rerun in Phase 9.5.

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

Development PostgreSQL, JWT and Cloudinary settings were verified live in the Phase
0–9 audit without exposing their values. All audit-created database fixtures/provider
assets were removed; before/after checks matched. **No new service secret is needed
for local CPU Phase 10.** Local loopback FastAPI health needs no token.

The user supplied the absolute dataset path; its value is configured in ignored
`ml-training/.env` as `DATASET_PATH`. `.env.example` contains a blank placeholder.
The reusable loader provides cwd-independent resolution, OS-variable precedence,
no interpolation/global mutation and absolute existing-directory validation. Intake,
review and future training code must use this configuration without hardcoded paths.
No manual labels, split manifests, provenance files, augmentation inventory or invented
plant metadata are requested. The remaining user responsibilities are approval of
the specific exclusion/use/preprocessing decisions and explicit Phase 10 authorization.

Later phases require deliberate choices for model/artifact compatibility, native mobile
authentication, production deployment/privacy, reviewed agricultural knowledge,
embeddings and Gemini. Gemini credentials, embedding services and production hosting
are **not required now**. No unresolved choice is recorded as an architectural decision.

## Historical Phase 0–9 verified baseline

- Backend: all **77 checked-in test cases** pass, supplemented by the farmer WebP probe;
  Prisma validation/generation, five applied migrations, catalog/invariant checks,
  replay, database diff, actual auth and pending-scan storage pass.
- Flutter: **52 isolated and two live tests** pass with formatting/analyzer checks.
- Python: AI **50**, training **5**, shared **78 in each environment** and **eight parity
  cases** pass; locked dependency checks, Ruff/strict mypy, compilation/package builds
  and live FastAPI startup/shutdown pass.

## Phase 9.5 verification

- Training: formatting/lint checks over eight files, strict mypy over four source
  files and **29 tests pass**, including dataset configuration/intake cases. Locked
  dependency checks pass with **35 training distributions**; python-dotenv 1.2.4 is
  the only added dependency.
- Real-image intake: all **8,040** files inventoried and both exact shared policies
  attempted; **8,029 accepted/11 rejected** under each. Every source byte hash matches
  its recovered archive, and final file/size/mtime/hash checks confirm no source changes.
- Cross-consumer parity: **160 real-image cases pass** (80 files × two policies),
  including configuration/version, masks, RGB/crop/final arrays, normalization,
  model/tensor values and repeated-call determinism.
- Repository/template/ignore, documentation links, whitespace and private-path/secret
  checks pass. All image-bearing comparison and source metadata artifacts remain ignored.

Stop after Phase 9.5. Approve the inclusion/use/policy decisions before explicitly
authorizing Phase 10; no classifier training, hyperparameter tuning or later feature
implementation occurred.
