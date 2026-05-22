CREATE TABLE disease_images (
    id INT AUTO_INCREMENT PRIMARY KEY, 
    disease_id INT NOT NULL, 
    image_path VARCHAR(255) NOT NULL, 
    uploaded_by INT, 
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
    FOREIGN KEY (disease_id) REFERENCES diseases(id) ON DELETE CASCADE, 
    FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE SET NULL 
);
