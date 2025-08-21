const { ethers } = require("hardhat");

async function main() {
    console.log("Starting contract deployment...");

    console.log("Environment variables:");
    console.log("SEPOLIA_RPC_URL:", process.env.SEPOLIA_RPC_URL ? "Set" : "Not set");
    console.log("PRIVATE_KEY_CMP:", process.env.PRIVATE_KEY_CMP ? "Set" : "Not set");
    console.log("ETHERSCAN_API_KEY:", process.env.ETHERSCAN_API_KEY ? "Set" : "Not set");


    // 获取签名者列表
    const signers = await ethers.getSigners();
    console.log(`Available signers: ${signers.length}`);

    if (signers.length === 0) {
        throw new Error("No signers available. Check your network configuration.");
    }

    // 获取部署者账户信息
    const deployer = signers[0];
    console.log(`Deploying contract with account: ${deployer.address}`);
    console.log(`Account balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`);

    // 部署合约
    const fundMeFactory = await ethers.getContractFactory("FundMe");
    console.log("Contract deploying...");
    const fundMe = await fundMeFactory.deploy(360);
    await fundMe.waitForDeployment();

    const contractAddress = await fundMe.getAddress();
    console.log(`Contract deployed successfully, address: ${contractAddress}`);

    // 等待区块确认
    console.log("Waiting for 5 confirmations...");
    await fundMe.deploymentTransaction().wait(5);
    console.log("5 confirmations received");

    // 条件验证 - 检查是否在测试网且有Etherscan API密钥
    const network = await ethers.provider.getNetwork();
    const chainId = network.chainId;

    console.log(`Current network chain ID: ${chainId}`);

    // 检查是否在Sepolia测试网（chainId 11155111）
    if (chainId === 11155111n && process.env.ETHERSCAN_API_KEY) {
        console.log("Verifying contract on Etherscan...");
        try {
            await verifyFundMe(contractAddress, [360]);
        } catch (error) {
            console.log("Verification failed, but continuing:", error.message);
        }
    } else {
        console.log("Skipping verification - not on Sepolia or no API key");
    }

    // 资金操作示例
    try {
        console.log("Funding contract with 0.0005 ETH...");
        const fundTx = await fundMe.fund({ value: ethers.parseEther("0.0005") });
        await fundTx.wait();
        console.log("Funding successful");
    } catch (error) {
        console.log("Funding failed:", error.message);
    }

    // 显示合约余额
    const balanceOfContract = await ethers.provider.getBalance(contractAddress);
    console.log(`Contract balance: ${ethers.formatEther(balanceOfContract)} ETH`);

    const other = signers[1];
    try {
        console.log("Funding contract with 0.0005 ETH by other ... ");
        const fundTx = await fundMe.connect(other).fund({ value: ethers.parseEther("0.0005") });
        await fundTx.wait();
        console.log("funding successful");
    } catch (error) {
        console.log("funding failed:", error.message);
    }

    const otherOfBalance = await ethers.provider.getBalance(contractAddress);
    console.log(`Contract balance: ${ethers.formatEther(otherOfBalance)}ETH`);

    // 查询资金映射（如果合约中有这个方法）
    try {
        const deployerFunds = await fundMe.funderToAmount(deployer.address);
        console.log("Funds from deployer:", ethers.formatEther(deployerFunds), "ETH");

        if (other) {
            const otherFunds = await fundMe.funderToAmount(other.address);
            console.log("Funds from other:", ethers.formatEther(otherFunds), "ETH");
        }
    } catch (error) {
        console.log("Error querying funder amounts:", error.message);
    }

}

async function verifyFundMe(contractAddress, args) {
    // 添加延迟以确保Etherscan能够索引到合约
    await new Promise(resolve => setTimeout(resolve, 30000));

    await hre.run("verify:verify", {
        address: contractAddress,
        constructorArguments: args  //数组
    });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Unexpected error:", error);
        process.exit(1);
    });