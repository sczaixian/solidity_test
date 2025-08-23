require("@nomicfoundation/hardhat-toolbox");

// deploy 相关包
require("@nomicfoundation/hardhat-ethers");
require("hardhat-deploy");
require("hardhat-deploy-ethers");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",

  namedAccounts: {
    firstAccount: {
      default: 0
    }
  }
};
