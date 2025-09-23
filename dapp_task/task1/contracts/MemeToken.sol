// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";


contract MemeToken is Initializable, UUPSUpgradeable, PausableUpgradeable, AccessControlUpgradeable{

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
    uint256 public constant BURN_FREE = 1;  // 通缩 1%

    // 于池交互，用户向池中增加或减少流动性
    struct Pool {
        address amount;
    }

    function initialize(IERC20 _memeToken) public initializer{
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        memeToken = _memeToken;
    } 

    function _authorizeUpgrade(address newImplementation) internal onlyRole(UPGRADE_ROLE) override {}

    function transfer(address to, uint256 value) external returns (bool){
        // 
    }
}