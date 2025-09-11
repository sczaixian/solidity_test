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
    event PauseWithdraw();
    event UnpauseWithdraw();
    event PauseClaim();
    event UnpauseClaim();
    event SetStartBlock(uint256 startBlock_);
    event SetEndBlock(uint256 endBlock_);
    event SetMetaNodePerBlock(uint256 MetaNodePerBlock_);
    event SetPoolWeight(uint256 indexed poolId, uint256 indexed poolWeight, uint256 totalPoolWeight);
    event AddPool(address stTokenAddress_, uint256 poolWeight_, uint256 minDepositAmount_, uint256 unstakeLockedBlocks_);
    event UpdatePool(uint256 indexed poolId, uint256 indexed lastRewardBlock, uint256 totalMetaNode);

    function initialize(IERC20 _MetaNode, uint256 _startBlock, uint256 _endBlock, uint256 _MetaNodePerBlock) public initializer {
        require(_startBlock <= _endBlock && _MetaNodePerBlock > 0, "invalid parameters");

        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        setMetaNode(_MetaNode);

        startBlock = _startBlock;
        endBlock = _endBlock;
        MetaNodePerBlock = _MetaNodePerBlock;

    }
    // 必须要实现
    function _authorizeUpgrade(address newImplementation) internal onlyRole(UPGRADE_ROLE) override { }

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
        
        emit AddPool(stTokenAddress_, poolWeight_, minDepositAmount_, unstakeLockedBlocks_);
    }

    function massUpdatePools() public {
        uint256 length = pool.length;
        for(uint256 i = 0; i < length; i++){
            updatePool(i); // i is pid
        }
    }

    function updatePool(uint256 pid_) public checkPid(pid_){
        /**
            判断有没有可以更新的块
            如果有计算 需要更新
            总token、每个token分发的 metanode、最后发奖励块、增加事件

         */
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
            (bool success3, uint256 accMetaNodePerST_) = pool_.accMetaTokenPerST.tryAdd(totalMetaNode_);
            require(success3, "");
            pool_.accMetaTokenPerST = accMetaNodePerST_;
        }
        pool_.lastRewardBlock = block.number;
        emit UpdatePool(pid_, pool_.lastRewardBlock, totalMetaNode);

    }

    function getMultiplier(uint256 from_, uint256 to_) public view returns(uint256 multiplier){
        /**
            计算多个块的奖励总和
         */
        require(from_ < to_, "");
        if(from_ < startBlock){ from_ = startBlock; }
        if(to_ > endBlock) { to_ = endBlock; }
        require(from_ < to_, "");
        bool success;
        (success, multiplier) = (to_ - from_).tryMul(MetaNodePerBlock);
        require(success, "");
    }
    /**
        暂停、放开 领取奖励、提款
        设置开始和结束块
        设置 每个 eth 折算多少个 token
     */
    function pauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(!withdrawPaused, "");
        withdrawPaused = true;
        emit PauseWithdraw();
    }

    function unpauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(withdrawPaused, "");
        withdrawPaused = false;
        emit UnpauseWithdraw();
    }

    function pauseClaim() public onlyRole(ADMIN_ROLE){
        require(!claimPaused, "");
        claimPaused = true;
        emit PauseClaim();
    }

    function unpauseClaim() public onlyRole(ADMIN_ROLE){
        require(claimPaused, "");
        claimPaused = false;
        emit UnpauseClaim();
    }

    function setStartBlock(uint256 startBlock_) public onlyRole(ADMIN_ROLE) {
        require(startBlock_ <= endBlock, "");
        startBlock = startBlock_;
        emit SetStartBlock(startBlock_);
    }

    function setEndBlock(uint256 endBlock_) public onlyRole(ADMIN_ROLE) {
        require(startBlock <= endBlock_, "");
        endBlock = endBlock_;
        emit SetEndBlock(endBlock_);
    }

    function setMetaNodePerBlock(uint256 MetaNodePerBlock_) public onlyRole(ADMIN_ROLE){
        require(MetaNodePerBlock_ > 0, "");
        MetaNodePerBlock = MetaNodePerBlock_;
        emit SetMetaNodePerBlock(MetaNodePerBlock_);
    }

    function updatePool(uint256 pid_, uint256 minDepositAmount_, uint256 unstakeLockedBlocks_) public onlyRole(ADMIN_ROLE) checkPid(pid_){
        pool[pid_].minDepositAmount = minDepositAmount_;
        pool[pid_].unstakeLockedBlocks = unstakeLockedBlocks_;
        emit UpdatePool(pid_, minDepositAmount_, unstakeLockedBlocks_);
    }

    /**
        设置池子的权重
     */
    function setPoolWeight(uint256 pid_, uint256 poolWeight_, bool withUpdate_) public onlyRole(ADMIN_ROLE) checkPid(pid_){
        require(poolWeight_ > 0, "");
        if(withUpdate_){
            massUpdatePools();
        }
        totalPoolWeight = totalPoolWeight - pool[pid_].poolWeight + poolWeight_;
        pool[pid_].poolWeight = poolWeight_;
        emit SetPoolWeight(pid_, poolWeight_, totalPoolWeight);
    }

    function poolLength() external view returns(uint256){
        return pool.length;
    }

    function pendingMetaNode(uint256 pid_, address user_) external checkPid(pid_) view returns(uint256){
        return pendingMetaNodeByBlockNumber(pid_, user_, block.number);
    }

    /**
        传入区块 得到 还没领取奖励的metanode数量
     */
    function pendingMetaNodeByBlockNumber(uint256 pid_, address user_, uint256 blockNumber_) 
                                                    public checkPid(pid_) view returns(uint256){
        Pool storage pool_ = pool[pid_];
        User storage _user = user[pid_][user_];
        uint256 accMetaNodePerST = pool_.accMetaTokenPerST;
        uint256 stSupply = pool_.stTokenAmount;
        if(blockNumber_ > pool_.lastRewardBlock && stSupply != 0){
            uint256 multiplier = getMultiplier(pool_.lastRewardBlock, blockNumber_);
            uint256 MetaNodeForPool = multiplier * pool_.poolWeight / totalPoolWeight;
            accMetaNodePerST = accMetaNodePerST + MetaNodeForPool * (1 ether) / stSupply;
        }
        return _user.stAmount * accMetaNodePerST / (1 ether) - _user.finishedMetaNode + _user.pendingMetaNode;
    }

    function stakingBalance(uint256 pid_, address user_) external checkPid(pid_) view returns(uint256){
        return user[pid_][user_].stAmount;
    }

    /**
        查询 某个池子中 用户所有  解锁但是没有提取的总额
     */
    function withDrawAmount(uint256 pid_, address user_) 
            public checkPid(pid_) view returns(uint256 requestAmount, uint256 pendingWithdrawAmount){
        User storage _user = user[pid_][user_];
        for(uint256 i = 0; i < _user.requests.length; i++){
            if(_user.requests[i].unLockBlocks < block.number){
                pendingWithdrawAmount = pendingWithdrawAmount + _user.requests[i].amount;
            }
            requestAmount = requestAmount + _user.requests[i].amount;
        }
    }
    // ETH 与 ERC20 的表示方式不同
    function depositETH() public whenNotPaused() payable {
        /**
            先判断 是不是eth
            判断是不是 符合最小质押要求
            传给底层函数计算
         */
    }

    
    function deposit(uint256 _pid, uint256 _amount) public whenNotPaused() checkPid(_pid) {

    }
}
