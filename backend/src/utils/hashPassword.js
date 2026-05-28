const bycrypt = require('bcrypt');

hashPassword = async(password) =>{
    return await bycrypt.hash(password, 10);
};

module.exports = hashPassword

