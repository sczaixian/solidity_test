// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/IUniswapV2Router.sol";

contract InitialLiquidityProvider {
    address public owner;
    address public token;

    constructor(){
        owner = msg.sender;
    }

    function provideLiquidity(address router, uint256 amount) payable external {
        require(msg.sender == owner, "only owner");
        // 先赋权 ，再转账
        IERC20(token).approve(router, amount);
        IUniswapV2Router02(router).addLiquidityETH{value: msg.value}(
            token, 
            amount, 
            0,                     // 最小代币数量（滑点保护）
            0,                     // 最小ETH数量
            address(this),         // LP代币接收地址
            block.timestamp + 300  // 5分钟截止时间
            );
    }

    receive() external payable{
        revert("do not send ETH directly");
    }
}