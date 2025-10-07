// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../TaxController.sol";

/**
 * @title TaxController 测试合约
 * @dev 全面测试分级税率系统的各种功能
 */
contract TaxControllerTest is Test {
    TaxController public taxController;
    address public owner;
    address public taxPool;
    address public user1;
    address public user2;
    
    // 测试用的税率级别
    TaxController.TaxTier[] public testTiers;

    function setUp() public {
        owner = address(this);
        taxPool = address(0x123);
        user1 = address(0x456);
        user2 = address(0x789);
        
        // 部署合约
        taxController = new TaxController(taxPool);
        
        // 初始化测试税率级别
        testTiers.push(TaxController.TaxTier(0, 1, "基础级别: 0-1000"));
        testTiers.push(TaxController.TaxTier(1000, 3, "中级级别: 1000-5000"));
        testTiers.push(TaxController.TaxTier(5000, 5, "高级级别: 5000-10000"));
        testTiers.push(TaxController.TaxTier(10000, 8, "顶级级别: 10000+"));
    }

    // ============ 基础功能测试 ============

    /**
     * @dev 测试合约部署和初始化
     */
    function test_ContractInitialization() public {
        // 验证所有者
        assertEq(taxController.owner(), owner);
        
        // 验证税收池地址
        assertEq(taxController.taxPool(), taxPool);
        
        // 验证初始税率级别数量
        uint256 tierCount = taxController.getTaxTierCount();
        assertEq(tierCount, 4);
        
        // 验证第一个税率级别
        (uint256 minAmount, uint256 feePercent, string memory description) = taxController.taxTiers(0);
        assertEq(minAmount, 0);
        assertEq(feePercent, 1);
        assertEq(keccak256(bytes(description)), keccak256(bytes("基础级别: 0-1000")));
    }

    /**
     * @dev 测试税费计算 - 基础级别
     */
    function test_CalculateTax_BasicTier() public {
        // 测试金额 500，应该适用 1% 税率
        (uint256 taxAmount, uint256 tierIndex) = taxController.calculateTax(500);
        
        assertEq(taxAmount, 5); // 500 * 1% = 5
        assertEq(tierIndex, 0); // 应该匹配第一个级别
    }

    /**
     * @dev 测试税费计算 - 中级级别
     */
    function test_CalculateTax_IntermediateTier() public {
        // 测试金额 1500，应该适用 3% 税率
        (uint256 taxAmount, uint256 tierIndex) = taxController.calculateTax(1500);
        
        assertEq(taxAmount, 45); // 1500 * 3% = 45
        assertEq(tierIndex, 1); // 应该匹配第二个级别
    }

    /**
     * @dev 测试税费计算 - 高级级别
     */
    function test_CalculateTax_AdvancedTier() public {
        // 测试金额 6000，应该适用 5% 税率
        (uint256 taxAmount, uint256 tierIndex) = taxController.calculateTax(6000);
        
        assertEq(taxAmount, 300); // 6000 * 5% = 300
        assertEq(tierIndex, 2); // 应该匹配第三个级别
    }

    /**
     * @dev 测试税费计算 - 顶级级别
     */
    function test_CalculateTax_TopTier() public {
        // 测试金额 20000，应该适用 8% 税率
        (uint256 taxAmount, uint256 tierIndex) = taxController.calculateTax(20000);
        
        assertEq(taxAmount, 1600); // 20000 * 8% = 1600
        assertEq(tierIndex, 3); // 应该匹配第四个级别
    }

    /**
     * @dev 测试边界值情况
     */
    function test_CalculateTax_BoundaryValues() public {
        // 测试正好在边界上的金额
        (uint256 taxAmount1, ) = taxController.calculateTax(1000); // 边界值
        (uint256 taxAmount2, ) = taxController.calculateTax(1001); // 超过边界
        
        assertEq(taxAmount1, 10); // 1000 * 1% = 10
        assertEq(taxAmount2, 30); // 1001 * 3% = 30.03，整数除法后为30
    }

    /**
     * @dev 测试零金额情况
     */
    function test_CalculateTax_ZeroAmount() public {
        // 测试金额为0
        (uint256 taxAmount, uint256 tierIndex) = taxController.calculateTax(0);
        
        assertEq(taxAmount, 0);
        assertEq(tierIndex, 0);
    }

    // ============ 应用税费测试 ============

    /**
     * @dev 测试应用税费功能
     */
    function test_ApplyTax() public {
        uint256 amount = 2000;
        
        // 预期结果：税费 = 2000 * 3% = 60，净额 = 2000 - 60 = 1940
        (uint256 netAmount, uint256 taxAmount) = taxController.applyTax(user1, amount);
        
        assertEq(netAmount, 1940);
        assertEq(taxAmount, 60);
    }

    /**
     * @dev 测试应用税费事件触发
     */
    function test_ApplyTax_EventEmission() public {
        uint256 amount = 5000;
        
        // 预期触发 TaxApplied 事件
        vm.expectEmit(true, true, true, true);
        emit TaxApplied(user1, amount, 250, 2); // 5000 * 5% = 250，第三个级别
        
        taxController.applyTax(user1, amount);
    }

    /**
     * @dev 测试零税费情况
     */
    function test_ApplyTax_ZeroTax() public {
        // 金额为0，应该没有税费
        (uint256 netAmount, uint256 taxAmount) = taxController.applyTax(user1, 0);
        
        assertEq(netAmount, 0);
        assertEq(taxAmount, 0);
    }

    /**
     * @dev 测试无效地址情况
     */
    function test_ApplyTax_InvalidAddress() public {
        // 测试零地址
        vm.expectRevert("Invalid from address");
        taxController.applyTax(address(0), 1000);
    }

    // ============ 税率级别管理测试 ============

    /**
     * @dev 测试添加税率级别
     */
    function test_AddTaxTier() public {
        uint256 initialCount = taxController.getTaxTierCount();
        
        // 添加新的税率级别
        taxController.addTaxTier(20000, 10, "超级级别: 20000+");
        
        uint256 newCount = taxController.getTaxTierCount();
        assertEq(newCount, initialCount + 1);
        
        // 验证新添加的级别
        (uint256 minAmount, uint256 feePercent, string memory description) = taxController.taxTiers(newCount - 1);
        assertEq(minAmount, 20000);
        assertEq(feePercent, 10);
        assertEq(keccak256(bytes(description)), keccak256(bytes("超级级别: 20000+")));
    }

    /**
     * @dev 测试添加税率级别的事件触发
     */
    function test_AddTaxTier_EventEmission() public {
        vm.expectEmit(true, true, true, true);
        emit TaxTierAdded(20000, 10, "测试级别");
        
        taxController.addTaxTier(20000, 10, "测试级别");
    }

    /**
     * @dev 测试添加无效税率级别（费率超过100%）
     */
    function test_AddTaxTier_InvalidFeePercent() public {
        vm.expectRevert("Fee percent cannot exceed 100");
        taxController.addTaxTier(20000, 101, "无效级别");
    }

    /**
     * @dev 测试添加非递增门槛金额
     */
    function test_AddTaxTier_NonIncreasingMinAmount() public {
        vm.expectRevert("Min amount must be greater than previous tier");
        taxController.addTaxTier(500, 2, "无效门槛"); // 500 < 最后一个级别的10000
    }

    /**
     * @dev 测试更新税率级别
     */
    function test_UpdateTaxTier() public {
        uint256 tierIndex = 1; // 更新第二个级别
        
        taxController.updateTaxTier(tierIndex, 1200, 4, "更新后的中级级别");
        
        // 验证更新结果
        (uint256 minAmount, uint256 feePercent, string memory description) = taxController.taxTiers(tierIndex);
        assertEq(minAmount, 1200);
        assertEq(feePercent, 4);
        assertEq(keccak256(bytes(description)), keccak256(bytes("更新后的中级级别")));
    }

    /**
     * @dev 测试更新无效的税率级别索引
     */
    function test_UpdateTaxTier_InvalidIndex() public {
        vm.expectRevert("Invalid tier index");
        taxController.updateTaxTier(10, 1200, 4, "无效索引");
    }

    /**
     * @dev 测试移除税率级别
     */
    function test_RemoveTaxTier() public {
        uint256 initialCount = taxController.getTaxTierCount();
        
        // 移除第二个级别
        taxController.removeTaxTier(1);
        
        uint256 newCount = taxController.getTaxTierCount();
        assertEq(newCount, initialCount - 1);
        
        // 验证级别被正确移除，数组重新排列
        (uint256 minAmount, , ) = taxController.taxTiers(1);
        assertEq(minAmount, 5000); // 原来的第三个级别现在应该在第二个位置
    }

    /**
     * @dev 测试移除最后一个税率级别（应该失败）
     */
    function test_RemoveTaxTier_LastTier() public {
        // 先移除到只剩一个级别
        taxController.removeTaxTier(3);
        taxController.removeTaxTier(2);
        taxController.removeTaxTier(1);
        
        // 尝试移除最后一个级别
        vm.expectRevert("Cannot remove the last tax tier");
        taxController.removeTaxTier(0);
    }

    /**
     * @dev 测试获取所有税率级别
     */
    function test_GetAllTaxTiers() public {
        TaxController.TaxTier[] memory tiers = taxController.getAllTaxTiers();
        
        assertEq(tiers.length, 4);
        assertEq(tiers[0].minAmount, 0);
        assertEq(tiers[1].minAmount, 1000);
        assertEq(tiers[2].minAmount, 5000);
        assertEq(tiers[3].minAmount, 10000);
    }

    // ============ 权限测试 ============

    /**
     * @dev 测试非所有者权限操作
     */
    function test_NonOwnerPermissions() public {
        // 切换到非所有者地址
        vm.startPrank(user1);
        
        // 测试添加税率级别
        vm.expectRevert("Only owner can call this function");
        taxController.addTaxTier(20000, 10, "测试");
        
        // 测试更新税率级别
        vm.expectRevert("Only owner can call this function");
        taxController.updateTaxTier(0, 100, 2, "测试");
        
        // 测试移除税率级别
        vm.expectRevert("Only owner can call this function");
        taxController.removeTaxTier(1);
        
        // 测试设置税收池地址
        vm.expectRevert("Only owner can call this function");
        taxController.setTaxPool(user2);
        
        vm.stopPrank();
    }

    /**
     * @dev 测试设置税收池地址
     */
    function test_SetTaxPool() public {
        address newTaxPool = address(0x999);
        
        taxController.setTaxPool(newTaxPool);
        
        assertEq(taxController.taxPool(), newTaxPool);
    }

    /**
     * @dev 测试设置无效的税收池地址
     */
    function test_SetTaxPool_InvalidAddress() public {
        vm.expectRevert("Invalid tax pool address");
        taxController.setTaxPool(address(0));
    }

    // ============ 集成测试 ============

    /**
     * @dev 测试完整的工作流程
     */
    function test_CompleteWorkflow() public {
        // 1. 添加新的税率级别
        taxController.addTaxTier(20000, 12, "新的顶级级别");
        
        // 2. 验证新级别生效
        (uint256 taxAmount, ) = taxController.calculateTax(25000);
        assertEq(taxAmount, 3000); // 25000 * 12% = 3000
        
        // 3. 更新现有级别
        taxController.updateTaxTier(0, 500, 2, "更新的基础级别");
        
        // 4. 验证更新生效
        (uint256 taxAmount2, ) = taxController.calculateTax(500);
        assertEq(taxAmount2, 10); // 500 * 2% = 10
        
        // 5. 移除一个级别
        taxController.removeTaxTier(2);
        
        // 6. 验证移除后的计算
        (uint256 taxAmount3, ) = taxController.calculateTax(7000);
        assertEq(taxAmount3, 840); // 7000 * 12% = 840（现在匹配新的顶级级别）
        
        // 7. 设置新的税收池
        address newPool = address(0x888);
        taxController.setTaxPool(newPool);
        assertEq(taxController.taxPool(), newPool);
    }

    /**
     * @dev 测试大量交易的计算性能
     */
    function test_Performance() public {
        uint256[] memory testAmounts = new uint256[](10);
        testAmounts[0] = 100;
        testAmounts[1] = 500;
        testAmounts[2] = 1200;
        testAmounts[3] = 3000;
        testAmounts[4] = 6000;
        testAmounts[5] = 8000;
        testAmounts[6] = 12000;
        testAmounts[7] = 20000;
        testAmounts[8] = 50000;
        testAmounts[9] = 100000;
        
        for (uint256 i = 0; i < testAmounts.length; i++) {
            (uint256 taxAmount, ) = taxController.calculateTax(testAmounts[i]);
            assertTrue(taxAmount < testAmounts[i]); // 税费应该总是小于原金额
        }
    }
}

