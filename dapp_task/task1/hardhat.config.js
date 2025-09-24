require("@nomicfoundation/hardhat-toolbox");


require("dotenv").config(); // 加载环境变量


require("hardhat-deploy") 
require("@nomicfoundation/hardhat-ethers");
require("hardhat-deploy-ethers");
require('@openzeppelin/hardhat-upgrades')

module.exports = {
  solidity: "0.8.28",
  mocha:{
    timeout: 300000  // 200s
  },
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL, 
      accounts:[process.env.PRIVATE_KEY_CMP1,process.env.PRIVATE_KEY_CMP2,process.env.PRIVATE_KEY_HOM1],
      chainId: 11155111,
    },
  },

  etherscan: {  // 用于验证（verify）
    apiKey:process.env.ETHERSCAN_API_KEY
  },

  namedAccounts:{  // hardhat-deploy  配合  accounts ， 分别对应他们的索引
    firstAccount:{
      default:0
    },
    secondAccount:{
      default:1
    },
    therdAccount:{
      default:2
    },
  },
  gasReporter: {
    enabled: false // 不打印报告
  },
};
