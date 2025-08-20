// import ethers.js
// create main function,创建一个 函数，通过ethers包获取这个合约
// execute mian function 执行这个函数

const { ethers } = require("hardhat")   // {ethers} 从包中之引入 ethers 

async function main() {
    // create factory
    const fundMeFactory = await ethers.getContractFactory("FundMe")  // 通过合约的名字创建一个合约工厂
    // deploy contract from factory
    console.log("contract deploying ")
    const fundMe = await fundMeFactory.deploy()
    await fundMe.waitForDeployment()
    // console.log("contract has been deployed success, contract address is " +  fundMe.target)
    console.log(`contract has been deployed success, contract address is  ${fundMe.target}`)
}

main().then().catch((error) => {
    console.error(error)
    process.exit(1)
})
