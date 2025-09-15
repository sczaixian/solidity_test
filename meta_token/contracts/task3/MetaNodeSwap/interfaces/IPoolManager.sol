// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import { IFactory } from "./IFactory.sol";

/**
 * @title 池管理器接口
 * @notice 该接口继承自IFactory，提供池的创建、查询和管理功能
 */
interface IPoolManager is IFactory {
    
    /**
     * @dev 池信息结构体，包含池的完整状态信息
     */
    struct PoolInfo {
        address pool;           // 池合约地址
        address token0;         // 第一种代币地址
        address token1;         // 第二种代币地址
        uint32 index;           // 池在列表中的索引位置
        uint24 fee;             // 交易手续费率，以基点表示（如3000表示0.3%）
        uint8 feeProtocol;      // 协议费用比例（0-255，表示协议收取的手续费分成）
        int24 tickLower;        // 价格区间下限（以tick为单位）
        int24 tickUpper;        // 价格区间上限（以tick为单位）
        int24 tick;             // 当前价格对应的tick值
        uint160 sqrtPriceX96;   // 当前价格的平方根，以Q64.96格式表示
        uint128 liquidity;      // 当前池中的总流动性数量
    }

    /**
     * @dev 代币对结构体，表示两种代币的组合
     */
    struct Pair {
        address token0;         // 第一种代币地址
        address token1;         // 第二种代币地址
    }

    /**
     * @notice 获取所有已存在的代币对
     * @return 返回所有代币对的数组
     */
    function getPairs() external view returns (Pair[] memory);

    /**
     * @notice 获取所有池的详细信息
     * @return poolsInfo 返回包含所有池完整信息的数组
     */
    function getAllPools() external view returns (PoolInfo[] memory poolsInfo);

    /**
     * @dev 创建和初始化池的参数结构体
     */
    struct CreateAndInitializeParams {
        address token0;         // 第一种代币地址
        address token1;         // 第二种代币地址
        uint24 fee;             // 交易手续费率
        int24 tickLower;        // 初始价格区间下限
        int24 tickUpper;        // 初始价格区间上限
        uint160 sqrtPriceX96;   // 初始价格的平方根（Q64.96格式）
    }

    /**
     * @notice 创建并初始化池（如果尚未存在）
     * @dev 如果指定参数的池已存在，则直接返回现有池地址；
     *      如果不存在，则创建新池并进行初始化
     * @param params 创建和初始化池所需的参数
     * @return pool 返回池合约地址（新创建的或已存在的）
     */
    function createAndInitializePoolIfNecessary(
        CreateAndInitializeParams calldata params
    ) external payable returns (address pool);
}