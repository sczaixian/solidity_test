
module.exports= async({getNamedAccounts, deployments}) => {

    const {firstAccount} = await getNamedAccounts()
    const {deploy} = deployments
    
    await deploy("MockV3Aggregator", {
        from: firstAccount,
        args: [8, 300000000000],   // 3000  +  00000000  八个0 
        log: true
    })        
}

module.exports.tags = ["all", "mock"]


// 引入配置文件中的变量
// const { DECIMAL, INITIAL_ANSWER, devlopmentChains} = require("../helper-hardhat-config")
// module.exports= async({getNamedAccounts, deployments}) => {

//     const {firstAccount} = await getNamedAccounts()
//     const {deploy} = deployments
    
//     await deploy("MockV3Aggregator", {
//         from: firstAccount,
//         args: [DECIMAL, INITIAL_ANSWER],   
//         log: true
//     })        


// module.exports.tags = ["all", "mock"]




// const { DECIMAL, INITIAL_ANSWER, devlopmentChains} = require("../helper-hardhat-config")

// module.exports= async({getNamedAccounts, deployments}) => {

//     if(devlopmentChains.includes(network.name)) {
//         const {firstAccount} = await getNamedAccounts()
//         const {deploy} = deployments
        
//         await deploy("MockV3Aggregator", {
//             from: firstAccount,
//             args: [DECIMAL, INITIAL_ANSWER],
//             log: true
//         })        
//     } else {
//         console.log("environment is not local, mock contract depployment is skipped")
//     }
// }

// module.exports.tags = ["all", "mock"]