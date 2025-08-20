import type { HardhatUserConfig } from "hardhat/config";

import hardhatToolboxMochaEthersPlugin from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import { configVariable } from "hardhat/config";

const config: HardhatUserConfig = {
  plugins: [hardhatToolboxMochaEthersPlugin],
  solidity: {
    profiles: {
      default: {
        version: "0.8.28",
      },
      production: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
  },
  networks: {
    hardhatMainnet: {
      type: "edr-simulated",
      chainType: "l1",
    },
    hardhatOp: {
      type: "edr-simulated",
      chainType: "op",
    },
    sepolia: {
      type: "http",
      chainType: "l1",
      chainId: 11155111,
      // url: configVariable("SEPOLIA_RPC_URL"),
      // accounts: [configVariable("SEPOLIA_PRIVATE_KEY")],
      url: "https://eth-sepolia.g.alchemy.com/v2/RmsPYhly5O6-XH8UdmqCQ",
      accounts: ["decf550fcc469204df8d024977ad887c888a3164b0977f588ae645d3786b4511"],
      gas: "auto",
      gasPrice: "auto",
    },
  },
};

export default config;
