// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


contract MERC20{

    string public name;
    string public symbol;
    uint256 public totalSupply;
    address public owner;
    mapping(address => uint256) balances;

    constructor(string memory _name, string memory _symbol){
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
    }

    function mint(uint256 amount) public{
        balances[msg.sender] = amount;
        totalSupply += amount;
    }

    function transfer(address payee, uint256 amount) public {
        require(balances[msg.sender] >= amount, "you do not have enough balance to transfer");
        unchecked {
            balances[msg.sender] -= amount;
            balances[payee] += amount;
        }
    }
    
}