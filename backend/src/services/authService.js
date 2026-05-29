const userRepository = require('../repositories/userRepository');
const hashPassword = require('../utils/hashPassword');
const comparePassword = require('../utils/comparePassword');


const generateToken = require('../utils/generateToken');


exports.register = async (name, email, password) => {
    const existingUser = await userRepository
.findByEmail(email);
    if (existingUser) {
        throw new Error('Email already in use');
    }

    const hashedPassword = await hashPassword(password);
    
    const userId = await userRepository
.createUser(name, email, hashedPassword);
    return {
        id: userId
    };
};


exports.login = async (email,password) =>{
    const user =
    await userRepository.findByEmail(email);

    if(!user){

        throw new Error(
            "Invalid email or password"
        );
    }

    const isMatch = await comparePassword(password, user.password);
    if(!isMatch){
        throw new Error(
            "Invalid email or password"
        );
    };

    const token = generateToken(user);
    return {
        token, 
        user
    };

};