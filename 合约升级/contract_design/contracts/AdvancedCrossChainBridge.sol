// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


/*
跨链桥工作原理
源链操作：
用户锁定代币 → 发出跨链事件 → 中继器监听事件

目标链操作：
中继器提交证明 → 验证跨链消息 → 解锁/铸造代币

Nonce防护：   防止重放攻击
余额检查：    防止下溢攻击
交易哈希追踪： 防止重复处理
访问控制：    关键功能权限管理


实际应用扩展
集成Chainlink CCIP或其他跨链解决方案
添加手续费机制
实现多签名控制
添加紧急暂停功能
进行全面的安全审计
*/


/**
 * @title 高级跨链桥接合约
 * @dev 支持多链资产转移，包含安全机制和事件追踪
 */
contract AdvancedCrossChainBridge {
    
    address public owner;                                                     // 合约所有者
    mapping(uint256 => bool) public supportedChains;                          // 支持的链ID映射
    mapping(uint256 => mapping(address => uint256)) public chainBalances;     // 用户在各链的余额：chainId => user => balance
    mapping(uint256 => mapping(address => uint256)) public nonces;            // 防止重放攻击的非ce映射：chainId => user => nonce
    mapping(bytes32 => bool) public processedTransactions;                    // 跨链交易状态：txHash => bool
    
    // 事件定义
    event BridgeTransferInitiated(address indexed sender, uint256 indexed fromChain, uint256 indexed toChain, uint256 amount, uint256 nonce, uint256 timestamp);
    event BridgeTransferCompleted(address indexed receiver, uint256 indexed fromChain, uint256 indexed toChain, uint256 amount, bytes32 transactionHash);
    event TokensLocked(address indexed user, uint256 chainId, uint256 amount, uint256 timestamp);
    event TokensUnlocked(address indexed user, uint256 chainId, uint256 amount, uint256 timestamp);
    
    // 修饰器：仅所有者可调用
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    // 修饰器：检查链是否支持
    modifier onlySupportedChain(uint256 chainId) {
        require(supportedChains[chainId], "Chain not supported");
        _;
    }
    
    // 修饰器：检查余额是否充足
    modifier sufficientBalance(uint256 amount) {
        require(chainBalances[block.chainid][msg.sender] >= amount, "Insufficient balance");
        _;
    }

    /**
     * @dev 构造函数，初始化合约
     * @param initialOwner 合约所有者地址
     * @param initialChains 初始支持的链ID数组
     */
    constructor(address initialOwner, uint256[] memory initialChains) {
        owner = initialOwner;
        
        // 添加初始支持的链
        for (uint256 i = 0; i < initialChains.length; i++) {
            supportedChains[initialChains[i]] = true;
        }
        supportedChains[block.chainid] = true;    // 总是支持当前链
    }
    
    /**
     * @dev 存入代币到跨链桥
     * @param amount 存入的代币数量
     */
    function depositTokens(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        
        // 在实际应用中，这里会转移用户的代币到合约
        // 为了简化示例，我们直接更新余额映射
        chainBalances[block.chainid][msg.sender] += amount;
        emit TokensLocked(msg.sender, block.chainid, amount, block.timestamp);
    }
    
    /**
     * @dev 从跨链桥提取代币
     * @param amount 提取的代币数量
     */
    function withdrawTokens(uint256 amount) external sufficientBalance(amount) {
        chainBalances[block.chainid][msg.sender] -= amount;
        emit TokensUnlocked(msg.sender, block.chainid, amount, block.timestamp);
    }
    
    /**
     * @dev 发起跨链转账（源链操作）
     * @param targetChain 目标链ID
     * @param amount 转账金额
     * @return nonce 本次交易的nonce
     */
    function initiateBridgeTransfer(uint256 targetChain, uint256 amount) external sufficientBalance(amount) onlySupportedChain(targetChain) returns (uint256 nonce) {
        require(targetChain != block.chainid, "Cannot bridge to same chain");
        require(amount > 0, "Amount must be greater than 0");
        nonce = nonces[block.chainid][msg.sender];           // 获取并更新nonce
        nonces[block.chainid][msg.sender] = nonce + 1;
        chainBalances[block.chainid][msg.sender] -= amount;  // 锁定源链上的代币
        emit BridgeTransferInitiated(msg.sender, block.chainid, targetChain, amount, nonce, block.timestamp);
        return nonce;
    }
    
    /**
     * @dev 完成跨链转账（目标链操作）
     * @param receiver 接收者地址
     * @param sourceChain 源链ID
     * @param amount 转账金额
     * @param sourceNonce 源链交易nonce
     * @param signature 验证签名（简化版，实际需要复杂验证）
     */
    function completeBridgeTransfer(address receiver, uint256 sourceChain, uint256 amount, uint256 sourceNonce, bytes memory signature) external onlySupportedChain(sourceChain) {
        require(sourceChain != block.chainid, "Cannot complete from same chain");
        require(amount > 0, "Amount must be greater than 0");
        require(receiver != address(0), "Invalid receiver address");
        bytes32 txHash = keccak256(abi.encodePacked( receiver, sourceChain, block.chainid, amount, sourceNonce ));   // 生成交易哈希用于防重放
        require(!processedTransactions[txHash], "Transaction already processed");     // 检查交易是否已处理
        processedTransactions[txHash] = true;
        
        // 验证签名（简化版 - 实际需要跨链消息验证）
        // 在真实场景中，这里会验证来自源链的证明或签名
        bool isValid = validateCrossChainProof(receiver, sourceChain, amount, sourceNonce, signature);
        require(isValid, "Invalid cross-chain proof");
        chainBalances[block.chainid][receiver] += amount;      // 在目标链上解锁/铸造代币
        emit BridgeTransferCompleted(receiver, sourceChain, block.chainid, amount, txHash);
    }
    
    /**
     * @dev 验证跨链证明（简化版）
     * @notice 实际实现需要集成Oracle、中继器或零知识证明
     */
    function validateCrossChainProof(address receiver, uint256 sourceChain, uint256 amount, uint256 sourceNonce, bytes memory /*signature*/) internal pure returns(bool){
        // 简化验证 - 总是返回true
        // 实际实现需要：
        // 1. 验证来自源链的签名
        // 2. 检查源链的区块头有效性
        // 3. 验证Merkle证明等
        
        // 基础参数验证
        if (receiver == address(0) || amount == 0) {
            return false;
        }
        
        return true;
    }
    
    /**
     * @dev 添加支持的链（仅所有者）
     * @param chainId 要添加的链ID
     */
    function addSupportedChain(uint256 chainId) external onlyOwner {
        supportedChains[chainId] = true;
    }
    
    /**
     * @dev 移除支持的链（仅所有者）
     * @param chainId 要移除的链ID
     */
    function removeSupportedChain(uint256 chainId) external onlyOwner {
        require(chainId != block.chainid, "Cannot remove current chain");
        supportedChains[chainId] = false;
    }
    
    /**
     * @dev 获取用户余额
     * @param user 用户地址
     * @param chainId 链ID
     */
    function getBalance(address user, uint256 chainId) external view returns(uint256){
        return chainBalances[chainId][user];
    }
    
    /**
     * @dev 获取用户当前nonce
     * @param user 用户地址
     */
    function getCurrentNonce(address user) external view returns(uint256){
        return nonces[block.chainid][user];
    }
}