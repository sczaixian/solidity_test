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

    uint256 public constant EXCHANGE_RATE = 100;// 兑换比例， x * y = 100

    bool public fundPaused;

    AggregatorV3Interface public dataFeed;

    uint256 public unlockBlocks;  // 冻结时间(多少个块)

    /*
    用户将自己的币存到合约，换取token 需要先将用户的币折算成usd,兑换比例是1:100，
    在冻结时间过后可以用平台币换回自己的币 换算方式相同，先按照比例兑换成 usd，然后依照当前的比例兑换给用户
    */
    struct DepositRecord {
        address asset;   // 代币地址
        uint256 amount;  // 数量
        uint256 blockNum;  // 时间
    }

    struct User{
        DepositRecord [] dr;   // 用户往合约质押代币

    }



    // 于池交互，用户向池中增加或减少流动性
    struct Pool {
        address amount;
    }




    event SetMemeToken(IERC20 indexed _memeToken);
    event PauseFund();
    event UNpauseFund();

    event FundedETH(address indexed sender, uint256 amount);
    event FundedToken(address indexed token, address indexed sender, uint256 amount);




    function initialize(IERC20 _memeToken, address _dataFeedAddr, 
        uint256 _traTax, uint256 _recvTax, uint256 _maxTxAmount, uint256 _maxTxNum) public initializer{
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        setMemeToken(_memeToken);

        dataFeed = AggregatorV3Interface(_dataFeedAddr);
        traTax = _traTax;
        recvTax = _recvTax;
        maxTxAmount = _maxTxAmount;
        maxTxNum = _maxTxNum;
    } 

    function _authorizeUpgrade(address newImplementation) internal onlyRole(UPGRADE_ROLE) override {}

    function setMemeToken(IERC20 _memeToken) public onlyRole(ADMIN_ROLE) {
        memeToken = _memeToken;

        emit SetMemeToken(_memeToken);
    }

    function transfer(address to, uint256 value) external returns (bool){
        // 
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
            IERC20(feedAddr).safeTransfer(msg.sender, amount);
            emit FundedToken(feedAddr, msg.sender, amount);
        }
    }



    function getChainlinkDataFeedLatestAnswer() public view returns (int) {
        // prettier-ignore
        (
            /* uint80 roundId */,
            int256 answer,
            /*uint256 startedAt*/,
            /*uint256 updatedAt*/,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();
        return answer;
    }

    // function transfer()


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


}

/*代币税功能：实现交易税机制，对每笔代币交易征收一定比例的税费，并将税费分配给特定的地址或用于特定的用途。
流动性池集成：设计并实现与流动性池的交互功能，支持用户向流动性池添加和移除流动性。
交易限制功能：设置合理的交易限制，如单笔交易最大额度、每日交易次数限制等，防止恶意操纵市场。
代码注释与文档撰写：在合约代码中添加详细的注释，解释每个函数和变量的作用及实现逻辑。撰写一份操作指南，
说明如何部署和使用该代币合约，包括如何进行代币交易、添加和移除流动性等操作。*/
// datafeed: eth/usd 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419