BEGIN;

-- Creator IDs were excluded from immutable payload comparison to allow ON DELETE
-- SET NULL. That exception must not permit rewriting a version's original author.
CREATE OR REPLACE FUNCTION protect_record_fields() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    mutable_fields text[] := coalesce(TG_ARGV, ARRAY[]::text[]);
    old_record jsonb := to_jsonb(OLD);
    new_record jsonb := to_jsonb(NEW);
BEGIN
    IF (old_record ? 'created_by_id')
       AND (new_record ->> 'created_by_id') IS NOT NULL
       AND (new_record -> 'created_by_id') IS DISTINCT FROM (old_record -> 'created_by_id') THEN
        RAISE EXCEPTION 'The creator of a versioned record cannot be reassigned'
            USING ERRCODE = '23514';
    END IF;
    IF (new_record - mutable_fields) IS DISTINCT FROM (old_record - mutable_fields) THEN
        RAISE EXCEPTION 'Immutable fields cannot be updated in %; create a new version or record', TG_TABLE_NAME
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END $$;

COMMIT;
