// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IPool.sol";

/**
 * @title 交换路由器接口
 * @notice 提供代币交换功能的路由器接口，支持精确输入和精确输出两种交换模式
 * @dev 继承自ISwapCallback，实现交换回调功能
 */
interface ISwapRouter is ISwapCallback {
    
    /**
     * @notice 交换事件
     * @dev 当交换操作完成时触发
     * @param sender 交换发起者地址
     * @param zeroForOne 交换方向：true表示用token0交换token1，false表示用token1交换token0
     * @param amountIn 实际输入代币数量
     * @param amountInRemaining 剩余未使用的输入代币数量（滑点保护）
     * @param amountOut 实际输出代币数量
     */
    event Swap(
        address indexed sender,
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountInRemaining,
        uint256 amountOut
    );

    // ============================ 精确输入交换 ============================

    /**
     * @dev 精确输入交换参数结构体
     * @notice 指定输入代币数量，获取不确定数量的输出代币
     */
    struct ExactInputParams {
        address tokenIn;             // 输入代币地址
        address tokenOut;            // 输出代币地址
        uint32[] indexPath;          // 交换路径的索引数组，用于多跳交换
        address recipient;           // 输出代币接收者地址
        uint256 deadline;            // 交易过期时间（区块号），超过该区块交易将失效
        uint256 amountIn;            // 精确的输入代币数量
        uint256 amountOutMinimum;    // 可接受的最少输出代币数量（滑点保护）
        uint160 sqrtPriceLimitX96;   // 价格限制（Q64.96格式），为0表示不限制价格
    }

    /**
     * @notice 执行精确输入交换
     * @dev 指定确切的输入数量，获取相应数量的输出代币
     * @param params 精确输入参数
     * @return amountOut 实际输出的代币数量
     */
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    // ============================ 精确输出交换 ============================

    /**
     * @dev 精确输出交换参数结构体
     * @notice 指定输出代币数量，支付不确定数量的输入代币
     */
    struct ExactOutputParams {
        address tokenIn;             // 输入代币地址
        address tokenOut;            // 输出代币地址
        uint32[] indexPath;          // 交换路径的索引数组，用于多跳交换
        address recipient;           // 输出代币接收者地址
        uint256 deadline;            // 交易过期时间（区块号），超过该区块交易将失效
        uint256 amountOut;           // 精确的输出代币数量
        uint256 amountInMaximum;     // 可接受的最大输入代币数量（滑点保护）
        uint160 sqrtPriceLimitX96;   // 价格限制（Q64.96格式），为0表示不限制价格
    }

    /**
     * @notice 执行精确输出交换
     * @dev 指定确切的输出数量，支付相应数量的输入代币
     * @param params 精确输出参数
     * @return amountIn 实际输入的代币数量
     */
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);

    // ============================ 报价功能 ============================

    /**
     * @dev 精确输入报价参数结构体
     * @notice 用于查询指定输入数量能获得的输出数量
     */
    struct QuoteExactInputParams {
        address tokenIn;             // 输入代币地址
        address tokenOut;            // 输出代币地址
        uint32[] indexPath;          // 交换路径的索引数组，用于多跳交换
        uint256 amountIn;            // 输入代币数量
        uint160 sqrtPriceLimitX96;   // 价格限制（Q64.96格式），为0表示不限制价格
    }

    /**
     * @notice 精确输入报价
     * @dev 查询指定输入数量能获得的输出数量（不实际执行交换）
     * @param params 精确输入报价参数
     * @return amountOut 预估的输出代币数量
     */
    function quoteExactInput(QuoteExactInputParams calldata params) external returns (uint256 amountOut);

    /**
     * @dev 精确输出报价参数结构体
     * @notice 用于查询获得指定输出数量需要的输入数量
     */
    struct QuoteExactOutputParams {
        address tokenIn;             // 输入代币地址
        address tokenOut;            // 输出代币地址
        uint32[] indexPath;          // 交换路径的索引数组，用于多跳交换
        uint256 amountOut;           // 输出代币数量
        uint160 sqrtPriceLimitX96;   // 价格限制（Q64.96格式），为0表示不限制价格
    }

    /**
     * @notice 精确输出报价
     * @dev 查询获得指定输出数量需要的输入数量（不实际执行交换）
     * @param params 精确输出报价参数
     * @return amountIn 预估的输入代币数量
     */
    function quoteExactOutput(QuoteExactOutputParams calldata params) external returns (uint256 amountIn);
}