// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../MultisigProtected.sol";

/**
 * @title 批量交易处理器测试合约
 * @dev 使用Foundry测试框架进行全方位测试
 */
contract MulticallProcessorTest is Test {
    MulticallProcessor public multicallProcessor;
    AdvancedMulticallProcessor public advancedProcessor;
    
    address testUser = address(0x123);
    address testUser2 = address(0x456);
    
    // 测试前置设置
    function setUp() public {
        // 部署合约
        multicallProcessor = new MulticallProcessor();
        advancedProcessor = new AdvancedMulticallProcessor();
        
        // 给测试用户分配ETH
        vm.deal(testUser, 100 ether);
        vm.deal(testUser2, 50 ether);
    }
    
    /**
     * @dev 测试基本批量交易功能
     */
    function test_BasicMulticall() public {
        vm.startPrank(testUser);
        
        // 准备批量交易数据
        bytes[] memory calls = new bytes[](3);
        
        // 调用1: 存款 1 ETH
        calls[0] = abi.encodeWithSignature("deposit()");
        
        // 调用2: 设置数值
        calls[1] = abi.encodeWithSignature("setValue(uint256)", 42);
        
        // 调用3: 获取余额
        calls[2] = abi.encodeWithSignature("getBalance()");
        
        // 执行批量交易，附带1 ETH用于存款
        bytes[] memory results = multicallProcessor.multicall{value: 1 ether}(calls);
        
        // 验证结果
        assertEq(results.length, 3, "应该返回3个结果");
        
        // 验证存款成功（合约余额应为1 ETH）
        uint256 contractBalance = multicallProcessor.getBalance();
        assertEq(contractBalance, 1 ether, "合约余额应为1 ETH");
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试原子性 - 一个失败应该导致全部回滚
     */
    function test_Atomicity() public {
        vm.startPrank(testUser);
        
        bytes[] memory calls = new bytes[](2);
        
        // 第一个调用：正常存款
        calls[0] = abi.encodeWithSignature("deposit()");
        
        // 第二个调用：无效函数（应该失败）
        calls[1] = abi.encodeWithSignature("nonExistentFunction()");
        
        // 应该回滚，因为第二个调用失败
        vm.expectRevert("Multicall failed: atomic execution required");
        multicallProcessor.multicall{value: 1 ether}(calls);
        
        // 验证没有存款成功（原子性）
        uint256 contractBalance = multicallProcessor.getBalance();
        assertEq(contractBalance, 0, "合约余额应为0，因为交易回滚");
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试高级处理器的灵活批量交易
     */
    function test_AdvancedMulticall() public {
        vm.startPrank(testUser);
        
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSignature("deposit()");
        calls[1] = abi.encodeWithSignature("setValue(uint256)", 100);
        calls[2] = abi.encodeWithSignature("getUserBalance(address)", testUser);
        
        // 执行批量交易，不要求全部成功
        (bytes[] memory results, bool[] memory successes) = 
            advancedProcessor.flexibleMulticall{value: 1 ether}(calls, false);
        
        // 验证结果
        assertEq(results.length, 3);
        assertEq(successes.length, 3);
        assertTrue(successes[0], "存款应该成功");
        assertTrue(successes[1], "设置数值应该成功");
        assertTrue(successes[2], "获取余额应该成功");
        
        // 验证存款确实成功
        uint256 userBalance = advancedProcessor.getUserBalance(testUser);
        assertEq(userBalance, 1 ether, "用户余额应为1 ETH");
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试部分失败的批量交易
     */
    function test_PartialFailure() public {
        vm.startPrank(testUser);
        
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSignature("deposit()"); // 成功
        calls[1] = abi.encodeWithSignature("invalidFunction()"); // 失败
        calls[2] = abi.encodeWithSignature("getUserBalance(address)", testUser); // 成功
        
        // 当不要求全部成功时，应该继续执行
        (bytes[] memory results, bool[] memory successes) = 
            advancedProcessor.flexibleMulticall{value: 1 ether}(calls, false);
        
        assertTrue(successes[0], "第一个调用应该成功");
        assertFalse(successes[1], "第二个调用应该失败");
        assertTrue(successes[2], "第三个调用应该成功");
        
        // 验证存款仍然成功
        uint256 userBalance = advancedProcessor.getUserBalance(testUser);
        assertEq(userBalance, 1 ether, "即使有失败调用，存款也应该成功");
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试要求全部成功时的行为
     */
    function test_RequireAllSuccess() public {
        vm.startPrank(testUser);
        
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSignature("deposit()");
        calls[1] = abi.encodeWithSignature("invalidFunction()"); // 这个会失败
        
        // 当要求全部成功时，应该回滚
        vm.expectRevert();
        advancedProcessor.flexibleMulticall{value: 1 ether}(calls, true);
        
        // 验证没有状态改变
        uint256 userBalance = advancedProcessor.getUserBalance(testUser);
        assertEq(userBalance, 0, "用户余额应为0，因为交易回滚");
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试 Gas 消耗优化
     */
    function test_GasOptimization() public {
        vm.startPrank(testUser);
        
        bytes[] memory singleCall = new bytes[](1);
        singleCall[0] = abi.encodeWithSignature("deposit()");
        
        bytes[] memory multipleCalls = new bytes[](3);
        multipleCalls[0] = abi.encodeWithSignature("deposit()");
        multipleCalls[1] = abi.encodeWithSignature("setValue(uint256)", 1);
        multipleCalls[2] = abi.encodeWithSignature("setValue(uint256)", 2);
        
        // 测量单个交易的Gas消耗
        uint256 gasBeforeSingle = gasleft();
        multicallProcessor.multicall{value: 1 ether}(singleCall);
        uint256 gasUsedSingle = gasBeforeSingle - gasleft();
        
        // 测量批量交易的Gas消耗
        uint256 gasBeforeBatch = gasleft();
        multicallProcessor.multicall{value: 1 ether}(multipleCalls);
        uint256 gasUsedBatch = gasBeforeBatch - gasleft();
        
        console.log("单次交易Gas消耗:", gasUsedSingle);
        console.log("批量交易Gas消耗:", gasUsedBatch);
        console.log("Gas节省比例:", ((gasUsedSingle * 3) - gasUsedBatch) * 100 / (gasUsedSingle * 3), "%");
        
        // 批量交易应该比单独执行3次更省Gas
        assertLt(gasUsedBatch, gasUsedSingle * 3, "批量交易应该更省Gas");
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试边界情况 - 空数组
     */
    function test_EmptyArray() public {
        vm.startPrank(testUser);
        
        bytes[] memory emptyCalls = new bytes[](0);
        
        bytes[] memory results = multicallProcessor.multicall(emptyCalls);
        
        assertEq(results.length, 0, "空输入应该返回空结果");
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试重入攻击防护
     */
    function test_ReentrancyProtection() public {
        // 部署恶意合约尝试重入攻击
        MaliciousContract malicious = new MaliciousContract(address(advancedProcessor));
        vm.deal(address(malicious), 10 ether);
        
        // 尝试攻击
        vm.expectRevert(); // 应该失败
        malicious.attack();
    }
    
    /**
     * @dev 测试事件日志
     */
    function test_EventLogging() public {
        vm.startPrank(testUser);
        
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSignature("deposit()");
        calls[1] = abi.encodeWithSignature("setValue(uint256)", 999);
        
        // 检查事件是否被触发
        vm.expectEmit(true, true, true, true);
        emit MulticallExecuted(testUser, 2, true);
        
        multicallProcessor.multicall{value: 1 ether}(calls);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试大容量批量交易
     */
    function test_LargeBatch() public {
        vm.startPrank(testUser);
        
        // 创建大量调用（测试Gas限制）
        uint256 callCount = 10;
        bytes[] memory calls = new bytes[](callCount);
        
        for (uint256 i = 0; i < callCount; i++) {
            calls[i] = abi.encodeWithSignature("setValue(uint256)", i);
        }
        
        bytes[] memory results = multicallProcessor.multicall(calls);
        
        assertEq(results.length, callCount, "应该返回正确数量的结果");
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试取款功能
     */
    function test_WithdrawFunction() public {
        vm.startPrank(testUser);
        
        // 先存款
        advancedProcessor.deposit{value: 2 ether}();
        
        // 准备取款调用
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("withdraw(uint256)", 1 ether);
        
        uint256 balanceBefore = testUser.balance;
        
        // 执行取款
        advancedProcessor.flexibleMulticall(calls, true);
        
        uint256 balanceAfter = testUser.balance;
        
        // 验证余额增加（减去交易费用）
        assertGt(balanceAfter, balanceBefore, "取款后余额应该增加");
        
        // 验证合约内余额减少
        uint256 remainingBalance = advancedProcessor.getUserBalance(testUser);
        assertEq(remainingBalance, 1 ether, "合约内剩余余额应为1 ETH");
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试权限控制
     */
    function test_Ownership() public {
        // 只有owner可以转移所有权
        vm.prank(testUser);
        vm.expectRevert("Only owner can call this function");
        advancedProcessor.transferOwnership(testUser2);
        
        // owner可以成功转移
        advancedProcessor.transferOwnership(testUser2);
        assertEq(advancedProcessor.owner(), testUser2, "所有权应该转移");
    }
}

/**
 * @title 恶意合约 - 用于测试重入攻击
 */
contract MaliciousContract {
    AdvancedMulticallProcessor public target;
    bool private attacked;
    
    constructor(address _target) {
        target = AdvancedMulticallProcessor(_target);
    }
    
    function attack() external payable {
        // 尝试在调用过程中进行重入攻击
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSignature("deposit()");
        calls[1] = abi.encodeWithSignature("withdraw(uint256)", 1 ether);
        
        // 这会失败，因为我们的合约没有重入保护漏洞
        target.flexibleMulticall{value: 1 ether}(calls, true);
        attacked = true;
    }
    
    receive() external payable {
        // 如果发生重入，这个函数会被调用
        if (!attacked) {
            // 尝试在接收ETH时再次调用（重入攻击）
            attack();
        }
    }
}

/**
 * @title 集成测试 - 模拟真实使用场景
 */
contract MulticallIntegrationTest is Test {
    AdvancedMulticallProcessor public processor;
    
    address user1 = address(0x1);
    address user2 = address(0x2);
    
    function setUp() public {
        processor = new AdvancedMulticallProcessor();
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }
    
    /**
     * @dev 模拟DeFi场景：授权、存款、交易
     */
    function test_DeFiScenario() public {
        vm.startPrank(user1);
        
        // 模拟典型的DeFi操作序列
        bytes[] memory defiOperations = new bytes[](3);
        
        // 1. 存款
        defiOperations[0] = abi.encodeWithSignature("deposit()");
        
        // 2. 设置交易参数
        defiOperations[1] = abi.encodeWithSignature("setValue(uint256)", 1000);
        
        // 3. 检查余额
        defiOperations[2] = abi.encodeWithSignature("getUserBalance(address)", user1);
        
        // 执行所有操作
        (bytes[] memory results, bool[] memory successes) = 
            processor.flexibleMulticall{value: 5 ether}(defiOperations, true);
        
        // 验证所有操作成功
        for (uint i = 0; i < successes.length; i++) {
            assertTrue(successes[i], "所有DeFi操作都应该成功");
        }
        
        // 验证最终状态
        uint256 finalBalance = processor.getUserBalance(user1);
        assertEq(finalBalance, 5 ether, "最终余额应该正确");
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试并发用户场景
     */
    function test_ConcurrentUsers() public {
        // 用户1的操作
        vm.prank(user1);
        bytes[] memory user1Calls = new bytes[](2);
        user1Calls[0] = abi.encodeWithSignature("deposit()");
        user1Calls[1] = abi.encodeWithSignature("setValue(uint256)", 100);
        processor.flexibleMulticall{value: 3 ether}(user1Calls, true);
        
        // 用户2的操作
        vm.prank(user2);
        bytes[] memory user2Calls = new bytes[](2);
        user2Calls[0] = abi.encodeWithSignature("deposit()");
        user2Calls[1] = abi.encodeWithSignature("setValue(uint256)", 200);
        processor.flexibleMulticall{value: 7 ether}(user2Calls, true);
        
        // 验证各自余额独立
        assertEq(processor.getUserBalance(user1), 3 ether, "用户1余额正确");
        assertEq(processor.getUserBalance(user2), 7 ether, "用户2余额正确");
    }
}