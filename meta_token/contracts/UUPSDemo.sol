// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title UUPS 逻辑合约
 * @dev 包含升级逻辑的实现合约
 * 
 * 安全考量：
 * 1. 升级逻辑在实现合约中，减少代理合约攻击面
 * 2. 权限控制：只有授权地址可以升级
 * 3. 升级前验证新实现是否有效
 * 4. 防止存储布局冲突
 */
contract UUPSLogic is UUPSUpgradeable, Ownable2StepUpgradeable {
    // 状态变量声明，注意与之前版本的兼容性
    uint256 public value;
    address public lastUpdater;
    
    // 添加存储间隙以备未来升级
    uint256[50] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers(); // 禁止外部初始化
    }

    /**
     * @dev 初始化函数，替代构造函数
     * @param initialValue 初始值
     */
    function initialize(uint256 initialValue) public initializer {
        __Ownable2Step_init();
        __UUPSUpgradeable_init();
        value = initialValue;
        lastUpdater = msg.sender;
    }

    /**
     * @dev 更新值的方法
     * @param newValue 新值
     */
    function updateValue(uint256 newValue) public {
        value = newValue;
        lastUpdater = msg.sender;
    }

    /**
     * @dev 内部升级授权检查
     * @param newImplementation 新实现地址
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        // 可添加额外的验证逻辑
        require(newImplementation != address(0), "UUPSLogic: invalid implementation");
        require(Address.isContract(newImplementation), "UUPSLogic: new implementation is not a contract");
        
        // 在实际生产中，这里可以添加更多验证，如：
        // - 检查新实现是否支持必要的接口
        // - 验证新实现的字节码哈希是否在允许列表中
        // - 确保新实现通过了安全审计
    }

    /**
     * @dev 获取当前实现版本
     */
    function getVersion() public pure virtual returns (string memory) {
        return "v1.0.0";
    }
    
    /**
     * @dev 获取代理的UUID，用于兼容性检查
     */
    function proxiableUUID() external view virtual override returns (bytes32) {
        return keccak256("PROXIABLE");
    }
}

/**
 * @title UUPS 代理合约
 * @dev 轻量级代理合约，升级逻辑在实现合约中
 */
contract UUPSProxy is ERC1967Proxy {
    /**
     * @dev 初始化代理合约
     * @param _logic 逻辑合约地址
     * @param _data 初始化数据
     */
    constructor(address _logic, bytes memory _data) payable ERC1967Proxy(_logic, _data) {}
    
    /**
     * @dev 获取当前实现地址
     */
    function implementation() public view returns (address) {
        return _implementation();
    }
}

/**
 * @title UUPSLogicV2
 * @dev 升级版逻辑合约，演示如何添加新功能而不破坏存储布局
 */
contract UUPSLogicV2 is UUPSLogic {
    // 新状态变量应该添加在原有变量之后
    uint256 public newFeatureData;
    
    // 添加存储间隙以备未来升级
    uint256[49] private __gapV2;
    
    /**
     * @dev 新功能方法
     */
    function newFeature(uint256 _data) public {
        newFeatureData = _data;
    }
    
    /**
     * @dev 重写版本方法以返回新版本号
     */
    function getVersion() public pure override returns (string memory) {
        return "v2.0.0";
    }
}