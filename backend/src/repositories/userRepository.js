const db = require("../config/db");

exports.findByEmail = async (email) => {
    const [rows] = await db.execute("SELECT * FROM users WHERE email = ?", [email]);
    return rows[0];
}

exports.findById = async(id) => {
    const [rows] = await db.execute("SELECT * FROM users WHERE id = ?", [id]);
    return rows[0];
}

exports.createUser = async (
    name,
    email,
    password
) => {

    const [result] = await db.query(
        `
        INSERT INTO users
        (name,email,password)
        VALUES (?,?,?)
        `,
        [
            name,
            email,
            password
        ]
    );
    return result.insertId;
};

exports.deleteUser = async (id) => {

    await db.query(
        "DELETE FROM users WHERE id=?",
        [id]
    );

};