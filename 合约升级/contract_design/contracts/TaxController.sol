
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


// 分级税率控制器 根据交易金额的不同区间应用不同的税率
contract TaxController {
    // 税率级别结构体
    struct TaxTier {
        uint256 minAmount;     // 最小金额门槛
        uint256 feePercent;    // 税率百分比 (如5表示5%)
        string  description;   // 级别描述 
    }
    
    TaxTier[] public taxTiers;    // 税率级别数组，按minAmount升序排列
    address   public taxPool;     // 税收接收地址
    address   public owner;       // 合约所有者

    // 事件
    event TaxTierAdded(uint256 minAmount, uint256 feePercent, string description);
    event TaxTierUpdated(uint256 index, uint256 minAmount, uint256 feePercent, string description);
    event TaxTierRemoved(uint256 index);
    event TaxApplied(address indexed from, uint256 amount, uint256 taxAmount, uint256 tierIndex);
    
    // 修饰器：仅所有者可调用
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(address _taxPool) {
        owner   = msg.sender;
        taxPool = _taxPool;
        _initializeDefaultTiers();    // 初始化默认税率级别
    }

    /* 初始化默认税率级别
        0-1000: 1%
        1000-5000: 3% 
        5000-10000: 5%
        10000+: 8%
    */
    function _initializeDefaultTiers() internal {
        taxTiers.push(TaxTier(0, 1, "lv1: 0-1000"));
        taxTiers.push(TaxTier(1000, 3, "lv2: 1000-5000"));
        taxTiers.push(TaxTier(5000, 5, "lv3: 5000-10000"));
        taxTiers.push(TaxTier(10000, 8, "lv4: 10000+"));
    }

    /* 
        算税费 taxAmount 应缴税费  tierIndex 适用的税率级别索引
        1. 从最高级别开始检查（数组末尾）
        2. 找到第一个金额满足 minAmount 的级别
        3. 按该级别的费率计算税费
    */
    function calculateTax(uint256 amount) public view returns(uint256 taxAmount, uint256 tierIndex) {
        require(amount > 0, "Amount must be greater than 0");
        // 从最高级别开始向下检查
        for(uint256 i = taxTiers.length; i > 0; i--) {
            uint256 currentIndex = i - 1;
            if(amount >= taxTiers[currentIndex].minAmount) {
                // 计算税费：金额 × 费率百分比 ÷ 100
                taxAmount = amount * taxTiers[currentIndex].feePercent / 100;
                return (taxAmount, currentIndex);
            }
        }
        // 如果没有匹配的级别，返回0税费
        return (0, 0);
    }

    // 应用税费（模拟转账）netAmount 净金额（扣除税费后） taxAmount 税费金额
    function applyTax(address from, uint256 amount) external returns (uint256 netAmount, uint256 taxAmount) {
        require(from != address(0), "Invalid from address");
        require(amount > 0, "Amount must be greater than 0");

        uint256 tierIndex;
        (taxAmount, tierIndex) = calculateTax(amount);  // 计算税费
        netAmount = amount - taxAmount;                 // 计算净金额
        require(netAmount >= 0, "Net amount cannot be negative");  // 确保扣除税费后金额不为负
        
        if(taxAmount > 0) {
            // 在实际应用中，这里会调用代币转账
            // _transfer(from, taxPool, taxAmount);
            
            // 触发事件记录税费应用
            emit TaxApplied(from, amount, taxAmount, tierIndex);
        }
        
        return (netAmount, taxAmount);
    }

    // 添加新的税率级别
    function addTaxTier(uint256 minAmount, uint256 feePercent, string memory description) external onlyOwner {
        require(feePercent <= 100, "Fee percent cannot exceed 100");
        // 确保minAmount是递增的（简化验证）
        if(taxTiers.length > 0) {
            require(minAmount > taxTiers[taxTiers.length - 1].minAmount, "Min amount must be greater than previous tier");
        }

        taxTiers.push(TaxTier(minAmount, feePercent, description));
        emit TaxTierAdded(minAmount, feePercent, description);
    }

    // 更新税率级别
    function updateTaxTier(uint256 index, uint256 minAmount, uint256 feePercent, string memory description) external onlyOwner {
        require(index < taxTiers.length, "Invalid tier index");
        require(feePercent <= 100, "Fee percent cannot exceed 100");
        
        taxTiers[index] = TaxTier(minAmount, feePercent, description);
        emit TaxTierUpdated(index, minAmount, feePercent, description);
    }

    // 移除税率级别
    function removeTaxTier(uint256 index) external onlyOwner {
        require(index < taxTiers.length, "Invalid tier index");
        require(taxTiers.length > 1, "Cannot remove the last tax tier");
        // 将最后一个元素移动到要删除的位置，然后pop
        if (index != taxTiers.length - 1) {
            taxTiers[index] = taxTiers[taxTiers.length - 1];
        }
        taxTiers.pop();
        
        emit TaxTierRemoved(index);
    }

    // 获取所有税率级别
    function getAllTaxTiers() external view returns (TaxTier[] memory) {
        return taxTiers;
    }

    // 获取税率级别数量
    function getTaxTierCount() external view returns (uint256) {
        return taxTiers.length;
    }

    // 设置税收接收地址
    function setTaxPool(address newTaxPool) external onlyOwner {
        require(newTaxPool != address(0), "Invalid tax pool address");
        taxPool = newTaxPool;
    }

    // 模拟代币转账
    function _transfer(address from, address to, uint256 amount) internal pure {
        // 这里应该调用代币合约的transfer函数
        // 例如：IERC20(tokenAddress).transferFrom(from, to, amount);
        // 当前为模拟实现
        require(from != address(0) && to != address(0), "Invalid addresses");
        require(amount > 0, "Transfer amount must be positive");
    }
}

/*
假设税率级别：0-100(1%), 100-500(3%), 500+(5%)
金额600元，应该匹配500+的5%税率
从后往前找，先找到500+级别，立即返回，效率高


TaxControllerTest.sol

*/