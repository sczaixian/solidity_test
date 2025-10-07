// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


/*
Diamond 合约，它使用 Fallback 函数和 delegatecall 来将函数调用委托给不同的功能插件（Facet）。
每个 Facet 是一个独立的合约，包含一些相关的函数。Diamond 合约中有一个映射 selectorToFacet，将函数选择器映射到对应的 Facet 地址。
当调用 Diamond 合约中未直接定义的函数时，Fallback 函数会被触发，它通过 msg.sig（即函数选择器）查找对应的 Facet 地址，然后使用 delegatecall 来执行该 Facet 中的函数。

Diamond 模式是一种可升级的智能合约架构，通过代理合约将函数调用委托给不同的功能模块（Facets）。
核心优势：
模块化：    不同功能分离到不同合约
可升级：    可单独升级某个功能模块
无存储冲突： 统一的存储布局避免冲突
Gas 优化：  只部署需要的功能
*/

/**
Diamond 核心合约  作为代理层，将所有函数调用委托给相应的功能模块
 存储布局统一性
所有 Facet 使用相同的 AppStorage 结构体和相同的存储位置，这确保了：
所有模块访问的是同一份数据
避免存储槽冲突
支持模块间的数据共享
 */

contract Diamond {
    // 存储所有者地址
    address public owner;
    
    // 存储布局结构体 - 这是 Diamond 模式的关键
    // 所有 Facet 都使用相同的存储布局，避免存储冲突
    struct AppStorage {
        // ERC20 相关存储
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        uint256 totalSupply;
        string  name;
        string  symbol;
        uint8   decimals;
        
        // 其他业务逻辑存储...
        mapping(bytes32 => bool) flags;
        uint256 someValue;
    }
    
    // 固定存储位置 - 所有 Facet 都从这里读取/写入数据
    bytes32 constant APP_STORAGE_POSITION = keccak256("diamond.storage");
    
    // 函数选择器到 Facet 地址的映射
    mapping(bytes4 => address) public selectorToFacet;
    
    // 事件
    event FunctionAdded(bytes4 indexed selector, address indexed facetAddress);
    event FunctionRemoved(bytes4 indexed selector);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Diamond: caller is not owner");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    // 获取应用存储的引用
    function appStorage() internal pure returns (AppStorage storage storageStruct) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            storageStruct.slot := position
        }
    }
    
    // 添加或替换函数实现    _facetAddress Facet 合约地址     _functionSelectors 函数选择器数组
    function addFunctions(address _facetAddress, bytes4[] calldata _functionSelectors) external onlyOwner {
        require(_facetAddress != address(0), "Diamond: facet address is zero");
        
        for (uint256 i = 0; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            selectorToFacet[selector] = _facetAddress;
            emit FunctionAdded(selector, _facetAddress);
        }
    }
    
    /**
     * @dev 移除函数
     * @param _functionSelectors 要移除的函数选择器数组
     */
    function removeFunctions(bytes4[] calldata _functionSelectors) external onlyOwner {
        for (uint256 i = 0; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            require(selectorToFacet[selector] != address(0), "Diamond: function does not exist");
            delete selectorToFacet[selector];
            emit FunctionRemoved(selector);
        }
    }
    
    /**
     * @dev 转移合约所有权
     * @param newOwner 新的所有者地址
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Diamond: new owner is zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    /**
     * @dev Fallback 函数 - Diamond 模式的核心
     * 当调用不存在的函数时，会执行此函数
     * 通过 delegatecall 将调用委托给相应的 Facet
     */
    fallback() external payable {
        // 获取函数选择器对应的 Facet 地址
        address facet = selectorToFacet[msg.sig];
        require(facet != address(0), "Diamond: Function does not exist");
        
        // 使用内联汇编进行 delegatecall
        assembly {
            // 将调用数据复制到内存中（从位置0开始）
            // calldatacopy(目标内存位置, 源calldata位置, 大小)
            calldatacopy(0, 0, calldatasize())
            
            // 执行 delegatecall
            // delegatecall( gas限制, 目标地址, 输入内存位置, 输入大小, 输出内存位置, 输出大小)
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            
            // 将返回数据复制到内存中
            returndatacopy(0, 0, returndatasize())
            
            // 处理调用结果
            switch result
            case 0 {
                // 如果调用失败，回滚
                revert(0, returndatasize())
            }
            default {
                // 如果调用成功，返回数据
                return(0, returndatasize())
            }
        }
    }
    
    // 接收以太币的函数
    receive() external payable {}
}

