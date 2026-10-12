BEGIN;

-- Extension operators are in public; restricted application search paths must
-- still enforce READY immutability. Canonical vector text compares exact stored
-- float32 values without resolving the vector equality operator by search_path.
CREATE OR REPLACE FUNCTION protect_ready_knowledge_embedding() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.embedding_status = 'READY' AND
       (NEW.embedding::text, NEW.embedding_model, NEW.embedding_version,
        NEW.embedding_dimensions, NEW.embedding_status)
       IS DISTINCT FROM
       (OLD.embedding::text, OLD.embedding_model, OLD.embedding_version,
        OLD.embedding_dimensions, OLD.embedding_status) THEN
        RAISE EXCEPTION 'Ready knowledge embeddings are immutable' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END $$;

COMMIT;
