// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MyContractV1 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public value;
    string public text;
    uint256 public timestamp;
    
    // 映射和数组用于测试存储布局兼容性
    mapping(address => uint256) public balances;
    address[] public users;
    
    // 事件
    event ValueUpdated(uint256 newValue);
    event TextUpdated(string newText);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        
        value = 100;
        text = "Hello V1";
        timestamp = block.timestamp;
    }
    
    // UUPS 升级授权函数
    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyOwner 
    {}
    
    // V1 功能函数
    function setValue(uint256 _value) external {
        value = _value;
        emit ValueUpdated(_value);
    }
    
    function setText(string memory _text) external {
        text = _text;
        emit TextUpdated(_text);
    }
    
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        _addUser(msg.sender);
    }
    
    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }
    
    function getUserCount() external view returns (uint256) {
        return users.length;
    }
    
    function _addUser(address user) internal {
        for (uint i = 0; i < users.length; i++) {
            if (users[i] == user) {
                return;
            }
        }
        users.push(user);
    }
    
    // 获取版本信息
    function version() virtual external pure returns (string memory) {
        return "v1.0.0";
    }
}