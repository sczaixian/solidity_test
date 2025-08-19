

// SPDX-License-Identifier: MIT
pragma solidity ^0.8;


// 引入 OpenZeppelin 的 ERC20 合约
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor() ERC20("MyToken", "MTK") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}

// https://sepolia.etherscan.io/block/9008137