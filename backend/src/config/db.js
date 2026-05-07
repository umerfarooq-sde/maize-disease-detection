const mysql = require("mysql2");
require("dotenv").config();

const db = mysql.createConnection({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME
});

// Connect to XAMPP MySQL
db.connect((err) => {
    if (err) {
        console.error("MySQL Connection Failed:");
        console.error(err.message);
    } else {
        console.log("MySQL Connected Successfully (XAMPP)");
    }
});

module.exports = db;