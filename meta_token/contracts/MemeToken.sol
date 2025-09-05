// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import {ERC1363Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC1363Upgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BridgeableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20BridgeableUpgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


/*

​​Transparent​​: 升级逻辑在​​代理合约​​中。 (透明代理)
    代理合约（Proxy）本身包含升级逻辑。它有一个 admin 地址，这个地址有权更改指向实现合约（Implementation）的地址。
    为了防止管理员和普通用户之间的功能调用冲突，它使用了一种名为“透明”的机制：​​如果调用者是管理员，
    则代理不会将任何调用委托给实现合约；反之，则总是委托。​

    Proxy Contract​​: 存储状态数据，并持有一个实现合约的地址和一个管理员地址。
    ​​Implementation Contract (Logic Contract)​​: 包含执行逻辑，没有状态
 
​​UUPS​​: 升级逻辑在​​实现合约​​中。 代理合约极其轻量 只知道一个指向实现合约的地址，并将所有调用都委托给它

    更高风险​​：如果实现合约（特别是升级函数）中存在漏洞，或者新部署的实现合约​​忘记了包含升级逻辑​​，代理合约将​​永久变得不可升级​​（因为代理自己不会升级）。
    ​​实现合约更复杂​​：开发者必须记得在实现合约中继承并正确集成升级相关的逻辑。

*/
contract MyToken is Initializable, ERC20Upgradeable, ERC20BridgeableUpgradeable, ERC20BurnableUpgradeable, ERC20PausableUpgradeable, OwnableUpgradeable, ERC1363Upgradeable, ERC20PermitUpgradeable, UUPSUpgradeable {
    address internal constant SUPERCHAIN_TOKEN_BRIDGE = 0x4200000000000000000000000000000000000028;
    error Unauthorized();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __ERC20_init("MyToken", "MTK");
        __ERC20Bridgeable_init();
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __Ownable_init(initialOwner);
        __ERC1363_init();
        __ERC20Permit_init("MyToken");
        __UUPSUpgradeable_init();
    }

    /**
     * @dev Checks if the caller is the predeployed SuperchainTokenBridge. Reverts otherwise.
     *
     * IMPORTANT: The predeployed SuperchainTokenBridge is only available on chains in the Superchain.
     */
    function _checkTokenBridge(address caller) internal pure override {
        if (caller != SUPERCHAIN_TOKEN_BRIDGE) revert Unauthorized();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable)
    {
        super._update(from, to, value);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC20BridgeableUpgradeable, ERC1363Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}