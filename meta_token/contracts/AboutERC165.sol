// SPDX-License-Identifier: MIT

pragma solidity >=0.4.16;


// 标准化的方法来检测一个合约支持什么功能

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns(bool);
}


// solidity ^0.8.20;
abstract contract ERC165 is IERC165{
    function supportsInterface(bytes4 interfaceId) public view virtual returns(bool){
        return interfaceId == type(IERC165).interfaceId;
        /*
            interfaceId == type(IERC165).interfaceId || // 首先检查是否是 ERC-165 本身
            interfaceId == type(IMyOtherInterface).interfaceId || // 然后检查它实现的其他接口
            interfaceId == 0xabcdef12; // 或者直接使用硬编码的 interfaceId
        */
    }
}


// 提供一个安全、批量且 gas 高效的方法来检查任意合约地址是否支持特定的接口

// 安全性第一：优先处理低级调用（low-level call）可能失败的所有边缘情况（如非合约地址、调用耗尽 gas、调用 revert），而不是让这些情况导致调用者 revert。
// 批量操作：提供批量查询功能，在一次调用中检查多个接口，节省 gas（避免了重复的基础检查）。
// gas 效率：使用内联汇编（Yul）进行精确的低级调用，严格控制 gas 并手动处理返回数据。
// 实用性：提供不同颗粒度的函数，从检查单个接口到检查接口列表，满足各种应用场景。

library ERC165Checker{
    // 无效接口ID,任何检查都必须返回false
    bytes4 private constant INTERFACE_ID_INVALID = 0xffffffff;

    function supportsERC165InterfaceUnchecked(address account, bytes4 interfaceId) internal view returns(bool){
        (bool success, bool supported) = _trySupportsInterface(account, interfaceId);
        return success && supported;
    }

    function supportsERC165(address account) internal view returns(bool){
        if(supportsERC165InterfaceUnchecked(account, type(IERC165).interfaceId)){
            (bool success, bool supported) = _trySupportsInterface(account, INTERFACE_ID_INVALID);
            return success && !supported;
        }else{
            return false;
        }
    }



    function _trySupportsInterface(address account, bytes4 interfaceId) private view returns(bool success, bool supported){
        // 函数签名是函数名称和参数类型的字符串表示  ---->  "supportsInterface(bytes4)"
        // selector（函数选择器）是一个函数签名的唯一标识符
        // keccak256("supportsInterface(bytes4)")  ---->   0x01ffc9a7 前4字节
        bytes4 selector = IERC165.supportsInterface.selector;
        assembly ("memory-safe") {
            mstore(0x00, selector)
            mstore(0x04, interfaceId)  // 在 0x04 处放置 interfaceId 也就是要查询的 interfaceId 参数
            // 静态调用：使用 staticcall，确保这个查询操作是只读的，不会改变任何状态，绝对安全
            // 调用必须低于 30,000 gas
            // 执行 staticcall
            // 调用数据从内存 0x00 开始，总长度为 0x24 (36) 字节：
            // 4字节(selector) + 4字节(interfaceId) + 28字节填充(padding) = 36字节 (EVM操作码要求32字节对齐)
            success := staticcall(30000, account, 0x00, 0x24, 0x00, 0x20)   
            // returndatasize() > 0x1F 确保至少有 32 字节数据，mload(0x00) 读取返回数据
            supported := and( gt(returndatasize(), 0x1F), iszero(iszero(mload(0x00))))
        }
        /* staticcall(30000, account, 0x00, 0x24, 0x00, 0x20)  
            gasLimit	30000	分配给这次调用的最大 gas 数量。
            target	account	要调用（查询）的合约地址。
            inputOffset	0x00	内存中输入数据（calldata） 的起始位置。
            inputSize	0x24 (36 字节)	输入数据的长度。
            outputOffset	0x00	在内存中存放返回数据的起始位置。
            outputSize	0x20 (32 字节)	期望的返回数据的长度。
        */
    }
}
