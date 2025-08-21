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



module.exports = async({getNamedAccounts, deployments}) => {
    const firstAccount = (await getNamedAccounts()).firstAccount
    const {deploy} = deployments  // const deploy = deployements.deploy  ,{} 表示从很多变量中只拿deploy这个
    console.log(`firstAccount is ${firstAccount}`)
    await deploy("FundMe", {  // 谁部署的， 参数， 日志
        from: firstAccount,
        args: [ 360 ],
        log: true,
    })
}

module.exports.tags = ["all", "fundme"]  // npx hardhat deploy --tags all  或者  fundme