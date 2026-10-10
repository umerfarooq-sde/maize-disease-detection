BEGIN;

CREATE TYPE "PredictionStatus" AS ENUM ('CONFIDENT', 'LOW_CONFIDENCE');
ALTER TABLE scans ADD COLUMN inference_attempt_id UUID;
ALTER TABLE scans ADD CONSTRAINT scans_inference_attempt_check
    CHECK (inference_attempt_id IS NULL OR status = 'PROCESSING');
DROP TRIGGER scans_protect_identity ON scans;
CREATE TRIGGER scans_protect_identity BEFORE UPDATE ON scans FOR EACH ROW
    EXECUTE FUNCTION protect_record_fields('status', 'processing_time_ms', 'inference_attempt_id', 'error_code', 'finished_at', 'expires_at', 'updated_at');
ALTER TABLE scan_predictions
    ADD COLUMN prediction_status "PredictionStatus",
    ADD COLUMN uncertainty_reason VARCHAR(64),
    ADD COLUMN confidence_threshold DOUBLE PRECISION,
    ADD COLUMN inference_duration_ms DOUBLE PRECISION,
    ADD COLUMN inferred_at TIMESTAMPTZ(6);

-- Preserve historical predictions without inventing certainty/timing metadata.
-- New outcomes must have complete, coherent uncertainty and finite timing.
ALTER TABLE scan_predictions ADD CONSTRAINT scan_predictions_outcome_check CHECK (
    (prediction_status IS NULL AND uncertainty_reason IS NULL AND confidence_threshold IS NULL
        AND inference_duration_ms IS NULL AND inferred_at IS NULL)
    OR
    (prediction_status IS NOT NULL AND inferred_at IS NOT NULL
        AND inference_duration_ms IS NOT NULL AND inference_duration_ms BETWEEN 0 AND 20000
        AND (
            (prediction_status = 'LOW_CONFIDENCE' AND confidence_threshold IS NULL
                AND uncertainty_reason IS NOT NULL AND uncertainty_reason = 'THRESHOLD_UNCONFIGURED')
            OR
            (confidence_threshold IS NOT NULL AND confidence_threshold > 0 AND confidence_threshold < 1
                AND ((prediction_status = 'CONFIDENT' AND confidence >= confidence_threshold
                        AND uncertainty_reason IS NULL)
                    OR (prediction_status = 'LOW_CONFIDENCE' AND confidence < confidence_threshold
                        AND uncertainty_reason IS NOT NULL AND uncertainty_reason = 'BELOW_VALIDATION_THRESHOLD')))
        ))
);

COMMIT;
