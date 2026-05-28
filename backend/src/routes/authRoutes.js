const express = require("express");


const router = express.Router();

const authController = require("../controllers/authController");
const authMiddleware = require("../middlewares/authMiddleware");
console.log("authMiddleware type:", typeof authMiddleware);
console.log("deleteAccount:", typeof authController.deleteAccount);
console.log("register:", typeof authController.register);

// AUTH ROUTES
router.post("/register", authController.register);
router.post("/login", authController.login);
router.post("/logout", authMiddleware, authController.logout);
router.delete("/delete", authMiddleware, authController.deleteAccount);


module.exports = router;