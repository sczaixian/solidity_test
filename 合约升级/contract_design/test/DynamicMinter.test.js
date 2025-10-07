const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DynamicMinter", function () {
  let DynamicMinter;
  let dynamicMinter;
  let owner;
  let minter;
  let user1;
  let user2;
  
  const DAILY_LIMIT = ethers.utils.parseEther("1000");
  const MINT_AMOUNT = ethers.utils.parseEther("100");
  const LARGE_AMOUNT = ethers.utils.parseEther("1500");

  beforeEach(async function () {
    // 获取测试账户
    [owner, minter, user1, user2] = await ethers.getSigners();
    
    // 部署合约
    DynamicMinter = await ethers.getContractFactory("DynamicMinter");
    dynamicMinter = await DynamicMinter.deploy(DAILY_LIMIT);
    await dynamicMinter.deployed();
    
    // 设置铸币者
    await dynamicMinter.setMinter(minter.address, true);
  });

  describe("部署和初始化", function () {
    it("应该正确设置所有者", async function () {
      expect(await dynamicMinter.owner()).to.equal(owner.address);
    });

    it("应该正确设置每日限额", async function () {
      expect(await dynamicMinter.dailyMintLimit()).to.equal(DAILY_LIMIT);
    });

    it("应该正确初始化周期", async function () {
      const periodStartTime = await dynamicMinter.periodStartTime();
      expect(periodStartTime).to.be.gt(0);
      
      const currentPeriodMinted = await dynamicMinter.currentPeriodMinted();
      expect(currentPeriodMinted).to.equal(0);
    });

    it("部署者应该默认是铸币者", async function () {
      expect(await dynamicMinter.isMinter(owner.address)).to.equal(true);
    });
  });

  describe("铸币者管理", function () {
    it("所有者应该能够添加铸币者", async function () {
      await dynamicMinter.setMinter(user1.address, true);
      expect(await dynamicMinter.isMinter(user1.address)).to.equal(true);
    });

    it("所有者应该能够移除铸币者", async function () {
      await dynamicMinter.setMinter(user1.address, true);
      await dynamicMinter.setMinter(user1.address, false);
      expect(await dynamicMinter.isMinter(user1.address)).to.equal(false);
    });

    it("非所有者不能设置铸币者", async function () {
      await expect(
        dynamicMinter.connect(user1).setMinter(user2.address, true)
      ).to.be.revertedWith("Only owner can call this function");
    });

    it("应该发出 MinterUpdated 事件", async function () {
      await expect(dynamicMinter.setMinter(user1.address, true))
        .to.emit(dynamicMinter, "MinterUpdated")
        .withArgs(user1.address, true);
    });
  });

  describe("铸造功能", function () {
    it("铸币者应该能够铸造代币", async function () {
      await expect(
        dynamicMinter.connect(minter).mint(user1.address, MINT_AMOUNT)
      ).to.emit(dynamicMinter, "Mint");
      
      const currentPeriodMinted = await dynamicMinter.currentPeriodMinted();
      expect(currentPeriodMinted).to.equal(MINT_AMOUNT);
    });

    it("非铸币者不能铸造", async function () {
      await expect(
        dynamicMinter.connect(user1).mint(user2.address, MINT_AMOUNT)
      ).to.be.revertedWith("Caller is not a minter");
    });

    it("不能铸造到零地址", async function () {
      await expect(
        dynamicMinter.connect(minter).mint(ethers.constants.AddressZero, MINT_AMOUNT)
      ).to.be.revertedWith("Cannot mint to zero address");
    });

    it("不能铸造零数量", async function () {
      await expect(
        dynamicMinter.connect(minter).mint(user1.address, 0)
      ).to.be.revertedWith("Mint amount must be greater than 0");
    });

    it("应该更新已铸造数量", async function () {
      await dynamicMinter.connect(minter).mint(user1.address, MINT_AMOUNT);
      await dynamicMinter.connect(minter).mint(user2.address, MINT_AMOUNT);
      
      const currentPeriodMinted = await dynamicMinter.currentPeriodMinted();
      expect(currentPeriodMinted).to.equal(MINT_AMOUNT.mul(2));
    });

    it("应该发出 Mint 事件", async function () {
      const tx = await dynamicMinter.connect(minter).mint(user1.address, MINT_AMOUNT);
      const receipt = await tx.wait();
      
      await expect(tx)
        .to.emit(dynamicMinter, "Mint")
        .withArgs(user1.address, MINT_AMOUNT, receipt.timestamp);
    });
  });

  describe("每日限额", function () {
    it("不能超过每日铸造限额", async function () {
      // 铸造达到限额
      await dynamicMinter.connect(minter).mint(user1.address, DAILY_LIMIT);
      
      // 尝试再次铸造
      await expect(
        dynamicMinter.connect(minter).mint(user1.address, 1)
      ).to.be.revertedWith("Exceeds daily mint limit");
    });

    it("批量铸造不能超过限额", async function () {
      await expect(
        dynamicMinter.connect(minter).mint(user1.address, LARGE_AMOUNT)
      ).to.be.revertedWith("Exceeds daily mint limit");
    });
  });

  describe("时间窗口重置", function () {
    it("时间窗口后应该重置计数器", async function () {
      // 第一次铸造
      await dynamicMinter.connect(minter).mint(user1.address, MINT_AMOUNT);
      
      // 检查当前已铸造数量
      let currentPeriodMinted = await dynamicMinter.currentPeriodMinted();
      expect(currentPeriodMinted).to.equal(MINT_AMOUNT);
      
      // 时间前进25小时（超过24小时周期）
      await ethers.provider.send("evm_increaseTime", [25 * 60 * 60]); // 25小时
      await ethers.provider.send("evm_mine");
      
      // 再次铸造 - 应该重置计数器
      await dynamicMinter.connect(minter).mint(user2.address, MINT_AMOUNT);
      
      currentPeriodMinted = await dynamicMinter.currentPeriodMinted();
      expect(currentPeriodMinted).to.equal(MINT_AMOUNT);
    });

    it("应该更新周期开始时间", async function () {
      const originalStartTime = await dynamicMinter.periodStartTime();
      
      // 时间前进25小时
      await ethers.provider.send("evm_increaseTime", [25 * 60 * 60]);
      await ethers.provider.send("evm_mine");
      
      // 触发重置
      await dynamicMinter.connect(minter).mint(user1.address, MINT_AMOUNT);
      
      const newStartTime = await dynamicMinter.periodStartTime();
      expect(newStartTime).to.be.gt(originalStartTime);
    });

    it("应该发出 PeriodReset 事件", async function () {
      // 时间前进25小时
      await ethers.provider.send("evm_increaseTime", [25 * 60 * 60]);
      await ethers.provider.send("evm_mine");
      
      await expect(dynamicMinter.connect(minter).mint(user1.address, MINT_AMOUNT))
        .to.emit(dynamicMinter, "PeriodReset");
    });
  });

  describe("限额管理", function () {
    it("所有者应该能够更新每日限额", async function () {
      const newLimit = ethers.utils.parseEther("2000");
      await dynamicMinter.setDailyMintLimit(newLimit);
      
      expect(await dynamicMinter.dailyMintLimit()).to.equal(newLimit);
    });

    it("非所有者不能更新限额", async function () {
      const newLimit = ethers.utils.parseEther("2000");
      await expect(
        dynamicMinter.connect(user1).setDailyMintLimit(newLimit)
      ).to.be.revertedWith("Only owner can call this function");
    });

    it("不能设置零限额", async function () {
      await expect(
        dynamicMinter.setDailyMintLimit(0)
      ).to.be.revertedWith("Limit must be greater than 0");
    });

    it("应该发出 DailyLimitUpdated 事件", async function () {
      const newLimit = ethers.utils.parseEther("2000");
      await expect(dynamicMinter.setDailyMintLimit(newLimit))
        .to.emit(dynamicMinter, "DailyLimitUpdated")
        .withArgs(newLimit);
    });
  });

  describe("查询功能", function () {
    it("应该正确计算剩余铸造数量", async function () {
      // 初始剩余数量应该等于限额
      let remaining = await dynamicMinter.remainingMintAmount();
      expect(remaining).to.equal(DAILY_LIMIT);
      
      // 铸造后剩余数量应该减少
      await dynamicMinter.connect(minter).mint(user1.address, MINT_AMOUNT);
      
      remaining = await dynamicMinter.remainingMintAmount();
      expect(remaining).to.equal(DAILY_LIMIT.sub(MINT_AMOUNT));
    });

    it("时间窗口后剩余数量应该重置", async function () {
      // 铸造一些代币
      await dynamicMinter.connect(minter).mint(user1.address, MINT_AMOUNT);
      
      // 时间前进25小时
      await ethers.provider.send("evm_increaseTime", [25 * 60 * 60]);
      await ethers.provider.send("evm_mine");
      
      // 剩余数量应该重置为完整限额
      const remaining = await dynamicMinter.remainingMintAmount();
      expect(remaining).to.equal(DAILY_LIMIT);
    });

    it("应该正确返回周期结束时间", async function () {
      const periodStartTime = await dynamicMinter.periodStartTime();
      const periodEndTime = await dynamicMinter.getPeriodEndTime();
      
      expect(periodEndTime).to.equal(periodStartTime.add(24 * 60 * 60));
    });

    it("应该正确检查铸币者状态", async function () {
      expect(await dynamicMinter.isMinter(minter.address)).to.equal(true);
      expect(await dynamicMinter.isMinter(user1.address)).to.equal(false);
    });
  });

  describe("手动重置功能", function () {
    it("所有者应该能够手动重置周期", async function () {
      // 铸造一些代币
      await dynamicMinter.connect(minter).mint(user1.address, MINT_AMOUNT);
      
      // 手动重置
      await dynamicMinter.resetPeriod();
      
      const currentPeriodMinted = await dynamicMinter.currentPeriodMinted();
      expect(currentPeriodMinted).to.equal(0);
    });

    it("非所有者不能手动重置", async function () {
      await expect(
        dynamicMinter.connect(user1).resetPeriod()
      ).to.be.revertedWith("Only owner can call this function");
    });

    it("手动重置应该发出 PeriodReset 事件", async function () {
      await expect(dynamicMinter.resetPeriod())
        .to.emit(dynamicMinter, "PeriodReset");
    });
  });

  describe("边界情况", function () {
    it("应该能够铸造精确到限额的数量", async function () {
      // 铸造正好达到限额
      await dynamicMinter.connect(minter).mint(user1.address, DAILY_LIMIT);
      
      const currentPeriodMinted = await dynamicMinter.currentPeriodMinted();
      expect(currentPeriodMinted).to.equal(DAILY_LIMIT);
      
      // 不能再铸造
      await expect(
        dynamicMinter.connect(minter).mint(user1.address, 1)
      ).to.be.revertedWith("Exceeds daily mint limit");
    });

    it("多个铸币者的总额不能超过限额", async function () {
      // 添加第二个铸币者
      await dynamicMinter.setMinter(user1.address, true);
      
      // 第一个铸币者铸造一部分
      await dynamicMinter.connect(minter).mint(user2.address, DAILY_LIMIT.div(2));
      
      // 第二个铸币者尝试铸造超过剩余额度
      const remaining = await dynamicMinter.remainingMintAmount();
      await expect(
        dynamicMinter.connect(user1).mint(user2.address, remaining.add(1))
      ).to.be.revertedWith("Exceeds daily mint limit");
    });
  });
});