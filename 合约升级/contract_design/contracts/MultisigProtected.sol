// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface IGnosisSafe {
    function getThreshold() external view returns(uint256);  // 获取执行交易所需的最小签名数
    function getOwners() external view returns(address[] memory);  // 获取所有管理员地址
}


contract MultisigProtected{
    
    address public safeAddress;   // Gnosis Safe主合约地址
    address public admin;         // 合约管理员（用于初始化设置）
    uint256 public noce;          // 操作计数器，防止重放攻击

    // 记录操作执行
    event OperationExecuted(address indexed sender, string operation, uint256 noce, uint256 threshold);
    event SafeAddressUpdated(address oldSafe, address newSafe);    // Safe地址更新

    // 验证是否为有效的Gnosis Safe调用
    modifier onlySafe() {
        require(safeAddress != address(0), "Safe address not set");
        require(msg.sender == safeAddress, "Caller is not the Safe contract");

        // 获取当前交易的阈值要求
        uint256 threshold = IGnosisSafe(safeAddress).getThreshold();
        require(threshold >= 1, "Invalid threshold configuration");
        _;
    }


    // 带操作类型的多签保护修饰器
    modifier onlySafeOperation(string memory operation){
        require(safeAddress != address(0), "Safe address not set");
        require(msg.sender == safeAddress, "Caller is not the Safe contract");

        uint256 threshold = IGnosisSafe(safeAddress).getThreshold();
        require(threshold >= 1, "Invalid threshold configuration");
        _;

        // 记录操作执行
        noce++;
        emit OperationExecuted(msg.sender, operation, noce, threshold);
    }

    constructor(address _admin){
        require(_admin != address(0), "Invalid admin address");
        admin = _admin;
    }

    // 设置Gnosis Safe地址（只能由管理员调用）
    function setSafeAddress(address _safeAddress) external {
        require(msg.sender == admin, "Only admin can set safe address");
        require(_safeAddress != address(0), "Invalid safe address");

        address oldSafe = safeAddress;
        safeAddress = _safeAddress;
        emit SafeAddressUpdated(oldSafe, _safeAddress);
    }

    
    /*** ----------------  受保护的功能  ---------------- ***/ 

    // 资金转移功能（需要多签）
    function transferFunds(address to, uint256 amount) external onlySafeOperation("TRANSFER_FUNDS") {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be positive");
        payable(to).transfer(amount);
    }

    // 合约配置更新（需要多签）
    function updateConfiguration(bytes32 newConfig) external onlySafeOperation("UPDATE_CONFIG"){
        // 配置更新逻辑
        // 存储到状态变量等
    }

    // 紧急暂停功能
    function emergencyPause() external onlySafe {
        // 紧急情况下的暂停逻辑
        // 注意：这里使用 onlySafe 而不是 onlySafeOperation
        // 意味着在紧急情况下可能接受较低的多签要求
        noce++;
        emit OperationExecuted(msg.sender, "EMERGENCY_PAUSE", noce, IGnosisSafe(safeAddress).getThreshold());
    }

    function getMultisigInfo() external view returns(address currentSafe, uint256 threshold, uint256 currentNoce) {
        currentSafe = safeAddress;
        currentNoce = noce;
        if(safeAddress != address(0)){
            threshold = IGnosisSafe(safeAddress).getThreshold();
        } else {
            threshold = 0;
        }
    }
}

// 用户发起交易 → Gnosis Safe收集签名 → Safe合约调用目标合约 → 目标合约验证调用者
contract RealWorldUsage is MultisigProtected  {
    mapping (address => uint256) public balance;

    constructor(address _admin) MultisigProtected(_admin) {
        // TODO:
    }

    // 实际的多签转账实现
    function secureTransfer(address to, uint256 amount) external onlySafeOperation("SECURE_TRANSFER"){
        require(balance[address(this)] >= amount, "Insufficient balance");
        (bool success, ) = to.call{value: amount}("");
        require(success, "Transfer failed");
        balance[address(this)] -= amount;
    }

    // 接收以太币
    receive() external payable {
        balance[address(this)] += msg.value;
    }
}


