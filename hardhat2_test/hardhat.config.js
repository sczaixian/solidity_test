require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
  networks: {
    sepolia: {
      url: "https://eth-sepolia.g.alchemy.com/v2/RmsPYhly5O6-XH8UdmqCQ",
      accounts: [
        // "decf550fcc469204df8d024977ad887c888a3164b0977f588ae645d3786b4511",
        "e039af6407e7622a8354bd45ea44de86ca663c81d6176ab698fe788e603b2682"
      ],
      chainId: 11155111,
      gas: "auto",
      gasPrice: "auto",
    },
  },
  etherscan: {
    apiKey: {
      sepolia: "TZ1JWZAT8XK1M8V4JIVD2XJGHU93GRHQ86"
    }
  }
};
