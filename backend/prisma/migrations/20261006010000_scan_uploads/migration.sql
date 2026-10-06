BEGIN;

CREATE TYPE "ScanUploadState" AS ENUM ('UPLOADING', 'COMPLETED', 'CLEANUP_PENDING', 'CLEANING', 'FAILED');

ALTER TABLE scans ADD COLUMN uploaded_at TIMESTAMPTZ(6);
-- The existing identity trigger protects every new column too. Backfill under
-- the ALTER TABLE transaction's exclusive lock, then restore the same guard.
DROP TRIGGER scans_protect_identity ON scans;
UPDATE scans SET uploaded_at = created_at;
ALTER TABLE scans ALTER COLUMN uploaded_at SET DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE scans ALTER COLUMN uploaded_at SET NOT NULL;
CREATE TRIGGER scans_protect_identity BEFORE UPDATE ON scans FOR EACH ROW
    EXECUTE FUNCTION protect_record_fields('status', 'processing_time_ms', 'error_code', 'finished_at', 'expires_at', 'updated_at');

CREATE TABLE scan_uploads (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    request_key_hash CHAR(64) NOT NULL,
    image_hash CHAR(64) NOT NULL,
    public_id VARCHAR(255) NOT NULL,
    state "ScanUploadState" NOT NULL DEFAULT 'UPLOADING',
    scan_id UUID,
    created_at TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT scan_uploads_pkey PRIMARY KEY (id),
    CONSTRAINT scan_uploads_scan_id_fkey FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT scan_uploads_values_check CHECK (
        request_key_hash ~ '^[a-f0-9]{64}$' AND image_hash ~ '^[a-f0-9]{64}$'
        AND public_id = 'maizedoctor/scans/' || id::text
        AND ((state = 'COMPLETED') = (scan_id IS NOT NULL))
    )
);
CREATE UNIQUE INDEX scan_uploads_request_key_hash_key ON scan_uploads(request_key_hash);
CREATE UNIQUE INDEX scan_uploads_public_id_key ON scan_uploads(public_id);
CREATE UNIQUE INDEX scan_uploads_scan_id_key ON scan_uploads(scan_id);
CREATE INDEX scan_uploads_state_updated_at_idx ON scan_uploads(state, updated_at);
CREATE TRIGGER scan_uploads_updated_at BEFORE UPDATE ON scan_uploads FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER scan_uploads_protect_identity BEFORE UPDATE ON scan_uploads FOR EACH ROW
    EXECUTE FUNCTION protect_record_fields('state', 'scan_id', 'updated_at');

COMMIT;
