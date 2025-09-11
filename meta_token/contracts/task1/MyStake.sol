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


/* 
  用户 质押了 币 A  --> 
  Initializable: 提供了初始化函数的功能，确保合约的初始化逻辑只能执行一次。
  UUPSUpgradeable: UUPS 升级模式,升级逻辑放在实现合约中，而不是代理合约中
  PausableUpgradeable: 提供了暂停和恢复合约功能的机制,当合约遇到紧急情况或需要维护时，所有者可以暂停大部分功能(可升级版本的 Pausable)
  AccessControlUpgradeable: 基于角色的权限控制系统(可升级版本的 AccessControl)

  SafeERC20: 为 ERC20 代币操作提供了额外的安全性,函数会检查代币合约的返回值，确保操作成功
  
*/

contract MyStake is Initializable, UUPSUpgradeable, PausableUpgradeable, AccessControlUpgradeable {

    using SafeERC20 for IERC20;
    using Address for address;
    using Math for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");
    uint256 public constant ETH_PID = 0;

    // 待分配的 metaNode = 用户质押量 * 

    struct  Pool {
        address stTokenAddress;       // 质押代币的地址
        uint256 poolWeight;           // 质押池的权重，影响奖励分配。
        uint256 lastRewardBlock;      // 最后一次计算奖励的区块号。
        uint256 accMetaNodePerST;     // 每个质押代币累积的 MetaNode 数量。
        uint256 stTokenAmount;        // 池中的总质押代币量
        uint256 minDepositAmount;     // 最小质押金额。
        uint256 unstakeLockedBlocks;  // 解除质押的锁定区块数
    }

    // 记录用户取消质押的请求信息
    struct UnstakeRequest{
        uint256 amount;        // 请求提取的金额
        uint256 unlockBlocks;  // 解锁时间点
    }

    struct User{
        uint256 stAmount;            // 用户质押的代币数量
        uint256 finishedMetaNode;    // 已分配的 MetaNode 数量
        uint256 pendingMetaNode;     // 待领取的 MetaNode 数量，收益的token数量
        UnstakeRequest[] requests;   // 解质押请求列表，每个请求包含解质押数量和解锁区块。
    }

    // 在达到这个区块之前，用户可能可以质押资产，但不会获得任何奖励。通常用于设置奖励分发的开始时间
    uint256 public startBlock;  // 质押池开始发放奖励的起始区块高度

    // 这个区块之后，不再产生新的奖励。用户可能仍然可以提取资产，但不再累积奖励
    uint256 public endBlock;    // 质押池结束发放奖励的结束区块高度

    // 它表示整个质押池系统在每个区块中分配给所有池的总奖励量。奖励根据池的权重（pool weight）分配給各个池
    uint256 public MetaNodePerBlock;  // 每个区块分发的MetaNode代币数量

    // 用于禁用提取功能。如果设置为true，用户无法从质押池中提取他们的质押资产。这通常用于紧急情况或维护。
    bool public withdrawPaused;  // 暂停开关
    // 禁用领取奖励功能。如果设置为true，用户无法领取他们已累积的奖励。同样，用于紧急情况或维护
    bool public claimPaused; // 暂停开关
    
    // MetaNode代币的ERC20合约接口。用于处理奖励代币的转移、余额查询等操作。奖励以这种代币形式分发。
    IERC20 public MetaNode;

    // 如果总权重为100，某个池权重为50，那么该池获得50%的奖励
    uint256 public totalPoolWeight;  // 所有池的总权重


    Pool[] public pool;  // 存储所有质押池的信息

    mapping(uint256 => mapping (address => User)) public user;  // 每个池子--user_address--userinfo

    event SetMetaNode(IERC20 indexed MetaNode);
    event PauseWithdraw();
    event UnpauseWithdraw();
    event PauseClaim();
    event UnpauseClaim();
    event SetStartBlock(uint256 indexed startBlock);
    event SetEndBlock(uint256 indexed endBlock);
    event SetMetaNodePerBlock(uint256 indexed MetaNodePerBlock);
    event AddPool(address indexed stTokenAddress, uint256 indexed poolWeight, uint256 indexed lastRewardBlock, uint256 minDepositAmount, uint256 unstakeLockedBlocks);
    event UpdatePoolInfo(uint256 indexed poolId, uint256 indexed minDepositAmount, uint256 indexed unstakeLockedBlocks);
    event SetPoolWeight(uint256 indexed poolId, uint256 indexed poolWeight, uint256 totalPoolWeight);
    event UpdatePool(uint256 indexed poolId, uint256 indexed lastRewardBlock, uint256 totalMetaNode);
    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);
    event RequestUnstake(address indexed user, uint256 indexed poolId, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed poolId, uint256 amount, uint256 indexed blockNumber);
    event Claim(address indexed user, uint256 indexed poolId, uint256 MetaNodeReward);



    modifier checkPid(uint256 _pid) {
        require(_pid < pool.length, "invalid pid");
        _;
    }

    modifier whenNotClaimPaused() {
        require(!claimPaused, "claim is paused");
        _;
    }

    modifier whenNotWithdrawPaused() {
        require(!withdrawPaused, "withdraw is paused");
        _;
    }














    function initialize(IERC20 _MetaNode, uint256 _startBlock, uint256 _endBlock, uint256 _MetaNodePerBlock) public initializer {
        require(_startBlock <= _endBlock && _MetaNodePerBlock > 0, "invalid parameters!!");
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

    function setMetaNode(IERC20 _MetaNode) public onlyRole(ADMIN_ROLE) {
        MetaNode = _MetaNode;
        emit SetMetaNode(MetaNode);
    }


    function _authorizeUpgrade(address newImplementation) internal onlyRole(UPGRADE_ROLE) override {}

    function addPool(address _stTokenAddress, uint256 _poolWeight, uint256 _minDepositAmount, 
                                              uint256 _unstakeLockedBlocks, bool _withUpdate) public onlyRole(ADMIN_ROLE) {
        /*
            第一个 pool 必须是 eth
        */
        if(pool.length > 0){
            require(_stTokenAddress != address(0), "invalid staking token address");
        } else{
            require(_stTokenAddress == address(0), "invalid staking token address");
        }
        require(_unstakeLockedBlocks > 0, "invalid withdraw locked blocks");
        require(block.number < endBlock, "already ended");

        if(_withUpdate){
            massUpdatePools();
        }

        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalPoolWeight = totalPoolWeight + _poolWeight;
        
        pool.push(
            Pool({
                stTokenAddress: _stTokenAddress,poolWeight: _poolWeight,
                lastRewardBlock: lastRewardBlock, accMetaNodePerST: 0,
                stTokenAmount: 0, minDepositAmount: _minDepositAmount,
                unstakeLockedBlocks: _unstakeLockedBlocks
            })
        );

        emit AddPool(_stTokenAddress, _poolWeight, lastRewardBlock, _minDepositAmount, _unstakeLockedBlocks);
    }

    function massUpdatePools() public{
        uint256 length = pool.length;
        for(uint256 pid = 0; pid < length; pid++){
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid, uint256 _minDepositAmount, uint256 _unstakeLockedBlocks) public onlyRole(ADMIN_ROLE) checkPid(_pid){
        pool[_pid].minDepositAmount = _minDepositAmount;
        pool[_pid].unstakeLockedBlocks = _unstakeLockedBlocks;
        emit UpdatePoolInfo(_pid, _minDepositAmount, _unstakeLockedBlocks);
    }

    function setPoolWeight(uint256 _pid, uint256 _poolWeight, bool _withUpdate) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        require(_poolWeight > 0, "invalid pool weight");
        if(_withUpdate){
            massUpdatePools();
        }
        totalPoolWeight = totalPoolWeight - pool[_pid].poolWeight + _poolWeight;
        pool[_pid].poolWeight = _poolWeight;
        emit SetPoolWeight(_pid, _poolWeight, totalPoolWeight);
    }

    function updatePool(uint256 _pid) public checkPid(_pid){
        Pool storage pool_ = pool[_pid];
        if(block.number <= pool_.lastRewardBlock){
            return;
        }
        (bool success1, uint256 totalMetaNode) = getMultiplier(pool_.lastRewardBlock, block.number).tryMul(pool_.poolWeight);
        require(success1, "overflow");
        (success1, totalMetaNode) = totalMetaNode.tryDiv(totalPoolWeight);
        require(success1, "overflow");

        uint256 stSupply = pool_.stTokenAmount;
        if(stSupply > 0){
            (bool success2, uint256 totalMetaNode_) = totalMetaNode.tryMul(1 ether);
            require(success2, "overflow");
            
            (success2, totalMetaNode_) = totalMetaNode_.tryDiv(stSupply);
            require(success2, "overflow");
            
            (bool success3, uint256 accMetaNodePerST) = pool_.accMetaNodePerST.tryAdd(totalMetaNode_);
            require(success3, "overflow");
            pool_.accMetaNodePerST = accMetaNodePerST;
        }

        pool_.lastRewardBlock = block.number;

        emit UpdatePool(_pid, pool_.lastRewardBlock, totalMetaNode);
    }









    function getMultiplier(uint256 _from, uint256 _to) public view returns(uint256 multiplier) {
        require(_from <= _to, "invalid block");
        if(_from < startBlock) { _from = startBlock; }
        if(_to > endBlock) { _to = endBlock; }
        require(_from <= _to, "end block must be greater than start block");
        bool success;
        (success, multiplier) = (_to - _from).tryDiv(MetaNodePerBlock);
        require(success, "multiplier overflow");
    }




    function poolLength() external view returns(uint256){
        return pool.length;
    }


    function pendingMetaNode(uint256 _pid, address _user) external checkPid(_pid) view returns(uint256) {
        return pendingMetaNodeByBlockNumber(_pid, _user, block.number);
    }

    function pendingMetaNodeByBlockNumber(uint256 _pid, address _user, uint256 _blockNumber) public checkPid(_pid) view returns(uint256) {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][_user];
        uint256 accMetaNodePerST = pool_.accMetaNodePerST;
        uint256 stSupply = pool_.stTokenAmount;
        if(_blockNumber > pool_.lastRewardBlock && stSupply != 0){
            uint256 multiplier = getMultiplier(pool_.lastRewardBlock, _blockNumber);
            uint256 MetaNodeForPool = multiplier * pool_.poolWeight / totalPoolWeight;
            accMetaNodePerST = accMetaNodePerST + MetaNodeForPool * (1 ether) / stSupply;
        }
        return user_.stAmount * accMetaNodePerST / (1 ether) - user_.finishedMetaNode + user_.pendingMetaNode;
    }


    function stakingBalance(uint256 _pid, address _user) external checkPid(_pid) view returns(uint256) {
        return user[_pid][_user].stAmount;
    }

    function withdrawAmount(uint256 _pid, address _user) public checkPid(_pid) view returns(uint256 requestAmount, uint256 pendingWithdrawAmount) {
        User storage user_ = user[_pid][_user];
        for(uint256 i = 0; i < user_.requests.length; i++){
            if(user_.requests[i].unlockBlocks <= block.number){
                pendingWithdrawAmount = pendingWithdrawAmount + user_.requests[i].amount;
            }
            requestAmount = requestAmount + user_.requests[i].amount;
        }
    }

    // 质押ETH
    function depositEth() public whenNotPaused() payable {
        Pool storage pool_ = pool[ETH_PID];
        require(pool_.stTokenAddress == address(0), "invalid staking token address");
        uint256 _amount = msg.value;
        require(_amount >= pool_.minDepositAmount, "deposit amount is too small");
        _deposit(ETH_PID, _amount);
    }

    // 质押其他代币
    function deposit(uint256 _pid, uint256 _amount) public whenNotPaused() checkPid(_pid) {
        require(_pid != 0, "deposit not support ETH staking");
        Pool storage pool_ = pool[_pid];
        require(_amount > pool_.minDepositAmount, "deposit amount is too small");
        if(_amount > 0){
            IERC20(pool_.stTokenAddress).safeTransferFrom(msg.sender, address(this), _amount);
        }
        _deposit(_pid, _amount);
    }

    // 解锁函数
    function unstake(uint256 _pid, uint256 _amount) public whenNotPaused() checkPid(_pid) whenNotWithdrawPaused() {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];
        require(user_.stAmount >= _amount, "Not enough staking token balance");

        updatePool(_pid);

        uint256 pendingMetaNode_ = user_.stAmount * pool_.accMetaNodePerST / (1 ether) - user_.finishedMetaNode;

        if(pendingMetaNode_ > 0) {
            user_.pendingMetaNode = user_.pendingMetaNode + pendingMetaNode_;
        }

        if(_amount > 0) {
            user_.stAmount = user_.stAmount - _amount;
            user_.requests.push(UnstakeRequest({
                amount: _amount,
                unlockBlocks: block.number + pool_.unstakeLockedBlocks
            }));
        }

        pool_.stTokenAmount = pool_.stTokenAmount - _amount;
        user_.finishedMetaNode = user_.stAmount * pool_.accMetaNodePerST / (1 ether);

        emit RequestUnstake(msg.sender, _pid, _amount);
    }

    // 提取已解锁的代币
    function withdraw(uint256 _pid) public whenNotPaused() checkPid(_pid) whenNotWithdrawPaused() {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];

        uint256 pendingWithdraw_;
        uint256 popNum_;
        for(uint256 i = 0; i < user_.requests.length; i++){
            if(user_.requests[i].unlockBlocks > block.number){
                break;
            }
            pendingWithdraw_ = pendingWithdraw_ + user_.requests[i].amount;
            popNum_++;
        }
        for(uint256 i = 0; i < user_.requests.length - popNum_; i++){
            user_.requests[i] = user_.requests[i + popNum_];
        }

        for(uint256 i = 0; i < popNum_; i++){
            user_.requests.pop();
        }

        if(pendingWithdraw_ > 0){
            if(pool_.stTokenAddress == address(0)){
                _safeETHTransfer(msg.sender, pendingWithdraw_);
            }else{
                IERC20(pool_.stTokenAddress).safeTransfer(msg.sender, pendingWithdraw_);
            }   
        }
        emit Withdraw(msg.sender, _pid, pendingWithdraw_, block.number);
    }

    // 领取MetaNode奖励
    function claim(uint256 _pid) public whenNotPaused() checkPid(_pid) whenNotClaimPaused() {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];
        updatePool(_pid);
        uint256 pendingMetaNode_ = user_.stAmount * pool_.accMetaNodePerST / (1 ether) - user_.finishedMetaNode + user_.pendingMetaNode;
        if(pendingMetaNode_ > 0){
            user_.pendingMetaNode = 0;
            _safeMetaNodeTransfer(msg.sender, pendingMetaNode_);
        }
        // 有可能会缩水
        user_.finishedMetaNode = user_.stAmount * pool_.accMetaNodePerST / (1 ether);
        emit Claim(msg.sender, _pid, pendingMetaNode_);
    }

    function _deposit(uint256 _pid, uint256 _amount) internal {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];
        updatePool(_pid);

        if (user_.stAmount > 0) {
            (bool success1, uint256 accST) = user_.stAmount.tryMul(pool_.accMetaNodePerST);  // 总共可以得到token
            require(success1, "user stAmount mul accMetaNodePerST overflow");
            (success1, accST) = accST.tryDiv(1 ether);  // 单位统一
            require(success1, "accST div 1 ether overflow");
            
            (bool success2, uint256 pendingMetaNode_) = accST.trySub(user_.finishedMetaNode);
            require(success2, "accST sub finishedMetaNode overflow");

            if(pendingMetaNode_ > 0) {
                // 上次质押到当前时刻（这次操作）过程中产生的收益
                (bool success3, uint256 _pendingMetaNode) = user_.pendingMetaNode.tryAdd(pendingMetaNode_);
                require(success3, "user pendingMetaNode overflow");
                user_.pendingMetaNode = _pendingMetaNode;
            }
        }

        if(_amount > 0) {
            (bool success4, uint256 stAmount) = user_.stAmount.tryAdd(_amount);
            require(success4, "user stAmount overflow");
            user_.stAmount = stAmount;
        }

        (bool success5, uint256 stTokenAmount) = pool_.stTokenAmount.tryAdd(_amount);
        require(success5, "pool stTokenAmount overflow");
        pool_.stTokenAmount = stTokenAmount;

        // user_.finishedMetaNode = user_.stAmount.mulDiv(pool_.accMetaNodePerST, 1 ether);
        (bool success6, uint256 finishedMetaNode) = user_.stAmount.tryMul(pool_.accMetaNodePerST);
        require(success6, "user stAmount mul accMetaNodePerST overflow");

        (success6, finishedMetaNode) = finishedMetaNode.tryDiv(1 ether);
        require(success6, "finishedMetaNode div 1 ether overflow");

        user_.finishedMetaNode = finishedMetaNode;  // 直接把状态修改

        emit Deposit(msg.sender, _pid, _amount);
    }


    // 安全转移代币
    function _safeMetaNodeTransfer(address _to, uint256 _amount) internal {
        uint256 MetaNodeBal = MetaNode.balanceOf(address(this));

        if (_amount > MetaNodeBal) {
            MetaNode.transfer(_to, MetaNodeBal);
        } else {
            MetaNode.transfer(_to, _amount);
        }
    }

    // 安全转移ETH
    function _safeETHTransfer(address _to, uint256 _amount) internal {
        (bool success, bytes memory data) = address(_to).call{ value: _amount }("");
        require(success, "ETH transfer call failed");
        // 对于普通的 ETH 转账（使用 call 且不带数据），接收合约不应该返回任何数据。
        // 大多数合约的 receive() 或 fallback() 函数不会返回数据，因此这个检查通常是多余的，甚至可能导致问题。
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "ETH transfer operation did not succeed");
        }
    }



    // 开关 开闭  设置属性
    function pauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(!withdrawPaused, "withfraw has been already paused");
        withdrawPaused = true;
        emit PauseWithdraw();
    }

    function unpauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(withdrawPaused, "withdraw has been already unpaused");
        withdrawPaused = false;
        emit UnpauseWithdraw();
    }

     function pauseClaim() public onlyRole(ADMIN_ROLE) {
        require(!claimPaused, "claim has been already paused");
        claimPaused = true;
        emit PauseClaim();
    }

    function unpauseClaim() public onlyRole(ADMIN_ROLE) {
        require(claimPaused, "claim has been already unpaused");
        claimPaused = false;
        emit UnpauseClaim();
    }

    function setStartBlock(uint256 _startBlock) public onlyRole(ADMIN_ROLE) {
        require(_startBlock <= endBlock, "start block must be smaller than end block");
        startBlock = _startBlock;
        emit SetStartBlock(_startBlock);
    }

    function setEndBlock(uint256 _endBlock) public onlyRole(ADMIN_ROLE) {
        require(startBlock <= _endBlock, "start block must be smaller than end block");
        endBlock = _endBlock;
        emit SetEndBlock(_endBlock);
    }

    function setMetaNodePerBlock(uint256 _MetaNodePerBlock) public onlyRole(ADMIN_ROLE) {
        require(_MetaNodePerBlock > 0, "invalid parameter");
        MetaNodePerBlock = _MetaNodePerBlock;
        emit SetMetaNodePerBlock(_MetaNodePerBlock);
    }

}