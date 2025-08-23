// 01-deploy-fundme.js 第一个要被执行的deploy

// function deployFunction(){
//     console.log("test  deploye")
// }
// module.exports.default = deployFunction



// 简写
// module.exports = async() => {
//     console.log("test  deploye")
// }



// module.exports = async(hre) => {
//     const getNamedAssounts = hre.getNamedAssounts
//     const deployements = hre.deployements
// }

const {devlopmentChains, networkConfig, LOCK_TIME, CONFIRMATIONS} = require("../helper-hardhat-config")

module.exports = async({getNamedAccounts, deployments}) => {
    const firstAccount = (await getNamedAccounts()).firstAccount
    const {deploy} = deployments  // const deploy = deployements.deploy  ,{} 表示从很多变量中只拿deploy这个

    let dataFeedAddr
    let confirmations
    if(devlopmentChains.includes(network.name)){
        const mockV3Aggregator = await deployments.get("MockV3Aggregator")   
        dataFeedAddr = mockV3Aggregator.address
        confirmations = 0
    } else{
        dataFeedAddr = networkConfig[network.config.chainId].ethUsdDataFeed
        confirmations = CONFIRMATIONS
    }

    console.log(`firstAccount is ${firstAccount}`)

    const fundMe = await deploy("FundMe", {  // 谁部署的， 参数， 日志
        from: firstAccount,
        args: [ LOCK_TIME, dataFeedAddr ],
        log: true,
        waitConfirmations: confirmations
    })

    if(hre.network.config.chainId == 11155111 && process.env.ETHERSCAN_API_KEY){
        await hre.run("verify:verify", {
            address: fundMe.getAddress(),
            constructorArguments: [LOCK_TIME, dataFeedAddr],
        })
    } else {
        console.log("Network is not sepolia, verification skipped...")
    }
    
}

module.exports.tags = ["all", "fundme"]  // npx hardhat deploy --tags all  或者  fundme