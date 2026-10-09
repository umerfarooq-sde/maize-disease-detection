# Model lifecycle boundary

Phase 11 validates the approved metadata digest, checkpoint/calibration hashes,
literal class mapping, full shared preprocessing configuration, runtime dependencies
and strict finite state/output compatibility before loading one model in the lifespan.
Missing/incompatible artifacts fail startup with safe codes. Optional confidence
policies must be separately pinned and validation-derived; none is configured now.
Authenticated model health distinguishes readiness from process liveness. See
[artifact and lifecycle contracts](../../../docs/27-production-ml-inference.md).
