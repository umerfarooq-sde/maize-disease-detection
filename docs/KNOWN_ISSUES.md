# Known issues

Updated: 2026-10-10 (Asia/Karachi), Phase 12 integration.

Phase 11 internal classifier serving is complete: approved-artifact startup/readiness,
authenticated prediction/model health, exact shared full-frame preprocessing and
bounded requests are verified. All 219 AI tests and 16 frozen TRAIN serving parity
cases pass; representative end-to-end preprocessing/inference averages 17.75 ms
locally. No operational threshold is approved: all current results explicitly report
`LOW_CONFIDENCE/THRESHOLD_UNCONFIGURED`. See [the inference contract](27-production-ml-inference.md).
Node orchestration is implemented; deployment and detailed result UI remain deferred. Scientific/use limitations below
are preserved and no final TEST evaluation is repeated.

Phase 10.5 is complete. **FIT WITH DOCUMENTED LIMITATIONS** for a local FYP
research inference prototype. The original v1 scoring arithmetic is preserved, but
confirmed transformed-parent leakage invalidates its independent-evaluation claim.
The corrected v2 index and fresh model are verified; all 8,040 original files remain
unchanged. The new evaluation is descriptive on a previously inspected corpus,
without independent field/plant validation or commercial clearance.

Selected model version `mobilenet-v3-small-v2-20261009`, experiment
`mobilenet-v3-small-20261009-v2-01`, checkpoint `checkpoints/epoch-008.pt`,
SHA-256 `e95a2e83262637fc1a08b919e6003bddb2fe70664b9c51418f059b7c8287dc66`.
The completed run stops at epoch 11 under patience 3, out of 12 maximum. Validation:
**96.81% accuracy / 0.9589 macro F1**. One post-freeze final test: **95.83% / 0.9452**,
598 correct of 624. Test Gray Leaf Spot recall is **83.53%**, F1 **0.8659**. These are
internal benchmark scores, not measured farmer-field accuracy. Calibration remains
disabled (`T=1`): group cross-fitting worsens NLL/Brier/ECE. No confidence threshold
is locked. Read [the fitness report](26-model-fitness-validation.md) and
[safe numerical/artifact evidence](../ml-training/reports/mobilenet-v3-small-20261009-v2-01-fitness/README.md).

## P0 — project, data-loss or serious security blockers

None found in the reviewed implementation and executed checks. This finding does
not certify production security or prove field-image/model accuracy.

## Resolved Phase 9.5 decisions and Phase 10 implementation requirements

| Issue | Evidence | Required action |
|---|---|---|
| Contradictory supervised labels | Three cross-label families contain seven filenames/five byte contents, including exact, rotated and re-encoded relatives. | User approved exclusion of every family member from training, validation and test. Persist explicit reason codes and evidence; preserve original bytes/names/labels. |
| Shared-invalid inputs | Both policies reject 11 files: four misleading extensions, one multi-frame MPO, two invalid color profiles and four size/dimension failures. These are admissibility failures, not eleven unreadable images. | User approved reason-coded index exclusions. No source conversion, deletion, rename or validation relaxation. |
| Full-frame baseline approved | Conservative extraction falls back on 8,021 of 8,029 accepted images; only four unique Rust contents receive extraction. | Pin shared 1.0.0 full-frame configuration/hash in every experiment/artifact. ImageNet normalization is configured centrally for pretrained MobileNetV3 Small; no separate inference transform. |
| Research use approved; commercial clearance absent | Recovered declarations include CC BY-NC-SA 4.0, original-author, non-commercial/share-alike and all-rights-reserved notices. | Current use is non-commercial academic/FYP research. Preserve declarations; never redistribute raw images through Git, reports, artifacts or app. Commercial licensing review or dataset replacement is required before commercial use. |

