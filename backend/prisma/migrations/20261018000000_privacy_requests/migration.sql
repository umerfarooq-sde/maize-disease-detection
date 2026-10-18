-- Additive operational workflow only. No existing account/data is erased.
BEGIN;
CREATE TABLE privacy_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE REFERENCES users(id) ON DELETE SET NULL,
  reviewer_id uuid REFERENCES users(id) ON DELETE SET NULL,
  status varchar(24) NOT NULL DEFAULT 'REQUESTED',
  policy_hash char(64),
  assets jsonb NOT NULL DEFAULT '[]',
  frozen_at timestamptz(6), completed_at timestamptz(6),
  created_at timestamptz(6) NOT NULL DEFAULT now(),
  updated_at timestamptz(6) NOT NULL DEFAULT now(),
  CONSTRAINT privacy_status CHECK (status IN ('REQUESTED','APPROVED','ASSET_CLEANUP','COMPLETED','REJECTED')),
  CONSTRAINT privacy_policy_hash CHECK (policy_hash IS NULL OR policy_hash ~ '^[a-f0-9]{64}$'),
  CONSTRAINT privacy_asset_array CHECK (jsonb_typeof(assets)='array'),
  CONSTRAINT privacy_approval CHECK (status NOT IN ('APPROVED','ASSET_CLEANUP','COMPLETED') OR (policy_hash IS NOT NULL AND frozen_at IS NOT NULL)),
  CONSTRAINT privacy_finished CHECK ((status='COMPLETED') = (completed_at IS NOT NULL))
);
CREATE INDEX privacy_requests_status_updated_at_idx ON privacy_requests(status,updated_at);
CREATE INDEX privacy_requests_reviewer_id_idx ON privacy_requests(reviewer_id);
CREATE TRIGGER privacy_requests_updated_at BEFORE UPDATE ON privacy_requests FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
COMMIT;
