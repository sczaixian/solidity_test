// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;



abstract contract Context {
    function _messageSender() internal view returns(address){
        return msg.sender;
    }
}