
const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("Upgradeable Contract Test", function () {
    let contractA, contractB, proxy, proxyAsA, proxyAsB, ownerA, ownerB;
    let admin, user1;

    before(async function () {
        [admin, user1] = await ethers.getSigners();
    });

    it("Should complete the full upgradeable contract flow", async function () {
        console.log("=== 开始完整测试流程 ===");

        // 1. 部署 ContractA
        const ContractA = await ethers.getContractFactory("ContractA");
        contractA = await ContractA.deploy();
        const contractAAddress = await contractA.getAddress();
        console.log("✓ ContractA 部署完成:", contractAAddress);

        // 2. 部署 FixedProxy
        const FixedProxy = await ethers.getContractFactory("FixedProxy");
        // .connect(account) 用于指定使用哪个账户发送交易
        proxy = await FixedProxy.connect(admin).deploy(contractAAddress);
        const proxyAddress = await proxy.getAddress();
        console.log("✓ FixedProxy 部署完成:", proxyAddress);

        // 3. 验证代理合约的管理员
        const proxyAdmin = await proxy.getAdmin();
        console.log("✓ 代理合约管理员:", proxyAdmin);
        console.log("✓ 当前调用者:", admin.address);
        console.log("✓ 当前实现地址:", await proxy.getImplementation());

        // 4. 连接到代理合约
        proxyAsA = await ethers.getContractAt("ContractA", proxyAddress);

        // 5. 初始化 ContractA
        await proxyAsA.initialize();
        console.log("✓ ContractA 初始化完成");

        ownerA = await proxyAsA.getOwner();
        console.log(`✓ ownerA: ${ownerA}`);

        // 6. 验证管理员未被覆盖
        const adminAfterInit = await proxy.getAdmin();
        console.log("✓ 初始化后管理员:", adminAfterInit);
        expect(adminAfterInit).to.equal(proxyAdmin);

        // 7. 测试 ContractA 功能
        await proxyAsA.setValue(100);
        let value = await proxyAsA.getValue();
        console.log("✓ 设置数值 100, 当前数值:", value.toString());
        expect(value).to.equal(100);

        // 8. 再次验证管理员
        const adminAfterSetValue = await proxy.getAdmin();
        console.log("✓ 设置数值后管理员:", adminAfterSetValue);
        expect(adminAfterSetValue).to.equal(proxyAdmin);

        // 9. 部署 ContractB
        const ContractB = await ethers.getContractFactory("ContractB");
        contractB = await ContractB.deploy();
        const contractBAddress = await contractB.getAddress();
        console.log("✓ ContractB 部署完成:", contractBAddress);

        // 10. 升级到 ContractB
        console.log("正在执行升级...");
        const upgradeTx = await proxy.connect(admin).upgrade(contractBAddress);
        await upgradeTx.wait();
        console.log("✓ 升级到 ContractB 完成");

        // 11. 验证升级成功
        const currentImplementation = await proxy.getImplementation();
        console.log("✓ 升级后实现地址:", currentImplementation);
        expect(currentImplementation).to.equal(contractBAddress);

        // 12. 连接到新的实现
        proxyAsB = await ethers.getContractAt("ContractB", proxyAddress);

        // 13. 验证原有数据仍然存在
        value = await proxyAsB.getValue();
        console.log("✓ 升级后原有数值仍然存在:", value.toString());
        expect(value).to.equal(100);

        // 14. 测试新功能
        await proxyAsB.setNewFeature(42);
        let feature = await proxyAsB.getNewFeature();
        console.log("✓ 新功能值设置为 42, 当前值:", feature.toString());
        expect(feature).to.equal(42);

        // 15. 验证版本
        const version = await proxyAsB.version();
        console.log("✓ 当前版本:", version);
        expect(version).to.equal("V2.0");

        console.log("=== 测试完成 ===");
    });
});



/*

  Upgradeable Contract Test
=== 开始完整测试流程 ===
✓ ContractA 部署完成: 0xf5059a5D33d5853360D16C683c16e67980206f36
✓ FixedProxy 部署完成: 0x95401dc811bb5740090279Ba06cfA8fcF6113778
✓ 代理合约管理员: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
✓ 当前调用者: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
✓ 当前实现地址: 0xf5059a5D33d5853360D16C683c16e67980206f36
✓ ContractA 初始化完成
✓ 初始化后管理员: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
✓ 设置数值 100, 当前数值: 100
✓ 设置数值后管理员: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
✓ ContractB 部署完成: 0x4826533B4897376654Bb4d4AD88B7faFD0C98528
正在执行升级...
✓ 升级到 ContractB 完成
✓ 升级后实现地址: 0x4826533B4897376654Bb4d4AD88B7faFD0C98528
✓ 升级后原有数值仍然存在: 100
✓ 新功能值设置为 42, 当前值: 42
✓ 当前版本: V2.0
=== 测试完成 ===
    ✔ Should complete the full upgradeable contract flow (192ms)


  1 passing (309ms)
  */























// const { ethers } = require("hardhat");
// const { expect } = require("chai");

