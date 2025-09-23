// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title 头寸管理器接口
 * @notice 管理流动性头寸的ERC721合约接口，支持头寸的创建、销毁和收益收集
 * @dev 继承自IERC721，每个头寸都是一个NFT
 */
interface IPositionManager is IERC721 {
    
    /**
     * @dev 头寸信息结构体，包含头寸的完整状态信息
     */
    struct PositionInfo {
        uint256 id;                         // 头寸ID（也是NFT的tokenId）
        address owner;                      // 头寸所有者地址
        address token0;                      // 第一种代币地址
        address token1;                      // 第二种代币地址
        uint32 index;                        // 池索引号（用于区分相同代币对的不同池）
        uint24 fee;                         // 交易手续费率（以基点表示，如3000表示0.3%）
        uint128 liquidity;                  // 头寸提供的流动性数量
        int24 tickLower;                    // 流动性价格区间下限（以tick为单位）
        int24 tickUpper;                    // 流动性价格区间上限（以tick为单位）
        uint128 tokensOwed0;                // 应得但尚未提取的token0数量（手续费收益）
        uint128 tokensOwed1;                // 应得但尚未提取的token1数量（手续费收益）
        uint256 feeGrowthInside0LastX128;   // 上次更新时token0的内部手续费增长率（Q128.128格式）
        uint256 feeGrowthInside1LastX128;   // 上次更新时token1的内部手续费增长率（Q128.128格式）
    }

    // ============================ 视图函数 ============================

    /**
     * @notice 获取所有头寸的详细信息
     * @return positionInfo 包含所有头寸完整信息的数组
     */
    function getAllPositions() external view returns (PositionInfo[] memory positionInfo);

    // ============================ 状态变更函数 ============================

    /**
     * @dev 铸造头寸（添加流动性）的参数结构体
     */
    struct MintParams {
        address token0;             // 第一种代币地址
        address token1;             // 第二种代币地址
        uint32 index;               // 池索引号
        uint256 amount0Desired;     // 期望添加的token0数量
        uint256 amount1Desired;     // 期望添加的token1数量
        address recipient;          // 头寸NFT接收者地址
        uint256 deadline;           // 交易过期时间（区块号），超过该区块交易将失效
    }

    /**
     * @notice 铸造新的流动性头寸
     * @dev 为用户创建新的流动性头寸并铸造NFT，会调用mintCallback进行代币支付
     * @param params 铸造参数
     * @return positionId 新创建的头寸ID（NFT tokenId）
     * @return liquidity 实际添加的流动性数量
     * @return amount0 实际使用的token0数量
     * @return amount1 实际使用的token1数量
     */
    function mint(MintParams calldata params) external payable returns (
        uint256 positionId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    /**
     * @notice 销毁头寸并提取流动性
     * @dev 销毁头寸NFT并提取对应的流动性价值
     * @param positionId 要销毁的头寸ID
     * @return amount0 返还的token0数量
     * @return amount1 返还的token1数量
     */
    function burn(uint256 positionId) external returns (uint256 amount0, uint256 amount1);

    /**
     * @notice 收集头寸积累的手续费收益
     * @dev 提取头寸应得的手续费收益
     * @param positionId 头寸ID
     * @param recipient 收益接收地址
     * @return amount0 提取的token0手续费数量
     * @return amount1 提取的token1手续费数量
     */
    function collect(uint256 positionId, address recipient) external returns (uint256 amount0, uint256 amount1);

    /**
     * @notice 铸造回调函数
     * @dev 当铸造头寸时，池合约会调用此函数要求用户支付相应的代币
     * @param amount0 需要支付的token0数量
     * @param amount1 需要支付的token1数量
     * @param data 附加数据，可用于传递自定义信息
     */
    function mintCallback(uint256 amount0, uint256 amount1, bytes calldata data) external;
}