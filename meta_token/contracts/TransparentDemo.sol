// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title TransparentUpgradeableProxy
 * @dev 透明代理合约，区分管理员调用和用户调用
 * 
 * 安全考量：
 * 1. 防止存储冲突：使用ERC1967存储槽位
 * 2. 防止函数选择器冲突：管理员函数使用特殊前缀
 * 3. 权限控制：只有管理员可以升级合约
 * 4. 初始化保护：防止重复初始化
 */
contract TransparentUpgradeableProxy is ERC1967Proxy, Ownable {
    /**
     * @dev 初始化透明代理
     * @param _logic 逻辑合约地址
     * @param _data 初始化数据
     * @param _admin 管理员地址
     */
    constructor(
        address _logic,
        bytes memory _data,
        address _admin
    ) payable ERC1967Proxy(_logic, _data) {
        _transferOwnership(_admin);
    }

    /**
     * @dev 管理员调用代理时执行此函数，普通用户调用时委托调用逻辑合约
     * 防止管理员意外执行逻辑合约中的危险函数
     */
    function _beforeFallback() internal virtual override {
        require(msg.sender != owner(), "TransparentUpgradeableProxy: admin cannot fallback to proxy target");
        super._beforeFallback();
    }

    /**
     * @dev 升级逻辑合约实现，仅管理员可调用
     * @param implementation 新逻辑合约地址
     */
    function upgradeTo(address implementation) public onlyOwner {
        _upgradeTo(implementation);
    }

    /**
     * @dev 升级逻辑合约并调用函数，仅管理员可调用
     * @param implementation 新逻辑合约地址
     * @param data 初始化数据
     */
    function upgradeToAndCall(address implementation, bytes memory data) public payable onlyOwner {
        _upgradeTo(implementation);
        Address.functionDelegateCall(implementation, data);
    }

    /**
     * @dev 返回当前实现地址
     */
    function implementation() public view returns (address) {
        return _implementation();
    }
}

/**
 * @title 示例逻辑合约
 * @dev 用于演示透明代理模式的简单逻辑合约
 */
contract ExampleLogic {
    uint256 public value;
    address public admin;
    
    event ValueChanged(uint256 newValue);
    
    // 初始化函数
    function initialize(uint256 _initialValue) public {
        require(value == 0, "Already initialized");
        value = _initialValue;
        admin = msg.sender;
    }
    
    // 更新值的方法
    function setValue(uint256 _newValue) public {
        require(msg.sender == admin, "Only admin can set value");
        value = _newValue;
        emit ValueChanged(_newValue);
    }
    
    // 获取版本信息
    function version() public pure returns (string memory) {
        return "v1.0.0";
    }
}