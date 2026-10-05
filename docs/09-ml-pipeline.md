# Machine-Learning Pipeline

> **Status:** Required pipeline design; dataset, model, class taxonomy, and measured metrics are not yet documented.

## Training/inference parity

Training and production inference must call the same shared preprocessing implementation. Do not copy preprocessing into separate training and serving code paths. The shared pipeline should apply the relevant steps consistently:

1. Validate file and image dimensions.
2. Decode and convert color channels.
3. Apply the agreed segmentation/background-removal behavior.
4. Crop and resize with recorded parameters.
5. Normalize with the same values and channel order.
6. Convert to the model's expected tensor type and shape.

Test parity with representative images and verify tensor shape, dtype, range, and channel order.

## Dataset hygiene

- Validate labels, class mapping, file integrity, and duplicates before training.
- Split by the appropriate independent unit before augmentation to prevent leakage.
- Never use test examples during training or model selection.
- Never augment validation or test data.
- Keep a held-out test set for final evaluation and document split provenance.
- Record data source, license/consent constraints, collection period, and preprocessing version.

## Evaluation

Track and retain:

- Accuracy, precision, recall, and F1.
- Confusion matrix and per-class metrics.
- Training/validation loss and accuracy by epoch.
- Dataset split and class distribution.
- Model, code, preprocessing, and configuration versions.

Report class imbalance and uncertainty. A high aggregate score alone is not sufficient evidence for safe farmer-facing recommendations.

## Experiment and release management

Track experiments reproducibly, including random seeds, code revision, hyperparameters, dataset version, and metrics. Register immutable model artifacts with an explicit class mapping and compatibility metadata. Promote models through review and validation; never overwrite the production artifact in place. Keep a rollback path.

## Inference validation

Test model load/readiness, output dimensions, finite scores, class-index mapping, invalid inputs, low-confidence behavior, and compatibility between the deployed artifact and preprocessing. Define confidence thresholds only from evaluation and product requirements; do not invent a threshold in the absence of evidence.
