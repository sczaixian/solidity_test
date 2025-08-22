
const { ethers, deployments, getNamedAccounts } = require("hardhat")
const { assert } = require("chai")  //
const { deployConract } = require("../tasks")

describe("test fundme contract", async function () {
    // 全局变量
    let fundMe
    let firstAccount

    this.beforeEach(async function () {
        // 部署了所有 tag 为 all 的合约
        await deployments.fixture(["all"])  // 会执行 deploy/下面 tags 有 all 的
        // 初始化全局变量
        const fundMeDeployment = await deployments.get("FundMe") // 拿到合约的部署信息
        fundMe = await ethers.getContractAt("FundMe", fundMeDeployment.address) // 合约名字， 合约地址
        firstAccount = (await getNamedAccounts()).firstAccount
    })

    it("test if the owner is mag.sender", async function () {
        // const [deployer] = await ethers.getSigners()  这些逻辑都在 beforeEach 中了
        // const fundMeFactory = await ethers.getContractFactory("FundMe")
        // const fundMe = await fundMeFactory.deploy(360)
        // await fundMe.waitForDeployment()
        // assert.equal((await fundMe.owner()), deployer.address)


        await fundMe.waitForDeployment()
        assert.equal((await fundMe.owner()), firstAccount)
    })

    it("test if the datafeed is assigned correctly", async function () {
        // const fundMeFactory = await ethers.getContractFactory("FundMe")
        // const fundMe = await fundMeFactory.deploy(360)
        await fundMe.waitForDeployment()
        assert.equal((await fundMe.dataFeed()), "0x694AA1769357215DE4FAC081bf1f309aDC325306")
    })

    // it("fund and refund successfully",
    //     async function () {
    //         // make sure target not reached
    //         await fundMe.fund({ value: ethers.parseEther("0.0005") })
    //         // make sure window closed
    //         await new Promise(resolve => setTimeout(resolve, 181 * 1000))
    //         // make sure we can get receipt 
    //         const refundTx = await fundMe.refund()
    //         const refundReceipt = await refundTx.wait()
    //         expect(refundReceipt)
    //             .to.be.emit(fundMe, "RefundByFunder")
    //             .withArgs(firstAccount, ethers.parseEther("0.1"))
    //     }
    // )
})