// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import "./interfaces/IFactory.sol";
import "./Pool.sol";

/**
 * @title 流动性池工厂合约
 * @notice 负责创建和管理所有流动性池合约
 * @dev 使用CREATE2操作码部署池合约，确保相同参数的池有确定性地址
 */
contract Factory is IFactory {
    
    /**
     * @dev 存储所有已创建的池合约地址
     * @notice 映射结构：token0地址 => token1地址 => 池地址数组[]
     * @dev 代币地址会按照排序后的顺序存储
     */
    mapping(address => mapping(address => address[])) public pools;

    /**
     * @dev 当前正在创建的池的参数
     * @notice 在createPool函数执行过程中临时存储参数
     */
    Parameters public override parameters;

    /**
     * @notice 对两个代币地址进行排序
     * @dev 确保token0总是小于token1，避免重复创建相同代币对的池
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @return token0 排序后较小的代币地址
     * @return token1 排序后较大的代币地址
     */
    function sortToken(
        address tokenA,
        address tokenB
    ) private pure returns (address, address) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    /**
     * @notice 根据代币对和索引获取池地址
     * @dev 查询指定代币对在特定索引位置的池合约地址
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @param index 池在数组中的索引位置
     * @return 池合约地址，如果不存在则返回零地址
     */
    function getPool(
        address tokenA,
        address tokenB,
        uint32 index
    ) external view override returns (address) {
        // 验证参数有效性
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        require(tokenA != address(0) && tokenB != address(0), "ZERO_ADDRESS");

        // 声明变量
        address token0;
        address token1;

        // 对代币地址进行排序
        (token0, token1) = sortToken(tokenA, tokenB);

        // 返回指定索引的池地址
        return pools[token0][token1][index];
    }

    /*
     * @notice 创建新的流动性池
     * @dev 如果相同参数的池已存在，则返回现有池地址；否则创建新池
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @param tickLower 价格区间下限（以tick为单位）
     * @param tickUpper 价格区间上限（以tick为单位）
     * @param fee 交易手续费率（以基点表示）
     * @return pool 新创建或已存在的池合约地址
     * 
     * @解析 函数执行流程：
     * 1. 参数验证：确保代币地址有效且不相同
     * 2. 代币排序：确保token0 < token1
     * 3. 检查现有池：遍历现有池，如果找到相同参数的池则直接返回
     * 4. 创建新池：使用CREATE2部署新池合约
     * 5. 存储池地址：将新池地址添加到映射中
     * 6. 触发事件：通知外部观察者池已创建
     */
    function createPool(
        address tokenA,
        address tokenB,
        int24 tickLower,
        int24 tickUpper,
        uint24 fee
    ) external override returns (address pool) {
        // 验证代币地址不能相同
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");

        // 声明变量
        address token0;
        address token1;

        // 对代币地址进行排序（确保一致性）
        (token0, token1) = sortToken(tokenA, tokenB);

        // 获取该代币对的所有现有池
        address[] memory existingPools = pools[token0][token1];

        // 检查是否已存在相同参数的池
        for (uint256 i = 0; i < existingPools.length; i++) {
            IPool currentPool = IPool(existingPools[i]);

            // 比较池参数：价格区间和手续费率
            if (
                currentPool.tickLower() == tickLower &&
                currentPool.tickUpper() == tickUpper &&
                currentPool.fee() == fee
            ) {
                // 如果找到匹配的池，直接返回现有池地址
                return existingPools[i];
            }
        }

        // ========== 创建新池 ==========

        // 临时存储创建参数（供Pool构造函数使用）
        parameters = Parameters(
            address(this),  // 工厂地址
            token0,         // 排序后的token0
            token1,         // 排序后的token1
            tickLower,      // 价格区间下限
            tickUpper,      // 价格区间上限
            fee             // 手续费率
        );

        // 生成CREATE2盐值（确保相同参数的池有确定性地址）
        bytes32 salt = keccak256(
            abi.encode(token0, token1, tickLower, tickUpper, fee)
        );

        // 使用CREATE2操作码部署新池合约
        // CREATE2优势：相同参数总是生成相同地址，便于前端预测池地址
        pool = address(new Pool{salt: salt}());

        // 将新池地址存储到映射中
        pools[token0][token1].push(pool);

        // 清理临时存储的参数
        delete parameters;

        // 触发池创建事件
        emit PoolCreated(
            token0,                     // 排序后的token0
            token1,                     // 排序后的token1
            uint32(existingPools.length), // 新池的索引位置
            tickLower,                  // 价格区间下限
            tickUpper,                  // 价格区间上限
            fee,                        // 手续费率
            pool                        // 新池合约地址
        );
    }
}