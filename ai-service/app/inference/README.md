# Classification boundary

No classifier or fallback prediction exists in Phase 8. Future inference uses the
shared preprocessing package and a pinned immutable model artifact, validates class
mapping/output shape and returns model/preprocessing provenance. Node owns scan state
and orchestration; this module will own numerical model execution.
