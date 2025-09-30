// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ContractB {
    // 必须与 ContractA 完全相同的存储布局
    uint256 public value;          // 槽位0
    address public owner;          // 槽位1
    bool private initialized;      // 槽位2
    
    // 只能在末尾添加新变量
    uint256 public newFeature;     // 槽位3
    string public description;     // 槽位4
    
    event ValueChanged(uint256 newValue);
    event OwnershipTransferred(address previousOwner, address newOwner);
    event NewFeatureSet(uint256 feature);
    event DescriptionUpdated(string description);
    
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
        description = "Initial Description";
    }
    
    function setValue(uint256 _value) public onlyOwner {
        value = _value;
        emit ValueChanged(_value);
    }
    
    function getValue() public view returns (uint256) {
        return value;
    }
    
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    // 新增功能
    function setNewFeature(uint256 _feature) public onlyOwner {
        newFeature = _feature;
        emit NewFeatureSet(_feature);
    }
    
    function getNewFeature() public view returns (uint256) {
        return newFeature;
    }
    
    function setDescription(string memory _description) public onlyOwner {
        description = _description;
        emit DescriptionUpdated(_description);
    }
    
    function getDescription() public view returns (string memory) {
        return description;
    }
    
    function getOwner() external view returns(address) {
        return owner;
    }
    
    function version() public pure returns (string memory) {
        return "V2.0";
    }
}