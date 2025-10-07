// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title 可配置资金分配器
 * @dev 用于将资金按照预设比例分配给多个接收方
 */
contract FundDistributor {
    // 分配结构体：定义接收方和分配百分比
    struct Allocation {
        address receiver;    // 接收方地址
        uint16 percentage;   // 分配百分比（0-10000，支持两位小数）
    }
    
    // 公共变量
    Allocation[] public allocations;     // 分配方案数组
    address public defaultReceiver;      // 默认接收方（用于处理剩余资金）
    address public owner;                // 合约所有者
    
    // 事件定义
    event FundsDistributed(address indexed from, uint256 totalAmount, uint256 timestamp);
    event AllocationAdded(address indexed receiver, uint16 percentage);
    event AllocationRemoved(uint256 index);
    
    // 修饰器：只有所有者可以调用
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor(address _defaultReceiver) {
        owner = msg.sender;
        defaultReceiver = _defaultReceiver;
    }
    
    /**
     * @dev 添加分配规则
     * @param _receiver 接收方地址
     * @param _percentage 分配百分比（基于10000，如1000表示10%）
     */
    function addAllocation(address _receiver, uint16 _percentage) external onlyOwner {
        require(_receiver != address(0), "Invalid receiver address");
        require(_percentage > 0 && _percentage <= 10000, "Percentage must be between 1 and 10000");
        
        allocations.push(
            Allocation({receiver: _receiver, percentage: _percentage})
        );
        
        emit AllocationAdded(_receiver, _percentage);
    }
    
    /**
     * @dev 移除分配规则
     * @param index 要移除的分配规则索引
     */
    function removeAllocation(uint256 index) external onlyOwner {
        require(index < allocations.length, "Index out of bounds");
        
        // 将最后一个元素移到要删除的位置，然后弹出
        allocations[index] = allocations[allocations.length - 1];
        allocations.pop();
        
        emit AllocationRemoved(index);
    }
    
    /**
     * @dev 获取总分配百分比
     * @return totalPercentage 总百分比
     */
    function getTotalPercentage() public view returns (uint256 totalPercentage) {
        for (uint i = 0; i < allocations.length; i++) {
            totalPercentage += allocations[i].percentage;
        }
        return totalPercentage;
    }
    
    /**
     * @dev 核心分配函数 - 将资金按比例分配
     * @param totalAmount 要分配的总金额
     */
    function _distributeFunds(uint256 totalAmount) internal {
        require(totalAmount > 0, "Amount must be greater than 0");
        require(allocations.length > 0, "No allocations configured");
        
        uint256 totalPercentage = getTotalPercentage();
        require(totalPercentage <= 10000, "Total percentage cannot exceed 100%");
        
        uint256 remainingAmount = totalAmount;
        uint256 distributedAmount = 0;
        
        // 遍历所有分配规则进行资金分配
        for (uint i = 0; i < allocations.length; i++) {
            Allocation memory allocation = allocations[i];
            
            // 计算当前接收方应得金额：总金额 × 百分比 ÷ 10000
            uint256 amount = (totalAmount * allocation.percentage) / 10000;
            
            // 确保不会因为整数除法而分配0金额
            if (amount > 0) {
                _transfer(allocation.receiver, amount);
                distributedAmount += amount;
                remainingAmount -= amount;
            }
        }
        
        // 处理剩余资金（由于整数除法可能产生）
        if (remainingAmount > 0) {
            _transfer(defaultReceiver, remainingAmount);
            distributedAmount += remainingAmount;
        }
        
        // 验证分配总额正确
        require(distributedAmount == totalAmount, "Distribution amount mismatch");
        
        emit FundsDistributed(msg.sender, totalAmount, block.timestamp);
    }
    
    /**
     * @dev 内部转账函数（需要根据具体代币实现）
     * @param to 接收方地址
     * @param amount 转账金额
     */
    function _transfer(address to, uint256 amount) internal virtual {
        // 这里需要根据具体情况实现：
        // 1. 如果是ETH转账：payable(to).transfer(amount);
        // 2. 如果是ERC20代币：IERC20(tokenAddress).transfer(to, amount);
        // 3. 如果是合约本身的余额：需要实现相应的转账逻辑
        
        // 示例：ETH转账
        payable(to).transfer(amount);
    }
    
    /**
     * @dev 接收ETH的fallback函数
     */
    receive() external payable {
        // 当合约收到ETH时自动触发分配
        if (msg.value > 0 && allocations.length > 0) {
            _distributeFunds(msg.value);
        }
    }
    
    /**
     * @dev 手动触发资金分配
     * @param amount 分配金额
     */
    function distribute(uint256 amount) external {
        require(amount <= address(this).balance, "Insufficient balance");
        _distributeFunds(amount);
    }
    
    /**
     * @dev 获取分配规则数量
     * @return 分配规则总数
     */
    function getAllocationCount() external view returns (uint256) {
        return allocations.length;
    }
    
    /**
     * @dev 获取合约余额
     * @return 合约当前的ETH余额
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev 转移合约所有权
     * @param newOwner 新的所有者地址
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner address");
        owner = newOwner;
    }
}
/*
uint16  65535  int16 [-32768 32767]
使用 uint16 存储百分比，范围 0-10000
10000 = 100%，1000 = 10%，100 = 1%
支持两位小数精度（如 1250 = 12.50%）

税收分配：将交易税按比例分给国库、流动性池等
收入分成：平台收入分给多个参与者
捐赠分配：将捐款分给多个慈善机构
版税分配：将版税分给多个创作者
*/