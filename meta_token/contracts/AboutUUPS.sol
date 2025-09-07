// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { StorageSlot } from "./StorageSlot.sol";
import { ERC1967Utils } from "./ERC1967Utils.sol";



/**
 * @dev ERC-1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}



abstract contract UUPSUpgradeable is IERC1822Proxiable {
    // 在构造函数中，address(this) 被永久地存储为实现合约的地址。这是一个巧妙的技巧，
    // 用于在 delegatecall 的上下文中区分“我是谁”（实现合约地址）和“我在哪里执行”（代理合约地址）。
    address private immutable __self = address(this);
    string public constant UPGRADE_INTERFACE_VERSION = "";

    error UUPSUnauthorizedCallContext();
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    // 确保函数只能通过代理合约被调用（通过 delegatecall），而不能在实现合约本身上直接调用。
    modifier onlyProxy() {
        _checkProxy();
        _;
    }

    // 与 onlyProxy 相反，确保某些函数（特别是 proxiableUUID) 只能在实现合约本身上直接调用，而不能通过代理调用。
    modifier notDelegated() {
        _checkNotDelegated();
        _;
    }

    function _checkProxy() internal view virtual {
        if (
            address(this) == __self || // Must be called through delegatecall
            ERC1967Utils.getImplementation() != __self // Must be called through an active proxy
        ) {
            revert UUPSUnauthorizedCallContext();
        }
    }

    function _checkNotDelegated() internal view virtual {
        if (address(this) != __self) {
            // Must not be called through delegatecall
            revert UUPSUnauthorizedCallContext();
        }
    }

    function proxiableUUID() external view virtual notDelegated returns (bytes32) {
        return ERC1967Utils.IMPLEMENTATION_SLOT;
    }

    function upgradeToAndCall(address newImplementation, bytes memory data) public payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        // UUPS 兼容性检查
        _upgradeToAndCallUUPS(newImplementation, data);
    }

    // 虚拟函数，必须由继承者重写
    function _authorizeUpgrade(address newImplementation) internal virtual;


    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data) private {
        // 尝试调用新实现合约的 proxiableUUID() 函数
        // 验证返回的 bytes32 slot 是否等于标准的 ERC1967Utils.IMPLEMENTATION_SLOT
        // 确保新的实现合约也是一个 UUPS 兼容的合约
        try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
            if (slot != ERC1967Utils.IMPLEMENTATION_SLOT) {
                revert UUPSUnsupportedProxiableUUID(slot);
            }
            // 调用方法：最终会通过代理的 delegatecall 修改代理合约中存储的实现地址，并可选地发起一个调用。
            ERC1967Utils.upgradeToAndCall(newImplementation, data);
        } catch {
            // The implementation is not UUPS
            revert ERC1967Utils.ERC1967InvalidImplementation(newImplementation);
        }
    }
}

/*
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MyUpgradeableToken is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers(); // 初始化器锁，防止初始化漏洞
    }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        // ... 其他初始化逻辑
    }

    // 必须重写这个函数，并提供访问控制
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // ... 你的业务逻辑
}
*/