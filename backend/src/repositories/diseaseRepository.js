const db = require("../config/db");

exports.getAllDiseases = async () => {

    const [rows] = await db.query(
        `
        SELECT
            d.id,
            d.name,
            d.description,
            d.symptoms,
            d.prevention,
            d.treatment,
            d.created_at,
            u.name AS created_by_name
        FROM diseases d
        LEFT JOIN users u
        ON d.created_by = u.id
        ORDER BY d.created_at DESC
        `
    );

    return rows;
};

exports.getDiseaseById = async (id) => {

    const [rows] = await db.query(
        `
        SELECT
            d.*,
            u.name AS created_by_name
        FROM diseases d
        LEFT JOIN users u
        ON d.created_by = u.id
        WHERE d.id = ?
        `,
        [id]
    );

    return rows[0];
};

exports.createDisease = async (name, description, symptoms, prevention, treatment, createdBy) => {
    // created by refers to admin id  
    const [result] = await db.query(
        `
        INSERT INTO diseases
        (
            name,
            description,
            symptoms,
            prevention,
            treatment,
            created_by   
        )
        VALUES (?, ?, ?, ?, ?, ?)
        `,
        [name, description, symptoms, prevention, treatment, createdBy]
    );

    return result.insertId;
};


exports.updateDisease = async (
    id,
    name,
    description,
    symptoms,
    prevention,
    treatment
) => {

    await db.query(
        `
        UPDATE diseases
        SET
            name = ?,
            description = ?,
            symptoms = ?,
            prevention = ?,
            treatment = ?
        WHERE id = ?
        `,
        [
            name,
            description,
            symptoms,
            prevention,
            treatment,
            id
        ]
    );

};

exports.deleteDisease = async (id) => {

    await db.query(
        `
        DELETE FROM diseases
        WHERE id = ?
        `,
        [id]
    );

};


exports.addDiseaseImage = async (
    diseaseId,
    imagePath,
    uploadedBy
) => {

    const [result] = await db.query(
        `
        INSERT INTO disease_images
        (
            disease_id,
            image_path,
            uploaded_by
        )
        VALUES (?, ?, ?)
        `,
        [
            diseaseId,
            imagePath,
            uploadedBy
        ]
    );

    return result.insertId;
};


exports.getDiseaseImages = async (
    diseaseId
) => {

    const [rows] = await db.query(
        `
        SELECT *
        FROM disease_images
        WHERE disease_id = ?
        `,
        [diseaseId]
    );

    return rows;
};

exports.deleteDiseaseImage = async (
    imageId
) => {

    await db.query(
        `
        DELETE FROM disease_images
        WHERE id = ?
        `,
        [imageId]
    );

};

exports.searchDiseases = async (
    keyword
) => {

    const [rows] = await db.query(
        `
        SELECT *
        FROM diseases
        WHERE
            name LIKE ?
            OR symptoms LIKE ?
        `,
        [
            `%${keyword}%`,
            `%${keyword}%`
        ]
    );

    return rows;
};


exports.getDiseaseWithImages =
async (id) => {

    const [diseaseRows] = await db.query(
        `
        SELECT *
        FROM diseases
        WHERE id = ?
        `,
        [id]
    );

    const disease =
        diseaseRows[0];

    if(!disease){
        return null;
    }

    const [imageRows] = await db.query(
        `
        SELECT *
        FROM disease_images
        WHERE disease_id = ?
        `,
        [id]
    );

    disease.images = imageRows;

    return disease;
};