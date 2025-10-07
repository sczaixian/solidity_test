// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title 基于时间窗口的动态铸造合约
 * @dev 提供基于24小时时间窗口的铸造限制，支持多铸币者管理
 */
contract DynamicMinter {
    // 所有者地址
    address public owner;
    
    // 铸币者映射
    mapping(address => bool) private _minters;
    
    // 每日铸造限制
    uint256 public dailyMintLimit;
    
    // 当前周期已铸造数量
    uint256 public currentPeriodMinted;
    
    // 当前周期开始时间戳
    uint256 public periodStartTime;
    
    // 周期长度（24小时）
    uint256 public constant PERIOD_LENGTH = 24 hours;
    
    // 事件定义
    event Mint(address indexed to, uint256 amount, uint256 timestamp);
    event MinterUpdated(address indexed account, bool status);
    event DailyLimitUpdated(uint256 newLimit);
    event PeriodReset(uint256 newStartTime);
    
    // 修饰器：仅所有者可调用
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    // 修饰器：仅铸币者可调用
    modifier onlyMinter() {
        require(_minters[msg.sender], "Caller is not a minter");
        _;
    }
    
    /**
     * @dev 构造函数
     * @param _dailyMintLimit 每日铸造限制
     */
    constructor(uint256 _dailyMintLimit) {
        owner = msg.sender;
        dailyMintLimit = _dailyMintLimit;
        periodStartTime = block.timestamp;
        currentPeriodMinted = 0;
        
        // 默认将部署者设为铸币者
        _minters[msg.sender] = true;
    }
    
    /**
     * @dev 内部函数：检查并重置时间周期
     * @notice 如果当前时间超过周期结束时间，重置计数器
     */
    function _checkAndResetPeriod() internal {
        // 计算当前周期结束时间
        uint256 periodEndTime = periodStartTime + PERIOD_LENGTH;
        
        // 如果当前时间超过周期结束时间，重置周期
        if (block.timestamp >= periodEndTime) {
            currentPeriodMinted = 0;
            periodStartTime = block.timestamp;
            emit PeriodReset(periodStartTime);
        }
    }
    
    /**
     * @dev 铸造代币
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external onlyMinter {
        // 检查并重置时间周期
        _checkAndResetPeriod();
        
        // 验证铸造数量不为0
        require(amount > 0, "Mint amount must be greater than 0");
        
        // 验证接收地址有效
        require(to != address(0), "Cannot mint to zero address");
        
        // 检查是否超过当日限制
        require(currentPeriodMinted + amount <= dailyMintLimit, "Exceeds daily mint limit");
        
        // 更新已铸造数量
        currentPeriodMinted += amount;
        
        // 执行铸造逻辑（这里需要根据实际代币合约实现）
        _mint(to, amount);
        
        emit Mint(to, amount, block.timestamp);
    }
    
    /**
     * @dev 设置铸币者权限
     * @param account 账户地址
     * @param status 权限状态
     */
    function setMinter(address account, bool status) external onlyOwner {
        require(account != address(0), "Invalid address");
        _minters[account] = status;
        emit MinterUpdated(account, status);
    }
    
    /**
     * @dev 更新每日铸造限制
     * @param newLimit 新的每日限制
     */
    function setDailyMintLimit(uint256 newLimit) external onlyOwner {
        require(newLimit > 0, "Limit must be greater than 0");
        dailyMintLimit = newLimit;
        emit DailyLimitUpdated(newLimit);
    }
    
    /**
     * @dev 手动重置时间周期（紧急情况下使用）
     */
    function resetPeriod() external onlyOwner {
        currentPeriodMinted = 0;
        periodStartTime = block.timestamp;
        emit PeriodReset(periodStartTime);
    }
    
    /**
     * @dev 查询剩余可铸造数量
     * @return 剩余数量
     */
    function remainingMintAmount() external view returns (uint256) {
        uint256 periodEndTime = periodStartTime + PERIOD_LENGTH;
        
        // 如果当前时间超过周期，返回完整限额
        if (block.timestamp >= periodEndTime) {
            return dailyMintLimit;
        }
        
        // 否则返回剩余额度
        return dailyMintLimit - currentPeriodMinted;
    }
    
    /**
     * @dev 查询当前周期结束时间
     * @return 周期结束时间戳
     */
    function getPeriodEndTime() external view returns (uint256) {
        return periodStartTime + PERIOD_LENGTH;
    }
    
    /**
     * @dev 检查地址是否为铸币者
     * @param account 要检查的地址
     * @return 是否为铸币者
     */
    function isMinter(address account) external view returns (bool) {
        return _minters[account];
    }
    
    /**
     * @dev 内部铸造函数 - 需要根据具体代币标准实现
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function _mint(address to, uint256 amount) internal virtual {
        // 这里需要实现具体的代币铸造逻辑
        // 例如：ERC20 的 _mint 函数
        // 这是一个占位符实现
    }
    
    /**
     * @dev 转移合约所有权
     * @param newOwner 新的所有者地址
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        owner = newOwner;
    }
}



/*
# 运行所有测试
npx hardhat test

# 运行特定测试文件
npx hardhat test test/DynamicMinter.js

# 带详细输出运行测试
npx hardhat test --verbose

# 运行气体消耗报告
npx hardhat test --gas





# 安装覆盖率工具
npm install --save-dev solidity-coverage

# 在 hardhat.config.js 中添加：
require('solidity-coverage');

# 运行覆盖率测试
npx hardhat coverage
*/