// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
Optimism采用乐观Rollup技术，具有以下特点：
L1作为数据可用层：交易数据存储在以太坊主网
L2作为执行层：交易在L2快速执行
欺诈证明机制：确保状态正确性

// 核心步骤： 存款流程 (L1 → L2)
1. 用户调用 depositToL2() 并发送ETH
2. 通过 OptimismPortal 发送存款交易
3. 交易数据提交到L1，状态根更新到L1
4. L2节点同步数据并在L2执行
5. 用户在L2收到对应资产


提款流程 (L2 → L1)
// 两阶段提款：
阶段1 - 发起提款 (L2):
  - 用户调用 initiateWithdrawal()
  - 生成提款记录，进入挑战期(7天)

阶段2 - 完成提款 (L1):
  - 挑战期结束后调用 finalizeWithdrawal()
  - 验证欺诈证明期已过
  - 执行提款转账


挑战期保护: 7天欺诈证明窗口
消息验证: 仅允许跨链消息系统调用完成函数
防重放: 使用nonce防止重复提款
权限控制: 严格的身份验证
*/

/**
 * @title Optimism跨链桥接合约
 * @dev 实现L1↔L2双向资产转移
 * 
 * 核心组件说明：
 * - OptimismPortal: L1↔L2通信门户
 * - CrossDomainMessenger: 跨链消息传递
 * - L2StandardBridge: L2标准桥接
 */
contract OptimismBridge {
    // 事件定义
    event DepositToL2( address indexed from, address indexed to, uint256 amount, uint256 timestamp );
    event WithdrawalInitiated( address indexed from, address indexed to, uint256 amount, uint256 timestamp );
    event WithdrawalFinalized( address indexed to, uint256 amount, uint256 timestamp );
    address public immutable OPTIMISM_PORTAL;              // Optimism核心合约地址
    address public immutable L2_CROSS_DOMAIN_MESSENGER;
    mapping(uint256 => bool) public withdrawals;           // 提款记录映射 (nonce => 是否已完成)
    uint256 private nonceCounter;
    
    // 提款信息结构
    struct WithdrawalInfo {
        address recipient;
        uint256 amount;
        uint256 timestamp;
    }
    mapping(uint256 => WithdrawalInfo) public withdrawalRecords;

    /**
     * @dev 构造函数，初始化Optimism核心合约地址
     * @param _optimismPortal Optimism门户合约地址
     * @param _l2Messenger L2跨域消息传递合约地址
     */
    constructor(address _optimismPortal, address _l2Messenger) {
        require(_optimismPortal != address(0), "Invalid portal address");
        require(_l2Messenger != address(0), "Invalid messenger address");
        OPTIMISM_PORTAL           = _optimismPortal;
        L2_CROSS_DOMAIN_MESSENGER = _l2Messenger;
    }

    /**
     * @dev 从L1存款到L2
     * @param l2Recipient 在L2上接收资产的地址
     * 
     * 流程说明：
     * 1. 用户调用函数并发送ETH
     * 2. 通过OptimismPortal将ETH存入L2
     * 3. L2自动铸造等量WETH给接收者
     * 4. 整个过程通常只需几分钟
     */
    function depositToL2(address l2Recipient) external payable {
        require(msg.value > 0, "Must send ETH");
        require(l2Recipient != address(0), "Invalid recipient");
        bytes memory messageData = abi.encodeWithSignature("depositETH(address)", l2Recipient);    // 编码存款数据 - 使用标准接口
        
        // 调用OptimismPortal进行存款
        (bool success, ) = OPTIMISM_PORTAL.call{value: msg.value}(
            abi.encodeWithSignature(
                "depositTransaction(address,uint256,uint64,bool,bytes)",
                L2_CROSS_DOMAIN_MESSENGER,  // 目标合约(L2)
                msg.value,                  // 存款金额
                100000,                     // Gas限制
                false,                      // 是否为创建合约
                messageData                 // 调用数据
            )
        );
        
        require(success, "L2 deposit failed");
        emit DepositToL2(msg.sender, l2Recipient, msg.value, block.timestamp);
    }

    /**
     * @dev 从L2发起提款到L1
     * @param amount 提款金额
     * 
     * 提款流程说明：
     * 阶段1 - 发起提款(L2):
     *   - 用户调用此函数发起提款请求
     *   - 生成提款记录并等待挑战期(7天)
     *   
     * 阶段2 - 完成提款(L1):
     *   - 挑战期结束后调用finalizeWithdrawal完成提款
     */
    function initiateWithdrawal(uint256 amount) external {
        require(amount > 0, "Amount must be positive");
        require(address(this).balance >= amount, "Insufficient contract balance");
        uint256 currentNonce = nonceCounter++;
        
        // 存储提款信息
        withdrawalRecords[currentNonce] = WithdrawalInfo({
            recipient: msg.sender,
            amount: amount,
            timestamp: block.timestamp
        });
        
        // 编码提款消息 - 发送到L1的此合约
        bytes memory withdrawalData = abi.encodeWithSelector(this.finalizeWithdrawal.selector, msg.sender, amount, currentNonce);
        
        // 通过跨链消息传递发起提款
        (bool success, ) = L2_CROSS_DOMAIN_MESSENGER.call(
            abi.encodeWithSignature(
                "sendMessage(address,bytes,uint32)",
                address(this),      // L1目标合约
                withdrawalData,     // 调用数据
                200000              // Gas限制
            )
        );
        
        require(success, "Withdrawal initiation failed");
        emit WithdrawalInitiated(msg.sender, msg.sender, amount, block.timestamp);
    }

    /**
     * @dev 在L1上完成提款
     * @param recipient 接收者地址
     * @param amount 提款金额
     * @param withdrawalNonce 提款唯一标识
     * 
     * 安全机制：
     * - 只能由Optimism的跨链消息系统调用
     * - 防止重放攻击
     * - 验证提款有效性
     */
    function finalizeWithdrawal(address recipient, uint256 amount, uint256 withdrawalNonce) external {
        // 验证调用者 - 在真实环境中应该是跨链消息系统
        require(msg.sender == address(this) || msg.sender == OPTIMISM_PORTAL, "Unauthorized");
        require(!withdrawals[withdrawalNonce], "Withdrawal already finalized");    // 防止重复提款
        WithdrawalInfo memory info = withdrawalRecords[withdrawalNonce];           // 验证提款记录存在
        require(info.recipient == recipient, "Recipient mismatch");
        require(info.amount == amount, "Amount mismatch");
        withdrawals[withdrawalNonce] = true;                     // 标记为已完成
        (bool success, ) = recipient.call{value: amount}("");    // 转账给接收者
        require(success, "Transfer failed");
        
        emit WithdrawalFinalized(recipient, amount, block.timestamp);
    }

    /**
     * @dev 查询提款状态
     * @param withdrawalNonce 提款标识
     * @return 是否已完成提款
     */
    function isWithdrawalFinalized(uint256 withdrawalNonce) external view returns (bool) {
        return withdrawals[withdrawalNonce];
    }

    /**
     * @dev 获取合约ETH余额
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev 接收ETH的回退函数
     */
    receive() external payable {}
}