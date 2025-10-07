// scripts/deploy.js
async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("使用账户部署合约:", deployer.address);
  console.log("账户余额:", (await deployer.getBalance()).toString());

  // 部署 MulticallProcessor
  const MulticallProcessor = await ethers.getContractFactory("MulticallProcessor");
  const multicallProcessor = await MulticallProcessor.deploy();
  await multicallProcessor.deployed();
  console.log("MulticallProcessor 部署地址:", multicallProcessor.address);

  // 部署 AdvancedMulticallProcessor
  const AdvancedMulticallProcessor = await ethers.getContractFactory("AdvancedMulticallProcessor");
  const advancedProcessor = await AdvancedMulticallProcessor.deploy();
  await advancedProcessor.deployed();
  console.log("AdvancedMulticallProcessor 部署地址:", advancedProcessor.address);

  // 保存部署地址到文件
  const fs = require("fs");
  const addresses = {
    multicallProcessor: multicallProcessor.address,
    advancedProcessor: advancedProcessor.address
  };
  
  fs.writeFileSync("deployed-addresses.json", JSON.stringify(addresses, null, 2));
  console.log("部署地址已保存到 deployed-addresses.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });