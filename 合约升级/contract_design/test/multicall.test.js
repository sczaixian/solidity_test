// test/multicall.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("批量交易处理器测试套件", function () {
  let multicallProcessor;
  let advancedProcessor;
  let owner;
  let user1;
  let user2;
  
  // 测试前置设置
  beforeEach(async function () {
    // 获取测试账户
    [owner, user1, user2] = await ethers.getSigners();
    
    // 部署合约
    const MulticallProcessor = await ethers.getContractFactory("MulticallProcessor");
    multicallProcessor = await MulticallProcessor.deploy();
    
    const AdvancedMulticallProcessor = await ethers.getContractFactory("AdvancedMulticallProcessor");
    advancedProcessor = await AdvancedMulticallProcessor.deploy();
    
    // 等待部署完成
    await multicallProcessor.deployed();
    await advancedProcessor.deployed();
  });

  describe("基础批量交易功能测试", function () {
    it("应该成功执行批量交易", async function () {
      // 准备批量交易数据
      const calls = [
        multicallProcessor.interface.encodeFunctionData("deposit"),
        multicallProcessor.interface.encodeFunctionData("setValue", [42]),
        multicallProcessor.interface.encodeFunctionData("getBalance")
      ];

      // 执行批量交易，附带 1 ETH
      const tx = await multicallProcessor.connect(user1).multicall(calls, {
        value: ethers.utils.parseEther("1.0")
      });
      
      await tx.wait();

      // 验证合约余额
      const contractBalance = await multicallProcessor.getBalance();
      expect(contractBalance).to.equal(ethers.utils.parseEther("1.0"));

      // 验证交易成功
      expect(tx.hash).to.be.a('string');
      expect(tx.hash).to.have.lengthOf(66);
    });

    it("应该处理空批量交易", async function () {
      const emptyCalls = [];
      
      const results = await multicallProcessor.multicall(emptyCalls);
      
      expect(results).to.be.an('array');
      expect(results).to.have.lengthOf(0);
    });
  });

  describe("原子性测试", function () {
    it("一个调用失败应该导致全部回滚", async function () {
      const calls = [
        multicallProcessor.interface.encodeFunctionData("deposit"),
        // 无效的函数调用
        "0x12345678"
      ];

      // 应该回滚
      await expect(
        multicallProcessor.connect(user1).multicall(calls, {
          value: ethers.utils.parseEther("1.0")
        })
      ).to.be.revertedWith("Multicall failed");

      // 验证没有状态改变
      const contractBalance = await multicallProcessor.getBalance();
      expect(contractBalance).to.equal(0);
    });
  });

  describe("高级批量交易功能测试", function () {
    it("应该执行灵活的批量交易", async function () {
      const calls = [
        advancedProcessor.interface.encodeFunctionData("deposit"),
        advancedProcessor.interface.encodeFunctionData("setValue", [100]),
        advancedProcessor.interface.encodeFunctionData("getUserBalance", [user1.address])
      ];

      const result = await advancedProcessor.connect(user1).flexibleMulticall(calls, false, {
        value: ethers.utils.parseEther("1.0")
      });

      const [results, successes] = result;

      // 验证结果
      expect(results).to.have.lengthOf(3);
      expect(successes).to.have.lengthOf(3);
      expect(successes[0]).to.be.true;
      expect(successes[1]).to.be.true;
      expect(successes[2]).to.be.true;

      // 验证存款成功
      const userBalance = await advancedProcessor.getUserBalance(user1.address);
      expect(userBalance).to.equal(ethers.utils.parseEther("1.0"));
    });

    it("应该处理部分失败的交易", async function () {
      const calls = [
        advancedProcessor.interface.encodeFunctionData("deposit"),
        "0x12345678", // 无效调用
        advancedProcessor.interface.encodeFunctionData("getUserBalance", [user1.address])
      ];

      const result = await advancedProcessor.connect(user1).flexibleMulticall(calls, false, {
        value: ethers.utils.parseEther("1.0")
      });

      const [results, successes] = result;

      expect(successes[0]).to.be.true;  // 存款成功
      expect(successes[1]).to.be.false; // 无效调用失败
      expect(successes[2]).to.be.true;  // 余额查询成功

      // 验证存款仍然成功
      const userBalance = await advancedProcessor.getUserBalance(user1.address);
      expect(userBalance).to.equal(ethers.utils.parseEther("1.0"));
    });

    it("要求全部成功时应该回滚", async function () {
      const calls = [
        advancedProcessor.interface.encodeFunctionData("deposit"),
        "0x12345678" // 无效调用
      ];

      await expect(
        advancedProcessor.connect(user1).flexibleMulticall(calls, true, {
          value: ethers.utils.parseEther("1.0")
        })
      ).to.be.reverted;

      // 验证没有状态改变
      const userBalance = await advancedProcessor.getUserBalance(user1.address);
      expect(userBalance).to.equal(0);
    });
  });

  describe("Gas 优化测试", function () {
    it("批量交易应该比单独交易更省Gas", async function () {
      // 测量单独交易的Gas消耗
      const singleCallTx = await advancedProcessor.connect(user1).deposit({
        value: ethers.utils.parseEther("1.0")
      });
      const singleReceipt = await singleCallTx.wait();
      const singleGasUsed = singleReceipt.gasUsed;

      // 重置状态
      await advancedProcessor.connect(user1).withdraw(ethers.utils.parseEther("1.0"));

      // 测量批量交易的Gas消耗
      const calls = [
        advancedProcessor.interface.encodeFunctionData("deposit"),
        advancedProcessor.interface.encodeFunctionData("setValue", [1]),
        advancedProcessor.interface.encodeFunctionData("setValue", [2])
      ];

      const batchTx = await advancedProcessor.connect(user1).flexibleMulticall(calls, true, {
        value: ethers.utils.parseEther("1.0")
      });
      const batchReceipt = await batchTx.wait();
      const batchGasUsed = batchReceipt.gasUsed;

      console.log(`单独交易Gas消耗: ${singleGasUsed.toString()}`);
      console.log(`批量交易Gas消耗: ${batchGasUsed.toString()}`);
      
      const singleTxTotal = singleGasUsed.mul(3);
      const gasSaved = singleTxTotal.sub(batchGasUsed);
      const gasSavedPercentage = gasSaved.mul(100).div(singleTxTotal);
      
      console.log(`Gas节省: ${gasSaved.toString()} (${gasSavedPercentage.toString()}%)`);

      // 批量交易应该比单独执行3次更省Gas
      expect(batchGasUsed.lt(singleTxTotal)).to.be.true;
    });
  });

  describe("事件测试", function () {
    it("应该正确触发事件", async function () {
      const calls = [
        multicallProcessor.interface.encodeFunctionData("deposit"),
        multicallProcessor.interface.encodeFunctionData("setValue", [999])
      ];

      // 检查事件触发
      await expect(
        multicallProcessor.connect(user1).multicall(calls, {
          value: ethers.utils.parseEther("1.0")
        })
      ).to.emit(multicallProcessor, "MulticallExecuted")
       .withArgs(user1.address, 2, true);
    });

    it("失败时应该触发CallFailed事件", async function () {
      const calls = [
        "0x12345678" // 无效调用
      ];

      // 对于基础版本，会直接回滚，所以不测试事件
      // 测试高级版本的部分失败情况
      const advancedCalls = [
        advancedProcessor.interface.encodeFunctionData("deposit"),
        "0x12345678" // 无效调用
      ];

      const tx = await advancedProcessor.connect(user1).flexibleMulticall(advancedCalls, false, {
        value: ethers.utils.parseEther("1.0")
      });
      
      const receipt = await tx.wait();
      
      // 检查是否有CallFailed事件
      const events = receipt.events.filter(
        event => event.event === "CallFailed"
      );
      
      expect(events).to.have.lengthOf(1);
      expect(events[0].args.index).to.equal(1); // 第二个调用失败
    });
  });

  describe("权限控制测试", function () {
    it("只有所有者可以转移所有权", async function () {
      // 非所有者尝试转移所有权
      await expect(
        advancedProcessor.connect(user1).transferOwnership(user2.address)
      ).to.be.revertedWith("Only owner can call this function");

      // 所有者可以成功转移
      await advancedProcessor.transferOwnership(user2.address);
      expect(await advancedProcessor.owner()).to.equal(user2.address);
    });
  });

  describe("集成测试场景", function () {
    it("模拟DeFi操作场景", async function () {
      const defiOperations = [
        advancedProcessor.interface.encodeFunctionData("deposit"),
        advancedProcessor.interface.encodeFunctionData("setValue", [1000]),
        advancedProcessor.interface.encodeFunctionData("getUserBalance", [user1.address])
      ];

      const result = await advancedProcessor.connect(user1).flexibleMulticall(defiOperations, true, {
        value: ethers.utils.parseEther("5.0")
      });

      const [results, successes] = result;

      // 验证所有操作成功
      successes.forEach((success, index) => {
        expect(success, `操作 ${index} 应该成功`).to.be.true;
      });

      // 验证最终状态
      const finalBalance = await advancedProcessor.getUserBalance(user1.address);
      expect(finalBalance).to.equal(ethers.utils.parseEther("5.0"));
    });

    it("测试并发用户场景", async function () {
      // 用户1的操作
      const user1Calls = [
        advancedProcessor.interface.encodeFunctionData("deposit"),
        advancedProcessor.interface.encodeFunctionData("setValue", [100])
      ];

      await advancedProcessor.connect(user1).flexibleMulticall(user1Calls, true, {
        value: ethers.utils.parseEther("3.0")
      });

      // 用户2的操作
      const user2Calls = [
        advancedProcessor.interface.encodeFunctionData("deposit"),
        advancedProcessor.interface.encodeFunctionData("setValue", [200])
      ];

      await advancedProcessor.connect(user2).flexibleMulticall(user2Calls, true, {
        value: ethers.utils.parseEther("7.0")
      });

      // 验证各自余额独立
      const user1Balance = await advancedProcessor.getUserBalance(user1.address);
      const user2Balance = await advancedProcessor.getUserBalance(user2.address);

      expect(user1Balance).to.equal(ethers.utils.parseEther("3.0"));
      expect(user2Balance).to.equal(ethers.utils.parseEther("7.0"));
    });
  });

  describe("边界情况测试", function () {
    it("处理大容量批量交易", async function () {
      const callCount = 10;
      const calls = [];
      
      for (let i = 0; i < callCount; i++) {
        calls.push(
          multicallProcessor.interface.encodeFunctionData("setValue", [i])
        );
      }

      const results = await multicallProcessor.multicall(calls);
      
      expect(results).to.have.lengthOf(callCount);
    });

    it("测试取款功能", async function () {
      // 先存款
      await advancedProcessor.connect(user1).deposit({
        value: ethers.utils.parseEther("2.0")
      });

      const balanceBefore = await ethers.provider.getBalance(user1.address);

      // 准备取款调用
      const calls = [
        advancedProcessor.interface.encodeFunctionData("withdraw", [ethers.utils.parseEther("1.0")])
      ];

      const tx = await advancedProcessor.connect(user1).flexibleMulticall(calls, true);
      const receipt = await tx.wait();

      // 计算实际Gas费用
      const gasUsed = receipt.gasUsed;
      const gasPrice = tx.gasPrice;
      const gasCost = gasUsed.mul(gasPrice);

      const balanceAfter = await ethers.provider.getBalance(user1.address);

      // 验证余额增加（考虑Gas费用）
      const expectedBalanceIncrease = ethers.utils.parseEther("1.0");
      const actualBalanceIncrease = balanceAfter.sub(balanceBefore).add(gasCost);
      
      expect(actualBalanceIncrease).to.be.closeTo(
        expectedBalanceIncrease,
        ethers.utils.parseEther("0.01") // 允许小误差
      );

      // 验证合约内余额减少
      const remainingBalance = await advancedProcessor.getUserBalance(user1.address);
      expect(remainingBalance).to.equal(ethers.utils.parseEther("1.0"));
    });
  });
});