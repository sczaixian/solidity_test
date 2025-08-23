

module.exports = async ({getNamedAccounts, deployments}) => {
    const {firstAccount} = await getNamedAccounts()
    const { deploy, log} = deployments

    log("deploying wrapped nft on destination chain")
    await deploy("WrappedMyToken", {
        contract: "WrappedMyToken",
        from: firstAccount,
        log: true,
        args:["WrappedNFT", "WNFT"]
    })
    log("deployed wrapped nft")
}

module.exports.tags = ["all", "destchain"]