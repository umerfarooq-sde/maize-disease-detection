CREATE TABLE diseases ( 
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL, 
    description TEXT, 
    symptoms TEXT, 
    prevention TEXT, 
    treatment TEXT, 
    created_by INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, 
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL 
);
