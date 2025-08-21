require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config(); // 加载环境变量
require("./tasks")  // 引入
require("hardhat-deploy")  // 引入hardhat deploye
module.exports = {
  solidity: "0.8.28",
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "",
      // accounts: process.env.PRIVATE_KEY_HOM1 ? [process.env.PRIVATE_KEY_HOM1,process.env.PRIVATE_KEY_HOM2] : [],
      accounts:[process.env.PRIVATE_KEY_HOM1,process.env.PRIVATE_KEY_HOM2,process.env.PRIVATE_KEY_CMP],
      chainId: 11155111,
    },
  },
  etherscan: {
    apiKey:process.env.ETHERSCAN_API_KEY,
  },
  namedAccounts:{
    firstAccount:{
      default:0
    },
    secondAccount:{
      default:1
    },
    therdAccount:{
      default:2
    },
  }
};
