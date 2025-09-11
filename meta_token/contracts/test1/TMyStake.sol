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


contract TMetaNode is Initializable, UUPSUpgradeable,PausableUpgradeable, AccessControlUpgradeable{
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




    event SetMetaNode(IERC20 indexed MetaNode_);




    modifier checkPoolId(uint256 pid_){
        require(pid_ < pool.length, "");
        _;
    }


    function _authorizeUpgrade(address newImplementation) internal onlyRole(UPGRADE_ROLE) override {}

    function initialize(IERC20 MetaNode_, uint256 startBlock_, uint256 endBlock_, uint256 MetaNodePerBlock_) public initializer {
        require(startBlock_ < endBlock_, "");
        __UUPSUpgradeable_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);

        setMetaNode(MetaNode_);

        startBlock = startBlock_;
        endBlock = endBlock_;
        MetaNodePerBlock = MetaNodePerBlock_;
    }

    function setMetaNode(IERC20 MetaNode_) public onlyRole(ADMIN_ROLE) {
        MetaNode = MetaNode_;
        emit SetMetaNode(MetaNode_);
    }


    function addPool(address stTokenAddress_, uint256 poolWeight_, 
                    uint256 minDepositAmount_, uint256 unstakeLockedBlocks_, bool withUpdate_) public onlyRole(ADMIN_ROLE) {
        if(pool.length == 0){
            require(stTokenAddress_ == address(0), "");
        }else{
            require(stTokenAddress_ != address(0), "");
        }

        require(unstakeLockedBlocks_ > 0, "");
        require(block.number < endBlock, "");  // ?  我什么在这里校验endblock， endblock后就不能加池子了吗？

        if (withUpdate_){
            massUpdatePools();
        }

        uint256 _lastRewardBlock = block.number < startBlock ? startBlock : block.number;
        totalPoolWeight = totalPoolWeight + poolWeight_;

        pool.push(Pool({
            stTokenAddress: stTokenAddress_,
            poolWeight:poolWeight_,
            lastRewardBlock: _lastRewardBlock,
            accMetaTokenPerST: 0,
            stTokenAmount: 0,
            minDepositAmount: minDepositAmount_,
            unstakeLockedBlocks: unstakeLockedBlocks_
        }));

        
    }

    function massUpdatePools() public {
        uint256 length_ = pool.length;
        for(uint256 i = 0; i < length_; i++){
            updatePool(i);
        }
    }

    function updatePool(uint256 pid_, uint256 minDepositAmount_, uint256 unstakeLockedBlocks_) public checkPoolId(pid_) onlyRole(ADMIN_ROLE) {
        pool[pid_].minDepositAmount = minDepositAmount_;
        pool[pid_].unstakeLockedBlocks = unstakeLockedBlocks_;
        // event;
    }

    function updatePool(uint256 pid_) public checkPoolId(pid_) {
        Pool storage pool_ = pool[pid_];
        if(pool_.lastRewardBlock >= block.number){
            return;
        }

        (bool success1, uint256 totalMetaNode) = getMultiplier(pool_.lastRewardBlock, block.number).tryMul(pool_.poolWeight);
        require(success1, "");
        (success1, totalMetaNode) = totalMetaNode.tryDiv(totalPoolWeight);

        uint256 stSupply = pool_.stTokenAmount;
        if(stSupply > 0){
            (bool success2, uint256 totalMetaNode_) = totalMetaNode.tryDiv(1 ether);
            require(success2, "");
            (success2, totalMetaNode_) = totalMetaNode_.tryDiv(stSupply);
            require(success2, "");
            (bool success3, uint256 accMetaTokenPerST_) = pool_.accMetaTokenPerST.tryAdd(totalMetaNode_);
            require(success3, "");
            pool_.accMetaTokenPerST = accMetaTokenPerST_;
        }
        pool_.lastRewardBlock = block.number;

    }

    function getMultiplier(uint256 from_, uint256 to_) public view returns(uint256 multiplier) {
        require(from_ < to_, "");
        if(from_ < startBlock){
            from_ = startBlock;
        }
        if(to_ > endBlock){
            to_ = endBlock;
        }
        require(from_ < to_, "");

        bool success;
        (success, multiplier) = (to_ - from_).tryMul(MetaNodePerBlock);
        require(success, "");
    }


    function pendingMetaNode(uint256 pid_, address user_) external checkPoolId(pid_) view returns(uint256){
        return pendingMetaNodeByBlockNum(pid_, user_, block.number);
    }


    function pendingMetaNodeByBlockNum(uint256 pid_, address user_, uint256 blockNumber_) public checkPoolId(pid_) view returns(uint256){
        Pool storage _pool = pool[pid_];
        User storage _user = user[pid_][user_];

        uint256 _accMetaTokenPerST = _pool.accMetaTokenPerST;
        uint256 stSupply = _pool.stTokenAmount;
        uint256 _lastRewardBlock = _pool.lastRewardBlock;
        uint256 _poolWeight = _pool.poolWeight;

        if (blockNumber_ > _pool.lastRewardBlock && stSupply != 0) {
            uint256 totalMetaNode = getMultiplier(_lastRewardBlock, blockNumber_);
            totalMetaNode = totalMetaNode *_poolWeight / totalPoolWeight;
            _accMetaTokenPerST = _accMetaTokenPerST + totalMetaNode * (1 ether) / stSupply;
        }
        return _user.stAmount * _accMetaTokenPerST / (1 ether) - _user.finishedMetaNode + _user.pendingMetaNode;
    }

    function withdrawAmount(uint256 pid_, address user_) public checkPoolId(pid_) view returns(uint256 requestAmount, uint256 pendingWithdrawAmount) {
        User storage _user = user[pid_][user_];

        for(uint256 i = 0; i < _user.requests.length; i++){
            if(_user.requests[i].unLockBlocks < block.number){
                pendingWithdrawAmount = pendingWithdrawAmount + _user.requests[i].amount;
            }
            requestAmount = requestAmount + _user.requests[i].amount;
        }
    }

    function depositETH() public whenNotPaused() payable {
        Pool storage _pool = pool[ETH_PID];
        require(_pool.stTokenAddress == address(0), "");
        uint256 amount = msg.value;
        require(amount > _pool.minDepositAmount, "");
        _deposit(ETH_PID, amount);
    }

    function _deposit(uint256 pid_, uint256 value_) internal {
        
    }
}
