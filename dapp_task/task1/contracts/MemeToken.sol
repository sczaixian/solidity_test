// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";


import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MemeToken is Initializable, UUPSUpgradeable, PausableUpgradeable, AccessControlUpgradeable, ReentrancyGuard, ERC20Upgradeable {

    using SafeERC20 for IERC20;
    using Address for address;
    using Math for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");

    IERC20 public memeToken;

    mapping (address => uint256) private _balance;
    mapping (address => mapping(address => uint256)) private _allowances;

    uint256 public maxTxAmount;  // 最大交易限额
    uint256 public maxTxNum;     // 每日最多交易次数
    uint256 public traTax;  // 交易方扣税
    uint256 public recvTax; // 收款方扣税
    uint256 public constant BURN_FEE = 1;  // 通缩 1%
    uint256 public constant COMMUNITY_FEE = 1; // 社区基金 1%

    uint256 public constant EXCHANGE_RATE = 100_0000_0000;// 兑换比例， x * y = 100 锁定价值 100亿usd

    bool public fundPaused;
    uint8 public constant feedDecimals = 8;    // 代币小数位数
    AggregatorV3Interface public dataFeed;
    uint256 public constant unlockBlocks = 20000;  // 冻结时间(多少个块，约1周)

    /*
        以用户为单位，用户 和 池子之间 分开
        用户可以用自己的币或者token 折算成 usd 再兑换为 memeToken， 赎回时反向操作（根据当时的兑换比例），
        因为 平台币会不断通缩，理论上 这个平台币价值会越来越高
        平台 发型量 1000亿  按照 100亿usd 折算  也就是 初始 为 10:1  当平台币缩量到10亿时 兑换比例就变成了1:10
        

        user 下会有多个stToken，
        每个 stToken 会有记录价值多少usd，每次兑换后赎回会有一个冷却期，比如7D，每次质押的时候会遍历当前 stToken 链，合并掉已经过了冷冻期的节点
        维护一个 可提取额度，提款操作：
            优先选择适合的 stToken，不满足优先从小块分配
        
    */
    /* 存入 代币 换取 平台币 */
    struct DepositRecord {
        uint256 amount;      // 折算成usd数量
        uint256 unblockNum;  // 解锁时间 
    } 

    struct User{
        uint256 amount;                           // 总存入usd数量
        uint256 lastUnlockBlockNum;               // 上次解锁块
        mapping(address => DepositRecord[]) dr;   // 某个 stToken 的存入链
    }
    mapping (address => User) public userDeposits;  // address -> user -> stToken -> deposit
    // https://docs.chain.link/data-feeds/price-feeds/addresses?page=1&testnetPage=1&search=eth%2Fusd

    /* 
        AUD / USD     0xB0C712f98daE15264c8E26132BCC91C40aD4d5F9
        BTC / USD     0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43
        BTC / USD     0x38c8b98A2Cb36a55234323D7eCCD36ad3bFC5954
        CSPX / USD    0x4b531A318B0e44B549F3b2f824721b3D0d51930A
        CZK / USD     0xC32f0A9D70A34B9E7377C10FDAd88512596f61EA
        DAI / USD     0x14866185B1962B63C3Ea9E03Bc1da838bab34C19
        ETH / USD     0x694AA1769357215DE4FAC081bf1f309aDC325306
        EUR / USD     0x1a81afB8146aeFfCFc5E50e8479e826E7D55b910
        FORTH / USD   0x070bF128E88A4520b3EfA65AB1e4Eb6F0F9E6632
        GBP / USD     0x91FAB41F5f3bE955963a986366edAcff1aaeaa83
        GHO / USD     0x635A86F9fdD16Ff09A0701C305D3a845F1758b8E
        IB01 / USD    0xB677bfBc9B09a3469695f40477d05bc9BcB15F50
        IBTA / USD    0x5c13b249846540F81c093Bc342b5d963a7518145
        JPY / USD     0x8A6af2B75F23831ADc973ce6288e5329F63D86c6
        LINK / USD    0xc59E3633BAAC79493d908e63626716e204A45EdF
        PYUSD / USD   0x57020Ba11D61b188a1Fd390b108D233D87c06057
        SNX / USD     0xc0F82A46033b8BdBA4Bb0B0e28Bc2006F64355bC
        SUSDE / USD   0x6f7be09227d98Ce1Df812d5Bc745c0c775507E92
        USDC / USD    0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E
        USDE / USD    0x55ec7c3ed0d7CB5DF4d3d8bfEd2ecaf28b4638fb
        USDG / USD    0x90E422f6B8cB0bD178C0F84764ad790715cbc2aa
        USDL / USD    0x5376B13E1622CB498E0E95F328fC7547e827fcC8
        WSTETH / USD  0xaaabb530434B0EeAAc9A42E25dbC6A22D7bE218E
        XAU / USD     0xC5981F461d74c46eB4b0CF3f4Ec79f025573B0Ea
    */
    // 映射：支持的原始资产地址 -> 其对应的预言机喂价合约地址  todo: feedprice isActive？
    mapping(address => address) public assetPriceFeed;


    // 于池交互，用户向池中增加或减少流动性
    struct Pool {
        uint256 amount;  // 币总量
    }
    mapping(address => Pool) public pools;   //  token  --> pool;



    event SetMemeToken(IERC20 indexed _memeToken);
    event PauseFund();
    event UNpauseFund();
    event FundedETH(address indexed sender, uint256 amount);
    event FundedToken(address indexed token, address indexed sender, uint256 amount);
    event SetFeedPrice(address indexed accAddress, address indexed feedAddress);
    event StakeToken(address indexed tokenAddr, uint256 indexed amount);


    function initialize(IERC20 _memeToken, uint256 _traTax, uint256 _recvTax, 
                        uint256 _maxTxAmount, uint256 _maxTxNum) public initializer{
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        setMemeToken(_memeToken);

        traTax = _traTax;
        recvTax = _recvTax;
        maxTxAmount = _maxTxAmount;
        maxTxNum = _maxTxNum;
    } 

    
    function stakeToken(address tokenAddr, uint256 amount) public {
        require(assetPriceFeed[tokenAddr] != address(0), "");
        require(amount > 0, "");
        Pool storage _pool = pools[tokenAddr];
        User storage _user = userDeposits[msg.sender];

        // 通过 token 得到usd
        address feedAddr = assetPriceFeed[tokenAddr];
        uint256 memAmount = convertTokenToUsd(feedAddr, amount);

        uint256 _totalSupply = totalSupply();

        (bool success, uint256 _amount) = _totalSupply.tryDiv(EXCHANGE_RATE);  // 计算得到比例
        require(success, "");
        (success, _amount) = amount.tryMul(_amount);  // 计算得到代币数量
        require(success, "");
        _mergeDeposit(tokenAddr);
        _user.dr[tokenAddr].push(
            DepositRecord({
                amount: memAmount, 
                unblockNum: block.number + unlockBlocks
            })
        );
        _pool.amount = _pool.amount + memAmount;
        emit StakeToken(tokenAddr, amount);
    }

    // 将可以提款的节点合并，后面寻找只需要找节点0就行
    function _mergeDeposit(address tokenAddr) internal {
        DepositRecord[] storage _dr = userDeposits[msg.sender].dr[tokenAddr];
        uint256 idx = 0;
        uint256 amountCount;
        for(uint256 i = 0; i < _dr.length; i++ ){
            if (_dr[i].unblockNum > block.number){
                break;
            }
            amountCount = amountCount + _dr[i].amount;
            idx++;
        }
        for(uint256 i = 1; i < _dr.length - idx; i++){
            _dr[i ] = _dr[i + idx];
        }

        for(uint256 i = 0; i < idx; i++){
            _dr.pop();
        }

        _dr[0].amount = amountCount;
    }


    function fund(address feedAddr, uint256 amount) external payable nonReentrant { 
        require(!fundPaused, "fund paused");
        require(amount > 0, "");
        if(feedAddr == address(0)){
            require(msg.value >= amount, "");
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "transfer failed");
            emit FundedETH(msg.sender, msg.value);
        }else{
            
        }
    }


    function transfer(address to, uint256 value) public override returns (bool){
        require(to != address(0), "");
        IERC20(to).safeTransfer(msg.sender, value);
        emit FundedToken(to, msg.sender, value);
        return true;
    }

    function _transter(address sender, address recipient, uint256 amount) internal {
        uint burnAmount = amount * traTax / 100;
        

    }


    function getChainlinkDataFeedLatestAnswer(address _dataFeedAddress) public view returns (int) {
        // prettier-ignore
        (
            /* uint80 roundId */,
            int256 answer,
            /*uint256 startedAt*/,
            /*uint256 updatedAt*/,
            /*uint80 answeredInRound*/
        ) = AggregatorV3Interface(_dataFeedAddress).latestRoundData();
        return answer;
    }

    //  token to usd
    function convertTokenToUsd(address _dataFeedAddress, uint256 amount) internal view returns(uint256) {
        require(amount > 0, "");
        uint256 price = uint256(getChainlinkDataFeedLatestAnswer(_dataFeedAddress));
        return amount * price / (10 ** 8);
    }


    function pauseFund() public onlyRole(ADMIN_ROLE) {
        require(!fundPaused, "fund already pause");
        fundPaused = true;
        emit PauseFund();
    }

    function unpauseFund() public onlyRole(ADMIN_ROLE) {
        require(fundPaused, "fund already unpause");
        fundPaused = false;
        emit UNpauseFund();
    }

    function setFeedPrice(address access, address feedAddress) public onlyRole(ADMIN_ROLE){
        require(access != address(0), "");
        require(feedAddress != address(0), "");
        assetPriceFeed[access] = feedAddress;
        emit SetFeedPrice(access, feedAddress);
    }

    function setMemeToken(IERC20 _memeToken) public onlyRole(ADMIN_ROLE) {
        memeToken = _memeToken;
        emit SetMemeToken(_memeToken);
    }

    function _authorizeUpgrade(address newImplementation) internal onlyRole(UPGRADE_ROLE) override {}

}

/*代币税功能：实现交易税机制，对每笔代币交易征收一定比例的税费，并将税费分配给特定的地址或用于特定的用途。
流动性池集成：设计并实现与流动性池的交互功能，支持用户向流动性池添加和移除流动性。
交易限制功能：设置合理的交易限制，如单笔交易最大额度、每日交易次数限制等，防止恶意操纵市场。
代码注释与文档撰写：在合约代码中添加详细的注释，解释每个函数和变量的作用及实现逻辑。撰写一份操作指南，
说明如何部署和使用该代币合约，包括如何进行代币交易、添加和移除流动性等操作。*/
// datafeed: eth/usd 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419