// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";



// // 导入Uniswap接口
// interface IUniswapV2Router02 {
//     function addLiquidityETH(address token, uint amountTokenDesired, uint amountTokenMin, uint amountETHMin, address to, uint deadline) 
//                                                                 external payable returns (uint amountToken, uint amountETH, uint liquidity);
//     function factory() external pure returns (address);
// }

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
}

// AutoLiquidity - 自动流动性管理合约 该合约用于自动向Uniswap添加流动性并管理流动性锁定
contract AutoLiquidity {
    IUniswapV2Router02 public immutable uniswapRouter;   // Uniswap V2 路由器地址 (主网)
    address public owner;               // 合约所有者
    uint256 public liquidityLockTime;   // 流动性锁定时间戳
    address public liquidityPair;       // 流动性配对地址
    
    // 事件声明
    event LiquidityAdded(uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);
    event LiquidityLocked(uint256 lockUntil);
    event LiquidityUnlocked();
    
    // 修饰器：只有所有者可以调用
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }
    
    // 修饰器：检查流动性是否已解锁
    modifier whenUnlocked() {
        require(block.timestamp >= liquidityLockTime, "Liquidity is locked");
        _;
    }
    
    // 构造函数，初始化Uniswap路由器和所有者  _router Uniswap V2 路由器地址
    constructor(address _router) {
        require(_router != address(0), "Router address cannot be zero");
        uniswapRouter = IUniswapV2Router02(_router);
        owner = msg.sender;
        liquidityLockTime = block.timestamp; // 初始设置为当前时间，表示未锁定
    }
    
    // 接收ETH的函数
    receive() external payable {}
    
    /**
     * @dev 内部函数：添加流动性到Uniswap
     * @param tokenAddress 要配对的代币地址
     * @param tokenAmount 代币数量
     * @param ethAmount ETH数量
     * @param slippage 滑点容忍度 (基础点为单位，如50表示0.5%)
     */
    function _addLiquidity(address tokenAddress, uint256 tokenAmount, uint256 ethAmount, uint256 slippage) internal returns (uint256 liquidity) {
        require(tokenAddress != address(0), "Token address cannot be zero");
        require(tokenAmount > 0, "Token amount must be greater than 0");
        require(ethAmount > 0, "ETH amount must be greater than 0");
        require(address(this).balance >= ethAmount, "Insufficient ETH balance");
        
        IERC20 token = IERC20(tokenAddress);  // 获取代币实例
        uint256 tokenBalance = token.balanceOf(address(this));   // 检查代币余额
        require(tokenBalance >= tokenAmount, "Insufficient token balance");
        uint256 minTokenAmount = tokenAmount * (10000 - slippage) / 10000;    // 计算最小接受量（考虑滑点）
        uint256 minETHAmount = ethAmount * (10000 - slippage) / 10000;
        
        // 授权Uniswap路由器使用代币
        require(token.approve(address(uniswapRouter), tokenAmount), "Token approval failed");
        
        // 添加流动性
        (uint256 amountToken, uint256 amountETH, uint256 resultLiquidity) = 
            uniswapRouter.addLiquidityETH{value: ethAmount}(
                tokenAddress,
                tokenAmount,
                minTokenAmount,  // 最小代币数量
                minETHAmount,    // 最小ETH数量
                address(this),   // LP代币发送到本合约
                block.timestamp + 1200 // 20分钟过期时间
            );
        
        liquidity = resultLiquidity;
        liquidityPair = _getPair(tokenAddress);  // 获取流动性配对地址
        
        // 触发事件
        emit LiquidityAdded(amountToken, amountETH, resultLiquidity);
        
        // 退还未使用的代币和ETH
        _refundRemaining(token, tokenAmount, amountToken);
    }
    
    /**
     * @dev 公开函数：添加流动性（供外部调用）
     * @param tokenAddress 代币地址
     * @param tokenAmount 代币数量
     * @param slippage 滑点容忍度
     */
    function addLiquidity(address tokenAddress, uint256 tokenAmount, uint256 slippage) external payable onlyOwner returns (uint256) {
        require(slippage <= 500, "Slippage too high"); // 最大5%滑点
        uint256 ethAmount = msg.value;
        return _addLiquidity(tokenAddress, tokenAmount, ethAmount, slippage);
    }
    
    /**
     * @dev 锁定流动性
     * @param daysToLock 锁定天数（最大365天）
     */
    function lockLiquidity(uint256 daysToLock) external onlyOwner {
        require(daysToLock > 0 && daysToLock <= 365, "Lock period 1-365 days");
        liquidityLockTime = block.timestamp + (daysToLock * 1 days);     // 设置锁定时间
        emit LiquidityLocked(liquidityLockTime);
    }
    
    // 解锁流动性（只能在锁定期满后调用）
    function unlockLiquidity() external onlyOwner whenUnlocked {
        liquidityLockTime = block.timestamp; // 设置为当前时间表示解锁
        emit LiquidityUnlocked();
    }
    
    /**
     * @dev 提取LP代币（只能在解锁后调用）
     * @param to 接收地址
     */
    function withdrawLPTokens(address to) external onlyOwner whenUnlocked {
        require(to != address(0), "Invalid recipient address");
        require(liquidityPair != address(0), "No liquidity pair exists");
        
        IERC20 lpToken = IERC20(liquidityPair);
        uint256 balance = lpToken.balanceOf(address(this));
        require(balance > 0, "No LP tokens to withdraw");
        
        require(lpToken.transfer(to, balance), "LP token transfer failed");
    }
    
    /**
     * @dev 获取配对地址
     * @param tokenAddress 代币地址
     */
    function _getPair(address tokenAddress) internal view returns (address) {
        IUniswapV2Factory factory = IUniswapV2Factory(uniswapRouter.factory());
        return factory.getPair(tokenAddress, uniswapRouter.WETH());   // 传入代币地址和 WETH 地址，返回对应的交易对合约地址
    }
    
    // 退还剩余的代币
    function _refundRemaining(IERC20 token, uint256 expectedAmount, uint256 usedAmount) internal {
        if (usedAmount < expectedAmount) {
            uint256 refundAmount = expectedAmount - usedAmount;
            // 如果合约中有多余的代币，可以退还给所有者
            // 这里只是示例，实际实现可能需要根据需求调整
        }
    }
    
    // 获取合约信息
    function getContractInfo() external view returns (address _owner, uint256 _lockTime, bool _isLocked, address _pairAddress) {
        return (owner, liquidityLockTime, block.timestamp < liquidityLockTime, liquidityPair);
    }
    
    // 紧急提取ETH（仅限所有者）
    function emergencyWithdrawETH(address to) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        uint256 balance = address(this).balance;
        payable(to).transfer(balance);
    }
    
    // 转移所有权
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
}