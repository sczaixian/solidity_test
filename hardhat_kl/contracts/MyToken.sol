// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0

// https://www.openzeppelin.com/solidity-contracts#   <--- gen from

pragma solidity ^0.8.27;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Burnable, Ownable {
    uint256 private _nextTokenId;
    
    // descrip-json: https://docs.opensea.io/docs/metadata-standards
    string constant META_DATA = "ipfs://QmUBA67N8NYeKRZH2o19ayUABBf4knwuzsfGasPzqgzdEr";

    // constructor(address initialOwner)
    //     ERC721("MyToken", "MTK")
    //     Ownable(initialOwner)
    // {}

    constructor(string memory tokenName, string memory tokenSymbol)
        ERC721(tokenName, tokenSymbol)
        Ownable(msg.sender) {
    }
    
    function safeMint(address to) public returns (uint256) {
        /* 这里也可以加上自定义需求，如加一些手续费 */
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, META_DATA);
        return tokenId;
    }

    // The following functions are overrides required by Solidity.

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}