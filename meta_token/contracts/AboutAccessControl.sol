// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4;


import { Context } from "./Context.sol";
import { IERC165, ERC165 } from "./AboutERC165.sol";

/*
基于角色的权限控制机制  定义不同的角色，并将这些角色分配给地址，从而控制对特定功能的访问权限。

*/

interface IAccessControl{
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error AccessControlBadConfirmation();
    // 角色的管理员角色变更时触发
    event RoleAdminChaned(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    // 角色被授予时触发
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    // 角色被撤销时触发
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    function hasRole(bytes32 role, address account) external view returns(bool);
    function getRoleAdmin(bytes32 role) external view returns(bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address callerConfirmation) external;
}

abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData{
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }

    mapping(bytes32 role => RoleData) private _roles;

    // 默认管理员角色，拥有最高权限
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    modifier onlyRole(bytes32 role){
        _checkRole(role);
        _;
    }
    
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        return _roles[role].hasRole[account];
    }

    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _messageSender());
    }


    function _checkRole(bytes32 role, address account) internal view virtual {
        if(!hasRole(role, account)){
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns(bool){
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    function getRoleAdmin(bytes32 role) public view virtual returns(bytes32) {
        return _roles[role].adminRole;
    }

    // 授予角色给指定地址，只能由该角色的管理员调用
    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)){
        _revokeRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    // 允许地址主动放弃自己的角色，是一种安全特性，防止私钥泄露后的权限滥用
    function renounceRole(bytes32 role, address callerConfirmation) public virtual {
        if(callerConfirmation != _messageSender()){
            revert AccessControlBadConfirmation();
        }
        _revokeRole(role, callerConfirmation);
    }

    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChaned(role, previousAdminRole, adminRole);
    }

    function _revokeRole(bytes32 role, address account) internal virtual returns(bool) {
        if(hasRole(role, account)){
            _roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, _messageSender());
            return true;
        }
        return false;
    }

    function _grantRole(bytes32 role, address account) internal virtual returns(bool) {
        if(!hasRole(role, account)){
            _roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, _messageSender());
            return true;
        }
        return false;
    }
}

/*
    // 自定义角色
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        // 只有拥有 MINTER_ROLE 的角色可以调用
        _mint(to, amount);
    }
*/