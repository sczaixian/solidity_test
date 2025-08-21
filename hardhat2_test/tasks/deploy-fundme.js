
const { task } = require("hardhat/config")

task("deploy-fundme", "deploy and verify fundme contract").setAction(async(taskArgs, hre)=>{
    const fundMeFactory = await ethers.getContractFactory("FundMe")
    console.log("contract deploying")
    const fundMe = await fundMeFactory.deploy(360)
    await fundMe.waitForDeployment()
    console.log(`contract has been deployed successful, contract address is ${fundMe.getAddress()}`)

    if(hre.network.config.chainId == 11155111 && process.env.ETHERSCAN_API_KEY){
        console.log("waiting for 5 conformations")
        await fundMe.deploymentTransaction().wait(5)
        await verifyFundMe(fundMe.getAddress(), [360])
    }
})

async function verifyFundMe(fundAddr, args) {
    await hre.run("verify:verify", {
        address: fundAddr,
        constructorArguments: args,
    })
}

module.exports = {}