// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import "./IPool.sol";

interface ISwapRouter is ISwapCallback {
    event Swap(address indexed sender,bool zeroForOne,uint256 amountIn,uint256 amountInRemaining,uint256 amountOut);

    struct ExactInputParams {
        address tokenIn;       // 输入代币地址
        address tokenOut;      // 输出代币地址
        uint32[] indexPath;
        address recipient;     // 接收者地址
        uint256 deadline;      // 过期的区块号
        uint256 amountIn;      // 输入代币数量
        uint256 amountOutMinimum;   // 最少输出代币数量
        uint160 sqrtPriceLimitX96;  // 限定价格，值为0则不限价
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    struct ExactOutputParams {
        address tokenIn;address tokenOut;uint32[] indexPath;address recipient;
        uint256 deadline;uint256 amountOut;uint256 amountInMaximum;uint160 sqrtPriceLimitX96;
    }

    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);

    struct QuoteExactInputParams {
        address tokenIn;address tokenOut;uint32[] indexPath;
        uint256 amountIn;uint160 sqrtPriceLimitX96;}

    function quoteExactInput(QuoteExactInputParams calldata params) external returns (uint256 amountOut);

    struct QuoteExactOutputParams {
        address tokenIn;
        address tokenOut;
        uint32[] indexPath;
        uint256 amountOut;
        uint160 sqrtPriceLimitX96;
    }

    function quoteExactOutput(QuoteExactOutputParams calldata params) external returns (uint256 amountIn);
}