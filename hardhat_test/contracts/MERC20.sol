
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {FundMe} from "./FundMe.sol";

contract MERC20 is ERC20{
    FundMe fundMe;
    constructor(address fundMeAddr) ERC20("MyTokenName", "MTN") {
        fundMe = FundMe(fundMeAddr);
    }

    function mint(uint256 amountToMint) public {
        require(fundMe.fundersToAmount(msg.sender) >= amountToMint, "You cannot mint this many tokens");
        require(fundMe.getFundSuccess(), "The fundme is not completed yet");
        _mint(msg.sender, amountToMint);  // public 会自动创建 getter函数
        fundMe.setFuntToAmount(msg.sender, fundMe.fundersToAmount(msg.sender) - amountToMint);
    }

    function claim(uint256 amountToClaim) public {
        // complete cliam
        require(balanceOf(msg.sender) >= amountToClaim, "You dont have enough ERC20 tokens");
        require(fundMe.getFundSuccess(), "The fundme is not completed yet");
        /*to add */
        // 燃烧掉      
        _burn(msg.sender, amountToClaim);
    }
}