// describe("Upgradeable Contract Test", function () {
//     let contractA, contractB, proxy, proxyAsA, proxyAsB;
//     let admin, user1;

//     before(async function () {
//         // 获取签名者 - 第一个账户作为管理员
//         [admin, user1] = await ethers.getSigners();
//     });

//     it("Should complete the full upgradeable contract flow", async function () {
//         console.log("=== 开始完整测试流程 ===");

//         // 1. 部署 ContractA
//         const ContractA = await ethers.getContractFactory("ContractA");
//         contractA = await ContractA.deploy();
//         const contractAAddress = await contractA.getAddress();
//         console.log("✓ ContractA 部署完成:", contractAAddress);

//         // 2. 部署 FixedProxy - 使用管理员账户部署
//         const FixedProxy = await ethers.getContractFactory("FixedProxy");
//         proxy = await FixedProxy.connect(admin).deploy(contractAAddress);
//         const proxyAddress = await proxy.getAddress();
//         console.log("✓ FixedProxy 部署完成:", proxyAddress);

//         // 3. 验证代理合约的管理员
//         const proxyAdmin = await proxy.admin();
//         console.log("✓ 代理合约管理员:", proxyAdmin);
//         console.log("✓ 当前调用者:", admin.address);

//         // 4. 使用 ContractA 的 ABI 连接到代理合约
//         proxyAsA = await ethers.getContractAt("ContractA", proxyAddress);

//         // 5. 初始化 ContractA
//         await proxyAsA.initialize();
//         console.log("✓ ContractA 初始化完成");

//         // 6. 测试 ContractA 功能
//         await proxyAsA.setValue(100);
//         let value = await proxyAsA.getValue();
//         console.log("✓ 设置数值 100, 当前数值:", value.toString());
//         expect(value).to.equal(100);

//         await proxyAsA.setValue(999);
//         value = await proxyAsA.getValue();
//         console.log("✓ 更新数值 999, 当前数值:", value.toString());
//         expect(value).to.equal(999);

//         // 7. 部署 ContractB
//         const ContractB = await ethers.getContractFactory("ContractB");
//         contractB = await ContractB.deploy();
//         const contractBAddress = await contractB.getAddress();
//         console.log("✓ ContractB 部署完成:", contractBAddress);

//         // 8. 升级到 ContractB - 使用管理员账户调用升级
//         console.log("正在执行升级...");
//         await proxy.connect(admin).upgrade(contractBAddress);
//         console.log("✓ 升级到 ContractB 完成");

//         // 9. 验证升级是否成功
//         const currentImplementation = await proxy.getImplementation();
//         console.log("✓ 当前实现合约地址:", currentImplementation);
//         expect(currentImplementation).to.equal(contractBAddress);

//         // 10. 使用 ContractB 的 ABI 连接到同一个代理地址
//         proxyAsB = await ethers.getContractAt("ContractB", proxyAddress);

//         // 11. 验证原有数据仍然存在
//         value = await proxyAsB.getValue();
//         console.log("✓ 升级后原有数值仍然存在:", value.toString());
//         expect(value).to.equal(999);

//         // 12. 测试 ContractB 的新功能
//         await proxyAsB.setNewFeature(42);
//         let feature = await proxyAsB.getNewFeature();
//         console.log("✓ 新功能值设置为 42, 当前值:", feature.toString());
//         expect(feature).to.equal(42);

//         await proxyAsB.setDescription("Hello Upgradeable World");
//         let desc = await proxyAsB.getDescription();
//         console.log("✓ 描述设置为:", desc);
//         expect(desc).to.equal("Hello Upgradeable World");

//         // 13. 验证版本
//         const version = await proxyAsB.version();
//         console.log("✓ 当前版本:", version);
//         expect(version).to.equal("V2.0");

//         console.log("=== 测试完成 ===");
//     });

//     it("Should not allow non-owner to set value", async function () {
//         // 确保 proxyAsA 已定义
//         if (!proxyAsA) {
//             throw new Error("proxyAsA is not defined - run the first test first");
//         }
        
//         // 使用非所有者账户尝试设置值
//         await expect(
//             proxyAsA.connect(user1).setValue(123)
//         ).to.be.revertedWith("Not owner");
//     });

//     it("Should not allow non-admin to upgrade", async function () {
//         // 确保 proxy 和 contractB 已定义
//         if (!proxy || !contractB) {
//             throw new Error("Contracts not defined - run the first test first");
//         }
        
//         const contractBAddress = await contractB.getAddress();
        
//         // 使用非管理员账户尝试升级
//         await expect(
//             proxy.connect(user1).upgrade(contractBAddress)
//         ).to.be.revertedWith("Only admin");
//     });

//     it("Should show correct implementation address", async function () {
//         // 确保 proxy 和 contractB 已定义
//         if (!proxy || !contractB) {
//             throw new Error("proxy is not defined - run the first test first");
//         }
        
//         const currentImplementation = await proxy.getImplementation();
//         const contractBAddress = await contractB.getAddress();
//         console.log("当前实现合约地址:", currentImplementation);
//         expect(currentImplementation).to.equal(contractBAddress);
//     });
// });















