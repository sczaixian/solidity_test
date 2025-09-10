// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";


contract TMyStake is Initializable, UUPSUpgradeable, AccessControlUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;
    using Address for address;
    using Math for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");
    uint256 public constant ETH_PID = 0;

    struct Pool{
        address stTokenAddress;  // 质押代币地址
        uint256 poolWeight;
        uint256 lastRewardBlock;
        uint256 accMetaTokenPerST;
        uint256 stTokenAmount;
        uint256 minDepositAmount;
        uint256 unstakeLockedBlocks;
    }

    struct UnstakeRequest{
        uint256 amount;
        uint256 unLockBlocks;
    }

    struct User{
        uint256 stAmount;
        uint256 finishedMetaNode;
        uint256 pendingMetaNode;
        UnstakeRequest[] requests;
    }


    uint256 public startBlock;
    uint256 public endBlock;
    uint256 public MetaNodePerBlock;  // 每个块产出token量
    bool public withdrawPaused;  // 用于禁用提取功能
    bool public claimPaused;     // 禁用领取奖励功能。
    IERC20 public MetaNode;
    uint256 public totalPoolWeight;
    Pool[] public pool;

    // 池子  --->  user_address  ---->  user
    mapping(uint256 => mapping( address => User)) public user;

    modifier checkPid(uint256 pid_){
        require(pid_ < pool.length, "");
        _;
    }

    // 检查是否
    modifier whenNotClaimPaused(){
        require(!claimPaused, "");
        _;
    }

    modifier whenNotWithdrawPauseed(){
        require(!withdrawPaused, "");
        _;
    }

    event SetMetaNode(IERC20 indexed MetaNode);
    event AddPool(address stTokenAddress_, uint256 poolWeight_, uint256 minDepositAmount_, uint256 unstakeLockedBlocks_);

    function initialize (IERC20 MetaNode_, uint256 startBlock_, uint256 endBlock_, uint256 MetaNodePerBlock_) public initializer {
        require(startBlock_ < endBlock_ && MetaNodePerBlock_ > 0, "");
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);
        grantRole(ADMIN_ROLE, msg.sender);

        setMetaNode(MetaNode_);

        startBlock = startBlock_;
        endBlock = endBlock_;
        MetaNodePerBlock = MetaNodePerBlock_;
    }

    function setMetaNode(IERC20 MetaNode_) public onlyRole(ADMIN_ROLE) {
        MetaNode = MetaNode_;
        emit SetMetaNode(MetaNode);
    }

    
    function addPool(address stTokenAddress_, uint256 poolWeight_, uint256 minDepositAmount_, 
                     uint256 unstakeLockedBlocks_, bool withUpdate_) public onlyRole(ADMIN_ROLE){
        if(pool.length > 0){
            require(stTokenAddress_ > address(0), "");
        }else{
            require(stTokenAddress_ == address(0), "");
        }

        require(unstakeLockedBlocks_ > 0, "");
        require(block.number > endBlock, "");
        if(withUpdate_) {
            massUpdatePools();
        }
        uint256 lastRewardBlock_ = block.number > startBlock ? block.number : startBlock;
        totalPoolWeight = totalPoolWeight + poolWeight_;

        pool.push(Pool({
            stTokenAddress: stTokenAddress_,
            poolWeight: poolWeight_,
            lastRewardBlock: lastRewardBlock_,
            accMetaTokenPerST: 0,
            stTokenAmount: 0,
            minDepositAmount: minDepositAmount_,
            unstakeLockedBlocks: unstakeLockedBlocks_}));
        
        AddPool(stTokenAddress_, poolWeight_, minDepositAmount_, unstakeLockedBlocks_);
    }

    function massUpdatePools() public {
        uint256 length = pool.length;
        for(uint256 i = 0; i < length; i++){
            updatePool(i); // i is pid
        }
    }

    function updatePool(uint256 pid_) public checkPid(pid_){
        Pool storage pool_ = pool[pid_];
        if(pool_.lastRewardBlock > block.number){
            return;
        }

        (bool success1, uint256 totalMetaNode) = getMultiplier(pool_.lastRewardBlock, block.number).tryMul(pool_.poolWeight);
        require(success1, "overflow");
        (success1, totalMetaNode) = totalMetaNode.tryDiv(totalPoolWeight);  // 多块奖励总和 * （池子权重 / 总权重） 得到最终分红
        require(success1, "");

        uint256 stSupply = pool_.stTokenAmount;
        if(stSupply > 0){
            (bool success2, uint256 totalMetaNode_) = totalMetaNode.tryMul(1 ether);
            require(success2, "overflow");
            (success2, totalMetaNode_) = totalMetaNode_.tryDiv(stSupply);
            require(success2, "overflow");
        }

    }

    function getMultiplier(uint256 from_, uint256 to_) public view returns(uint256 multiplier){
        require(from_ < to_, "");
        if(from_ < startBlock){ from_ = startBlock; }
        if(to_ > endBlock) { to_ = endBlock; }
        require(from_ < to_, "");
        bool success;
        (success, multiplier) = (to_ - from_).tryMul(MetaNodePerBlock);
        require(success, "");
    }

}
