// test/EnhancedSybilResistantMint.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EnhancedSybilResistantMint", function () {
  let EnhancedSybilResistantMint;
  let enhancedContract;
  let owner;
  let user1;

  const MAX_TOTAL_SUPPLY = 1000;
  const MINT_AMOUNT = 1;

  beforeEach(async function () {
    [owner, user1] = await ethers.getSigners();

    EnhancedSybilResistantMint = await ethers.getContractFactory("EnhancedSybilResistantMint");
    enhancedContract = await EnhancedSybilResistantMint.deploy(MAX_TOTAL_SUPPLY);
    await enhancedContract.deployed();
  });

  describe("时间限制测试", function () {
    it("应该在铸造时间开始前拒绝铸造", async function () {
      // 默认部署后1天才开始，所以现在应该被拒绝
      const signature = await generateValidSignature(
        user1.address,
        ethers.constants.AddressZero,
        MINT_AMOUNT,
        owner,
        enhancedContract.address
      );

      await expect(
        enhancedContract.connect(user1).verifiedMintWithTimeLimit(
          MINT_AMOUNT,
          signature,
          ethers.constants.AddressZero
        )
      ).to.be.revertedWith("Mint not started");
    });

    it("应该在正确的时间段内允许铸造", async function () {
      // 设置立即开始的铸造时间
      const startTime = Math.floor(Date.now() / 1000);
      const endTime = startTime + 3600; // 1小时后结束

      await enhancedContract.connect(owner).setMintTime(startTime, endTime);

      // 前进到开始时间
      await ethers.provider.send("evm_setNextBlockTimestamp", [startTime]);
      await ethers.provider.send("evm_mine");

      const signature = await generateValidSignature(
        user1.address,
        ethers.constants.AddressZero,
        MINT_AMOUNT,
        owner,
        enhancedContract.address
      );

      await expect(
        enhancedContract.connect(user1).verifiedMintWithTimeLimit(
          MINT_AMOUNT,
          signature,
          ethers.constants.AddressZero
        )
      ).to.emit(enhancedContract, "MintSuccess");
    });

    it("应该在铸造时间结束后拒绝铸造", async function () {
      // 设置立即开始但很快结束的时间
      const startTime = Math.floor(Date.now() / 1000);
      const endTime = startTime + 60; // 1分钟后结束

      await enhancedContract.connect(owner).setMintTime(startTime, endTime);

      // 前进到结束时间之后
      await ethers.provider.send("evm_setNextBlockTimestamp", [endTime + 1]);
      await ethers.provider.send("evm_mine");

      const signature = await generateValidSignature(
        user1.address,
        ethers.constants.AddressZero,
        MINT_AMOUNT,
        owner,
        enhancedContract.address
      );

      await expect(
        enhancedContract.connect(user1).verifiedMintWithTimeLimit(
          MINT_AMOUNT,
          signature,
          ethers.constants.AddressZero
        )
      ).to.be.revertedWith("Mint ended");
    });
  });

  describe("总供应量限制测试", function () {
    it("应该拒绝超过总供应量的铸造", async function () {
      // 设置立即开始的时间
      const startTime = Math.floor(Date.now() / 1000);
      await enhancedContract.connect(owner).setMintTime(startTime, startTime + 3600);

      // 尝试铸造超过总供应量的数量
      const excessiveAmount = MAX_TOTAL_SUPPLY + 1;

      const signature = await generateValidSignature(
        user1.address,
        ethers.constants.AddressZero,
        excessiveAmount,
        owner,
        enhancedContract.address
      );

      await expect(
        enhancedContract.connect(user1).verifiedMintWithTimeLimit(
          excessiveAmount,
          signature,
          ethers.constants.AddressZero
        )
      ).to.be.revertedWith("Exceeds max supply");
    });
  });
});

// 辅助函数（与上面相同）
async function generateValidSignature(userAddress, referrerAddress, amount, signer, contractAddress) {
  const messageHash = ethers.utils.solidityKeccak256(
    ["address", "address", "address", "uint256"],
    [userAddress, referrerAddress, contractAddress, amount]
  );

  const ethSignedMessageHash = ethers.utils.hashMessage(
    ethers.utils.arrayify(messageHash)
  );

  const signature = await signer.signMessage(
    ethers.utils.arrayify(messageHash)
  );

  return signature;
}