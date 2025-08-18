// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract BeggingContract{

    address public owner;
    uint256 public totalEth;

    mapping (address => uint256) public logs;

    function donate(address from, uint256 eth) payable public returns(bool){

        return true;
    }

    error OnlyOwner();

    modifier onlyOwner(){
        if(owner != msg.sender) revert OnlyOwner();
        _;  
    }

    function withdraw() onlyOwner() {

    }


}