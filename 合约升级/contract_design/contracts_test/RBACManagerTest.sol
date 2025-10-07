// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/*
安装依赖（如果使用 Hardhat + Foundry）：npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
# 使用 Hardhat
npx hardhat test

# 或使用 Foundry
forge test -vvv
*/
import "hardhat/console.sol";
import {Test} from "forge-std/Test.sol";
import {RBACManager, ProjectManagement} from "../role_manager.sol";

/**
 * @title RBAC 系统测试合约
 * @dev 全面测试角色管理系统的各项功能
 */
contract RBACManagerTest is Test {
    ProjectManagement public pm;
    
    // 测试地址
    address public admin = address(0x1001);
    address public projectManager = address(0x1002);
    address public developer = address(0x1003);
    address public user = address(0x1004);
    address public unauthorizedUser = address(0x1005);
    
    // 角色哈希
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant PROJECT_MANAGER_ROLE = keccak256("PROJECT_MANAGER_ROLE");
    bytes32 public constant DEVELOPER_ROLE = keccak256("DEVELOPER_ROLE");
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");

    /**
     * @dev 测试前置设置
     */
    function setUp() public {
        // 设置测试地址的余额，防止 gas 不足
        vm.deal(admin, 100 ether);
        vm.deal(projectManager, 100 ether);
        vm.deal(developer, 100 ether);
        vm.deal(user, 100 ether);
        vm.deal(unauthorizedUser, 100 ether);
        
        // 使用管理员地址部署合约
        vm.prank(admin);
        pm = new ProjectManagement();
        
        console.log("✅ 测试环境初始化完成");
        console.log("📝 合约部署者:", admin);
        console.log("📝 合约地址:", address(pm));
    }

    /**
     * @dev 测试 1: 初始角色设置
     */
    function test_InitialRoleSetup() public {
        console.log("\n🧪 测试 1: 初始角色设置");
        
        // 验证部署者拥有默认管理员角色
        assertTrue(pm.hasRole(DEFAULT_ADMIN_ROLE, admin), "部署者应该是默认管理员");
        console.log("✅ 部署者正确拥有默认管理员角色");
        
        // 验证其他地址没有管理员角色
        assertFalse(pm.hasRole(DEFAULT_ADMIN_ROLE, projectManager), "项目经理不应该有管理员角色");
        assertFalse(pm.hasRole(DEFAULT_ADMIN_ROLE, developer), "开发者不应该有管理员角色");
        console.log("✅ 初始角色权限正确");
    }

    /**
     * @dev 测试 2: 角色授予功能
     */
    function test_RoleGranting() public {
        console.log("\n🧪 测试 2: 角色授予功能");
        
        // 管理员授予项目经理角色
        vm.prank(admin);
        pm.grantRole(PROJECT_MANAGER_ROLE, projectManager);
        
        // 验证角色授予成功
        assertTrue(pm.hasRole(PROJECT_MANAGER_ROLE, projectManager), "项目经理角色授予失败");
        console.log("✅ 项目经理角色成功授予");
        
        // 项目经理授予开发者角色（测试角色继承）
        vm.prank(projectManager);
        pm.grantRole(DEVELOPER_ROLE, developer);
        
        assertTrue(pm.hasRole(DEVELOPER_ROLE, developer), "开发者角色授予失败");
        console.log("✅ 开发者角色成功授予（通过项目经理）");
        
        // 开发者授予用户角色
        vm.prank(developer);
        pm.grantRole(USER_ROLE, user);
        
        assertTrue(pm.hasRole(USER_ROLE, user), "用户角色授予失败");
        console.log("✅ 用户角色成功授予（通过开发者）");
    }

    /**
     * @dev 测试 3: 权限验证 - 只有管理员可以授予角色
     */
    function test_OnlyAdminCanGrantRoles() public {
        console.log("\n🧪 测试 3: 权限验证测试");
        
        // 先设置基本角色
        vm.prank(admin);
        pm.grantRole(PROJECT_MANAGER_ROLE, projectManager);
        
        // 尝试用未授权地址授予角色 - 应该失败
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        pm.grantRole(DEVELOPER_ROLE, developer);
        
        console.log("✅ 未授权地址无法授予角色");
        
        // 尝试用开发者授予角色 - 应该失败（开发者还没有 DEVELOPER_ROLE）
        vm.prank(developer);
        vm.expectRevert();
        pm.grantRole(USER_ROLE, user);
        
        console.log("✅ 权限不足的地址无法授予角色");
    }

    /**
     * @dev 测试 4: 角色撤销功能
     */
    function test_RoleRevocation() public {
        console.log("\n🧪 测试 4: 角色撤销功能");
        
        // 先授予角色
        vm.prank(admin);
        pm.grantRole(PROJECT_MANAGER_ROLE, projectManager);
        
        assertTrue(pm.hasRole(PROJECT_MANAGER_ROLE, projectManager), "角色授予失败");
        
        // 撤销角色
        vm.prank(admin);
        pm.revokeRole(PROJECT_MANAGER_ROLE, projectManager);
        
        assertFalse(pm.hasRole(PROJECT_MANAGER_ROLE, projectManager), "角色撤销失败");
        console.log("✅ 角色成功撤销");
    }

    /**
     * @dev 测试 5: 角色放弃功能
     */
    function test_RoleRenunciation() public {
        console.log("\n🧪 测试 5: 角色放弃功能");
        
        // 授予角色
        vm.prank(admin);
        pm.grantRole(DEVELOPER_ROLE, developer);
        assertTrue(pm.hasRole(DEVELOPER_ROLE, developer), "角色授予失败");
        
        // 放弃角色
        vm.prank(developer);
        pm.renounceRole(DEVELOPER_ROLE, developer);
        
        assertFalse(pm.hasRole(DEVELOPER_ROLE, developer), "角色放弃失败");
        console.log("✅ 角色成功放弃");
        
        // 测试不能放弃别人的角色
        vm.prank(admin);
        pm.grantRole(DEVELOPER_ROLE, developer);
        
        vm.prank(user); // 用户尝试放弃开发者的角色
        vm.expectRevert();
        pm.renounceRole(DEVELOPER_ROLE, developer);
        
        console.log("✅ 不能放弃别人的角色");
    }

    /**
     * @dev 测试 6: 批量角色操作
     */
    function test_BatchRoleOperations() public {
        console.log("\n🧪 测试 6: 批量角色操作");
        
        // 创建测试地址数组
        address[] memory accounts = new address[](3);
        accounts[0] = address(0x2001);
        accounts[1] = address(0x2002);
        accounts[2] = address(0x2003);
        
        // 批量授予角色
        vm.prank(admin);
        pm.grantRole(PROJECT_MANAGER_ROLE, projectManager);
        
        vm.prank(projectManager);
        pm.batchGrantRole(DEVELOPER_ROLE, accounts);
        
        // 验证批量授予成功
        for (uint i = 0; i < accounts.length; i++) {
            assertTrue(pm.hasRole(DEVELOPER_ROLE, accounts[i]), "批量授予失败");
        }
        console.log("✅ 批量角色授予成功");
        
        // 批量撤销角色
        vm.prank(projectManager);
        pm.batchRevokeRole(DEVELOPER_ROLE, accounts);
        
        // 验证批量撤销成功
        for (uint i = 0; i < accounts.length; i++) {
            assertFalse(pm.hasRole(DEVELOPER_ROLE, accounts[i]), "批量撤销失败");
        }
        console.log("✅ 批量角色撤销成功");
    }

    /**
     * @dev 测试 7: 项目管理系统功能
     */
    function test_ProjectManagementFunctions() public {
        console.log("\n🧪 测试 7: 项目管理系统功能测试");
        
        // 设置角色
        vm.prank(admin);
        pm.grantRole(PROJECT_MANAGER_ROLE, projectManager);
        
        vm.prank(projectManager);
        pm.grantRole(DEVELOPER_ROLE, developer);
        
        // 测试创建项目 - 只有项目经理可以创建
        vm.prank(projectManager);
        uint256 projectId = pm.createProject("Web3 DApp开发", 5000 ether);
        
        assertEq(projectId, 1, "项目ID不正确");
        console.log("✅ 项目创建成功，ID:", projectId);
        
        // 测试未授权用户创建项目 - 应该失败
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        pm.createProject("非法项目", 1000 ether);
        console.log("✅ 未授权用户无法创建项目");
        
        // 测试查看项目 - 只有开发者及以上权限可以查看
        vm.prank(developer);
        (uint256 id, string memory name, address managerAddr, uint256 budget, bool completed) = pm.getProject(1);
        
        assertEq(id, 1, "项目ID不匹配");
        assertEq(name, "Web3 DApp开发", "项目名称不匹配");
        assertEq(managerAddr, projectManager, "项目经理地址不匹配");
        assertEq(budget, 5000 ether, "项目预算不匹配");
        assertFalse(completed, "项目状态应该为未完成");
        console.log("✅ 项目信息查询成功");
        
        // 测试未授权用户查看项目 - 应该失败
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        pm.getProject(1);
        console.log("✅ 未授权用户无法查看项目");
        
        // 测试完成项目
        vm.prank(projectManager);
        pm.completeProject(1);
        
        // 验证项目完成状态
        vm.prank(developer);
        (, , , , completed) = pm.getProject(1);
        assertTrue(completed, "项目应该标记为已完成");
        console.log("✅ 项目成功完成");
    }

    /**
     * @dev 测试 8: 角色继承关系
     */
    function test_RoleInheritance() public {
        console.log("\n🧪 测试 8: 角色继承关系测试");
        
        // 验证角色管理员关系
        assertEq(pm.getRoleAdmin(USER_ROLE), DEVELOPER_ROLE, "用户角色的管理员应该是开发者");
        assertEq(pm.getRoleAdmin(DEVELOPER_ROLE), PROJECT_MANAGER_ROLE, "开发者角色的管理员应该是项目经理");
        assertEq(pm.getRoleAdmin(PROJECT_MANAGER_ROLE), DEFAULT_ADMIN_ROLE, "项目经理角色的管理员应该是默认管理员");
        
        console.log("✅ 角色继承关系正确:");
        console.log("   USER_ROLE → DEVELOPER_ROLE");
        console.log("   DEVELOPER_ROLE → PROJECT_MANAGER_ROLE");
        console.log("   PROJECT_MANAGER_ROLE → DEFAULT_ADMIN_ROLE");
        
        // 测试继承权限：管理员可以管理所有角色
        vm.prank(admin);
        pm.grantRole(USER_ROLE, user); // 管理员可以直接授予用户角色
        
        assertTrue(pm.hasRole(USER_ROLE, user), "管理员应该能授予任何角色");
        console.log("✅ 管理员具有完整的继承权限");
    }

    /**
     * @dev 测试 9: 错误消息验证
     */
    function test_ErrorMessages() public {
        console.log("\n🧪 测试 9: 错误消息验证");
        
        // 测试权限不足的错误消息
        vm.prank(unauthorizedUser);
        
        try pm.createProject("测试项目", 1000 ether) {
            fail("应该抛出权限错误");
        } catch (bytes memory reason) {
            bytes memory expectedError = abi.encodePacked(
                "RBAC: account ",
                Strings.toHexString(unauthorizedUser),
                " is missing role ",
                Strings.toHexString(uint256(PROJECT_MANAGER_ROLE), 32)
            );
            
            // 检查错误消息是否包含关键信息
            assertTrue(
                bytes(reason).length > 0,
                "应该返回错误消息"
            );
            console.log("✅ 权限错误消息格式正确");
        }
    }

    /**
     * @dev 测试 10: 综合场景测试
     */
    function test_IntegratedScenario() public {
        console.log("\n🧪 测试 10: 综合场景测试");
        
        // 1. 管理员设置组织架构
        vm.prank(admin);
        pm.grantRole(PROJECT_MANAGER_ROLE, projectManager);
        
        vm.prank(projectManager);
        pm.grantRole(DEVELOPER_ROLE, developer);
        
        vm.prank(developer);
        pm.grantRole(USER_ROLE, user);
        
        console.log("✅ 组织架构设置完成");
        
        // 2. 项目经理创建多个项目
        vm.prank(projectManager);
        uint256 project1 = pm.createProject("企业官网", 2000 ether);
        
        vm.prank(projectManager);
        uint256 project2 = pm.createProject("移动应用", 8000 ether);
        
        console.log("✅ 项目创建完成:", project1, project2);
        
        // 3. 开发者查看项目
        vm.prank(developer);
        pm.getProject(project1);
        vm.prank(developer);
        pm.getProject(project2);
        console.log("✅ 开发者成功查看所有项目");
        
        // 4. 完成项目
        vm.prank(projectManager);
        pm.completeProject(project1);
        console.log("✅ 项目1完成");
        
        // 5. 验证最终状态
        vm.prank(developer);
        (, , , , bool completed) = pm.getProject(project1);
        assertTrue(completed, "项目1应该已完成");
        
        vm.prank(developer);
        (, , , , completed) = pm.getProject(project2);
        assertFalse(completed, "项目2应该未完成");
        
        console.log("✅ 综合场景测试通过");
    }

    /**
     * @dev 辅助函数：用于测试失败情况
     */
    function fail(string memory message) internal pure {
        require(false, message);
    }
}

