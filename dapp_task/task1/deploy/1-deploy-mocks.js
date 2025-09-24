const { getNamedAccounts, deployments, network } = require("hardhat")
const { DECIMAL, INITIAL_ANSWER, devlopmentChains} = require("../helper-hardhat-config")

module.exports = async({getNamedAccounts, deployments}) => {
    console.log(`network name is ${network.name}`)

    if( devlopmentChains.includes(network.name)){
        console.log("start deploy mock .....")
        const { firstAccount } = await getNamedAccounts()
        const { deploy } = deployments
        
        // constructor(uint8 _decimals, int256 _initialAnswer) {
        await deploy("MockV3Aggregator", {
            from: firstAccount,
            args: [DECIMAL, INITIAL_ANSWER],   // 3000  +  00000000  八个0 
            log: true
        })

    } else {
        console.log("skip mock ... ")
    }
}

module.exports.tags = ["all","mock"]