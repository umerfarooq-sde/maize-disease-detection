ALTER TABLE diseases ADD COLUMN catalogue_metadata jsonb;
ALTER TABLE diseases ADD CONSTRAINT disease_catalogue_metadata_object
CHECK (catalogue_metadata IS NULL OR jsonb_typeof(catalogue_metadata)='object');
