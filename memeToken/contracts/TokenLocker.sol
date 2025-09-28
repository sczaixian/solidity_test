// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;


// 锁仓合约
contract TokenLocker{

    struct LockToken{
        uint256 lockAmount;
        uint256 lockTime;
        uint256 startTime;
    }

    mapping(address => LockToken) public lockToken;

    uint256 public constant ONE_YEWR = 365 days;
    uint256 public constant ONE_MONTH = 30 days;
    uint256 public constant ONE_DAY = 1 days;
    uint256 public constant CLIFF_PERIOD = 90 days;   // 3个月悬崖期

    function lockTokens(address beneficiary, uint256 amount, uint256 lockPeriod) external {
        lockToken[beneficiary] = LockToken({
            lockAmount: amount,
            lockTime: block.timestamp + lockPeriod * ONE_DAY,
            startTime: 0
        });
    }

    function canWithdraw(address account) view public returns(uint256) {
        if(block.timestamp < lockToken[account].lockTime) return 0;
        return lockToken[account].lockAmount; 
    }

    function vestedAmount(address account) public view returns(uint256) {
        LockToken storage _lockToken = lockToken[account];
        if(block.timestamp < _lockToken.startTime + CLIFF_PERIOD) return 0;
        uint256 timePassed = block.timestamp - _lockToken.startTime - CLIFF_PERIOD;
        uint256 amount = _lockToken.lockAmount;
        uint256 vested = amount * timePassed / ONE_YEWR;
        return vested > amount ? amount : vested;
    }

}