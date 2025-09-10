// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title 工厂合约接口
 * @notice 用于创建和管理流动性池的工厂合约接口
 */
interface IFactory {
    
    /**
     * @dev 创建池所需的参数结构体
     */
    struct Parameters {
        address factory;    // 工厂合约地址
        address tokenA;     // 第一种代币地址
        address tokenB;     // 第二种代币地址
        int24 tickLower;    // 价格区间下限（以tick为单位）
        int24 tickUpper;    // 价格区间上限（以tick为单位）
        uint24 fee;         // 交易手续费率（以基点表示，如3000表示0.3%）
    }

    // ============================ 视图函数 ============================

    /**
     * @notice 获取当前工厂的配置参数
     * @return factory 工厂合约地址
     * @return tokenA 第一种代币地址
     * @return tokenB 第二种代币地址
     * @return tickLower 价格区间下限
     * @return tickUpper 价格区间上限
     * @return fee 手续费率
     */
    function parameters() external view returns (
        address factory,
        address tokenA,
        address tokenB,
        int24 tickLower,
        int24 tickUpper,
        uint24 fee
    );

    /**
     * @notice 根据代币地址和索引获取池地址
     * @dev 相同的代币对可以创建多个不同参数的池
     * @param tokenA 第一种代币地址
     * @param tokenB 第二种代币地址
     * @param index 池的索引号（用于区分相同代币对的不同池）
     * @return pool 池合约地址，如果不存在则返回零地址
     */
    function getPool(
        address tokenA,
        address tokenB,
        uint32 index
    ) external view returns (address pool);

    // ============================ 状态变更函数 ============================

    /**
     * @notice 创建新的流动性池
     * @dev 根据提供的参数创建新的池合约
     * @param tokenA 第一种代币地址
     * @param tokenB 第二种代币地址
     * @param tickLower 价格区间下限
     * @param tickUpper 价格区间上限
     * @param fee 手续费率
     * @return pool 新创建的池合约地址
     */
    function createPool(
        address tokenA,
        address tokenB,
        int24 tickLower,
        int24 tickUpper,
        uint24 fee
    ) external returns (address pool);

    // ============================ 事件 ============================

    /**
     * @notice 池创建事件
     * @dev 当新池创建成功时触发
     * @param token0 排序后的第一种代币地址
     * @param token1 排序后的第二种代币地址
     * @param index 池的索引号
     * @param tickLower 价格区间下限
     * @param tickUpper 价格区间上限
     * @param fee 手续费率
     * @param pool 新创建的池合约地址
     */
    event PoolCreated(
        address token0,
        address token1,
        uint32 index,
        int24 tickLower,
        int24 tickUpper,
        uint24 fee,
        address pool
    );
}