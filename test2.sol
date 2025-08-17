


// SPDX-License-Identifier: MIT
// pragma solidity ^0.8.26;   // 第一个0是固定的， 后两位可以改
// pragma solidity ~0.8.26;   // 前2位固定 第三位可以修改  也就是大于等于0.8.0
pragma solidity >=0.8.26 <=0.9.0;


contract Hello3Dot0{
    string public hello = "hello world";
    int public account = 1 * 2 ** 255 - 1;  // 最大值
    int public account2 = -1 * 2 ** 255;  // 最大值
    uint public a2 = 1 * 2 ** 256 - 1;      // 最大值
    bool public b1 = true;
    // Type(int).min
    // require(a>b); 条件检查不满足抛出异常

    // address 用于 如白名单机制、支付合约等
    address public addr = 0xd96AF416b2060500f828A3f31e617F15CBEA1e4b;
    // addr = msg.sender;
    address public addr2 = 0x1234567890123456789012345678901234567890;

    // address 类型不能接收以太币， 但是payable 可以接收以太币
    address payable paddr = payable(addr);
    uint256 balance = paddr.balance;
    bool success = paddr.send(1 ether); //  由于没有自动回退机制，不推荐
    // paddr.transfer(1); // 转移 1 以太币
    // bool success2 = paddr.call{};

    // 白名单
    mapping(address => bool) public whitelist;

    // 会自动补全位数
    // bytes2 b2 = 0x1000;  // 使用 0x... 格式（不带 hex 和引号）
    bytes2 b2 = hex"1000";  // 使用 hex"..." 格式（不带 0x）

    enum Status {  // 美剧不能声明public
        ACTIVE,
        INACTIVE
    }

    int [] arr;  // 变量做位合约状态不能赋值

    struct Person{
        uint8 age;
        bool sex;
        string name;
    }

    Person public zood = Person(15, false, "zood");

    // bytes32 hash = block.blockhash(100);  返回指定区块的哈希值
}