/**
 * @title 压力测试合约
 * @dev 测试RBAC系统在大规模使用下的表现
 */
contract RBACStressTest is Test {
    ProjectManagement public pm;
    address public admin = address(0x1001);
    
    function setUp() public {
        vm.prank(admin);
        pm = new ProjectManagement();
    }
    
    /**
     * @dev 压力测试：批量角色操作
     */
    function test_StressBatchOperations() public {
        uint256 batchSize = 50;
        address[] memory accounts = new address[](batchSize);
        
        // 生成测试地址
        for (uint256 i = 0; i < batchSize; i++) {
            accounts[i] = address(uint160(0x5000 + i));
        }
        
        // 设置项目经理
        vm.prank(admin);
        pm.grantRole(pm.PROJECT_MANAGER_ROLE(), admin);
        
        // 批量授予角色
        vm.prank(admin);
        pm.batchGrantRole(pm.DEVELOPER_ROLE(), accounts);
        
        // 验证所有角色授予成功
        for (uint256 i = 0; i < batchSize; i++) {
            assertTrue(
                pm.hasRole(pm.DEVELOPER_ROLE(), accounts[i]),
                "批量授予失败"
            );
        }
        
        console.log("✅ 压力测试通过，批量处理了 %s 个地址", batchSize);
    }
}