// ============ Fuzz 测试 ============

/**
 * @dev 模糊测试合约
 */
contract TaxControllerFuzzTest is Test {
    TaxController public taxController;
    address public taxPool = address(0x123);
    
    function setUp() public {
        taxController = new TaxController(taxPool);
    }
    
    /**
     * @dev 模糊测试税费计算
     * @param amount 随机金额
     */
    function testFuzz_CalculateTax(uint256 amount) public {
        // 限制金额范围以避免溢出
        vm.assume(amount <= 1_000_000_000 * 10**18); // 假设最大金额为10亿个代币
        
        (uint256 taxAmount, uint256 tierIndex) = taxController.calculateTax(amount);
        
        // 验证基本属性
        assertTrue(taxAmount <= amount); // 税费不能超过金额
        assertTrue(tierIndex < 4); // 级别索引应该在有效范围内
        
        // 验证税费计算的正确性
        if (amount == 0) {
            assertEq(taxAmount, 0);
        }
    }
    
    /**
     * @dev 模糊测试应用税费
     * @param amount 随机金额
     */
    function testFuzz_ApplyTax(uint256 amount) public {
        // 限制金额范围
        vm.assume(amount <= 1_000_000_000 * 10**18);
        vm.assume(amount > 0); // 确保金额大于0
        
        address testUser = address(0x456);
        
        (uint256 netAmount, uint256 taxAmount) = taxController.applyTax(testUser, amount);
        
        // 验证基本属性
        assertEq(netAmount + taxAmount, amount); // 净额 + 税费应该等于原金额
        assertTrue(netAmount > 0); // 净额应该大于0
        assertTrue(taxAmount >= 0); // 税费应该大于等于0
    }
}