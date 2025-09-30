const { ethers, upgrades } = require("hardhat");

async function main() {
  console.log("Deploying MyContractV1...");
  
  const MyContractV1 = await ethers.getContractFactory("MyContractV1");
  const myContract = await upgrades.deployProxy(MyContractV1, [], {
    initializer: "initialize",
    kind: "uups",
  });
  
  await myContract.waitForDeployment();
  const proxyAddress = await myContract.getAddress();
  
  console.log("Proxy deployed to:", proxyAddress);
  
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
  console.log("Implementation V1 deployed to:", implementationAddress);
  
  // 验证合约
  console.log("\nContract verification:");
  console.log("Value:", (await myContract.value()).toString());
  console.log("Text:", await myContract.text());
  console.log("Version:", await myContract.version());
  
  return proxyAddress;
}

async function upgrade(proxyAddress) {
  console.log("\nUpgrading to MyContractV2...");
  
  const MyContractV2 = await ethers.getContractFactory("MyContractV2");
  const myContractV2 = await upgrades.upgradeProxy(proxyAddress, MyContractV2);
  
  console.log("Proxy upgraded to V2");
  
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
  console.log("Implementation V2 deployed to:", implementationAddress);
  
  // 初始化 V2 的新功能
  console.log("Initializing V2 features...");
  await myContractV2.initializeV2();
  
  console.log("Version:", await myContractV2.version());
  console.log("Multiplier:", (await myContractV2.multiplier()).toString());
  
  return myContractV2;
}

// 主执行函数
async function runDeployment() {
  try {
    const proxyAddress = await main();
    
    // 等待一段时间后升级
    console.log("\nWaiting for upgrade...");
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    await upgrade(proxyAddress);
    
  } catch (error) {
    console.error("Deployment failed:", error);
    process.exit(1);
  }
}

if (require.main === module) {
  runDeployment();
}

module.exports = { main, upgrade };