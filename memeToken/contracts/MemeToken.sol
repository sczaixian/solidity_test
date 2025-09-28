// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./InitialLiquidityProvider.sol";

contract MemeToken is ERC20, Ownable{
    address public _owner;    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public isExcludedFromFee;    // 免手续费

    uint256 public buyTax = 300;       // 买入税 3%
    uint256 public sellTax = 500;      // 卖出税 5%
    uint256 public transferTax = 100;  // 转账税 1%


    uint256 public liquidityTax = 40;  // 税收40%进入流动性
    uint256 public marketingTax = 30;  // 税收30%用于营销
    uint256 public rewardTax = 30;     // 税收30%用于分红

    uint256 public maxWalletAmount = totalSupply() / 100;        // 最大持仓1%
    uint256 public maxTransactionAmount = totalSupply() / 10000; // 单笔交易最大金额万1
    bool public antiWhaleAbled = true;                           // 反巨鲸

    address public constant deadAddress = 0x000000000000000000000000000000000000dEaD;  // 黑洞地址
    uint256 private _liquidityThreshold = totalSupply() / 1000;  // 税收流动性触发阈值
    uint256 private _collectedTax;                               // 税收累计
    bool private _inSwap;

    address public marketingWallet;          // 营销地址
    uint256 public totalRewardsDistributed;  // 记录总共分红了多少代币给持币者 用于追踪历史累计分红总额
    uint256 public totalBurned;              // 销毁总额

    // 买入: 用户ETH → UniswapRouter → UniswapV2Pair → 用户获得MTK
    // 卖出: 用户MTK → UniswapRouter → UniswapV2Pair → 用户获得ETH
    address public uniswapV2Pair;           // 用于交易类型识别
    bool public tradingEnabled = false;     // 开关

    address public teamWallet; // 团队研发
    address public ecosystemWallet;  // 生态基金

    struct Allocation {
        address wallet;      // 地址
        string purpose;      // 用途描述
        uint256 percentage;  // 分配比例
        uint256 lockPeriod;  // 锁仓期限
    }

    Allocation[] public allocations;

    address public initialLiquidityWallet;  // 流动性
    address public communityWallet;         // 社区钱包
    address public treasuryWallet;
    
    modifier lockSwap {
        _inSwap = true;
        _;
        _inSwap = false;
    }

    modifier tradingChack(address from, address to){
        // 如果交易未启用，只允许owne和免手续费的地址交易
        if(!tradingEnabled){
            require(isExcludedFromFee[from] || isExcludedFromFee[to], "");
        }
        _;
    }

    // 事件
    event TaxesDistributed(uint256 liquidity, uint256 marketing, uint256 rewards);

    constructor(address _marketingWallet) ERC20("MemeToken","MTK") Ownable(msg.sender) {
        require(_marketingWallet != address(0), "marketingWallet address cannot be zero address");
        marketingWallet = _marketingWallet;
        _owner = msg.sender;

        _mint(msg.sender, 10_0000_0000);

        // 创建一个新的EOA地址专门用于初始流动性 
        initialLiquidityWallet = address(new InitialLiquidityProvider());  
        // 初始分配：90%给部署者，10%锁定用于未来的空投和营销
        _balances[msg.sender] = totalSupply() * 90 / 100;
        _balances[address(this)] = totalSupply() * 10 / 100;

        // 设置免手续费地址
        isExcludedFromFee[_owner] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[deadAddress] = true;
        isExcludedFromFee[_marketingWallet] = true;


        emit Transfer(address(0), msg.sender, _balances[msg.sender]);
        emit Transfer(address(0), address(this), _balances[address(this)]);
    }

    function setUniswapPair(address pair) onlyOwner external{
        require(uniswapV2Pair == address(0), "Pair is already set");
        uniswapV2Pair = pair;
        tradingEnabled = true;
    }

    function setAllocations() onlyOwner external{
        allocations.push(Allocation(teamWallet, "Team Gradual release over 12 months", 10, 365));
        allocations.push(Allocation(marketingWallet, "Marketing and Development", 15, 0));
        allocations.push(Allocation(initialLiquidityWallet, "Initial Liquidity", 5, 0));
        allocations.push(Allocation(communityWallet, "Community Airdrop", 10, 0));
        allocations.push(Allocation(treasuryWallet, "Project Treasury", 60, 730));
    }

    function _transfer(address from, address to, uint256 amount) override internal tradingChack(from, to) {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        // 检查余额是否足够
        require(_balances[from] >= amount, "Insufficient balance");
        
        // 反鲸鱼检查
        if (antiWhaleAbled && !isExcludedFromFee[to]) {
            require(amount < maxTransactionAmount, "transfer amount exceeds max transaction");
            require(_balances[to] + amount <= maxWalletAmount, "wallet balace exceeds limit");
        }

        // 检查是否在交换中，避免重入
        if(_inSwap){
            _basicTransfer(from, to, amount);
            return;
        }

        uint256 txAmount = 0;
        // 计算税费（免手续费地址不扣税）
        if(!isExcludedFromFee[from] && !isExcludedFromFee[to]){
            txAmount = _calculateTax(from, to, amount);
        }

        // 执行转账
        uint256 transferAmount = amount - txAmount;
        _basicTransfer(from, to, transferAmount);

        // 处理税费
        if(txAmount > 0){
            _basicTransfer(from, address(this), txAmount);
            _collectedTax += txAmount;
            // 如果积累的税费达到阈值，进行分配
            if(_collectedTax >= _liquidityThreshold && from != uniswapV2Pair){

            }
        }
    }

    function _basicTransfer(address from, address to, uint256 amount) private {
        _balances[from] -= amount;
        _balances[to] += amount;
    }

    function _calculateTax(address from, address to, uint256 amount) private view returns(uint256){
        // 如果是买入操作（从交易对买入）
        if(from == uniswapV2Pair){
            return amount * buyTax / 10000;
        }else if (to == uniswapV2Pair) {   // 如果是卖出操作（卖出到交易对）
            return amount * sellTax / 10000;
        } else {   // 普通转账
            return amount * transferTax / 10000;
        }
    }

    function _distributeTaxes() private lockSwap {
        uint256 amountToDistribute = _collectedTax;
        if(amountToDistribute == 0) return;
        _collectedTax = 0;

        uint256 liquidityAmount = amountToDistribute * liquidityTax / 100;
        uint256 marketingAmount = amountToDistribute * marketingTax / 100;
        uint256 rewardAmount = amountToDistribute - liquidityAmount - marketingAmount;

        // 发送营销费用
        if(marketingAmount > 0){
            _basicTransfer(address(this), marketingWallet, marketingAmount);
        }

        // 添加流动性
        if (liquidityAmount > 0) {
            
        }

        // 分红分配 按照持币比例分红
        if (rewardAmount > 0) {
            _distributeRewards(rewardAmount);
        }

        emit TaxesDistributed(liquidityAmount, marketingAmount, rewardAmount);
    }

    function _distributeRewards(uint256 amount) private {

    }


    // ========== 所有者功能 ==========
    
    /**
     * @dev 设置税收比率（基础单位是10000，所以500表示5%）
     */
    function setTaxRates(uint256 _buyTax, uint256 _sellTax, uint256 _transferTax) external onlyOwner {
        require(_buyTax <= 1000, "Buy tax too high"); // 最大10%
        require(_sellTax <= 1000, "Sell tax too high");
        require(_transferTax <= 500, "Transfer tax too high"); // 最大5%
        
        buyTax = _buyTax;
        sellTax = _sellTax;
        transferTax = _transferTax;
    }
    
    /**
     * @dev 设置税收分配比例
     */
    function setTaxDistribution(uint256 _liquidity, uint256 _marketing, uint256 _reward) external onlyOwner {
        require(_liquidity + _marketing + _reward == 100, "Distribution must sum to 100%");
        liquidityTax = _liquidity;
        marketingTax = _marketing;
        rewardTax = _reward;
    }
    
    /**
     * @dev 设置反鲸鱼参数
     */
    function setAntiWhaleSettings(uint256 _maxWallet, uint256 _maxTransaction, bool _enabled) external onlyOwner {
        require(_maxWallet >= totalSupply() / 1000, "Max wallet too small"); // 至少0.1%
        require(_maxTransaction >= totalSupply() / 10000, "Max transaction too small"); // 至少0.01%
        
        maxWalletAmount = _maxWallet;
        maxTransactionAmount = _maxTransaction;
        antiWhaleAbled = _enabled;
    }
    
    /**
     * @dev 设置免手续费地址
     */
    function setExcludedFromFee(address account, bool excluded) external onlyOwner {
        isExcludedFromFee[account] = excluded;
    }
    
    /**
     * @dev 手动触发税费分配
     */
    function manualDistributeTaxes() external onlyOwner {
        _distributeTaxes();
    }
    
    /**
     * @dev 提取意外发送到合约的代币
     */
    function rescueTokens(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20(tokenAddress).transfer(msg.sender, amount);
    }
   
    
    // ========== 公共视图函数 ==========
    
    // 获取合约统计信息
    function getContractInfo() external view returns (
        uint256 circulatingSupply,
        uint256 burnedAmount,
        uint256 rewardsDistributed,
        uint256 currentTaxBalance
    ) {
        circulatingSupply = totalSupply() - _balances[deadAddress] - _balances[address(0)];
        burnedAmount = totalBurned;
        rewardsDistributed = totalRewardsDistributed;
        currentTaxBalance = _collectedTax;
    }

}