The configured `DATASET_PATH` resolves to 8,040 actual images in the exact folders
`Common_Rust`, `Gray_Leaf_Spot`, `Healthy` and `Northern_Corn_Leaf_Blight`. All files
match recovered source-archive bytes. The merge has 4,186 byte-unique contents,
3,854 excess copies and ten reviewed near-content pairs/20 contents; all PlantVillage
color contents already occur in the other source. No official split exists to preserve.
Phase 10.5 repairs the incomplete v1 grouping. V2 collapses copies and groups all
confirmed relatives in immutable 2,911/627/624 partitions (4,162 contents/4,121 groups),
with zero known content/group intersections. One unresolved possible Healthy parent
pair spans TRAIN/VAL; this is a disclosed risk, not confirmed leakage.
Augment only training after splitting; never train or tune on test data. No manually
preprocessed second dataset is created. All 8,040 raw names/bytes/sizes/mtimes remain unchanged.

Complete independent plant/field/session mapping remains unavailable. Recovered
original filenames/UUIDs establish image identity; sparse EXIF timestamps/IDs may be
copied metadata. This is an evaluation limitation to disclose, not a demand for the
user to fabricate metadata. Folder labels, sources, existing derivative evidence and
absence of splits have already been determined from the files.

The approved decisions are implemented in exclusions, immutable eligibility/class/split
manifests, leakage checks, train-only augmentation and versioned checkpoints/metrics.
Commercial licensing or
replacement remains a future requirement; research approval is not commercial clearance.

## P2 — code/configuration and dependency work before related later phases

| Issue | Current behavior / risk | Boundary and action |
|---|---|---|
| Admission alignment resolved in Phase 12 | Node now rejects tiny/trailing/malformed containers, invalid EXIF orientation and multi-frame APNG declarations; 56 shared synthetic cases agree (21 accepted/35 rejected). | FastAPI remains authoritative for codec/profile/preprocessing failures; persist safe FAILED outcomes and preserve the accepted scan/image. Target deployment codec parity still needs verification. |
| Native Flutter authentication lifecycle is deferred | Upload transport can use an injected bearer token. Mobile login, secure token persistence, HttpOnly refresh-cookie handling and serialized refresh are not implemented. | Add the native session/cookie lifecycle when mobile authentication is authorized. Backend auth is verified; this is future client work, not an existing login regression. |
| Node/FastAPI integration resolved in Phase 12 | Dedicated server byte client, strict output checks, version-bound transactions, owned reads and safe retries/recovery are implemented. | Flutter calls Node; complete diagnosis UI, deployment policy and native auth remain later work. See [integration](28-node-fastapi-integration.md). |
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
| Deployment preprocessing/inference resource limits | Local batch-one preprocessing/inference averages 17.75 ms; six simultaneous Uvicorn requests produce one success/five busy responses under the default bound. Worst-case 16 MP memory/time and Linux codec parity are unmeasured. | Before deployment profile maximum inputs, memory/throughput, worker count and native-thread failure supervision; validate target-platform outputs. |
| Docker runtime/native pgvector | Compose configuration validates; Docker Engine is absent, and preserved native Windows PostgreSQL lacks pgvector binaries. Configured Neon works. | Only if choosing those alternative environments; verify pgvector and migrations there. Not required for local CPU training with the current database. |

## P3 — maintenance and coverage

The following package/platform findings and broad test counts come from the Phase
0–9 audit; unrelated backend/mobile suites were not needlessly rerun in Phase 9.5.

- Starlette 1.7.0 emits its HTTPX TestClient deprecation warning; all 50 AI tests pass.
  Migrate the test client deliberately with lock/compatibility checks. The existing
  pg query-queue deprecation warning also remains a dependency-maintenance item.
  The expanded Phase 11 AI suite now passes 219 tests with the same existing warning.
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
assets were removed; before/after checks matched. CPU training does not require a
service secret. Phase 11 inference startup requires a server-only token even on
loopback; an ignored local token is configured without printing it. Public `/health`
requires no token, while internal prediction/model health always enforce it.

