// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;



contract ABI{

    function getSelector() public pure returns(bytes4){
        return msg.sig;  // 返回函数签名
    }

    // 获取函数返回器
    function computeSelector(string memory func) public pure returns(bytes4){
        return bytes4(keccak256(bytes(func)));
    }


    /*
        函数选择器
    */
    function transfer(address addr, uint256 amount) public pure returns(bytes memory) {
        return msg.data;
    }

    function encodeFunctionCall() public pure returns(bytes memory) {
        return abi.encodeWithSignature("transfer(address,uint256)", 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 100);
    }
}