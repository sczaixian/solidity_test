// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "../AboutERC20.sol";

contract TMetaNode is ERC20{
    constructor() ERC20("TMetaNode", "TMN"){
        _mint(msg.sender, 10000000 * 1_000_000_000_000_000_000);
    }
}