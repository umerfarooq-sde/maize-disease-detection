# Shared preprocessing boundary

Phase 9 installs `maizedoctor_preprocessing` from `shared/preprocessing`. This module
re-exports its exact public functions without serving-specific transformations.
Phase 11 inference uses the approved full-frame 1.0.0 configuration and existing
tensor conversion, verified against frozen TRAIN tensor/logit hashes. Augmentation
stays outside this pipeline. See [inference admission/parity](../../../docs/27-production-ml-inference.md).
See [shared preprocessing](../../../docs/22-shared-preprocessing.md).
