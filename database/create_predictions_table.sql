CREATE TABLE predictions (
    id INT AUTO_INCREMENT PRIMARY KEY,

    user_id INT NOT NULL,
    image_path VARCHAR(255) NOT NULL,

    predicted_disease_id INT,

    confidence DECIMAL(5,2) CHECK (confidence BETWEEN 0 AND 100),

    model_version VARCHAR(50),

    inference_time_ms INT,

    llm_explanation TEXT,

    status ENUM('pending', 'completed', 'failed') DEFAULT 'pending',

    error_message TEXT,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (predicted_disease_id) REFERENCES diseases(id) ON DELETE SET NULL
);