The user supplied the absolute dataset path; its value is configured in ignored
`ml-training/.env` as `DATASET_PATH`. `.env.example` contains a blank placeholder.
The reusable loader provides cwd-independent resolution, OS-variable precedence,
no interpolation/global mutation and absolute existing-directory validation. Intake,
review and future training code must use this configuration without hardcoded paths.
No manual labels, split manifests, provenance files, augmentation inventory or invented
plant metadata are requested. The user approved the exclusion/use/preprocessing decisions
and explicitly authorized Phase 10. No further approval is needed for its implementation.

Model/artifact compatibility is verified in Phase 11. Later phases require native mobile
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

## Phase 10.5 model limitations and resolved data defect

- **Resolved confirmed v1 leakage:** 36 new parent relations, 22 crossing old partitions;
  four additional contradictory families excluded in full. New immutable v2 verified
  against all original filenames/bytes/sizes/mtimes; old artifacts unchanged. V1 scores
  remain historical and cannot establish independent evaluation.
- **Remaining identity uncertainty:** two unresolved Healthy pairs, including one
  TRAIN/VAL candidate. Screening/known hashes do not prove complete physical plant,
  session or field independence. Do not claim 4,162 contents are independent plants.
- **Internal evaluation only:** earlier v1 test was consumed. New fresh classifier,
  val-only decisions and single frozen v2 test prevent new test-driven tuning; they
  cannot establish an untouched external field holdout. Multi-seed/CV classifier
  stability remains unmeasured on the current CPU correction budget.
- **Source/class weakness:** VAL archive-overlap accuracy 570/579 (98.45%), Corn-only
  37/48 (77.08%), Corn-only GLS recall 2/9; no Healthy in the latter. Test GLS recall
  83.53%, F1 0.8659. Background/letterbox/watermark activation and class morphology ambiguity
  require external validation; coarse CAM is diagnostic rather than causal proof.
- **Confidence:** two validation/three test wrong predictions ≥0.99 remain. Group-fold
  temperature fitting worsens NLL/Brier/ECE; calibration is disabled (T=1). No operational cutoff is
  approved without risk/coverage/class-cost objectives; greater confidence does not
  establish correct farmer advice or OOD detection.
- **Training/artifacts verified:** completed patience 3 stop at epoch 11 (best epoch 8),
  mild selected train/VAL gap of 2.57 percentage points, no significant internal
  underfitting. 219 ML/50 AI/78 shared tests in each environment, 12 synthetic parity
  and 16 actual TRAIN compatibility cases pass; strict metadata/hash/
  independent metric checks pass. Exact optimizer/RNG resume remains unavailable.
- **Deployment boundary:** local AI forward-only latency/memory are measured, excluding
  preprocessing and concurrency. Maintain exact shared full-frame 1.0.0 config; align
  Node/Python admission or handle processing errors in later integration. No inference
  API, commercial permission or field-accuracy certification is added in this audit.

## Phase 11 serving verification and remaining boundary

Strict pinned startup, repeated inference, synthetic fixtures for every class,
JPEG/PNG/WebP and invalid admission, uncertainty-policy provenance, safe failures,
concurrent requests and graceful shutdown pass. Real serving matches all 16 saved
TRAIN tensors/logits exactly; no TEST images are reopened. Missing-checkpoint actual
startup exits 3 with safe logs, and the final approved model starts/stops cleanly.
Ruff/strict mypy, 78 shared tests in each environment, 12 synthetic parity cases,
uv lock and installed-package compatibility checks pass. Model artifacts and dependency
locks are unchanged. Future deployment still needs private networking/TLS/token rotation,
maximum-input profiling and target-platform parity; the software interface does not
establish external field accuracy, an approved certainty threshold or OOD rejection.

Stop after Phase 11. Phase 12 requires a separate instruction. Independent field
data and commercial licensing or source replacement remain future requirements.
