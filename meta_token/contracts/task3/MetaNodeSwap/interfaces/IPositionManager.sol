
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IPositionManager is IERC721 {
    struct PositionInfo {
        uint256 id;
        address owner;
        address token0;
        address token1;
        uint32 index;
        uint24 fee;
        uint128 liquidity;
        int24 tickLower;
        int24 tickUpper;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
        // feeGrowthInside0LastX128 和 feeGrowthInside1LastX128 用于计算手续费
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
    }

}