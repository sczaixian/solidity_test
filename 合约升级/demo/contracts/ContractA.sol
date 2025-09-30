// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ContractA {
    // 存储布局必须与代理合约不冲突
    // 这些变量将使用从槽位0开始的存储
    uint256 public value;          // 槽位0
    address public owner;          // 槽位1  
    bool private initialized;      // 槽位2
    
    event ValueChanged(uint256 newValue);
    event OwnershipTransferred(address previousOwner, address newOwner);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier initializer() {
        require(!initialized, "Already initialized");
        initialized = true;
        _;
    }
    
    function initialize() public initializer {
        owner = msg.sender;
    }
    
    function setValue(uint256 _value) public onlyOwner {
        value = _value;
        emit ValueChanged(_value);
    }
    
    function getValue() public view returns (uint256) {
        return value;
    }

    function getOwner() external view returns(address) {
        return owner;
    }
    
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    function version() public pure returns (string memory) {
        return "V1.0";
    }
}