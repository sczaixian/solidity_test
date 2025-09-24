
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



/*G:\web3\solidity_test\dapp_task\task1>npx hardhat --network sepolia deploy
[dotenv@17.2.2] injecting env (6) from .env -- tip: ⚙️  suppress all logs with { quiet: true }
Nothing to compile
network name is sepolia
skip mock ...
network is sepolia
deployer:  0x3E0bDb54f94D735dDCf8D2074c852a8C22914aA7
MyToken (Proxy) deployed to: 0x22Fdd672Dbef3300b9b55aB8aBCE61Ba6037BE3C
Implementation contract address: 0xE313d022e6B6A444E4dE09e00ba180547E3b75AD
Verification failed: A network request failed. This is an error from the block explorer, not Hardhat. Error: Connect Timeout Error
*/