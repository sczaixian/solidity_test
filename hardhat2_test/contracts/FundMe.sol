// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// 1. 创建一个收款函数
// 2. 记录投资人并且查看
// 3. 在锁定期内，达到目标值，生产商可以提款
// 4. 在锁定期内，没有达到目标值，投资人在锁定期以后退款

contract FundMe{
    address public owner;
    mapping(address => uint256) public fundersToAmount;

    uint256 constant MINIMUM_VALUE = 1 * 10 ** 17; //0.1USD
    uint256 constant TARGET = 1000 * 10 ** 18;
    uint256 deploymentTimestamp;
    uint256 lockTime;
    address erc20Addr;
    bool public getFundSuccess = false;  // 不写默认是false

    AggregatorV3Interface internal dataFeed;

    modifier onlyOwner(){
        require(msg.sender == owner, "this function can only called by owner");
        _;
    }

    modifier windowClosed(){
        require(block.timestamp >= deploymentTimestamp + lockTime, "windows is not closed");
        _;
    }

    constructor (uint256 _lockTime){
        dataFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        owner = msg.sender;
        deploymentTimestamp = block.timestamp;
        lockTime = _lockTime;
    }

    function fund() external payable {
        require(convertEthToUsd(msg.value) >= MINIMUM_VALUE, "send more eth");
        require(block.timestamp <= deploymentTimestamp + lockTime, "windows is closed");
        fundersToAmount[msg.sender] += convertEthToUsd(msg.value);
    }

    /* 转移真正的 eth， 他们是通过区块链控制的
        getFund()
        refund()
    */ 
    function getFund() external payable onlyOwner windowClosed {
        require(convertEthToUsd(address(this).balance) >= TARGET, "target is not reached");

        // payable(msg.sender).transfer(address(this).balance);
        // bool success = payable(msg.sender).send(address(this).balance);

        bool success;
        (success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "");
        fundersToAmount[msg.sender] = 0;
        getFundSuccess = true;
    }

    function refund() external windowClosed {
        require(convertEthToUsd(address(this).balance) < TARGET, "target is reached");
        require(fundersToAmount[msg.sender] != 0, "there is no fund for you");
        bool success;
        (success,) = payable(msg.sender).call{value: fundersToAmount[msg.sender]}("");
        require(success, "transfer tx failed");
        fundersToAmount[msg.sender] = 0;
    }

    function setFuntToAmount(address funder, uint256 amountToUpdate) external {
        require(msg.sender == erc20Addr, "you do not have permission to call this function");
        fundersToAmount[funder] = amountToUpdate;
    }

    function transferOwnership(address newOwner) external windowClosed onlyOwner{
        owner = newOwner;
    }

    function getChainlinkDataFeedLatestAnswer() public view returns (int) {
        // prettier-ignore
        (
            /* uint80 roundId */,
            int256 answer,
            /*uint256 startedAt*/,
            /*uint256 updatedAt*/,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();
        return answer;
    }

    function convertEthToUsd(uint256 ethAmount) internal view returns(uint256) {
        uint256 ethPrice = uint256(getChainlinkDataFeedLatestAnswer());
        return ethAmount * ethPrice / (10 ** 8);
    }

}