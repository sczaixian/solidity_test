const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MERC20 Token Contract", function () {
    let MERC20;
    let merc20;
    let owner;
    let addr1;
    let addr2;

    beforeEach(async function () {
        // 获取账户
        [owner, addr1, addr2] = await ethers.getSigners();

        // 部署合约
        MERC20 = await ethers.getContractFactory("MERC20");
        merc20 = await MERC20.deploy("MyToken", "MTK", 18, ethers.parseEther("1000"));
        await merc20.waitForDeployment();
    });

    describe("Deployment", function () {
        it("Should set the correct owner", async function () {
            expect(await merc20.owner()).to.equal(owner.address);
        });

        it("Should assign the total supply of tokens to the owner", async function () {
            const ownerBalance = await merc20.balanceOf(owner.address);
            expect(await merc20.totalSupply()).to.equal(ownerBalance);
        });

        it("Should set the correct token metadata", async function () {
            expect(await merc20.name()).to.equal("MyToken");
            expect(await merc20.symbol()).to.equal("MTK");
            expect(await merc20.decimals()).to.equal(18);
        });
    });

    describe("Transactions", function () {
        const amount = ethers.parseEther("100");

        it("Should transfer tokens between accounts", async function () {
            // 转账给 addr1
            await merc20.transfer(addr1.address, amount);
            const addr1Balance = await merc20.balanceOf(addr1.address);
            expect(addr1Balance).to.equal(amount);

            // addr1 转账给 addr2
            await merc20.connect(addr1).transfer(addr2.address, amount);
            const addr2Balance = await merc20.balanceOf(addr2.address);
            expect(addr2Balance).to.equal(amount);
        });

        it("Should emit Transfer events", async function () {
            await expect(merc20.transfer(addr1.address, amount))
                .to.emit(merc20, "Transfer")
                .withArgs(owner.address, addr1.address, amount);
        });

        it("Should fail if sender doesn't have enough tokens", async function () {
            const initialOwnerBalance = await merc20.balanceOf(owner.address);

            // 尝试转账超过余额
            await expect(
                merc20.connect(addr1).transfer(owner.address, ethers.parseEther("1"))
            ).to.be.revertedWithCustomError(merc20, "InsufficientBalance");

            // 验证余额未变
            expect(await merc20.balanceOf(owner.address)).to.equal(initialOwnerBalance);
        });
    });

    describe("Approvals", function () {
        const amount = ethers.parseEther("100");

        it("Should set allowance", async function () {
            await merc20.approve(addr1.address, amount);
            expect(await merc20.allowance(owner.address, addr1.address)).to.equal(amount);
        });

        it("Should emit Approval event", async function () {
            await expect(merc20.approve(addr1.address, amount))
                .to.emit(merc20, "Approval")
                .withArgs(owner.address, addr1.address, amount);
        });
    });

    describe("Transfer From", function () {
        const amount = ethers.parseEther("100");
        const spendAmount = ethers.parseEther("50");

        beforeEach(async function () {
            // 先转账给 addr1
            await merc20.transfer(addr1.address, amount);
            // 授权 owner 使用 addr1 的代币
            await merc20.connect(addr1).approve(owner.address, amount);
        });

        it("Should allow transferFrom with sufficient allowance", async function () {
            await merc20.transferFrom(addr1.address, addr2.address, spendAmount);

            expect(await merc20.balanceOf(addr1.address)).to.equal(amount - spendAmount);
            expect(await merc20.balanceOf(addr2.address)).to.equal(spendAmount);
        });

        it("Should update allowance after transferFrom", async function () {
            await merc20.transferFrom(addr1.address, addr2.address, spendAmount);

            const newAllowance = await merc20.allowance(addr1.address, owner.address);
            expect(newAllowance).to.equal(amount - spendAmount);
        });

        it("Should fail with insufficient allowance", async function () {
            await expect(
                merc20.transferFrom(addr1.address, addr2.address, amount + ethers.parseEther("1"))
            ).to.be.revertedWithCustomError(merc20, "InsufficientAllowance");
        });

        it("Should fail with insufficient balance", async function () {
            // 尝试转账超过余额
            await expect(
                merc20.transferFrom(addr1.address, addr2.address, amount + ethers.parseEther("1"))
            ).to.be.revertedWithCustomError(merc20, "InsufficientAllowance");
        });
    });

    describe("Minting", function () {
        const mintAmount = ethers.parseEther("500");

        it("Should mint new tokens by owner", async function () {
            const initialSupply = await merc20.totalSupply();
            await merc20.mint(addr1.address, mintAmount);

            expect(await merc20.totalSupply()).to.equal(initialSupply + mintAmount);
            expect(await merc20.balanceOf(addr1.address)).to.equal(mintAmount);
        });

        it("Should emit Transfer event on mint", async function () {
            await expect(merc20.mint(addr1.address, mintAmount))
                .to.emit(merc20, "Transfer")
                .withArgs(ethers.ZeroAddress, addr1.address, mintAmount);
        });

        it("Should prevent non-owners from minting", async function () {
            await expect(
                merc20.connect(addr1).mint(addr1.address, mintAmount)
            ).to.be.revertedWithCustomError(merc20, "OnlyOwner");
        });
    });
});