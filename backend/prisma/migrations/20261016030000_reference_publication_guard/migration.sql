-- SQL CHECK accepts UNKNOWN, so missing provenance keys must coalesce to false.
-- Retain legacy/draft records; only publication requires complete rights review.
ALTER TABLE disease_images DROP CONSTRAINT reference_media_state;
ALTER TABLE disease_images ADD CONSTRAINT reference_media_state CHECK (
 upload_state IN ('UPLOADING','READY','RETIRED') AND (status <> 'ACTIVE' OR COALESCE(
   upload_state='READY' AND image_url IS NOT NULL AND NOT cleanup_pending
   AND jsonb_typeof(provenance)='object'
   AND provenance->>'rightsConfirmed'='true'
   AND length(btrim(provenance->>'license')) > 0
   AND length(btrim(provenance->>'contributor')) > 0
   AND length(btrim(provenance->>'attribution')) > 0
   AND length(btrim(provenance->>'reviewedAt')) > 0
   AND provenance->>'contentKind' IN ('REFERENCE','SYNTHETIC_TEST')
   AND jsonb_typeof(provenance->'source')='object'
   AND provenance->'source'->>'url' ~ '^https://'
 ,false)));
