const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("MyContract UUPS Upgrade", function () {
  let myContract;
  let owner, user1, user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // 部署 V1
    const MyContractV1 = await ethers.getContractFactory("MyContractV1");
    myContract = await upgrades.deployProxy(MyContractV1, [], {
      initializer: "initialize",
      kind: "uups",
    });

    await myContract.waitForDeployment();
  });

  describe("V1 Functionality", function () {
    it("should initialize with correct values", async function () {
      expect(await myContract.value()).to.equal(100);
      expect(await myContract.text()).to.equal("Hello V1");
      expect(await myContract.version()).to.equal("v1.0.0");
    });

    it("should set value correctly", async function () {
      await myContract.setValue(999);
      expect(await myContract.value()).to.equal(999);
    });

    it("should set text correctly", async function () {
      await myContract.setText("New Text");
      expect(await myContract.text()).to.equal("New Text");
    });

    it("should handle deposits", async function () {
      const depositAmount = ethers.parseEther("1.0");

      await myContract.connect(user1).deposit({ value: depositAmount });

      expect(await myContract.getBalance(user1.address)).to.equal(depositAmount);
      expect(await myContract.getUserCount()).to.equal(1);
    });
  });

  describe("UUPS Upgrade to V2", function () {
    let myContractV2;

    beforeEach(async function () {
      // 先设置一些数据
      await myContract.setValue(500);
      await myContract.setText("Before Upgrade");
      await myContract.connect(user1).deposit({ value: ethers.parseEther("0.5") });

      // 升级到 V2
      const MyContractV2 = await ethers.getContractFactory("MyContractV2");
      myContractV2 = await upgrades.upgradeProxy(await myContract.getAddress(), MyContractV2);

      // 初始化 V2 功能
      await myContractV2.initializeV2();
    });

    it("should preserve V1 state after upgrade", async function () {
      expect(await myContractV2.value()).to.equal(500);
      expect(await myContractV2.text()).to.equal("Before Upgrade");
      expect(await myContractV2.getBalance(user1.address)).to.equal(ethers.parseEther("0.5"));
    });

    it("should have V2 version", async function () {
      expect(await myContractV2.version()).to.equal("v2.0.0");
    });

    it("should initialize V2 features", async function () {
      expect(await myContractV2.multiplier()).to.equal(2);
    });

    it("should use new V2 functions", async function () {
      // 测试增强值功能
      expect(await myContractV2.getEnhancedValue()).to.equal(1000); // 500 * 2

      // 测试设置乘数
      await myContractV2.setMultiplier(3);
      expect(await myContractV2.multiplier()).to.equal(3);
      expect(await myContractV2.getEnhancedValue()).to.equal(1500); // 500 * 3
    });

    it("should handle rewards system", async function () {
      const rewardAmount = ethers.parseEther("0.1");

      await myContractV2.addReward(user1.address, rewardAmount);

      expect(await myContractV2.rewards(user1.address)).to.equal(rewardAmount);
      expect(await myContractV2.getUserTotal(user1.address)).to.equal(
        ethers.parseEther("0.6") // 0.5 deposit + 0.1 reward
      );
    });

    it("should handle batch operations", async function () {
      await myContractV2.batchUpdateValues(777, "Batch Updated");

      expect(await myContractV2.value()).to.equal(777);
      expect(await myContractV2.text()).to.equal("Batch Updated");
    });

    it("should reject upgrade from non-owner", async function () {
      const MyContractV2 = await ethers.getContractFactory("MyContractV2");

      await expect(
        upgrades.upgradeProxy(await myContract.getAddress(), MyContractV2.connect(user1))
      ).to.be.reverted;
    });
  });

  describe("Storage Layout Compatibility", function () {
    it("should maintain storage layout after upgrade", async function () {
      // 在 V1 中设置复杂状态
      await myContract.setValue(123);
      await myContract.setText("Storage Test");
      await myContract.connect(user1).deposit({ value: ethers.parseEther("1.0") });
      await myContract.connect(user2).deposit({ value: ethers.parseEther("2.0") });

      const userCountBefore = await myContract.getUserCount();

      // 升级到 V2
      const MyContractV2 = await ethers.getContractFactory("MyContractV2");
      const myContractV2 = await upgrades.upgradeProxy(await myContract.getAddress(), MyContractV2);
      await myContractV2.initializeV2();

      // 验证所有状态保持不变
      expect(await myContractV2.value()).to.equal(123);
      expect(await myContractV2.text()).to.equal("Storage Test");
      expect(await myContractV2.getBalance(user1.address)).to.equal(ethers.parseEther("1.0"));
      expect(await myContractV2.getBalance(user2.address)).to.equal(ethers.parseEther("2.0"));
      expect(await myContractV2.getUserCount()).to.equal(userCountBefore);
    });
  });
});