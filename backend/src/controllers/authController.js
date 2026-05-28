const authService = require('../services/authService');

const userRepository = require('../repositories/userRepository');

exports.register = async (req, res,next) => {
    try{
        const {name, email, password} = req.body;
        const result = await authService.register(name, email, password);
        res.status(201).json(
            {
                success: true,
                userId: result.id
            }
        );

    }catch(error){
        next(error);
    }
};

exports.login =
async(req,res,next)=>{

try{

    const {
        email,
        password
    } = req.body;

    const result =
    await authService.login(
        email,
        password
    );

    res.json({
        success:true,
        token:result.token,
        user:{
            id:result.user.id,
            name:result.user.name,
            email:result.user.email,
            role:result.user.role
        }
    });

}
catch(err){
    next(err);
}

};



exports.logout = async (req, res) => {
    // For JWT, logout is handled on the client side by deleting the token.
    res.json({ success: true, message: "Logged out successfully" });
};

exports.deleteAccount = async (req, res, next) => {
    try{
        await userRepository.deleteUser(req.user.id);
        res.json({
            success: true,
            message: "Account deleted successfully"
        });
    }
    catch(error){
        next(error);
    }
}


