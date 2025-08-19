// SPDX-License-Identifier:MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {FundMe} from "./01.sol";

contract FundTokenERC20 is FundMe{
    FundMe fundMe;

    constructor (address fundMeAddr) ERC20("FundTokenERC20", "FT") {
        fundMe = FundMe(fundMeAddr);
    }

    function minut(uint256 amountToMint) public {
        require(fundMe.funderToAmount(msg.sender) >= amountToMint, "");
        // success
        _mint(msg.sender, amountToMint);
        // fundMe.setFunderToAmount(msg.sender, fundMe.funderToAmount(msg.sender) - amountToMint);
        
    }

    function claim(uint256 amountToClaim)
}