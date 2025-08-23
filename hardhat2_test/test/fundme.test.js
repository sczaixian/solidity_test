
const { ethers, deployments, getNamedAccounts, network } = require("hardhat")
const { assert, expect } = require("chai")
const helpers = require("@nomicfoundation/hardhat-network-helpers")
const {devlopmentChains} = require("../helper-hardhat-config")

// 三元操作符 condition ？logic_1 : logic_2
// 这里加了 ！ 就是  要执行 logic_2
! devlopmentChains.includes(network.name) 
? describe.skip 
: describe("test fundme contract", async function () {
    // 全局变量
    let fundMe
    let firstAccount
    let secondAccount
    let mockV3Aggregator 

    beforeEach(async function () {
        // 部署了所有 tag 为 all 的合约
        await deployments.fixture(["all"])  // 每一次执行it 会执行 deploy/下面 tags 有 all 的
        firstAccount = (await getNamedAccounts()).firstAccount
        secondAccount = (await getNamedAccounts()).secondAccount
        // 初始化全局变量
        const fundMeDeployment = await deployments.get("FundMe") // 拿到合约的部署信息
        mockV3Aggregator = await deployments.get("MockV3Aggregator")
        fundMe = await ethers.getContractAt("FundMe", fundMeDeployment.address) // 合约名字， 合约地址
        fundMeSecondAccount = ethers.getContractAt("FundMe", secondAccount)
        console.log(`end of foreach the firstAccount is address ${firstAccount}, and the secondAccount address is ${secondAccount}`)
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
        assert.equal((await fundMe.dataFeed()), mockV3Aggregator.address)
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

    it("window closed, value grater than minimum, fund filed", async function (){
        await helpers.time.increase(200)
        await helpers.mine()
        await expect(fundMe.fund({value: ethers.parseEther("0.0005")})).to.be.revertedWith("window is closed")
    })


    it("window open, value is grater minimum, fund success", async function(){
        await fundMe.fund({value: ethers.parseEther("0.0005")})
        const balance = await fundMe.fundersToAmount(firstAccount)
        console.log("----------------> ", balance, ethers.parseEther("0.0015"))
        await expect(balance).to.equal(ethers.parseEther("1.5"))
    })

     it("window closed, target not reached, getFund failed",
        async function() {
            await fundMe.fund({value: ethers.parseEther("0.0005")})
            // make sure the window is closed
            await helpers.time.increase(200)
            await helpers.mine()            
            await expect(fundMe.getFund())
                .to.be.revertedWith("target is not reached")
        }
    )

    it("window closed, target reached, getFund success", 
        async function() {
            await fundMe.fund({value: ethers.parseEther("0.0005")})
            // make sure the window is closed
            await helpers.time.increase(200)
            await helpers.mine()   
            await expect(fundMe.getFund())
                .to.emit(fundMe, "FundWithdrawByOwner")
                .withArgs(ethers.parseEther("1"))
        }
    )

    // refund
    // windowClosed, target not reached, funder has balance
    it("window open, target not reached, funder has balance", 
        async function() {
            await fundMe.fund({value: ethers.parseEther("0.0005")})
            await expect(fundMe.refund())
                .to.be.revertedWith("window is not closed");
        }
    )
})