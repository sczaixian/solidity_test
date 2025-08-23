

const {developmentChains, networkConfig}  = require("../helper-hardhat-config")


module.exports = async ({getNamedAccounts, deployments}) =>{
    const {firstAccount} = await getNamedAccounts()
    const {deploy, log } = deployments

    let router
    let linkTokenAddress
    let wnftAddress

    if(developmentChains.includes(network.name)){
        const ccipSimulatorTx = await deployments.get("CCIPLocalSimulator")
        const ccipSimulator = await ethers.getContractAt("CCIPLocalSimulator", ccipSimulatorTx.address)
        const ccipSimulatorConfig = await ccipSimulator.configuration()
        router = ccipSimulatorConfig.destinationRouter_
        linkTokenAddress = ccipSimulatorConfig.linkToken_
    }else{
        router = networkConfig[network.config.chainId].router
        linkTokenAddress = networkConfig[network.config.chainId].linkToken
    }

    const wnftTx = await deployments.get("WrappedMyToken")
    wnftAddress = wnftTx.address

    log("deploying nftpoolBurnAndMint")
    await deploy("NFTPoolBurnAndMint", {
        constract: "NFTPoolBurnAndMint",
        from: firstAccount,
        log: true,
        args: [router, linkTokenAddress, wnftAddress]
    })
    log("nftPoolBurnAndMint deployed")
}


module.exports.ages = ["all", "destchain"]