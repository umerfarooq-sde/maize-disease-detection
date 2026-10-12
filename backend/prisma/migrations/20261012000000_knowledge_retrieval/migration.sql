BEGIN;

CREATE TYPE "KnowledgeType" AS ENUM ('OVERVIEW', 'SYMPTOMS', 'CAUSES', 'CONDITIONS', 'MANAGEMENT', 'PREVENTION', 'REFERENCES');
ALTER TABLE knowledge_documents
    ADD COLUMN knowledge_type "KnowledgeType",
    ADD COLUMN metadata jsonb NOT NULL DEFAULT '{}';
ALTER TABLE knowledge_chunks
    ADD COLUMN embedding_version varchar(160),
    ADD COLUMN metadata jsonb NOT NULL DEFAULT '{}';

ALTER TABLE knowledge_documents ADD CONSTRAINT knowledge_documents_metadata_check
    CHECK (jsonb_typeof(metadata) = 'object');
ALTER TABLE knowledge_chunks ADD CONSTRAINT knowledge_chunks_metadata_check
    CHECK (jsonb_typeof(metadata) = 'object');
ALTER TABLE knowledge_chunks ADD CONSTRAINT knowledge_chunks_embedding_version_check
    CHECK ((embedding_version IS NULL OR length(btrim(embedding_version)) > 0)
       AND (embedding_status <> 'READY' OR embedding_version IS NOT NULL));

CREATE INDEX knowledge_documents_disease_id_status_knowledge_type_idx
    ON knowledge_documents(disease_id, status, knowledge_type);

-- Content/provenance/config remain immutable. Initial embedding may transition to
-- READY, but replacement after readiness requires a new document/chunk version.
DROP TRIGGER knowledge_chunks_protect_content ON knowledge_chunks;
CREATE TRIGGER knowledge_chunks_protect_content BEFORE UPDATE ON knowledge_chunks
    FOR EACH ROW EXECUTE FUNCTION protect_record_fields(
        'token_count', 'embedding', 'embedding_model', 'embedding_version',
        'embedding_dimensions', 'embedding_status', 'updated_at');
CREATE FUNCTION protect_ready_knowledge_embedding() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.embedding_status = 'READY' AND
       (NEW.embedding, NEW.embedding_model, NEW.embedding_version,
        NEW.embedding_dimensions, NEW.embedding_status)
       IS DISTINCT FROM
       (OLD.embedding, OLD.embedding_model, OLD.embedding_version,
        OLD.embedding_dimensions, OLD.embedding_status) THEN
        RAISE EXCEPTION 'Ready knowledge embeddings are immutable' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER knowledge_chunks_protect_ready_embedding BEFORE UPDATE ON knowledge_chunks
    FOR EACH ROW EXECUTE FUNCTION protect_ready_knowledge_embedding();

-- Exact cosine search is appropriate for the initial 25-document corpus. No
-- approximate index with arbitrary dimensions/training is created prematurely.
COMMIT;
