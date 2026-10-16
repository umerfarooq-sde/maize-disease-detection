-- Replacement identity is retained even after the old asset is retired/cleaned.
ALTER TABLE disease_images ADD CONSTRAINT disease_images_replacement_for_fkey
 FOREIGN KEY (replacement_for) REFERENCES disease_images(id) ON DELETE RESTRICT ON UPDATE CASCADE;
