const {developmentChains, networkConfig} = require("../helper-hardhat-config")

module.exports = async ({getNamedAccounts, deployments})=>{
    const {firstAccount} = await getNamedAccounts()
    const {deploy, log} = deployments

    let sourceChainRouter
    let linkToken
    let nftAddress

    if(developmentChains.includes(network.name)){
        const ccipSimulatorTx = await deployments.get("CCIPLocalSimulator")
        const ccipSimulator = await ethers.getContractAt("CCIPLocalSimulator", ccipSimulatorTx.address)
        const ccipSimulatorConfig = await ccipSimulator.configuration()
        
        sourceChainRouter = ccipSimulatorConfig.sourceRouter_
        linkToken = ccipSimulatorConfig.linkToken_
        log(`local eviroment: sourcechain router: ${sourceChainRouter}, link token: ${linkToken}`)
    }else{
        sourceChainRouter = networkConfig[network.config.chainId].router 
        linkToken = networkCinfig[network.config.chainId].linkToken
        log(`non local environment: sourcechain router: ${sourceChainRouter}, link token: ${linkToken}`)
    }

    const nftTx = await deployments.get("MyToken")
    nftaddress = nftTx.address
    log(`NFT address: ${nftaddress}`)

    log("deploying the lmn pool")
    await deploy("NFTPoolLockAndRelease", {
        contract: "NFTPoolLockAndRelease",
        from: firstAccount,
        log: true,
        args:[sourceChainRouter, linkToken, nftaddress]
    })
    log("lmn pool deployed")
}

module.exports.tags = ["all", "sourcechain"]
