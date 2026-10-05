BEGIN;

-- A trigger invoked without arguments receives NULL TG_ARGV, not an empty array.
-- Subtracting NULL from jsonb yields NULL and previously bypassed the comparison.
CREATE OR REPLACE FUNCTION protect_record_fields() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE mutable_fields text[] := coalesce(TG_ARGV, ARRAY[]::text[]);
BEGIN
    IF (to_jsonb(NEW) - mutable_fields) IS DISTINCT FROM (to_jsonb(OLD) - mutable_fields) THEN
        RAISE EXCEPTION 'Immutable fields cannot be updated in %; create a new version or record', TG_TABLE_NAME
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END $$;

COMMIT;
