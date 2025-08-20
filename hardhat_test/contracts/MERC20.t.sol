// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {MERC20} from "./MERC20.sol";
import {Test} from "forge-std/Test.sol";

contract MERC20Test is Test{
    MERC20 token;
    address owner = address(0x1);
    address user1 = address(0x2);
    function setUp() public{
        token = new MERC20(owner);
    }

    // function test_mint() public{
    //     vm.prank(owner);
    //     token.mint(20);
    // }

}

// contract MERC20Test is Test {
//     MERC20 token;
//     address owner = address(0x1);
//     address user1 = address(0x2);
//     address user2 = address(0x3);
//     address zeroAddress = address(0);

//     uint256 constant INITIAL_SUPPLY = 1000 ether;
//     uint256 constant MINT_AMOUNT = 500 ether;
//     uint256 constant TRANSFER_AMOUNT = 100 ether;
//     uint256 constant APPROVAL_AMOUNT = 300 ether;
//     uint256 constant SPEND_AMOUNT = 150 ether;

//     function setUp() public {
//         // 设置发送者为合约所有者
//         vm.startPrank(owner);
//         // 部署代币合约
//         token = new MERC20("TestToken", "TST", 18, INITIAL_SUPPLY);
//         vm.stopPrank();
//     }

//     // 测试 1: 初始化状态
//     function test_InitialState() public {
//         assertEq(token.name(), "TestToken");
//         assertEq(token.symbol(), "TST");
//         assertEq(token.decimals(), 18);
//         assertEq(token.totalSupply(), INITIAL_SUPPLY);
//         assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
//         assertEq(token.owner(), owner);
//     }

//     // 测试 2: 转账功能
//     function test_Transfer() public {
//         // 所有者转账给用户1
//         vm.prank(owner);
//         token.transfer(user1, TRANSFER_AMOUNT);
        
//         // 验证余额变化
//         assertEq(token.balanceOf(owner), INITIAL_SUPPLY - TRANSFER_AMOUNT);
//         assertEq(token.balanceOf(user1), TRANSFER_AMOUNT);
        
//         // 用户1转账给用户2
//         vm.prank(user1);
//         token.transfer(user2, TRANSFER_AMOUNT / 2);
        
//         // 验证余额变化
//         assertEq(token.balanceOf(user1), TRANSFER_AMOUNT / 2);
//         assertEq(token.balanceOf(user2), TRANSFER_AMOUNT / 2);
//     }
// /*
//     // 测试 3: 转账事件触发
//     function test_TransferEvent() public {
//         // 预期转账事件
//         vm.expectEmit(true, true, false, true);
//         emit Transfer(owner, user1, TRANSFER_AMOUNT);
        
//         // 执行转账
//         vm.prank(owner);
//         token.transfer(user1, TRANSFER_AMOUNT);
//     }

//     // 测试 4: 余额不足转账失败
//     function test_TransferInsufficientBalance() public {
//         vm.prank(user1);
//         vm.expectRevert(abi.encodeWithSelector(MERC20.InsufficientBalance.selector));
//         token.transfer(user2, 1 ether);
//     }

//     // 测试 5: 授权功能
//     function test_Approve() public {
//         // 用户1授权给用户2
//         vm.prank(user1);
//         token.approve(user2, APPROVAL_AMOUNT);
        
//         // 验证授权额度
//         assertEq(token.allowance(user1, user2), APPROVAL_AMOUNT);
//     }

//     // 测试 6: 授权事件触发
//     function test_ApproveEvent() public {
//         // 预期授权事件
//         vm.expectEmit(true, true, false, true);
//         emit Approval(user1, user2, APPROVAL_AMOUNT);
        
//         // 执行授权
//         vm.prank(user1);
//         token.approve(user2, APPROVAL_AMOUNT);
//     }

//     // 测试 7: 代扣转账功能
//     function test_TransferFrom() public {
//         // 准备测试环境
//         vm.prank(owner);
//         token.transfer(user1, TRANSFER_AMOUNT);
        
//         // 用户1授权给所有者
//         vm.prank(user1);
//         token.approve(owner, APPROVAL_AMOUNT);
        
//         // 执行代扣转账
//         vm.prank(owner);
//         token.transferFrom(user1, user2, SPEND_AMOUNT);
        
//         // 验证余额变化
//         assertEq(token.balanceOf(user1), TRANSFER_AMOUNT - SPEND_AMOUNT);
//         assertEq(token.balanceOf(user2), SPEND_AMOUNT);
        
//         // 验证授权额度减少
//         assertEq(token.allowance(user1, owner), APPROVAL_AMOUNT - SPEND_AMOUNT);
//     }

//     // 测试 8: 授权不足时代扣转账失败
//     function test_TransferFromInsufficientAllowance() public {
//         // 准备测试环境
//         vm.prank(owner);
//         token.transfer(user1, TRANSFER_AMOUNT);
        
//         // 设置不足的授权额度
//         vm.prank(user1);
//         token.approve(owner, SPEND_AMOUNT - 1);
        
//         // 尝试超额转账
//         vm.prank(owner);
//         vm.expectRevert(abi.encodeWithSelector(MERC20.InsufficientAllowance.selector));
//         token.transferFrom(user1, user2, SPEND_AMOUNT);
//     }

//     // 测试 9: 铸币功能
//     function test_Mint() public {
//         uint256 initialSupply = token.totalSupply();
        
//         // 所有者铸币
//         vm.prank(owner);
//         token.mint(user1, MINT_AMOUNT);
        
//         // 验证总供应量和余额
//         assertEq(token.totalSupply(), initialSupply + MINT_AMOUNT);
//         assertEq(token.balanceOf(user1), MINT_AMOUNT);
//     }

//     // 测试 10: 铸币事件触发
//     function test_MintEvent() public {
//         // 预期铸币事件
//         vm.expectEmit(true, true, false, true);
//         emit Transfer(zeroAddress, user1, MINT_AMOUNT);
        
//         // 执行铸币
//         vm.prank(owner);
//         token.mint(user1, MINT_AMOUNT);
//     }

//     // 测试 11: 非所有者禁止铸币
//     function test_NonOwnerMint() public {
//         vm.prank(user1);
//         vm.expectRevert(abi.encodeWithSelector(MERC20.OnlyOwner.selector));
//         token.mint(user1, MINT_AMOUNT);
//     }

//     // 测试 12: 授权后自转账
//     function test_SelfTransferFrom() public {
//         // 准备测试环境
//         vm.prank(owner);
//         token.transfer(user1, TRANSFER_AMOUNT);
        
//         // 用户1授权给自己
//         vm.prank(user1);
//         token.approve(user1, APPROVAL_AMOUNT);
        
//         // 执行自转账
//         vm.prank(user1);
//         token.transferFrom(user1, user1, SPEND_AMOUNT);
        
//         // 验证余额不变
//         assertEq(token.balanceOf(user1), TRANSFER_AMOUNT);
        
//         // 验证授权额度减少
//         assertEq(token.allowance(user1, user1), APPROVAL_AMOUNT - SPEND_AMOUNT);
//     }
// */    
// }