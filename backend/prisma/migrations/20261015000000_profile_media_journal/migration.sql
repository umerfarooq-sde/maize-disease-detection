BEGIN;

-- Reuse the existing private profile; retain recovery intents before cloud I/O.
ALTER TABLE farmer_profiles
  ADD COLUMN avatar_pending_public_id VARCHAR(255),
  ADD COLUMN avatar_upload_started_at TIMESTAMPTZ(6),
  ADD COLUMN avatar_cleanup_public_ids TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
ALTER TABLE farmer_profiles ADD CONSTRAINT farmer_profiles_avatar_journal_check CHECK (
  (avatar_pending_public_id IS NULL) = (avatar_upload_started_at IS NULL)
  AND cardinality(avatar_cleanup_public_ids) <= 8
  AND array_position(avatar_cleanup_public_ids, NULL) IS NULL
  AND (avatar_pending_public_id IS NULL OR avatar_pending_public_id ~
    '^maizedoctor/profiles/[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$')
);

CREATE INDEX audit_logs_created_at_id_idx ON audit_logs(created_at DESC, id DESC);

COMMIT;
