

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/*
引用类型包括结构体（struct）、数组（array）和映射（mapping）。
引用类型在赋值时不会直接复制值，而是创建一个指向原数据的引用。
这样可以避免对大型数据的多次拷贝，节省 Gas。
*/

/*
1.对于纯计算函数，使用 memory返回临时数组是安全的
2.如果需要保持数组状态，应该使用 storage
3.大型数组考虑使用 storage而不是 memory以避免高 gas 消耗
*/

// string 不支持使用下标索引进行访问，需要先转换为 bytes 类型，而 bytes 类型本身是支持下标索引访问的。
// 使用长度受限的字节数组时，建议使用 bytes1 到 bytes32 类型，以减少 gas 费用

contract MappingExample {
    mapping(address => uint256) public balances;

    function update(uint256 newBalance) public {
        balances[msg.sender] = newBalance;
        // msg.data
        // msg.gas
        // msg.sig
        // msg.value
        // msg.sender
    }

    struct CustomType {
        bool myBool;
        uint256 myInt;
    }

    struct CustomType2 {
        CustomType[] cts; // 包含其他结构体
        mapping(string => CustomType2) indexs;
    }
    // 状态变量初始化
    CustomType ct1 = CustomType(true, 2);

    // 在函数内初始化
    // CustomType memory ct2 = CustomType(true, 2);
    // 具名方式初始化 不需要按照成员顺序 可以自由选择初始化的顺序，但必须忽略mapping类型的成员。
    // CustomType memory ct = CustomType({ myBool: true, myInt: 2 });

    // assert 失败时会消耗掉所有的剩余 Gas，而 require 则会返还剩余的 Gas 给调用者
    // assert：用于检查合约内部逻辑的错误或不应该发生的情况，通常在函数末尾或状态更改之后使用。
    // require：用于检查输入参数、外部调用返回值等，通常在函数开头使用。
    // assert 用于校验内部问题，require 用于校验外部问题， 
}


// 接口（Interface）
// 接口主要用于标准化不同合约之间的交互，它定义了合约之间的行为协议
// 无法继承其他合约或接口：接口不能扩展其他合约或接口。
// 无法定义构造函数：接口不允许定义任何构造函数，因为它不能有内部状态。
// 无法定义状态变量：接口不能有状态变量，因为它不存储数据。
// 无法定义结构体或枚举：接口不能包含结构体或枚举。
// 接口的语法 所有函数默认为 external，且不带实现。


// 合约之间通过接口进行通信