# Classification boundary

Phase 11 `InferenceService` uses the startup-loaded frozen CPU classifier and the
exact shared preprocessing API/configuration. It bounds concurrent work, validates
output shape/probabilities and returns typed class, uncertainty, version and timing
information. It never reloads weights per request or invents a confidence threshold.
Node retains scan state/orchestration. See
[the inference contract](../../../docs/27-production-ml-inference.md).
