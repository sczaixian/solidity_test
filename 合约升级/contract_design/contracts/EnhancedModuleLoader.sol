// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
    热加载：   在系统运行时动态替换模块实现，无需停机
    冷却机制： 防止频繁升级，确保系统稳定性
    版本控制： 通过时间戳和校验和跟踪模块变更
*/

// 增强版模块热加载系统 支持权限控制、安全检查和完整版本管理的模块加载系统
contract EnhancedModuleLoader {
    
    // 模块信息结构体
    struct Module {
        address implementation;  // 当前实现地址
        uint256 updatedAt;       // 最后更新时间戳
        bytes32 checksum;        // 代码校验和
        string  version;         // 版本号
        bool    isActive;        // 模块激活状态
    }
    
    mapping(string => Module) public modules;  // 模块名称到模块信息的映射
    address public admin;            // 管理员地址
    uint256 public cooldownPeriod;   // 冷却时间（秒）
    
    // 事件定义
    event ModuleUpgraded(string indexed name, address oldImplementation, address newImplementation, string version, uint256 timestamp);
    event ModuleRegistered(string indexed name, address implementation, string version, uint256 timestamp);
    event AdminChanged(address oldAdmin, address newAdmin);
    
    // 权限修饰符
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier moduleExists(string memory name) {
        require(modules[name].implementation != address(0), "Module does not exist");
        _;
    }
    
    /**
     * @dev 构造函数，设置管理员和冷却时间
     * @param _admin 管理员地址
     * @param _cooldownPeriod 冷却时间（秒）
     */
    constructor(address _admin, uint256 _cooldownPeriod) {
        require(_admin != address(0), "Invalid admin address");
        admin = _admin;
        cooldownPeriod = _cooldownPeriod;
    }
    
    /**
     * @dev 注册新模块
     * @param name 模块名称
     * @param implementation 实现地址
     * @param version 版本号
     * @param codeHash 合约代码哈希，用于验证完整性
     */
    function registerModule(string memory name, address implementation, string memory version, bytes32 codeHash) external onlyAdmin {
        require(modules[name].implementation == address(0), "Module already exists");
        require(implementation != address(0), "Invalid implementation address");
        require(bytes(name).length > 0, "Module name cannot be empty");
        
        // 验证目标地址是否为合约
        require(isContract(implementation), "Implementation must be a contract");
        
        // 验证代码哈希
        require(getCodeHash(implementation) == codeHash, "Code hash verification failed");
        
        modules[name] = Module({
            implementation: implementation,
            updatedAt:      block.timestamp,
            checksum:       codeHash,
            version:        version,
            isActive:       true
        });
        
        emit ModuleRegistered(name, implementation, version, block.timestamp);
    }
    
    /**
     * @dev 升级模块实现
     * @param name 模块名称
     * @param newImpl 新实现地址
     * @param version 新版本号
     * @param codeHash 新合约代码哈希
     */
    function upgradeModule(string memory name, address newImpl, string memory version, bytes32 codeHash) external onlyAdmin moduleExists(name) {
        Module storage mod = modules[name];
        
        // 检查冷却时间
        require(mod.updatedAt + cooldownPeriod < block.timestamp, "Cooldown period active");
        
        // 验证新实现地址
        require(newImpl != address(0), "Invalid implementation address");
        require(isContract(newImpl), "Implementation must be a contract");
        
        // 验证代码完整性
        require(getCodeHash(newImpl) == codeHash, "Code hash verification failed");
        
        address oldImplementation = mod.implementation;
        
        // 更新模块信息
        mod.implementation = newImpl;
        mod.updatedAt      = block.timestamp;
        mod.checksum       = codeHash;
        mod.version        = version;
        
        emit ModuleUpgraded(name, oldImplementation, newImpl, version, block.timestamp);
    }
    
    /**
     * @dev 暂停/恢复模块
     * @param name 模块名称
     * @param active 激活状态
     */
    function setModuleActive(string memory name, bool active) external onlyAdmin moduleExists(name) {
        modules[name].isActive = active;
    }
    
    /**
     * @dev 获取模块实现地址
     * @param name 模块名称
     * @return 实现地址
     */
    function getModuleImplementation(string memory name) external view moduleExists(name) returns (address) {
        return modules[name].implementation;
    }
    
    /**
     * @dev 获取模块详细信息
     * @param name 模块名称
     */
    function getModuleInfo(string memory name) external view moduleExists(name)
        returns (address implementation, uint256 updatedAt, bytes32 checksum, string memory version, bool isActive)
    {
        Module storage mod = modules[name];
        return (mod.implementation, mod.updatedAt, mod.checksum, mod.version, mod.isActive);
    }
    
    /**
     * @dev 转移管理员权限
     * @param newAdmin 新管理员地址
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid admin address");
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminChanged(oldAdmin, newAdmin);
    }
    
    /**
     * @dev 更新冷却时间
     * @param newCooldownPeriod 新的冷却时间（秒）
     */
    function updateCooldownPeriod(uint256 newCooldownPeriod) external onlyAdmin {
        cooldownPeriod = newCooldownPeriod;
    }
    
    /**
     * @dev 检查地址是否为合约
     * @param addr 要检查的地址
     * @return 是否为合约
     */
    function isContract(address addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(addr)
        }
        return (size > 0);
    }
    
    /**
     * @dev 获取合约代码哈希
     * @param addr 合约地址
     * @return 代码哈希
     */
    function getCodeHash(address addr) internal view returns (bytes32) {
        return keccak256(getCode(addr));
    }
    
    /**
     * @dev 获取合约字节码
     * @param addr 合约地址
     * @return 字节码
     */
    function getCode(address addr) internal view returns (bytes memory) {
        bytes memory code;
        assembly {
            // 获取代码大小
            let size := extcodesize(addr)
            // 分配内存
            code := mload(0x40)
            // 更新空闲内存指针
            mstore(0x40, add(code, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            // 存储长度
            mstore(code, size)
            // 复制代码
            extcodecopy(addr, add(code, 0x20), 0, size)
        }
        return code;
    }
    
    /**
     * @dev 计算剩余冷却时间
     * @param name 模块名称
     * @return 剩余冷却时间（秒），0表示可立即升级
     */
    function getRemainingCooldown(string memory name) external view moduleExists(name) returns (uint256) {
        Module storage mod = modules[name];
        if (block.timestamp >= mod.updatedAt + cooldownPeriod) {
            return 0;
        }
        return (mod.updatedAt + cooldownPeriod) - block.timestamp;
    }
}