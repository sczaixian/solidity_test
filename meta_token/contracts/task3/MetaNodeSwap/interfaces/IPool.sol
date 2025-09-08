// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;


interface IMintCallbacks{
    function mintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external;
}

interface ISwapCallback{
    function swapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}

interface IPool{
    function factory() external view returns(address);
    function token0() external view returns(address);
    function token1() external view returns(address);
    function fee() external view returns(uint24);
    function tickLower() external view returns(int24);
    function tickUpper() external view returns(int24);
    function sqrtPriceX96() external view returns(uint160);
    function tick() external view returns(int24);
    function liquidity() external view returns(uint128);
    function initialize(uint160 sqrtPriceX96) external;

    function freeGrowthGlobal0x128() external view returns(uint256);
    function feeGrowthGlobal1x128() external view returns(uint256);
    function getPosition(address owner) external view returns(
                    uint128 _liquidity, 
                    uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128,
                    uint128 tokensOwed0, uint128 tokensOwed1);
    

    event Mint(address sender, address indexed owner, uint128 amount, uint256 amount0, uint256 amount1);
    function mint(address recipient, uint128 amount, bytes calldata data) external returns(uint256 amount0, uint256 amount1);
    event Collect(address indexed owner, address recipient, uint128 amount0, uint128 amount1);
    function collect(address recipient, uint128 amount0Requested, uint128 amount1Requested) external returns(uint128 amount0, uint128 amount1);
    event Burn(address indexed owner, uint128 amount, uint256 amount0, uint256 amount1);
    function burn(uint128 amount) external returns(uint256 amount0, uint256 amount1);
    event Swap(address indexed sender, address indexed recipient, int256 amount0, int256 amount1, uint160 sqrtPriceX96, uint128 liquidity, int24 tick);
    function swap(address recipient, bool zeroForOne, int256 amountSecified, bytes calldata data) external returns(int256 amount0, int256 amount1);
}