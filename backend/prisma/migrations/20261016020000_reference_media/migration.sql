ALTER TABLE disease_images ALTER COLUMN image_url DROP NOT NULL;
ALTER TABLE disease_images ADD COLUMN status "RecordStatus" NOT NULL DEFAULT 'DRAFT',
 ADD COLUMN provenance jsonb, ADD COLUMN cleanup_pending boolean NOT NULL DEFAULT false,
 ADD COLUMN upload_state varchar(20) NOT NULL DEFAULT 'READY', ADD COLUMN replacement_for uuid;
ALTER TABLE disease_images ADD CONSTRAINT reference_media_state CHECK (
 upload_state IN ('UPLOADING','READY','RETIRED') AND (status <> 'ACTIVE' OR
 (upload_state='READY' AND image_url IS NOT NULL AND NOT cleanup_pending AND provenance IS NOT NULL
 AND provenance->>'rightsConfirmed'='true' AND provenance->>'reviewedAt' IS NOT NULL)));
CREATE INDEX disease_images_cleanup_idx ON disease_images(cleanup_pending,upload_state,created_at);