/**
 * @title ERC20 功能模块
 * @dev 实现 ERC20 标准的功能
 */
contract ERC20Facet {
    // 使用与 Diamond 合约相同的存储位置
    bytes32 constant APP_STORAGE_POSITION = keccak256("diamond.storage");
    
    struct AppStorage {
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        uint256 totalSupply;
        string name;
        string symbol;
        uint8 decimals;
        mapping(bytes32 => bool) flags;
        uint256 someValue;
    }
    
    function appStorage() internal pure returns (AppStorage storage storageStruct) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            storageStruct.slot := position
        }
    }
    
    // 事件
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    /**
     * @dev 查询余额
     */
    function balanceOf(address account) external view returns (uint256) {
        return appStorage().balances[account];
    }
    
    // 查询总供应量
    function totalSupply() external view returns (uint256) {
        return appStorage().totalSupply;
    }
    
    // 转账
    function transfer(address to, uint256 amount) external returns (bool) {
        AppStorage storage s = appStorage();
        require(s.balances[msg.sender] >= amount, "ERC20: insufficient balance");
        
        s.balances[msg.sender] -= amount;
        s.balances[to] += amount;
        
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    // 授权
    function approve(address spender, uint256 amount) external returns (bool) {
        appStorage().allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    // 查询授权额度
    function allowance(address owner, address spender) external view returns (uint256) {
        return appStorage().allowances[owner][spender];
    }
}

// 元数据功能模块  处理代币名称、符号等元数据
contract MetadataFacet {
    bytes32 constant APP_STORAGE_POSITION = keccak256("diamond.storage");
    
    struct AppStorage {
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        uint256 totalSupply;
        string name;
        string symbol;
        uint8 decimals;
        mapping(bytes32 => bool) flags;
        uint256 someValue;
    }
    
    function appStorage() internal pure returns (AppStorage storage storageStruct) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            storageStruct.slot := position
        }
    }
    
    function name() external view returns (string memory) {
        return appStorage().name;
    }
    
    function symbol() external view returns (string memory) {
        return appStorage().symbol;
    }
    
    function decimals() external view returns (uint8) {
        return appStorage().decimals;
    }
    
    // 初始化代币元数据（只能调用一次）
    function initializeToken(string calldata _name, string calldata _symbol, uint8 _decimals) external {
        AppStorage storage s = appStorage();
        // 简单的保护机制，确保只初始化一次
        require(bytes(s.name).length == 0, "Already initialized");
        
        s.name = _name;
        s.symbol = _symbol;
        s.decimals = _decimals;
        s.totalSupply = 1000000 * 10**_decimals; // 示例初始供应量
        s.balances[msg.sender] = s.totalSupply;
    }
}

// 部署和设置脚本 演示如何部署和设置 Diamond 合约
contract DiamondSetup {
    // 部署并配置完整的 Diamond 系统
    function deployDiamond() external returns (address diamondAddress) {
        // 1. 部署 Diamond 核心合约
        Diamond diamond = new Diamond();
        diamondAddress = address(diamond);
        
        // 2. 部署各个功能模块
        ERC20Facet erc20Facet = new ERC20Facet();
        MetadataFacet metadataFacet = new MetadataFacet();
        
        // 3. 为 Diamond 添加 ERC20 功能
        bytes4[] memory erc20Selectors = new bytes4[](5);
        erc20Selectors[0] = ERC20Facet.balanceOf.selector;
        erc20Selectors[1] = ERC20Facet.totalSupply.selector;
        erc20Selectors[2] = ERC20Facet.transfer.selector;
        erc20Selectors[3] = ERC20Facet.approve.selector;
        erc20Selectors[4] = ERC20Facet.allowance.selector;
        
        diamond.addFunctions(address(erc20Facet), erc20Selectors);
        
        // 4. 为 Diamond 添加元数据功能
        bytes4[] memory metadataSelectors = new bytes4[](4);
        metadataSelectors[0] = MetadataFacet.name.selector;
        metadataSelectors[1] = MetadataFacet.symbol.selector;
        metadataSelectors[2] = MetadataFacet.decimals.selector;
        metadataSelectors[3] = MetadataFacet.initializeToken.selector;
        
        diamond.addFunctions(address(metadataFacet), metadataSelectors);
        
        // 5. 初始化代币
        MetadataFacet(diamondAddress).initializeToken("Diamond Token", "DMD", 18);
    }
}