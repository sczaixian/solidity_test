require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config(); // 加载环境变量
require("./tasks")  // 引入 tasks
require("hardhat-deploy")  // 引入hardhat deploye
module.exports = {
  solidity: "0.8.28",
  networks: {
    sepolia: {
      // Hardhat 通过这个 URL 向区块链节点发送 JSON-RPC 请求； 用这个 URL 连接到 Sepolia 测试网
      url: process.env.SEPOLIA_RPC_URL || "",  //  用于指定要连接的区块链网络的节点 RPC 端点地址。
      // accounts: process.env.PRIVATE_KEY_HOM1 ? [process.env.PRIVATE_KEY_HOM1,process.env.PRIVATE_KEY_HOM2] : [],
      accounts:[process.env.PRIVATE_KEY_HOM1,process.env.PRIVATE_KEY_HOM2,process.env.PRIVATE_KEY_CMP],  // 用来转账
      chainId: 11155111,
    },
  },
  // 自动验证部署在区块链上的智能合约源代码
  // 将合约源代码与区块链上的字节码进行匹配验证
  // 验证成功后，Etherscan 会显示合约的源代码、ABI、以及支持在线交互
  etherscan: {  // 用于验证（verify）
    apiKey:{
      // 测试网
      sepolia: process.env.ETHERSCAN_API_KEY,  // 使用 API 密钥来访问其验证服务
      // goerli: process.env.ETHERSCAN_API_KEY,
      // 主网
      // mainnet: process.env.ETHERSCAN_API_KEY,
      // 其他网络
      // polygon: process.env.POLYGONSCAN_API_KEY,
      // polygonMumbai: process.env.POLYGONSCAN_API_KEY,
      // arbitrum: process.env.ARBISCAN_API_KEY,
      // optimism: process.env.OPTIMISMSCAN_API_KEY,

    }
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
  }
};
