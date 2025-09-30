// 测试脚本示例
async function testCompleteFlow() {
    console.log("=== 开始完整测试流程 ===");
    
    // 1. 部署 ContractA
    const ContractA = await ethers.getContractFactory("ContractA");
    const contractA = await ContractA.deploy();
    await contractA.deployed();
    console.log("✓ ContractA 部署完成:", contractA.address);
    
    // 2. 部署 FixedProxy
    const FixedProxy = await ethers.getContractFactory("FixedProxy");
    const proxy = await FixedProxy.deploy(contractA.address);
    await proxy.deployed();
    console.log("✓ FixedProxy 部署完成:", proxy.address);
    
    // 3. 使用 ContractA 的 ABI 连接到代理
    const proxyAsA = await ethers.getContractAt("ContractA", proxy.address);
    
    // 4. 初始化 ContractA
    await proxyAsA.initialize();
    console.log("✓ ContractA 初始化完成");
    
    // 5. 测试 ContractA 功能
    await proxyAsA.setValue(100);
    let value = await proxyAsA.getValue();
    console.log("✓ 设置数值 100, 当前数值:", value.toString());
    
    await proxyAsA.setValue(999);
    value = await proxyAsA.getValue();
    console.log("✓ 更新数值 999, 当前数值:", value.toString());
    
    // 6. 部署 ContractB
    const ContractB = await ethers.getContractFactory("ContractB");
    const contractB = await ContractB.deploy();
    await contractB.deployed();
    console.log("✓ ContractB 部署完成:", contractB.address);
    
    // 7. 升级到 ContractB
    await proxy.upgrade(contractB.address);
    console.log("✓ 升级到 ContractB 完成");
    
    // 8. 使用 ContractB 的 ABI 连接到同一个代理地址
    const proxyAsB = await ethers.getContractAt("ContractB", proxy.address);
    
    // 9. 验证原有数据仍然存在
    value = await proxyAsB.getValue();
    console.log("✓ 升级后原有数值仍然存在:", value.toString());
    
    // 10. 测试 ContractB 的新功能
    await proxyAsB.setNewFeature(42);
    let feature = await proxyAsB.getNewFeature();
    console.log("✓ 新功能值设置为 42, 当前值:", feature.toString());
    
    await proxyAsB.setDescription("Hello Upgradeable World");
    let desc = await proxyAsB.getDescription();
    console.log("✓ 描述设置为:", desc);
    
    // 11. 验证版本
    const version = await proxyAsB.version();
    console.log("✓ 当前版本:", version);
    
    console.log("=== 测试完成 ===");
}

