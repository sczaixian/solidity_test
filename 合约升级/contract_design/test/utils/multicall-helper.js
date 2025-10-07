// test/utils/multicall-helper.js
class MulticallHelper {
  constructor(contract) {
    this.contract = contract;
  }

  // 准备批量交易数据
  async prepareBatchData(operations) {
    const calls = [];
    
    for (const op of operations) {
      if (op.type === 'deposit') {
        calls.push(this.contract.interface.encodeFunctionData("deposit"));
      } else if (op.type === 'setValue') {
        calls.push(this.contract.interface.encodeFunctionData("setValue", [op.value]));
      } else if (op.type === 'getBalance') {
        calls.push(this.contract.interface.encodeFunctionData("getBalance"));
      } else if (op.type === 'withdraw') {
        calls.push(this.contract.interface.encodeFunctionData("withdraw", [op.amount]));
      }
    }
    
    return calls;
  }

  // 执行并分析批量交易
  async executeAndAnalyze(calls, options = {}) {
    const { value = 0, requireAllSuccess = false } = options;
    
    const tx = await this.contract.flexibleMulticall(calls, requireAllSuccess, {
      value: value
    });
    
    const receipt = await tx.wait();
    const [results, successes] = await this.contract.flexibleMulticall.staticCall(
      calls, requireAllSuccess, { value: value }
    );

    return {
      transaction: tx,
      receipt: receipt,
      results: results,
      successes: successes,
      gasUsed: receipt.gasUsed
    };
  }

  // 计算Gas节省
  calculateGasSavings(batchGas, individualGasArray) {
    const totalIndividualGas = individualGasArray.reduce((sum, gas) => sum + gas, 0);
    const savings = totalIndividualGas - batchGas;
    const savingsPercentage = (savings / totalIndividualGas) * 100;
    
    return {
      batchGas,
      totalIndividualGas,
      savings,
      savingsPercentage
    };
  }
}

module.exports = MulticallHelper;