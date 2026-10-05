BEGIN;

CREATE TABLE "auth_sessions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "refresh_token_hash" CHAR(64) NOT NULL,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "revoked_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "auth_sessions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "auth_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "auth_sessions_integrity_check" CHECK (
        refresh_token_hash ~ '^[a-f0-9]{64}$'
        AND expires_at > created_at
        AND (revoked_at IS NULL OR revoked_at >= created_at)
    )
);
CREATE UNIQUE INDEX "auth_sessions_refresh_token_hash_key" ON "auth_sessions"("refresh_token_hash");
CREATE INDEX "auth_sessions_user_id_revoked_at_idx" ON "auth_sessions"("user_id", "revoked_at");
CREATE INDEX "auth_sessions_expires_at_idx" ON "auth_sessions"("expires_at");
CREATE TRIGGER touch_updated_at BEFORE UPDATE ON auth_sessions FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE FUNCTION protect_auth_session() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF (NEW.id, NEW.user_id, NEW.expires_at, NEW.created_at)
        IS DISTINCT FROM (OLD.id, OLD.user_id, OLD.expires_at, OLD.created_at)
        OR (OLD.revoked_at IS NOT NULL AND
            (NEW.revoked_at, NEW.refresh_token_hash) IS DISTINCT FROM (OLD.revoked_at, OLD.refresh_token_hash)) THEN
        RAISE EXCEPTION 'Session identity, absolute expiry and revocation are immutable' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER auth_sessions_protect_identity BEFORE UPDATE ON auth_sessions FOR EACH ROW EXECUTE FUNCTION protect_auth_session();

COMMIT;
