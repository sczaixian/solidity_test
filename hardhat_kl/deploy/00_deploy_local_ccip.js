
const { developmentChains } = require("../helper-hardhat-config")

module.exports = async ({getNamedAccounts, deployments}) => {
    if(developmentChains.includes(network.name)){
        const {firstAccount} = await getNamedAccounts()
        const {deploy, log} = await deployments

        log("deploy the ccip local simulator")
        await deploy("CCIPLocalSimulator", {
            contract: "CCIPLocalSimulator",
            from: firstAccount,
            log: true,
            args: []
        })
        log("ccip local simulator deployed!")
    }else{
        log("not in local, skip ccip local")
    }
}

module.exports.tags = ["all", "test"]

