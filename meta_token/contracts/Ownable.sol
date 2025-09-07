
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


import { Context} from "./Context.sol";

abstract contract Ownable is Context{
    address private _owner;

    error OwnableUnauthorizedAccount(address account);  // 非法访问
    error OwnableInvalidOwner(address owner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);  // 权限转移

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    constructor(address initialOwner) {
        if(initialOwner == address(0)){
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    function reounceOwnership() public virtual onlyOwner {  // 放弃所有权
        _transferOwnership(address(0));
    }
   
    function owner()public view virtual returns(address){
        return _owner;
    }

    function _checkOwner() internal view virtual{
        if( owner() != _messageSender()){
            revert OwnableUnauthorizedAccount(_messageSender());
        }
    }

    function transferOwnership(address newOwner) public virtual onlyOwner{
        if(newOwner == address(0)){
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

     function _transferOwnership(address newOwner) internal virtual {  // 转移所有权
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

}