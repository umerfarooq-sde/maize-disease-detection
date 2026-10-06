# Shared preprocessing boundary

Phase 9 installs `maizedoctor_preprocessing` from `shared/preprocessing`. This module
re-exports its exact public functions without serving-specific transformations. Future
inference must use the same version/configuration/mask policy as training; augmentation
stays outside this pipeline. No preprocessing or inference HTTP endpoint is added.
See [shared preprocessing](../../../docs/22-shared-preprocessing.md).
