// test/StressTest.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("压力测试", function () {
  let SybilResistantMint;
  let contract;
  let owner;
  let users = [];

  // 创建多个测试用户
  before(async function () {
    [owner] = await ethers.getSigners();
    
    // 创建50个测试用户
    for (let i = 0; i < 50; i++) {
      const wallet = ethers.Wallet.createRandom().connect(ethers.provider);
      users.push(wallet);
    }
  });

  beforeEach(async function () {
    SybilResistantMint = await ethers.getContractFactory("SybilResistantMint");
    contract = await SybilResistantMint.deploy();
    await contract.deployed();
  });

  it("应该能够处理大量用户的并发铸造", async function () {
    this.timeout(60000); // 设置更长的超时时间

    const promises = users.map(async (user, index) => {
      // 为每个用户生成有效签名
      const signature = await generateValidSignature(
        user.address,
        ethers.constants.AddressZero,
        1,
        owner,
        contract.address
      );

      // 发送铸造交易
      return contract.connect(user).verifiedMint(1, signature, ethers.constants.AddressZero);
    });

    // 等待所有交易完成
    const results = await Promise.allSettled(promises);

    // 验证所有交易都成功
    const failedTransactions = results.filter(result => result.status === 'rejected');
    expect(failedTransactions.length).to.equal(0);

    // 验证所有用户的铸造计数都正确
    for (const user of users) {
      expect(await contract.mintCounts(user.address)).to.equal(1);
    }
  });

  it("应该正确防止大规模女巫攻击", async function () {
    // 模拟攻击者创建大量钱包
    const attackerWallets = [];
    for (let i = 0; i < 100; i++) {
      const wallet = ethers.Wallet.createRandom().connect(ethers.provider);
      attackerWallets.push(wallet);
    }

    // 尝试为每个攻击者钱包铸造（但没有有效签名）
    const fakeSignature = "0x" + "a".repeat(130); // 伪造签名

    const promises = attackerWallets.map(async (wallet) => {
      return contract.connect(wallet).verifiedMint(1, fakeSignature, ethers.constants.AddressZero);
    });

    const results = await Promise.allSettled(promises);

    // 所有攻击都应该失败
    const successfulAttacks = results.filter(result => result.status === 'fulfilled');
    expect(successfulAttacks.length).to.equal(0);

    // 验证没有攻击者成功铸造
    for (const wallet of attackerWallets) {
      expect(await contract.mintCounts(wallet.address)).to.equal(0);
    }
  });
});

// 辅助函数
async function generateValidSignature(userAddress, referrerAddress, amount, signer, contractAddress) {
  const messageHash = ethers.utils.solidityKeccak256(
    ["address", "address", "address", "uint256"],
    [userAddress, referrerAddress, contractAddress, amount]
  );

  const signature = await signer.signMessage(
    ethers.utils.arrayify(messageHash)
  );

  return signature;
}