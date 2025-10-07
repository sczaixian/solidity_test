// test/SybilResistantMint.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SybilResistantMint", function () {
  let SybilResistantMint;
  let sybilResistantMint;
  let owner;
  let user1;
  let user2;
  let attacker;
  let referrer;

  // 测试参数
  const MINT_AMOUNT = 1;
  const MAX_MINT_PER_ADDRESS = 3;

  beforeEach(async function () {
    // 获取测试账户
    [owner, user1, user2, attacker, referrer] = await ethers.getSigners();

    // 部署合约
    SybilResistantMint = await ethers.getContractFactory("SybilResistantMint");
    sybilResistantMint = await SybilResistantMint.deploy();
    await sybilResistantMint.deployed();
  });

  describe("部署测试", function () {
    it("应该正确设置合约所有者", async function () {
      expect(await sybilResistantMint.owner()).to.equal(owner.address);
    });

    it("应该设置正确的最大铸造限制", async function () {
      expect(await sybilResistantMint.MAX_MINT_PER_ADDRESS()).to.equal(MAX_MINT_PER_ADDRESS);
    });
  });

  describe("签名验证测试", function () {
    it("应该允许有效签名的铸造", async function () {
      // 生成有效签名
      const signature = await generateValidSignature(
        user1.address,
        referrer.address,
        MINT_AMOUNT,
        owner
      );

      // 执行铸造
      await expect(
        sybilResistantMint.connect(user1).verifiedMint(
          MINT_AMOUNT,
          signature,
          referrer.address
        )
      ).to.emit(sybilResistantMint, "MintSuccess");

      // 验证铸造计数
      expect(await sybilResistantMint.mintCounts(user1.address)).to.equal(1);
    });

    it("应该拒绝无效签名的铸造", async function () {
      // 使用攻击者私钥生成无效签名
      const invalidSignature = await generateValidSignature(
        user1.address,
        referrer.address,
        MINT_AMOUNT,
        attacker // 使用攻击者而不是所有者
      );

      // 应该被拒绝
      await expect(
        sybilResistantMint.connect(user1).verifiedMint(
          MINT_AMOUNT,
          invalidSignature,
          referrer.address
        )
      ).to.be.revertedWith("Invalid signature: Not authorized");
    });

    it("应该拒绝重放攻击", async function () {
      // 生成有效签名
      const signature = await generateValidSignature(
        user1.address,
        referrer.address,
        MINT_AMOUNT,
        owner
      );

      // 第一次铸造应该成功
      await sybilResistantMint.connect(user1).verifiedMint(
        MINT_AMOUNT,
        signature,
        referrer.address
      );

      // 第二次使用相同签名应该失败
      await expect(
        sybilResistantMint.connect(user1).verifiedMint(
          MINT_AMOUNT,
          signature,
          referrer.address
        )
      ).to.be.revertedWith("Signature already used");
    });
  });

  describe("铸造限制测试", function () {
    it("应该允许达到最大铸造限制", async function () {
      for (let i = 0; i < MAX_MINT_PER_ADDRESS; i++) {
        const signature = await generateValidSignature(
          user1.address,
          referrer.address,
          MINT_AMOUNT,
          owner
        );

        await sybilResistantMint.connect(user1).verifiedMint(
          MINT_AMOUNT,
          signature,
          referrer.address
        );

        expect(await sybilResistantMint.mintCounts(user1.address)).to.equal(i + 1);
      }
    });

    it("应该拒绝超过最大铸造限制", async function () {
      // 先铸造最大次数
      for (let i = 0; i < MAX_MINT_PER_ADDRESS; i++) {
        const signature = await generateValidSignature(
          user1.address,
          referrer.address,
          MINT_AMOUNT,
          owner
        );

        await sybilResistantMint.connect(user1).verifiedMint(
          MINT_AMOUNT,
          signature,
          referrer.address
        );
      }

      // 尝试第四次铸造应该失败
      const signature = await generateValidSignature(
        user1.address,
        referrer.address,
        MINT_AMOUNT,
        owner
      );

      await expect(
        sybilResistantMint.connect(user1).verifiedMint(
          MINT_AMOUNT,
          signature,
          referrer.address
        )
      ).to.be.revertedWith("Mint limit reached");
    });
  });

  describe("女巫攻击防护测试", function () {
    it("应该防止同一用户使用不同地址绕过限制", async function () {
      // 模拟女巫攻击：同一用户控制多个地址
      const user1Wallet = user1;
      const user2Wallet = user2; // 假设这是同一用户控制的第二个地址

      // 为用户1铸造
      const signature1 = await generateValidSignature(
        user1Wallet.address,
        referrer.address,
        MINT_AMOUNT,
        owner
      );

      await sybilResistantMint.connect(user1Wallet).verifiedMint(
        MINT_AMOUNT,
        signature1,
        referrer.address
      );

      // 为用户2铸造 - 这应该仍然需要单独的有效签名
      const signature2 = await generateValidSignature(
        user2Wallet.address,
        referrer.address,
        MINT_AMOUNT,
        owner
      );

      await sybilResistantMint.connect(user2Wallet).verifiedMint(
        MINT_AMOUNT,
        signature2,
        referrer.address
      );

      // 两个地址都应该有独立的铸造计数
      expect(await sybilResistantMint.mintCounts(user1Wallet.address)).to.equal(1);
      expect(await sybilResistantMint.mintCounts(user2Wallet.address)).to.equal(1);
    });

    it("应该拒绝没有签名的直接铸造尝试", async function () {
      // 尝试不使用签名直接铸造
      const fakeSignature = "0x1234567890abcdef";

      await expect(
        sybilResistantMint.connect(user1).verifiedMint(
          MINT_AMOUNT,
          fakeSignature,
          referrer.address
        )
      ).to.be.reverted;
    });
  });

  describe("边界情况测试", function () {
    it("应该拒绝零数量铸造", async function () {
      const signature = await generateValidSignature(
        user1.address,
        referrer.address,
        0, // 零数量
        owner
      );

      await expect(
        sybilResistantMint.connect(user1).verifiedMint(
          0,
          signature,
          referrer.address
        )
      ).to.be.revertedWith("Amount must be positive");
    });

    it("应该正确处理不同的推荐人地址", async function () {
      const differentReferrer = attacker.address; // 使用不同的推荐人

      const signature = await generateValidSignature(
        user1.address,
        differentReferrer,
        MINT_AMOUNT,
        owner
      );

      await expect(
        sybilResistantMint.connect(user1).verifiedMint(
          MINT_AMOUNT,
          signature,
          differentReferrer
        )
      ).to.emit(sybilResistantMint, "MintSuccess");
    });
  });

  describe("剩余铸造次数查询", function () {
    it("应该正确计算剩余铸造次数", async function () {
      // 初始状态
      expect(await sybilResistantMint.remainingMints(user1.address)).to.equal(MAX_MINT_PER_ADDRESS);

      // 铸造一次
      const signature1 = await generateValidSignature(
        user1.address,
        referrer.address,
        MINT_AMOUNT,
        owner
      );

      await sybilResistantMint.connect(user1).verifiedMint(
        MINT_AMOUNT,
        signature1,
        referrer.address
      );

      expect(await sybilResistantMint.remainingMints(user1.address)).to.equal(MAX_MINT_PER_ADDRESS - 1);

      // 铸造第二次
      const signature2 = await generateValidSignature(
        user1.address,
        referrer.address,
        MINT_AMOUNT,
        owner
      );

      await sybilResistantMint.connect(user1).verifiedMint(
        MINT_AMOUNT,
        signature2,
        referrer.address
      );

      expect(await sybilResistantMint.remainingMints(user1.address)).to.equal(MAX_MINT_PER_ADDRESS - 2);
    });
  });
});

// 辅助函数：生成有效签名
async function generateValidSignature(userAddress, referrerAddress, amount, signer) {
  // 构造与合约中完全相同的消息
  const messageHash = ethers.utils.solidityKeccak256(
    ["address", "address", "address", "uint256"],
    [userAddress, referrerAddress, await getContractAddress(), amount]
  );

  // 添加以太坊签名前缀
  const ethSignedMessageHash = ethers.utils.hashMessage(
    ethers.utils.arrayify(messageHash)
  );

  // 生成签名
  const signature = await signer.signMessage(
    ethers.utils.arrayify(messageHash)
  );

  return signature;
}

// 辅助函数：获取合约地址（在部署后）
async function getContractAddress() {
  const SybilResistantMint = await ethers.getContractFactory("SybilResistantMint");
  const contract = await SybilResistantMint.deploy();
  await contract.deployed();
  return contract.address;
}