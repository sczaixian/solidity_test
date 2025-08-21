
const {ethers} = require("hardhat")  // 引入 ethers

async function main() {

    const fundMeFactory = await ethers.getContractFactory("FundMe")
    console.log("contract deploying ... ")
    const fundMe = await fundMeFactory.deploy(360)
    await fundMe.waitForDeployment()
    console.log(`contract has been deployed successfully, contract addresss is ${fundMe.target}`)



    // if(hre.network.config.childId == 11155111 && Headers.etherscan.apikey.sepolia) {
    //     console.log("Waiting for 5 confirmations")
    //     await fundMe.deploymentTransaction().wait(5) 
    //     await verifyFundMe(fundMe.target, [300])
    // } else {
    //     console.log("verification skipped..")
    // }
    await verifyFundMe(fundMe.target, 360)
    
}

async function verifyFundMe(fundMeAddr, args) {
    console.log("waiing for 5 confirmations")
    await fundMe.deploymentTransaction().wait(5)  // 等5个区块的时间
    
    await hre.run("verify:verify",{
        address: fundMeAddr,
        constructorArguments:[args]
    })

}


main().then().catch((error) => {
    console.error(error)
    process.exit(1)
})