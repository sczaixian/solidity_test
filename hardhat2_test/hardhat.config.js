require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config(); // 加载环境变量
require("./tasks")
module.exports = {
  solidity: "0.8.28",
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY_CMP ? [process.env.PRIVATE_KEY_CMP] : [],
      chainId: 11155111,
    },
  },
  etherscan: {
    apiKey:process.env.ETHERSCAN_API_KEY,
  }
};
