const bycrypt = require('bcrypt');

const comparePassword = async(password, hash) => {
    return await bycrypt.compare(password, hash);

}

module.exports = comparePassword;