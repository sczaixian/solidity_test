// test/performance.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");
const MulticallHelper = require("./utils/multicall-helper");

describe("性能测试", function () {
  let advancedProcessor;
  let helper;
  let user1;

  beforeEach(async function () {
    [user1] = await ethers.getSigners();
    
    const AdvancedMulticallProcessor = await ethers.getContractFactory("AdvancedMulticallProcessor");
    advancedProcessor = await AdvancedMulticallProcessor.deploy();
    await advancedProcessor.deployed();
    
    helper = new MulticallHelper(advancedProcessor);
  });

  it("批量交易性能基准测试", async function () {
    const batchSizes = [1, 5, 10, 20];
    const results = {};

    for (const size of batchSizes) {
      // 准备批量操作
      const operations = [];
      for (let i = 0; i < size; i++) {
        operations.push({ type: 'setValue', value: i });
      }
      
      const calls = await helper.prepareBatchData(operations);
      
      // 执行批量交易
      const startTime = Date.now();
      const result = await helper.executeAndAnalyze(calls);
      const endTime = Date.now();
      
      results[size] = {
        gasUsed: result.gasUsed.toString(),
        executionTime: endTime - startTime,
        successRate: result.successes.filter(s => s).length / size
      };
      
      console.log(`批量大小 ${size}:`);
      console.log(`  Gas消耗: ${results[size].gasUsed}`);
      console.log(`  执行时间: ${results[size].executionTime}ms`);
      console.log(`  成功率: ${results[size].successRate * 100}%`);
    }

    // 验证所有批次都成功
    Object.values(results).forEach(result => {
      expect(result.successRate).to.equal(1);
    });
  });

  it("对比单独执行 vs 批量执行", async function () {
    const operationCount = 5;
    
    // 单独执行
    const individualGas = [];
    const individualTimes = [];
    
    for (let i = 0; i < operationCount; i++) {
      const startTime = Date.now();
      const tx = await advancedProcessor.setValue(i);
      const receipt = await tx.wait();
      const endTime = Date.now();
      
      individualGas.push(receipt.gasUsed);
      individualTimes.push(endTime - startTime);
    }
    
    // 批量执行
    const operations = [];
    for (let i = 0; i < operationCount; i++) {
      operations.push({ type: 'setValue', value: i });
    }
    
    const calls = await helper.prepareBatchData(operations);
    const batchStartTime = Date.now();
    const batchResult = await helper.executeAndAnalyze(calls);
    const batchEndTime = Date.now();
    
    // 计算节省
    const gasComparison = helper.calculateGasSavings(
      parseInt(batchResult.gasUsed),
      individualGas.map(g => parseInt(g))
    );
    
    const timeComparison = {
      individual: individualTimes.reduce((sum, time) => sum + time, 0),
      batch: batchEndTime - batchStartTime
    };
    
    console.log("Gas 对比:");
    console.log(`  单独执行总Gas: ${gasComparison.totalIndividualGas}`);
    console.log(`  批量执行Gas: ${gasComparison.batchGas}`);
    console.log(`  Gas节省: ${gasComparison.savings} (${gasComparison.savingsPercentage.toFixed(2)}%)`);
    
    console.log("时间对比:");
    console.log(`  单独执行总时间: ${timeComparison.individual}ms`);
    console.log(`  批量执行时间: ${timeComparison.batch}ms`);
    console.log(`  时间节省: ${timeComparison.individual - timeComparison.batch}ms`);
    
    // 验证批量执行更高效
    expect(gasComparison.savings).to.be.greaterThan(0);
  });
});