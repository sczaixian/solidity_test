// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";


// 简化的ERC20接口
interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}



// 高级DEX保护合约 提供安全的DEX交易功能，包含价格操控保护、防抢跑等功能
contract AdvancedDexProtection {
    
    IUniswapV2Router02 public immutable uniswapRouter;     // Uniswap V2 Router接口
    mapping(address => bool) public isWhitelistedPair;     // 白名单交易对映射
    address public owner;                 // 合约所有者
    uint256 public maxSlippage = 500;     // 最大滑点限制 (基础点为10000，500表示5%)
    uint256 public constant DEADLINE_DURATION = 20 minutes;     // 交易有效期（防止pending交易被恶意执行）
     
    // 事件声明
    event PairWhitelisted(address indexed pair, bool status);
    event SwapExecuted(address indexed user, address indexed pair, uint256 amountIn, uint256 amountOut);
    event SlippageUpdated(uint256 newSlippage);

    // 修饰器：仅所有者可调用
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }
    
    // 修饰器：验证交易对是否在白名单中
    modifier validateDexPair(address pair) {
        require(isWhitelistedPair[pair], "DEX pair not whitelisted");
        _;
    }
    
    // 修饰器：防抢跑保护 - 验证交易在合理时间内执行
    modifier antiFrontrun() {
        // 设置交易有效期，防止pending交易在价格不利时被执行
        require(block.timestamp <= block.timestamp + DEADLINE_DURATION, "Transaction expired");
        _;
    }

    /**
     * @dev 构造函数，初始化Router地址
     * @param routerAddress Uniswap V2 Router地址
     */
    constructor(address routerAddress) {
        require(routerAddress != address(0), "Invalid router address");
        uniswapRouter = IUniswapV2Router02(routerAddress);
        owner = msg.sender;
        
        // 初始化时自动将一些主流交易对加入白名单
        _initializeDefaultPairs();
    }
    
    // 初始化默认白名单交易对
    function _initializeDefaultPairs() internal {
        // 这里可以添加一些已知的安全交易对
        // 例如：WETH-USDC, WETH-USDT等
        // 实际部署时需要根据具体情况设置
    }

    /**
     * @dev 添加/移除白名单交易对
     * @param pair 交易对地址
     * @param status true=加入白名单, false=移除
     */
    function whitelistPair(address pair, bool status) external onlyOwner {
        require(pair != address(0), "Invalid pair address");
        
        // 验证是否为有效的Uniswap V2交易对
        if (status) {
            _validatePair(pair);
        }
        
        isWhitelistedPair[pair] = status;
        emit PairWhitelisted(pair, status);
    }
    
    /**
     * @dev 验证交易对的有效性
     * @param pair 交易对地址
     */
    function _validatePair(address pair) internal view {
        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);
        
        try pairContract.token0() returns (address token0) {
            require(token0 != address(0), "Invalid token0");
        } catch {
            revert("Not a valid Uniswap V2 pair");
        }
        
        try pairContract.token1() returns (address token1) {
            require(token1 != address(0), "Invalid token1");
        } catch {
            revert("Not a valid Uniswap V2 pair");
        }
        
        try pairContract.factory() returns (address factory) {
            require(factory != address(0), "Invalid factory");
        } catch {
            revert("Not a valid Uniswap V2 pair");
        }
    }

    /**
     * @dev 设置最大滑点限制
     * @param newSlippage 新的滑点值 (基础点，500 = 5%)
     */
    function setMaxSlippage(uint256 newSlippage) external onlyOwner {
        require(newSlippage <= 1000, "Slippage too high"); // 最大10%
        maxSlippage = newSlippage;
        emit SlippageUpdated(newSlippage);
    }

    /**
     * @dev 安全交换函数 - ETH → Token
     * @param pair 交易对地址
     * @param amountOutMin 最小输出数量
     * @param path 交易路径 [WETH, token]
     */
    function safeSwapETHForTokens(address pair, uint256 amountOutMin, address[] calldata path) external payable validateDexPair(pair) antiFrontrun {
        require(msg.value > 0, "Must send ETH");
        require(path.length >= 2, "Invalid path");
        require(path[0] == uniswapRouter.WETH(), "Path must start with WETH");
        
        uint256[] memory amounts = uniswapRouter.getAmountsOut(msg.value, path);    // 计算预期输出并验证滑点
        uint256 expectedAmountOut = amounts[amounts.length - 1];
        _validateSlippage(amountOutMin, expectedAmountOut);  // 滑点保护
        
        // 执行交换
        uniswapRouter.swapExactETHForTokens{value: msg.value}(
            amountOutMin,
            path,
            msg.sender, // 代币直接发送给用户
            block.timestamp + DEADLINE_DURATION
        );
        
        emit SwapExecuted(msg.sender, pair, msg.value, amountOutMin);
    }

    /**
     * @dev 安全交换函数 - Token → ETH
     * @param pair 交易对地址
     * @param amountIn 输入数量
     * @param amountOutMin 最小输出ETH数量
     * @param path 交易路径 [token, WETH]
     */
    function safeSwapTokensForETH(address pair, uint256 amountIn, uint256 amountOutMin, address[] calldata path) external validateDexPair(pair) antiFrontrun {
        require(amountIn > 0, "Invalid amount");
        require(path.length >= 2, "Invalid path");
        require(path[path.length - 1] == uniswapRouter.WETH(), "Path must end with WETH");
        
        uint256[] memory amounts = uniswapRouter.getAmountsOut(amountIn, path);    // 计算预期输出并验证滑点
        uint256 expectedAmountOut = amounts[amounts.length - 1];
        _validateSlippage(amountOutMin, expectedAmountOut);    // 滑点保护
        IERC20 token = IERC20(path[0]);     // 转移代币到本合约
        require(token.transferFrom(msg.sender, address(this), amountIn), "Transfer failed");
        
        // 授权Router使用代币
        require(token.approve(address(uniswapRouter), amountIn), "Approve failed");
        
        // 执行交换
        uniswapRouter.swapExactTokensForETH(
            amountIn,
            amountOutMin,
            path,
            msg.sender, // ETH直接发送给用户
            block.timestamp + DEADLINE_DURATION
        );
        
        emit SwapExecuted(msg.sender, pair, amountIn, amountOutMin);
    }

    /**
     * @dev 验证滑点是否在允许范围内
     * @param minAmountOut 用户设置的最小输出
     * @param expectedAmountOut 预期输出
     */
    function _validateSlippage(uint256 minAmountOut,  uint256 expectedAmountOut) internal view {
        if (expectedAmountOut == 0) return;
        uint256 actualSlippage = ((expectedAmountOut - minAmountOut) * 10000) / expectedAmountOut;  // 计算实际滑点
        require(actualSlippage <= maxSlippage, "Slippage too high");
    }

    // 紧急停止函数 - 仅所有者可调用
    function emergencyWithdraw(address token) external onlyOwner {
        if (token == address(0)) {
            payable(owner).transfer(address(this).balance);    // 提取ETH
        } else {
            IERC20 tokenContract = IERC20(token);    // 提取ERC20代币
            uint256 balance = tokenContract.balanceOf(address(this));
            tokenContract.transfer(owner, balance);
        }
    }

    // 接收ETH的fallback函数
    receive() external payable {}
}