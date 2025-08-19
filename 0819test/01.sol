// SPDK-License-Identifier:MIT
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// 1. 创建一个收款函数
// 2. 记录投资人并且查看
// 3. 在锁定期内，达到目标值，生产商可以提款
// 4. 在锁定期内，没有达到目标值，投资人在锁定期以后退款


contract FundMe{

    // string public name;
    // string public sym
    address public owner;
    uint256 constant MIN_VALUE = 100 * 10 ** 18;   // 最小众筹金额
    uint256 constant TARGET = 1000 * 10 ** 18;  // 达成条件
    uint256 lockTime;
    uint256 deploymentTimestamp;

    mapping(address => uint256) funderToAmount;
    
    AggregatorV3Interface internal dataFeed;


    error OnlyOwner();
    
    modifier onlyOwner(){
        if(msg.sender != owner) revert OnlyOwner();
        // require(msg.sender == owner, "this function can be only call by owner");
        _;
    }

    constructor(uint256 _lockTime){
        lockTime = _lockTime;
        deploymentTimestamp = block.timestamp;
        owner = msg.sender;
        dataFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
    }
    
    // 需要用到预言机 
    function getChainlinkDataFeedLatestAnswer() public view returns (int) {
        // prettier-ignore
        (
            /* uint80 roundID */,
            int answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();
        return answer;
    }

    function converEthToUsd(uint256 ethAmount) internal view returns(uint256){
        uint256 ethPrice = uint256(getChainlinkDataFeedLatestAnswer());
        return ethAmount * ethPrice / (1 ** 8);
    }

    function transferOwnership(address newOwner) external onlyOwner returns(bool) {
        owner = newOwner;
    }

    function fund(uint256 amount) external payable returns(bool) {
        require(converEthToUsd(msg.value) >= MIN_VALUE, "send more eth");
        funderToAmount[msg.sender] += amount;
        return true;
    }

    function getFound() external onlyOwner windowClosed {
        // 达成条件
        require(funderToAmount[address(this)] >= TARGET, "target is not reached");
        bool success;
        (success,) = payable(msg.sender).call{value: address(this).balance}("");
        funderToAmount[msg.sender] = 0;
    }

    function reFund() external windowClosed {
        // 没达成条件
        require(funderToAmount[address(this)] < TARGET, "target is reached");
        require(funderToAmount[msg.sender] > 0, "there is no fund for you");
        bool success;
        (success,) = payable(msg.sender).call{value: funderToAmount[msg.sender]}("");
        require(success, "transfer tx failed");
        funderToAmount[msg.sender] = 0;
    }

    modifier windowClosed(){
        require(block.timestamp >= deploymentTimestamp + lockTime, "window is not close");
        _;
    }

}