const express = require("express");
const app = express();
const authRoutes = require("./routes/authRoutes");
const errorMiddleware = require("./middlewares/errorMiddleware");



app.use(express.json());

//Routes
app.use("/api/auth", authRoutes);

app.use(errorMiddleware);

app.get("/test", (req, res) => {
    res.json({ message: "API is working!" });
});

module.exports = app;