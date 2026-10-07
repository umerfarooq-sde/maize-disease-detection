# Research baseline: mobilenet-v3-small-20261007-01-recovery

This immutable report contains aggregate numerical results, environment/code identity,
hyperparameters, class mapping, preprocessing provenance and diagnostic plots only.
It contains no source photographs, pixel caches or redistributed raw dataset.
Current use is **non-commercial academic/FYP research**; commercial licensing or
source replacement remains required. These internal grouped holdout scores do not
establish independent field performance or authorize production model promotion.

The foreground training process was externally interrupted during epoch 11 after
**10 fully completed epochs (2 warmup + 8 fine-tune)** out of a planned maximum 12.
The original `mobilenet-v3-small-20261007-01` directory is preserved byte-for-byte.
Recovery selected epoch 10 using the unchanged validation-only rule, strictly
reloaded it, then completed deterministic training/validation and one final test
evaluation. No additional fitting or test-based tuning occurred. Do not describe
this as completed 12-epoch training, early stopping or an exact optimizer/RNG resume.
`recovery.json` binds parent artifacts and evaluator identity; `selection-lock.json`
records selection before test evaluation. `recovery-script.txt` archives the exact
one-off evaluator source for review, rather than introducing a new serving operation.

The canonical [dataset index](../../manifests/maize-research-20261007-v1/summary.json)
records eligibility, exclusions and the fixed split. See
[Phase 10 results](../../../docs/25-ml-training-evaluation.md) for interpretation.

The full local experiment (including predictions and immutable checkpoints) is
`.cache/phase10/experiments/mobilenet-v3-small-20261007-01-recovery/` from repository root. Best checkpoint:
`checkpoints/epoch-010.pt`; SHA-256:
`a7a08eb88510fd8f58c7a30f174935bf9d6a7bfe941a0eec876ff01d32154c6d`. Model binaries are ignored by Git.
Future serving must restore this checkpoint with its exact class map, shared
preprocessing version/configuration/hash and compatible recorded dependencies.
No model was deployed or registered as production in this phase.

`integrity.json` records SHA-256 for every exported file. Numerical PNGs are generated
by Matplotlib from aggregate predictions/history, and contain no raw leaf images.
Never overwrite this report; create a distinct experiment for new runs.
