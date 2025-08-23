
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFT is ERC721URIStorage, Ownable {
    // using A for B语法​​：将库 A的函数绑定到类型 B上，允许直接通过 B的实例调用库函数
    // Counters.Counter  是个结构体
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter; // 这个结构体的实例，  这个实例可以调用 库 Counters 中的函数

    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
        Ownable(msg.sender)
    {
        _tokenIdCounter.increment();
    }

    // // 可选：重写父类函数确保正确支持接口
    // function supportsInterface(bytes4 interfaceId) public  view  override (ERC721URIStorage) returns(bool){
    //     return super.supportsInterface(interfaceId);
    // }

    // 0x1984EE3bCE0c863d24905dF9D54322856e54CCea，ipfs://QmT7nwsyHZhSwLSRrQhSKfEnawCVtNU664fgo2kFrtkCne
    function mintNFC(address to, string memory tokenURI)
        public
        returns (uint256)
    {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        // 铸造NFT（调用ERC721的_mint方法）
        _mint(to, tokenId);
        // 关联元数据链接（使用ERC721URIStorage的方法）
        _setTokenURI(tokenId, tokenURI);
        return tokenId;
        /*
        _safeMint(to, tokenId);          // 安全铸造（检查地址有效性）
        _setTokenURI(tokenId, tokenURI);  // 关联元数据
        
        return tokenId;
        */
    }

    // // 重写函数：支持元数据存储
    // function tokenURI(uint256 tokenId)
    //     public
    //     view
    //     override(ERC721, ERC721URIStorage)
    //     returns (string memory)
    // {
    //     return super.tokenURI(tokenId);
    // }

    // // 重写函数：支持燃烧 NFT
    // function _burn(uint256 tokenId)
    //     internal
    //     override(ERC721, ERC721URIStorage)
    // {
    //     super._burn(tokenId);
    // }
}



/**











QmUBA67N8NYeKRZH2o19ayUABBf4knwuzsfGasPzqgzdEr
CID:
QmUBA67N8NYeKRZH2o19ayUABBf4knwuzsfGasPzqgzdEr
已基于以下密钥成功发布：
self
k51qzi5uqu5dgnm9b9lg8kx2ub9ibfa51cu0a9hpgr1cjyzjm82zqhhr92bvsq

复制以下链接分享给其他人。只要您的节点保持可用，此IPNS地址将会以每天更新一次的频率更新解析记录
https://ipfs.io/ipns/k51qzi5uqu5dgnm9b9lg8kx2ub9ibfa51cu0a9hpgr1cjyzjm82zqhhr92bvsq




























CID:
QmT7nwsyHZhSwLSRrQhSKfEnawCVtNU664fgo2kFrtkCne
已基于以下密钥成功发布：
self
k51qzi5uqu5dm9gfpinnsbofejwdtojqy6btl9qle0b8wai3gpftoj6ui635ta
复制以下链接分享给其他人。只要您的节点保持可用，此IPNS地址将会以每天更新一次的频率更新解析记录
https://ipfs.io/ipns/k51qzi5uqu5dm9gfpinnsbofejwdtojqy6btl9qle0b8wai3gpftoj6ui635ta



status	0x1 Transaction mined and execution succeed
transaction hash	0x25731d163cca352f8eb7fe5c189a80a56574cb16ae303b84c7724ade0cd0321a
block hash	0xda6a455929109701b7801e96d2fddb80d2d669ef6916fcb0138a46a32cafc446
block number	9010283
from	0x1984EE3bCE0c863d24905dF9D54322856e54CCea
to	MyNFT.mintNFC(address,string) 0xc7e833424e1d30dae75c5196c588f7174a1a1275
gas	145725 gas
transaction cost	144568 gas 
input	0x6c8...00000
decoded input	{
	"address to": "0x1984EE3bCE0c863d24905dF9D54322856e54CCea",
	"string tokenURI": "ipfs://QmT7nwsyHZhSwLSRrQhSKfEnawCVtNU664fgo2kFrtkCne"
}
decoded output	 - 
logs	[
	{
		"from": "0xc7e833424e1d30dae75c5196c588f7174a1a1275",
		"topic": "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
		"event": "Transfer",
		"args": {
			"0": "0x0000000000000000000000000000000000000000",
			"1": "0x1984EE3bCE0c863d24905dF9D54322856e54CCea",
			"2": "1"
		}
	},
	{
		"from": "0xc7e833424e1d30dae75c5196c588f7174a1a1275",
		"topic": "0xf8e1a15aba9398e019f0b49df1a4fde98ee17ae345cb5f6b5e2c27f5033e8ce7",
		"event": "MetadataUpdate",
		"args": {
			"0": "1"
		}
	}
]
raw logs	[
  {
    "address": "0xc7e833424e1d30dae75c5196c588f7174a1a1275",
    "blockHash": "0xda6a455929109701b7801e96d2fddb80d2d669ef6916fcb0138a46a32cafc446",
    "blockNumber": "0x897c6b",
    "data": "0x",
    "logIndex": "0x39",
    "removed": false,
    "topics": [
      "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
      "0x0000000000000000000000000000000000000000000000000000000000000000",
      "0x0000000000000000000000001984ee3bce0c863d24905df9d54322856e54ccea",
      "0x0000000000000000000000000000000000000000000000000000000000000001"
    ],
    "transactionHash": "0x25731d163cca352f8eb7fe5c189a80a56574cb16ae303b84c7724ade0cd0321a",
    "transactionIndex": "0x1a"
  },
  {
    "address": "0xc7e833424e1d30dae75c5196c588f7174a1a1275",
    "blockHash": "0xda6a455929109701b7801e96d2fddb80d2d669ef6916fcb0138a46a32cafc446",
    "blockNumber": "0x897c6b",
    "data": "0x0000000000000000000000000000000000000000000000000000000000000001",
    "logIndex": "0x3a",
    "removed": false,
    "topics": [
      "0xf8e1a15aba9398e019f0b49df1a4fde98ee17ae345cb5f6b5e2c27f5033e8ce7"
    ],
    "transactionHash": "0x25731d163cca352f8eb7fe5c189a80a56574cb16ae303b84c7724ade0cd0321a",
    "transactionIndex": "0x1a"
  }
]




pinata
https://app.pinata.cloud/ipfs/files

也可以用ipfs客户端上传： https://github.com/ipfs/ipfs-desktop/releases
https://docs.ipfs.tech/install/ipfs-desktop/#windows


https://docs.opensea.io/docs/metadata-standards
 */


