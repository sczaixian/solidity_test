

module.exports = async ({getNamedAccounts, deployments}) => {
    const firstAccount = await getNamedAccounts()
    const {deploy, log} = deployments

    console.log("deploying nft contract")
    // 合约地址 + 部署时需要哪些参数
    deploy("MyToken", {
        contract: "MyToken",
        from: firstAccount,
        log: true,
        args: ["MyNFT", "MNT"]
    })
    log("mytoken is deployed!")
}

module.exports.tags = ["all", "sourcechain"]