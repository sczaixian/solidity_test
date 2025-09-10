// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title 铸造回调接口
 * @notice 在铸造流动性时，池合约会调用此接口进行代币转账
 */
interface IMintCallbacks {
    /**
     * @notice 铸造回调函数
     * @dev 当用户铸造流动性时，池合约会调用此函数要求用户支付相应的代币
     * @param amount0Owed 需要支付的token0数量
     * @param amount1Owed 需要支付的token1数量
     * @param data 附加数据，可用于传递自定义信息
     */
    function mintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external;
}

/**
 * @title 交换回调接口
 * @notice 在执行交换操作时，池合约会调用此接口进行代币转账
 */
interface ISwapCallback {
    /**
     * @notice 交换回调函数
     * @dev 当用户执行交换时，池合约会调用此函数要求用户支付输入代币
     * @param amount0Delta token0的数量变化（正数表示需要支付，负数表示将收到）
     * @param amount1Delta token1的数量变化（正数表示需要支付，负数表示将收到）
     * @param data 附加数据，可用于传递自定义信息
     */
    function swapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}

/**
 * @title 流动性池接口
 * @notice 定义流动性池的核心功能和事件
 */
interface IPool {
    // ============================ 视图函数 ============================
    
    /**
     * @notice 获取工厂合约地址
     * @return 工厂合约地址
     */
    function factory() external view returns(address);
    
    /**
     * @notice 获取第一种代币地址
     * @return token0地址
     */
    function token0() external view returns(address);
    
    /**
     * @notice 获取第二种代币地址
     * @return token1地址
     */
    function token1() external view returns(address);
    
    /**
     * @notice 获取交易手续费率
     * @return 手续费率（以基点表示，如3000表示0.3%）
     */
    function fee() external view returns(uint24);
    
    /**
     * @notice 获取价格区间下限
     * @return 价格区间下限的tick值
     */
    function tickLower() external view returns(int24);
    
    /**
     * @notice 获取价格区间上限
     * @return 价格区间上限的tick值
     */
    function tickUpper() external view returns(int24);
    
    /**
     * @notice 获取当前价格的平方根
     * @return 当前价格的平方根（Q64.96格式）
     */
    function sqrtPriceX96() external view returns(uint160);
    
    /**
     * @notice 获取当前价格对应的tick值
     * @return 当前tick值
     */
    function tick() external view returns(int24);
    
    /**
     * @notice 获取当前池中的总流动性
     * @return 流动性数量
     */
    function liquidity() external view returns(uint128);
    
    /**
     * @notice 获取token0的全局手续费增长率
     * @return token0的手续费增长率（Q128.128格式）
     */
    function feeGrowthGlobal0x128() external view returns(uint256);
    
    /**
     * @notice 获取token1的全局手续费增长率
     * @return token1的手续费增长率（Q128.128格式）
     */
    function feeGrowthGlobal1x128() external view returns(uint256);
    
    /**
     * @notice 获取指定地址的头寸信息
     * @param owner 头寸所有者地址
     * @return _liquidity 该头寸提供的流动性数量
     * @return feeGrowthInside0LastX128 上次更新时token0的内部手续费增长率
     * @return feeGrowthInside1LastX128 上次更新时token1的内部手续费增长率
     * @return tokensOwed0 应得的token0数量
     * @return tokensOwed1 应得的token1数量
     */
    function getPosition(address owner) external view returns(
        uint128 _liquidity, 
        uint256 feeGrowthInside0LastX128, 
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0, 
        uint128 tokensOwed1
    );

    // ============================ 状态变更函数 ============================
    
    /**
     * @notice 初始化池
     * @dev 设置初始价格，只能调用一次
     * @param sqrtPriceX96 初始价格的平方根（Q64.96格式）
     */
    function initialize(uint160 sqrtPriceX96) external;
    
    /**
     * @notice 铸造流动性
     * @dev 为用户铸造流动性代币，会调用mintCallback进行代币支付
     * @param recipient 流动性接收地址
     * @param amount 流动性数量
     * @param data 回调时传递的附加数据
     * @return amount0 实际支付的token0数量
     * @return amount1 实际支付的token1数量
     */
    function mint(address recipient, uint128 amount, bytes calldata data) external returns(uint256 amount0, uint256 amount1);
    
    /**
     * @notice 提取应得的手续费收益
     * @param recipient 收益接收地址
     * @param amount0Requested 请求提取的token0数量
     * @param amount1Requested 请求提取的token1数量
     * @return amount0 实际提取的token0数量
     * @return amount1 实际提取的token1数量
     */
    function collect(address recipient, uint128 amount0Requested, uint128 amount1Requested) external returns(uint128 amount0, uint128 amount1);
    
    /**
     * @notice 销毁流动性
     * @dev 销毁流动性代币，计算应返还的代币数量
     * @param amount 要销毁的流动性数量
     * @return amount0 应返还的token0数量
     * @return amount1 应返还的token1数量
     */
    function burn(uint128 amount) external returns(uint256 amount0, uint256 amount1);
    
    /**
     * @notice 执行代币交换
     * @dev 执行token0和token1之间的交换，会调用swapCallback进行代币支付
     * @param recipient 交换收益接收地址
     * @param zeroForOne 交换方向：true表示用token0交换token1，false表示用token1交换token0
     * @param amountSpecified 指定输入/输出数量（正数表示精确输入，负数表示精确输出）
     * @param data 回调时传递的附加数据
     * @return amount0 token0的数量变化
     * @return amount1 token1的数量变化
     */
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, bytes calldata data) external returns(int256 amount0, int256 amount1);

    // ============================ 事件 ============================
    
    /**
     * @notice 铸造事件
     * @param sender 操作发起者地址
     * @param owner 流动性所有者地址
     * @param amount 铸造的流动性数量
     * @param amount0 支付的token0数量
     * @param amount1 支付的token1数量
     */
    event Mint(address sender, address indexed owner, uint128 amount, uint256 amount0, uint256 amount1);
    
    /**
     * @notice 提取收益事件
     * @param owner 头寸所有者地址
     * @param recipient 收益接收地址
     * @param amount0 提取的token0数量
     * @param amount1 提取的token1数量
     */
    event Collect(address indexed owner, address recipient, uint128 amount0, uint128 amount1);
    
    /**
     * @notice 销毁事件
     * @param owner 头寸所有者地址
     * @param amount 销毁的流动性数量
     * @param amount0 返还的token0数量
     * @param amount1 返还的token1数量
     */
    event Burn(address indexed owner, uint128 amount, uint256 amount0, uint256 amount1);
    
    /**
     * @notice 交换事件
     * @param sender 交换发起者地址
     * @param recipient 收益接收地址
     * @param amount0 token0的数量变化
     * @param amount1 token1的数量变化
     * @param sqrtPriceX96 交换后的价格平方根
     * @param liquidity 交换后的流动性数量
     * @param tick 交换后的tick值
     */
    event Swap(address indexed sender, address indexed recipient, int256 amount0, int256 amount1, uint160 sqrtPriceX96, uint128 liquidity, int24 tick);
}