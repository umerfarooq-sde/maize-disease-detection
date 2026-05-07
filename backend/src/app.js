const express = require("express");
const db = require("./config/db");

const app = express();

app.get("/users", (req, res) => {
    db.query("SELECT * FROM users", (err, result) => {
        if (err) {
            return res.status(500).json(err);
        }
        res.json(result);
    });
});

module.exports = app;