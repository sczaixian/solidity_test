require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades"); // 确保已引入升级插件

module.exports = {
  solidity: {
    compilers: [
      // 主要针对你的合约文件
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      // 为OpenZeppelin合约添加以下版本:cite[4]
      {
        version: "0.8.22",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.21",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545"
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },

  gasReporter: {
    enabled: false // 不打印报告
  },

  "scripts": {
    "compile": "hardhat compile",
    "test": "hardhat test",
    "deploy": "hardhat run scripts/deploy.js",
    "deploy:local": "hardhat run scripts/deploy.js --network localhost",
    "node": "hardhat node"
  }
};