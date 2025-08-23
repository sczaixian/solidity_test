//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MyToken} from "./MyToken.sol";


contract WrappedMyToken is MyToken{
    constructor(string memory tokenName, string memory tokenSymbol) MyToken(tokenName, tokenSymbol){
    }
    // 自定义 id 的方式创造 nft
    function mintWithSpecificTokenId(address to, uint256 _tokenId) public{
        /* 这里可以加上白名单等功能 */
        _safeMint(to, _tokenId);
    }
}