// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library String{
    function toHexString(address account) internal pure returns(string memory){
        return toHexString(uint256(uint160(account)), 20);
    }
    function toHexString(uint256 value, uint256 length) internal pure returns(string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for(uint256 i = 2 * length + 1; i > 1; --i){
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "");
        return string(buffer);
    }
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
}

contract RBACManager{
    // 默认管理员角色-最高权限
    bytes32 public  constant DEFAULT_ADMIN_ROLE = 0x00;

    // 其他角色
    bytes32 public constant PROJECT_MANAGER_ROLE = keccak256("PROJECT_MANAGER_ROLE");
    bytes32 public constant DEVELOPER_ROLE = keccak256("DEVELOPER_ROLE");
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");


    struct RoleData{
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    // 分层权限校验
    modifier onlyRole(bytes32 role){
        _checkRole(role, msg.sender);
        _;
    }

    // 内部角色检查函数
    function _checkRole(bytes32 role, address account) internal view  virtual{
        if(!hasRole(role, account)){
            revert(
                string(abi.encodePacked("RBAC: account", String.toHexString(account), "is missing role", String.toHexString(uint256(role), 32)))
            );
        }
    }

    constructor(){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // 设置角色并授予地址
    function _setupRole(bytes32 role, address account) internal virtual{
        _grantRole(role, account);
        if(getRoleAdmin(role) == bytes32(0)){
            _setRoleAdmin(role, DEFAULT_ADMIN_ROLE);
        }
    }

    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual{
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    // 获取角色的管理员角色
    function getRoleAdmin(bytes32 role) public virtual returns(bytes32){
        return _roles[role].adminRole;
    }

    function hasRole(bytes32 role, address account) public view virtual returns(bool){
        return _roles[role].members[account];
    }

    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)){
        _grantRole(role, account);
    }

    function _grantRole(bytes32 role, address account) internal {
        if(!hasRole(role, account)){
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    // 放弃自己的某个角色
    function renounceRole(bytes32 role, address account) public virtual {
        require(account == msg.sender, "");
        _revokeRole(role, account);
    }

    // 撤销指定地址的角色
    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)){
        _revokeRole(role, account);
    }

    // 内部撤销角色实现
    function _revokeRole(bytes32 role, address account) internal virtual{
        if(hasRole(role, account)){
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    // 批量授予角色
    function batchGrantRole(bytes32 role, address[] memory accounts) public virtual onlyRole(getRoleAdmin(role)){
        for(uint256 i = 0; i < accounts.length; i++){
            _grantRole(role, accounts[i]);
        }
    }

    // 批量撤销角色
    function batchRevokeRole(bytes32 role, address[] memory accounts) public virtual onlyRole(getRoleAdmin(role)) {
        for(uint256 i = 0; i < accounts.length; i++){
            _revokeRole(role, accounts[i]);
        }
    }
}



/**
 * @title 项目管理系统 - 使用RBAC的示例
 */
contract ProjectManagement is RBACManager {
    
    struct Project {
        uint256 id;
        string name;
        address manager;
        uint256 budget;
        bool completed;
    }
    
    mapping(uint256 => Project) public projects;
    uint256 public projectCount;
    
    event ProjectCreated(uint256 indexed projectId, string name, address manager);
    event ProjectCompleted(uint256 indexed projectId);
    
    /**
     * @dev 创建新项目 - 仅项目经理以上权限
     */
    function createProject(string memory name, uint256 budget) 
        public onlyRole(PROJECT_MANAGER_ROLE) 
        returns (uint256) 
    {
        projectCount++;
        projects[projectCount] = Project({
            id: projectCount,
            name: name,
            manager: msg.sender,
            budget: budget,
            completed: false
        });
        
        emit ProjectCreated(projectCount, name, msg.sender);
        return projectCount;
    }
    
    /**
     * @dev 完成项目 - 仅项目管理员或更高级别
     */
    function completeProject(uint256 projectId) 
        public onlyRole(PROJECT_MANAGER_ROLE) 
    {
        require(projects[projectId].id != 0, "Project does not exist");
        require(!projects[projectId].completed, "Project already completed");
        require(
            projects[projectId].manager == msg.sender || 
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Only project manager or admin can complete"
        );
        
        projects[projectId].completed = true;
        emit ProjectCompleted(projectId);
    }
    
    /**
     * @dev 查看项目详情 - 开发者及以上权限
     */
    function getProject(uint256 projectId) 
        public view onlyRole(DEVELOPER_ROLE) 
        returns (Project memory) 
    {
        require(projects[projectId].id != 0, "Project does not exist");
        return projects[projectId];
    }
    
    /**
     * @dev 初始化角色层级
     */
    constructor() {
        // 设置角色继承关系
        _setRoleAdmin(USER_ROLE, DEVELOPER_ROLE);         // 开发者可以管理用户
        _setRoleAdmin(DEVELOPER_ROLE, PROJECT_MANAGER_ROLE); // 项目经理可以管理开发者
        _setRoleAdmin(PROJECT_MANAGER_ROLE, DEFAULT_ADMIN_ROLE); // 管理员可以管理项目经理
    }
}


// 角色层级：DEFAULT_ADMIN → PROJECT_MANAGER → DEVELOPER → USER
// 上层角色自动拥有下层角色的管理权限
// 用户调用函数 → 修饰器检查角色 → 内部_checkRole验证 → hasRole查询成员关系 → 通过/拒绝执行



contract OwnablePlus{
    address[] private _owners;
    mapping(address => bool) private _isOwner;
    uint256 public constant DELAY = 2 days;
    mapping(bytes32 => uint256) public schedule;

    event OwnerAdded(address indexed newOwner);
    event OwnerRemoved(address indexed removedOwner);
    event OperationScheduled(bytes32 indexed operationHash, uint256 scheduledTime);
    event OperationExecuted(bytes32 indexed operationHash);

    modifier onlyOwner{
        require(_isOwner[msg.sender], "OwnablePlus: caller is not an owner");
        _;
    }

    constructor(address [] memory initialOwners){
        require(initialOwners.length > 0, "OwnablePlus: at least one owner required");
        for(uint256 i = 0; i < initialOwners.length; i++){
            address owner = initialOwners[i];
            require(owner != address(0), "OwnablePlus: zero address cannot be owner");
            require(!_isOwner[owner], "OwnablePlus: duplicate owner");
            _isOwner[owner] = true;
            _owners.push(owner);
        }
    }

    // 添加新管理员（需要时间锁）
    function addOwner(address newOwner) external onlyOwner{
        require(newOwner != address(0), "OwnablePlus: new owner is zero address");
        require(!_isOwner[newOwner], "OwnablePlus: already an owner");
        bytes32 operationHash = keccak256(abi.encode("addOwner", newOwner));
         // 检查操作是否已经预约并等待期结束
        _checkSchedule(operationHash);
        // 执行添加操作
        _isOwner[newOwner] = true;
        _owners.push(newOwner);
        emit OwnerAdded(newOwner);
        emit OperationExecuted(operationHash); 
    }

    // 移除管理员（需要时间锁）
    function removeOwner(address ownerToRemove) external onlyOwner{
        require(_isOwner[ownerToRemove], "OwnablePlus: not an owner");
        require(_owners.length > 1, "OwnablePlus: cannot remove last owner");

        // 生成操作hash
        bytes32 operationHash = keccak256(abi.encode("removeOwner", ownerToRemove));

        // 检查操作是否已经预约并等待期结束
        _checkSchedule(operationHash);

        // 执行移除操作
        _isOwner[ownerToRemove] = false;

        // 从数组中移除
        for(uint256 i = 0; i < _owners.length; i++){
            if(_owners[i] == ownerToRemove){
                _owners[i] = _owners[_owners.length - 1];
                _owners.pop();
                break;
            }
        }
        emit OwnerRemoved(ownerToRemove);
        emit OperationExecuted(operationHash);
    }

    // 预约操作 - 开始时间锁流程
    function scheduleOperation(bytes32 operationHash) external onlyOwner{
        require(schedule[operationHash] == 0, "OwnablePlus: operation already scheduled");
        uint256 scheduledTime = block.timestamp + DELAY;
        schedule[operationHash] = scheduledTime;
        emit OperationScheduled(operationHash, scheduledTime);
    }

    // 取消已预约的操作
    function cancelOperation(bytes32 operationHash) external onlyOwner{
        require(schedule[operationHash] != 0, "OwnablePlus: operation not scheduled");
        delete schedule[operationHash];
    }

    // 检查操作是否可执行
    function isOperationReady(bytes32 operationHash) public view returns(bool){
        uint256 scheduledTime = schedule[operationHash];
        return scheduledTime != 0 && block.timestamp >= scheduledTime;
    }

    // 获取所有管理员地址
    function getOwners() external view returns(address[] memory){
        return _owners;
    }

    // 检查地址是否为管理员
    function isOwner(address account) external view returns(bool){
        return _isOwner[account];
    }

    // 内部函数：检查时间锁条件
    function _checkSchedule(bytes32 operationHash) internal{
        uint256 scheduledTime = schedule[operationHash];
        require(scheduledTime != 0, "OwnablePlus: operation not scheduled");
        require(block.timestamp >= scheduledTime, "OwnablePlus: operation not ready");
        // 执行后清除预约记录
        delete schedule[operationHash];
    }
}


// TimelockExample - 使用时间锁的示例合约
 // 演示如何使用OwnablePlus的时间锁功能
contract TimelockExample is OwnablePlus {
    uint256 public importantValue;
    address public importantAddress;
    
    event ValueChanged(uint256 newValue);
    event AddressChanged(address newAddress);
    
    constructor(address[] memory initialOwners) OwnablePlus(initialOwners) {}
    
    // 修改重要值（需要时间锁）
    function setImportantValue(uint256 newValue) external onlyOwner {
        bytes32 operationHash = keccak256(abi.encode("setValue", newValue));
        _checkSchedule(operationHash);
        
        importantValue = newValue;
        emit ValueChanged(newValue);
        emit OperationExecuted(operationHash);
    }
    
    // 修改重要地址（需要时间锁）
    function setImportantAddress(address newAddress) external onlyOwner {
        bytes32 operationHash = keccak256(abi.encode("setAddress", newAddress));
        _checkSchedule(operationHash);
        
        importantAddress = newAddress;
        emit AddressChanged(newAddress);
        emit OperationExecuted(operationHash);
    }
}