// 批量交易处理器 允许在单次交易中执行多个函数调用，提高效率并节省Gas
contract MulticallProcessor {
    // 事件记录，用于跟踪批量交易执行情况
    event MulticallExecuted(address indexed caller, uint256 callCount, bool success);
    event CallFailed(uint256 index, bytes reason);

    // 执行批量交易
    function multicall(bytes[] calldata data) external returns(bytes[] memory results){
        // 初始化结果数组，长度与输入数据相同
        results = new bytes[](data.length);
        bool allSuccess = true;
        for(uint256 i = 0; i < data.length; i++){
            try this.executeSingleCall(data[i]) returns(bytes memory result){
                // 调用成功，存储结果
                results[i] = result;
            } catch (bytes memory reason){
                // 调用失败，记录错误信息
                results[i] = reason;
                allSuccess = false;
                emit CallFailed(i, reason);
                // 根据需求决定是否立即回滚
                // 如果需要严格原子性，则使用 require 立即回滚
                // 如果允许部分失败，则继续执行
                require(false, "Multicall failed: atomic execution required");
            }
        }
        emit MulticallExecuted(msg.sender, data.length, allSuccess);
    }

    // 执行单个函数调用（内部使用）
    function executeSingleCall(bytes calldata callData) external returns(bytes memory) {
        // 使用 delegatecall 在当前合约上下文中执行
        // delegatecall 特点：
        // - 使用当前合约的存储
        // - 使用调用者的 msg.sender 和 msg.value
        // - 目标地址的代码在当前合约上下文中运行
        (bool success, bytes memory result) = address(this).delegatecall(callData);
        
        require(success, "Single call execution failed");
        return result;
    }

    // 存款功能
    function deposit() external payable {
        // todo:存款逻辑
        require(msg.value > 0, "Deposit amount must be greater than 0");
        // todo: 余额记录等逻辑
    }

    // 获取合约余额
    function getBalance() external view returns(uint256) {
        return address(this).balance;
    }

    // 简单的状态设置
    function setValue(uint256 newValue) external pure returns(bool) {
        // 设置某个值的逻辑
        return true;
    }
}


// 增强版批量交易处理器
contract AdvancedMulticallProcessor {
    address public owner;
    // 存储用户数据示例
    mapping(address => uint256) public userBalances;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }

    // 灵活的批量交易处理，支持不同的失败处理策略
    function flexibleMulticall(bytes[] calldata data, bool requireAllSuccess) external returns(bytes[] memory results, bool[] memory success){
        results = new bytes[](data.length);
        success = new bool[](data.length);
        bool hasFailure = false;
        for(uint256 i = 0; i < data.length; i++){
            try this.executeDelegateCall(data[i]) returns(bytes memory result) {
                results[i] = result;
                success[i] = true;
            } catch (bytes memory reason){
                results[i] = reason;
                success[i] = false;
                hasFailure = true;
                // 如果要求全部成功，立即回滚
                if(requireAllSuccess){
                    revert(string(abi.encodePacked("Call failed at index: ", i)));
                }
            }
        }

        if (requireAllSuccess && hasFailure) {
            revert("Multicall completed with failures, but requireAllSuccess was true");
        }
    }

    // 执行委托调用
    function executeDelegateCall(bytes calldata callData) external returns(bytes memory){
        (bool success, bytes memory result) = address(this).delegatecall(callData);
        require(success, "Delegate call failed");
        return result;
    }

    // 存款函数
    function deposit() external payable {
        require(msg.value > 0, "Invalid deposit amount");
        userBalances[msg.sender] += msg.value;
    }

    // 取款函数
    function wilthdraw(uint256 amount) external {
        require(userBalances[msg.sender] >= amount, "Insufficient balance");
        userBalances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    // 获取用户余额
    function getUserBalance(address user) external view returns(uint256) {
        return userBalances[user];
    }

    // 转移合约所有权
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}


// 使用示例
contract MulticallExample {

    function prepareMulticallData() external view returns (bytes[] memory) {
        bytes[] memory data = new bytes[](3);                          // 创建包含多个调用的数据数组
        data[0] = abi.encodeWithSignature("deposit()");                // 调用1：存款（需要在实际调用时附带ETH）
        data[1] = abi.encodeWithSignature("setValue(uint256)", 123);   // 调用2：设置值
        data[2] = abi.encodeWithSignature("getBalance()");             // 调用3：获取余额
        
        return data;
    }
    
    // 计算函数选择器，用于理解调用数据
    function getFunctionSignature(string memory functionName) external pure returns (bytes4) {
        return bytes4(keccak256(bytes(functionName)));
    }
}

/*
// delegatecall 执行机制：
// - 代码在目标合约中执行
// - 但在当前合约的上下文中（使用当前合约的存储）
// - msg.sender 和 msg.value 保持不变
(bool success, bytes memory result) = address(this).delegatecall(callData); 
*/


/*
MulticallProcessorTest 
# 使用 Foundry 测试框架
forge test
forge test -vvv  # 详细输出
forge test --match-test test_GasOptimization  # 运行特定测试
forge test --gas-report  # Gas 消耗报告


// test/multicall.test.js
// scripts/deploy.js
// test/utils/multicall-helper.js
// test/performance.test.js
# 安装依赖
npm install --save-dev hardhat @nomiclabs/hardhat-waffle @nomiclabs/hardhat-ethers chai ethers

# 运行所有测试
npx hardhat test

# 运行特定测试文件
npx hardhat test test/multicall.test.js

# 运行性能测试
npx hardhat test test/performance.test.js

# 带详细输出
npx hardhat test --verbose

# 部署合约
npx hardhat run scripts/deploy.js --network localhost
*/