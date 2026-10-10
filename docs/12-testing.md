# Testing Strategy

> **Status:** Checks are implemented through Phase 13: trained artifact serving,
> Node/FastAPI scan orchestration, transaction/recovery, complete farmer results/history
> and session privacy tests.
> Frozen Phase 10.5 evidence is preserved; integration QA uses synthetic images. The
> [historical foundation audit](23-pre-phase-10-audit.md) distinguishes implemented
> checks from future feature tests. The
> [dataset review](24-dataset-intake-preprocessing-review.md) records real-image evidence.

## Flutter

- Unit-test ViewModels for loading, success, empty, and error transitions.
- Test repositories and API serialization, including authentication and anonymous scan flows.
- Add widget tests for scan submission, result display, retry, and key accessibility states.

## Backend

- Unit-test service rules, ownership checks, RBAC, and error mapping.
- Test repositories against an isolated database or controlled Prisma test setup.
- Add API integration tests for versioned routes, validation, anonymous scans, authenticated history, rate limits, and stable error envelopes.
- Verify that unexpected dependency failures do not produce successful-looking scan results.

## AI service

- Test image validation, decoding, preprocessing stages, invalid inputs, and output tensor contracts.
- Test model readiness, class mapping, output shape, and finite prediction values.
- Test API schemas, timeouts, provider errors, retrieval fallback, and insufficient-evidence responses.
- Test that sensitive content and credentials are not emitted in logs.

## ML pipeline

- Validate dataset integrity, labels, class mapping, and split separation.
- Prove augmentation is applied only to training data.
- Assert training and serving use the same preprocessing implementation and parameters.
- Evaluate held-out metrics, confusion matrix, per-class performance, and artifact compatibility.

### Executed Phase 10 checks (2026-10-07)

| Check | Actual result |
|---|---|
| Training-project aggregate | 92 tests passed in 77.75 seconds; Ruff formatting checks 19 files, lint passes, strict mypy passes for nine source files |
| Synthetic training/AI parity | 12 cases pass with the pinned full-frame/ImageNet configuration; shared implementation, configuration/version, RGB geometry, dtype, normalization, model arrays and tensors agree |
| Real training-image parity | 16 fixed TRAIN images, four per literal class, pass the same cross-environment comparison; validation/test images are not used for this check |
| Immutable dataset index | 4,170 eligible contents in 4,161 verified groups; 2,917 train, 628 validation, 625 test samples; zero content/group overlap |
| Exclusion and source integrity | Eleven invalid inputs and all members of three contradictory families excluded with reasons; all 8,040 original file hashes remain unchanged |
| Actual CPU smoke | 32 TRAIN and 16 VALIDATION samples; checkpoint save/reload and prediction equality pass; no TEST evaluation |

The [persisted index summary](../ml-training/manifests/maize-research-20261007-v1/summary.json)
records literal class indices, seed `20261007`, grouped 70/15/15 target ratios and actual
counts. The baseline imports the existing shared preprocessing package with extraction
disabled and ImageNet mean/std at 224×224. Its configuration hash is
`b142e59f458d27a2d3fddbfc86c2f2f802670ab4909f1275babbef92de9cb5c8`;
the generic package default is unchanged.

Preparation tests cover full-family exclusions, safe duplicate collapse, preservation
of distinct alpha semantics, confirmed derivative/original grouping, split separation,
literal label integrity, deterministic replay, changed source/evidence detection,
output safety and manifest tampering. Training tests cover TRAIN-only augmentation,
model output/finite values, checkpoint compatibility and smoke/final-test isolation.
No raw images or machine-specific dataset paths are redistributed in the index,
checkpoints or numerical reports. Raw input always resolves through `DATASET_PATH`.

From repository root, repeat the automated checks when source or configuration changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Training
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-development.ps1 -Component Preprocessing
```

The smoke is a pipeline check, not an accuracy claim. Training was externally interrupted
during epoch 11 after ten completed epochs of a twelve-epoch maximum. Separate immutable
evaluation recovery verifies the unchanged epoch-10 validation winner and evaluates TEST
once: 95.20% accuracy, 0.9396 macro F1 on 625 contents. Independent saved-CSV metric/hash
checks and zero-input checkpoint restores pass; all source names/bytes/sizes/mtimes remain
unchanged. See [results and execution limitation](25-ml-training-evaluation.md).
Do not tune from held-out results or treat these scores as independent field performance.

## RAG and calculator

- Test source attribution, retrieval filtering, citation fidelity, and weak/no-evidence behavior.
- Evaluate grounded answers using a reviewed test set.
- Unit-test deterministic agricultural calculations independently; verify the language model cannot override numeric results.

## CI and release gates

### Phase 13 executed checks (2026-10-10)

- Flutter **110 isolated tests** pass; three live tests are opt-in by default.
  Format/analyzer pass. New cases cover typed history/ownership contracts, scan/result
  loading/error/retry, bounded polling/disposal, private guest capabilities, pagination,
  high-score uncertainty, native sessions/serialized refresh, delayed previous-session
  responses, login/logout and complete route transitions.
- Backend **162 isolated tests**, format/lint/strict TypeScript/build/environment pass.
  New history PostgreSQL suite **4 tests** verifies microsecond/tied ordering,
  new inserts between pages and private cursor isolation. Prisma validation and
  six-migration status pass; no migration is introduced.
- FastAPI **219 tests**, Ruff format/lint and strict mypy pass; model/shared sources
  are unchanged. Frozen ML artifact checks read hashes only, never dataset partitions.
- Both live Flutter guest and farmer tests pass against real Cloudinary/PostgreSQL
  and the approved FastAPI model. Farmer check verifies owned history/detail and
  another farmer's denial. Generated fixture assets/rows/users are removed; actual
  FastAPI loads once and shuts down cleanly. Physical-device picker remains unverified.

See [farmer workflow verification](29-farmer-detection-history.md).

### Phase 12 executed checks (2026-10-10)

- Backend format/lint/strict TypeScript/build/environment and **156 isolated tests** pass.
- Six migration replay/deployment/status checks pass with no structural drift; new
  inference/database suite **7 tests** verifies registration, real persistence,
  rollback, ownership, stale attempt fencing and SQL constraints.
- AI **219 tests**, Ruff formatting/lint and strict mypy pass. Shared **78 tests in
  each environment**, strict checks and **12 exact synthetic parity cases** pass.
- Cross-language admission QA **56 cases**, 21 accepted and 35 rejected, passes
  without dataset/model access. Flutter **59 tests** and analyzer pass; two live
  tests are opt-in. Detailed live integration results are recorded in
  [integration verification](28-node-fastapi-integration.md).

From `backend`: `npm.cmd run check`, `npm.cmd run db:check`,
`npm.cmd run test:auth:database`, `npm.cmd run test:scans:database`,
`npm.cmd run test:inference:database`, `npm.cmd run db:check:migrations`,
`npm.cmd run db:status` and `npm.cmd run db:diff`.
AI/shared checks use `scripts/check-development.ps1 -Component AI/Preprocessing`.
Run the admission script with the AI environment's Python. The optional real
provider/model API and Flutter tests require a configured running FastAPI service
and registered approved model; no test partition is read or rescored.

Run focused tests on changed components, then required full suites before release. Require formatting, linting, static/type checks, migration validation, and integration/contract checks. Record test data and model versions to make results reproducible. Do not use the held-out ML test set for training or repeated tuning.
