// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./MyContractV1.sol";

contract MyContractV2 is MyContractV1 {
    // 新增状态变量 - 注意存储布局兼容性
    uint256 public multiplier;
    mapping(address => uint256) public rewards;
    
    // 新增事件
    event MultiplierUpdated(uint256 newMultiplier);
    event RewardAdded(address indexed user, uint256 amount);
    
    // 新增功能 - 需要重新初始化
    function initializeV2() public reinitializer(2) {
        multiplier = 2;
    }
    
    // V2 新增功能
    function setMultiplier(uint256 _multiplier) external onlyOwner {
        multiplier = _multiplier;
        emit MultiplierUpdated(_multiplier);
    }
    
    function getEnhancedValue() external view returns (uint256) {
        return value * multiplier;
    }
    
    function addReward(address user, uint256 amount) external onlyOwner {
        rewards[user] += amount;
        emit RewardAdded(user, amount);
    }
    
    function getUserTotal(address user) external view returns (uint256) {
        return balances[user] + rewards[user];
    }
    
    // 重写版本函数
    function version() external pure override returns (string memory) {
        return "v2.0.0";
    }
    
    // 新增批量操作功能
    function batchUpdateValues(uint256 _value, string memory _text) external {
        value = _value;
        text = _text;
        emit ValueUpdated(_value);
        emit TextUpdated(_text);
    }
}