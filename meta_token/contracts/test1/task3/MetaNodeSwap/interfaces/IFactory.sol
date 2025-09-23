// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title 工厂合约接口
 * @notice 用于创建和管理流动性池的工厂合约接口
 */
interface IFactory {
    
    
    struct Parameters {
        address factory;    // 工厂合约地址
        address tokenA;     // 第一种代币地址
        address tokenB;     // 第二种代币地址
        int24 tickLower;    // 价格区间下限（以tick为单位）
        int24 tickUpper;    // 价格区间上限（以tick为单位）
        uint24 fee;         // 交易手续费率（以基点表示，如3000表示0.3%）
    }

    // ============================ 视图函数 ============================

    function parameters() external view returns (
        address factory, address tokenA, address tokenB,
        int24 tickLower, int24 tickUpper,
        uint24 fee
    );

  
    function getPool(address tokenA, address tokenB, uint32 index) external view returns (address pool);

    // ============================ 状态变更函数 ============================

    function createPool(
        address tokenA,address tokenB,int24 
        tickLower,int24 tickUpper,uint24 fee) external returns (address pool);

    // ============================ 事件 ============================

    event PoolCreated(
        address token0, address token1,
        uint32 index,
        int24 tickLower, int24 tickUpper,
        uint24 fee,
        address pool
    );
}