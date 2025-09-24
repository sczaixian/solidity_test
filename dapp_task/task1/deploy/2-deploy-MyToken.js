
const { ethers, upgrades } = require("hardhat")


module.exports = async() => {
    console.log(`network is ${network.name}`)

    const [deployer] = await ethers.getSigners()
    console.log("deployer: ", deployer.address)


    let myToken = await ethers.getContractFactory("MyToken");
    myToken = await upgrades.deployProxy(myToken, { initializer: 'initialize' });

    
    
    
    await myToken.waitForDeployment();
    const proxyAddress = await myToken.getAddress();
    console.log("MyToken (Proxy) deployed to:", proxyAddress);

    // Get the implementation contract address
    const implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
    console.log("Implementation contract address:", implementationAddress);

    // Verify the implementation contract (not the proxy)
    // Etherscan 需要验证的是 ​​实现合约​​（Implementation Contract），而不是代理合约本身
    if (network.config.chainId === 11155111 && process.env.ETHERSCAN_API_KEY?.trim()) {
        try {
            await hre.run("verify:verify", {
                address: implementationAddress,
                constructorArguments: [],
            });
            console.log("Implementation contract verified!");
        } catch (error) {
            console.error("Verification failed:", error.message);
        }
    } else {
        console.log("Verification skipped...");
    }
}

module.exports.tags = ["all", "mytoken"]



/*PS D:\web3_porjs\solidity_test\dapp_task\task1> npx hardhat --network sepolia deploy
[dotenv@17.2.2] injecting env (6) from .env -- tip: 🔐 prevent committing .env to code: https://dotenvx.com/precommit
Compiled 1 Solidity file successfully (evm target: paris).
network name is sepolia
skip mock ...
network is sepolia
deployer:  0x3E0bDb54f94D735dDCf8D2074c852a8C22914aA7
MyToken (Proxy) deployed to: 0xb027d610a93d55369E3f043BCcc8B234Ec10Aab0
Implementation contract address: 0xE313d022e6B6A444E4dE09e00ba180547E3b75AD
The contract 0xE313d022e6B6A444E4dE09e00ba180547E3b75AD has already been verified on the block explorer. If you're trying to verify a partially verified contract, please use the --force flag.
https://sepolia.etherscan.io/address/0xE313d022e6B6A444E4dE09e00ba180547E3b75AD#code

Implementation contract verified!*/