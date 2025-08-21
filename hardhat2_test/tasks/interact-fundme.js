const { task } = require("hardhat/config")

task("interact-fundme", "descript task...").addParam("addr", "fundme contract address")
.setAction(async(taskArgs, hre) => {
    const fundMeFactory = await ethers.getContructFactory("FundMe")
    const fundMe = fundMeFactory.attach(taskArgs.addr)
    const [firstAccount, secondAccount] = await ethers.getSigners()

    const fundTx = await fundMe.fund({value: ethers.parseEther("0.5")})
    await fundTx.wait()

    // check balance of contract
    const balanceOfContract = await ethers.provider.getBalance(fundMe.target)
    console.log(`Balance of the contract is ${balanceOfContract}`)
})

