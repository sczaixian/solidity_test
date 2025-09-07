// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Ownable} from "./Ownable.sol";

abstract contract Ownable2Step is Ownable{
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    function pendingOwner() public view virtual returns(address){
        return _pendingOwner;
    }

    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual override{
        delete _pendingOwner;
        super._transferOwnership(newOwner);
    }

    function acceptOwnership() public virtual {  // 新用户接受权限转移
        address sender = _messageSender();
        if(pendingOwner() != sender){
            revert OwnableUnauthorizedAccount(sender);
        }
        _transferOwnership(sender);
    }
}