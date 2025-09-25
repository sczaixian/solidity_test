// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { ERC20 } from "../AboutERC20.sol";
import { Ownable } from "../Ownable.sol";

contract MemeToken is ERC20, Ownable{
    string private _name;
    string private _symbol;
    uint256 private _totalSupply;


    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender) {
        _name = name;
        _symbol = symbol;
    }

    function transfer(address to, uint256 value) public override returns(bool) {
        address sender = msg.sender;
        require(_balances[sender] > value, "");
        if(address(0) == sender){
            // 
        }
        _transfer(sender, to, value);
        return true;
    }

}

/*
SHIB 风格代币合约（柴犬币）: 这类代币通常被称为 “Meme Coin” 或 “社区型代币”

一个典型的 SHIB 风格代币通常具备以下特点：

1.超高总量：通常拥有数万亿甚至更高数量的总供应量。这主要是出于营销和心理原因，让散户投资者感觉“自己拥有很多”，单价极低，制造“暴涨潜力”的错觉。
2.零预挖/公平发射：项目方宣称没有为自己预留代币，所有代币通过流动性池或空投等方式分配给社区。SHIB 将其总量的 50% 锁在了 Uniswap 的流动性池中，另 50% 送给了 Vitalik Buterin。
3.强大的社区文化：依赖社交媒体（如 Twitter、Telegram、Reddit）进行病毒式传播，拥有强烈的社区认同感和文化符号（如柴犬）。
4.通缩机制：许多后续项目引入了通缩机制，例如交易燃烧、质押奖励等，试图为代币创造稀缺性。
5.去中心化与自治：强调由社区完全掌控和驱动，项目方“放弃合约权限”是常见的宣传点。



*/