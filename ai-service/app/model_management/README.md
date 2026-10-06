# Model lifecycle boundary

No weights are loaded in Phase 8. `/health` reports process liveness independently
of `model.status=not_loaded`, `model.version=null` and unavailable AI capabilities.
Future artifact loading must preserve immutable versions/class maps, validate metadata
and expose separate readiness; never overwrite or silently replace production models.
