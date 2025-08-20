
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {FundMe} from "./FundMe.sol";
import {Test} from "forge-std/Test.sol";

contract FundMeTest is Test {
    FundMe fundMe ;
    address owner = address(0x01);
    uint256 constant FUND_AMOUNT = 200;

    function setUp() public {
        vm.startPrank(owner);
        fundMe = new FundMe(360);
        vm.stopPrank(); // 添加这行
    }
    function test_GetChainlinkDataFeedLatestAnswer() public{
        assertEq(fundMe.getChainlinkDataFeedLatestAnswer(), 419249840000);
    }
    // function test_Fund() public {
    //      vm.prank(owner);
    //      fundMe.fund();
    //      assertEq(fundMe.fundersToAmount(owner), FUND_AMOUNT);
    //  }

    // function test_Refund() public{
    //     vm.prank(owner);
        
    //     fundMe.refund();
    // }
}