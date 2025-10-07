const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OwnablePlus 合约测试", function () {
  let ownablePlus;
  let timelockExample;
  let owner1, owner2, owner3, nonOwner;
  
  // 测试常量
  const DELAY = 2 * 24 * 60 * 60; // 2天（秒）

  beforeEach(async function () {
    // 获取测试账户
    [owner1, owner2, owner3, nonOwner] = await ethers.getSigners();
    
    // 部署 OwnablePlus 合约
    const OwnablePlus = await ethers.getContractFactory("OwnablePlus");
    ownablePlus = await OwnablePlus.deploy([owner1.address, owner2.address]);
    await ownablePlus.deployed();
    
    // 部署 TimelockExample 合约
    const TimelockExample = await ethers.getContractFactory("TimelockExample");
    timelockExample = await TimelockExample.deploy([owner1.address, owner2.address]);
    await timelockExample.deployed();
  });

  describe("基础功能测试", function () {
    it("应该正确初始化管理员", async function () {
      expect(await ownablePlus.isOwner(owner1.address)).to.be.true;
      expect(await ownablePlus.isOwner(owner2.address)).to.be.true;
      expect(await ownablePlus.isOwner(owner3.address)).to.be.false;
      expect(await ownablePlus.isOwner(nonOwner.address)).to.be.false;
    });

    it("应该返回正确的管理员列表", async function () {
      const owners = await ownablePlus.getOwners();
      expect(owners).to.have.lengthOf(2);
      expect(owners).to.include(owner1.address);
      expect(owners).to.include(owner2.address);
    });

    it("应该正确返回延迟时间", async function () {
      expect(await ownablePlus.DELAY()).to.equal(DELAY);
    });
  });

  describe("权限控制测试", function () {
    it("管理员可以调用 onlyOwner 函数", async function () {
      // 管理员可以调用 scheduleOperation
      const operationHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      await expect(ownablePlus.connect(owner1).scheduleOperation(operationHash))
        .not.to.be.reverted;
    });

    it("非管理员不能调用 onlyOwner 函数", async function () {
      const operationHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      await expect(ownablePlus.connect(nonOwner).scheduleOperation(operationHash))
        .to.be.revertedWith("OwnablePlus: caller is not an owner");
    });
  });

  describe("时间锁功能测试", function () {
    it("应该正确预约操作", async function () {
      const operationHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("testOperation"));
      
      // 预约操作
      const tx = await ownablePlus.connect(owner1).scheduleOperation(operationHash);
      const receipt = await tx.wait();
      const block = await ethers.provider.getBlock(receipt.blockNumber);
      
      // 检查预约时间
      const scheduledTime = await ownablePlus.schedule(operationHash);
      expect(scheduledTime).to.equal(block.timestamp + DELAY);
      
      // 检查事件
      await expect(tx)
        .to.emit(ownablePlus, "OperationScheduled")
        .withArgs(operationHash, block.timestamp + DELAY);
    });

    it("应该正确检查操作是否就绪", async function () {
      const operationHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("testOperation"));
      
      // 预约操作
      await ownablePlus.connect(owner1).scheduleOperation(operationHash);
      
      // 立即检查应该返回 false
      expect(await ownablePlus.isOperationReady(operationHash)).to.be.false;
      
      // 时间前进 1 天，应该仍然返回 false
      await ethers.provider.send("evm_increaseTime", [24 * 60 * 60]); // 1天
      await ethers.provider.send("evm_mine");
      expect(await ownablePlus.isOperationReady(operationHash)).to.be.false;
      
      // 时间前进超过 2 天，应该返回 true
      await ethers.provider.send("evm_increaseTime", [25 * 60 * 60]); // 额外25小时
      await ethers.provider.send("evm_mine");
      expect(await ownablePlus.isOperationReady(operationHash)).to.be.true;
    });

    it("应该允许取消已预约的操作", async function () {
      const operationHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("testOperation"));
      
      // 预约操作
      await ownablePlus.connect(owner1).scheduleOperation(operationHash);
      expect(await ownablePlus.schedule(operationHash)).to.not.equal(0);
      
      // 取消操作
      await ownablePlus.connect(owner1).cancelOperation(operationHash);
      expect(await ownablePlus.schedule(operationHash)).to.equal(0);
    });

    it("不能取消未预约的操作", async function () {
      const operationHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("nonExistentOperation"));
      
      await expect(ownablePlus.connect(owner1).cancelOperation(operationHash))
        .to.be.revertedWith("OwnablePlus: operation not scheduled");
    });
  });

  describe("管理员管理测试", function () {
    it("应该通过时间锁添加新管理员", async function () {
      // 生成添加管理员的操作哈希
      const operationHash = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["string", "address"],
          ["addOwner", owner3.address]
        )
      );
      
      // 预约添加管理员操作
      await ownablePlus.connect(owner1).scheduleOperation(operationHash);
      
      // 立即尝试执行应该失败
      await expect(ownablePlus.connect(owner1).addOwner(owner3.address))
        .to.be.revertedWith("OwnablePlus: operation not ready");
      
      // 等待时间锁过期
      await ethers.provider.send("evm_increaseTime", [DELAY + 1]);
      await ethers.provider.send("evm_mine");
      
      // 执行添加管理员操作
      const tx = await ownablePlus.connect(owner1).addOwner(owner3.address);
      
      // 验证新管理员被添加
      expect(await ownablePlus.isOwner(owner3.address)).to.be.true;
      
      // 检查事件
      await expect(tx)
        .to.emit(ownablePlus, "OwnerAdded")
        .withArgs(owner3.address);
    });

    it("应该通过时间锁移除管理员", async function () {
      // 生成移除管理员的操作哈希
      const operationHash = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["string", "address"],
          ["removeOwner", owner2.address]
        )
      );
      
      // 预约移除管理员操作
      await ownablePlus.connect(owner1).scheduleOperation(operationHash);
      
      // 等待时间锁过期
      await ethers.provider.send("evm_increaseTime", [DELAY + 1]);
      await ethers.provider.send("evm_mine");
      
      // 执行移除管理员操作
      const tx = await ownablePlus.connect(owner1).removeOwner(owner2.address);
      
      // 验证管理员被移除
      expect(await ownablePlus.isOwner(owner2.address)).to.be.false;
      
      // 检查事件
      await expect(tx)
        .to.emit(ownablePlus, "OwnerRemoved")
        .withArgs(owner2.address);
    });

    it("不能移除最后一个管理员", async function () {
      // 先移除 owner2
      let operationHash = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["string", "address"],
          ["removeOwner", owner2.address]
        )
      );
      
      await ownablePlus.connect(owner1).scheduleOperation(operationHash);
      await ethers.provider.send("evm_increaseTime", [DELAY + 1]);
      await ethers.provider.send("evm_mine");
      await ownablePlus.connect(owner1).removeOwner(owner2.address);
      
      // 现在尝试移除最后一个管理员（owner1）
      operationHash = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["string", "address"],
          ["removeOwner", owner1.address]
        )
      );
      
      await ownablePlus.connect(owner1).scheduleOperation(operationHash);
      await ethers.provider.send("evm_increaseTime", [DELAY + 1]);
      await ethers.provider.send("evm_mine");
      
      await expect(ownablePlus.connect(owner1).removeOwner(owner1.address))
        .to.be.revertedWith("OwnablePlus: cannot remove last owner");
    });

    it("不能添加零地址作为管理员", async function () {
      const operationHash = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["string", "address"],
          ["addOwner", ethers.constants.AddressZero]
        )
      );
      
      await ownablePlus.connect(owner1).scheduleOperation(operationHash);
      await ethers.provider.send("evm_increaseTime", [DELAY + 1]);
      await ethers.provider.send("evm_mine");
      
      await expect(ownablePlus.connect(owner1).addOwner(ethers.constants.AddressZero))
        .to.be.revertedWith("OwnablePlus: new owner is zero address");
    });

    it("不能添加已存在的管理员", async function () {
      const operationHash = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["string", "address"],
          ["addOwner", owner1.address]
        )
      );
      
      await ownablePlus.connect(owner1).scheduleOperation(operationHash);
      await ethers.provider.send("evm_increaseTime", [DELAY + 1]);
      await ethers.provider.send("evm_mine");
      
      await expect(ownablePlus.connect(owner1).addOwner(owner1.address))
        .to.be.revertedWith("OwnablePlus: already an owner");
    });
  });

  describe("TimelockExample 合约测试", function () {
    it("应该通过时间锁修改重要值", async function () {
      const newValue = 999;
      const operationHash = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["string", "uint256"],
          ["setValue", newValue]
        )
      );
      
      // 预约操作
      await timelockExample.connect(owner1).scheduleOperation(operationHash);
      
      // 等待时间锁过期
      await ethers.provider.send("evm_increaseTime", [DELAY + 1]);
      await ethers.provider.send("evm_mine");
      
      // 执行操作
      const tx = await timelockExample.connect(owner1).setImportantValue(newValue);
      
      // 验证值被修改
      expect(await timelockExample.importantValue()).to.equal(newValue);
      
      // 检查事件
      await expect(tx)
        .to.emit(timelockExample, "ValueChanged")
        .withArgs(newValue);
    });

    it("应该通过时间锁修改重要地址", async function () {
      const newAddress = owner3.address;
      const operationHash = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["string", "address"],
          ["setAddress", newAddress]
        )
      );
      
      // 预约操作
      await timelockExample.connect(owner1).scheduleOperation(operationHash);
      
      // 等待时间锁过期
      await ethers.provider.send("evm_increaseTime", [DELAY + 1]);
      await ethers.provider.send("evm_mine");
      
      // 执行操作
      const tx = await timelockExample.connect(owner1).setImportantAddress(newAddress);
      
      // 验证地址被修改
      expect(await timelockExample.importantAddress()).to.equal(newAddress);
      
      // 检查事件
      await expect(tx)
        .to.emit(timelockExample, "AddressChanged")
        .withArgs(newAddress);
    });

    it("非管理员不能修改重要值", async function () {
      await expect(timelockExample.connect(nonOwner).setImportantValue(123))
        .to.be.revertedWith("OwnablePlus: caller is not an owner");
    });
  });

  describe("边界情况测试", function () {
    it("不能执行未预约的操作", async function () {
      const operationHash = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["string", "address"],
          ["addOwner", owner3.address]
        )
      );
      
      await expect(ownablePlus.connect(owner1).addOwner(owner3.address))
        .to.be.revertedWith("OwnablePlus: operation not scheduled");
    });

    it("不能重复预约同一个操作", async function () {
      const operationHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test"));
      
      await ownablePlus.connect(owner1).scheduleOperation(operationHash);
      
      await expect(ownablePlus.connect(owner1).scheduleOperation(operationHash))
        .to.be.revertedWith("OwnablePlus: operation already scheduled");
    });

    it("不同操作应该有不同的哈希", async function () {
      const hash1 = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["string", "address"],
          ["addOwner", owner3.address]
        )
      );
      
      const hash2 = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["string", "address"],
          ["addOwner", nonOwner.address]
        )
      );
      
      expect(hash1).to.not.equal(hash2);
    });
  });
});


// npm install --save-dev @nomiclabs/hardhat-ethers ethers @nomiclabs/hardhat-waffle chai