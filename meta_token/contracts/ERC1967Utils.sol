// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import { Address } from "./Address.sol";
import { IERC1967 } from "./IERC1967.sol";
import { StorageSlot } from "./StorageSlot.sol";

/*
代理模式 (Proxy Pattern)： 
    允许将合约的逻辑（实现）与存储分离。
    用户与一个固定的代理合约交互，
    代理合约通过 delegatecall 将所有调用转发给另一个实现合约（Implementation Contract）。delegatecall 的特点是：
    使用目标合约的代码，但在当前合约（代理）的上下文中执行，这意味着存储的修改发生在代理合约上

可升级性 (Upgradability)：
    因为逻辑在实现合约中，所以只需更改代理合约所指向的实现合约地址，就能升级整个应用的逻辑，而用户的资产（存储）和合约地址保持不变

ERC1967：标准化了代理合约中用于存储关键信息（如实现地址、管理员地址）的特定存储槽。    
    通过标准化槽位，区块链浏览器、钱包和第三方工具可以以一种一致的方式识别代理合约并查询其相关信息（如当前实现地址）。
*/
library ERC1967Utils {
    // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
    // 减 1 是为了避免哈希结果恰好指向某些特殊结构的存储槽
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    error ERC1967InvalidImplementation(address implementation);
    error ERC1967NonPayable();

    function getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    // 更新存储槽
    function _setImplementation(address newImplementation) private {
        // 检查新的实现地址是否是一个合约
        if (newImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(newImplementation);
        }
        // 将新的实现合约地址写入ERC1967标准规定的特定存储槽位
        // 这样，以后所有的普通用户调用都会自动转发到这个新合约
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
    }

    // 升级操作
    function upgradeToAndCall(address newImplementation, bytes memory data) internal {
        _setImplementation(newImplementation);
        emit IERC1967.Upgraded(newImplementation);

        // 如果调用者还提供了 data（即初始化调用数据），
        // 函数会代表这个代理合约，向新的实现合约发起一次低级别调用（delegatecall 或 call，取决于是否有value），
        // 来执行初始化操作（例如设置初始变量、注册合约等）。
        if (data.length > 0) {
            // 使用 functionDelegateCall 向新的实现合约发起一个调用
            Address.functionDelegateCall(newImplementation, data);
        } else {
            _checkNonPayable();
        }
    }
    // 如果用户发送了 ETH（msg.value > 0）但没有提供 data 来进行初始化调用，
    // 这些 ETH 将永远被困在代理合约中，因为代理合约本身通常没有提取 ETH 的逻辑。
    // 这是一个非常重要的安全特性，防止用户资金因误操作而丢失。
    function _checkNonPayable() private {
        if (msg.value > 0) {
            revert ERC1967NonPayable();
        }
    }

    error ERC1967InvalidAdmin(address admin);
    // 管理员地址  ADMIN_SLOT = keccak-256("eip1967.proxy.admin") - 1
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    function getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(ADMIN_SLOT).value;
    }
    // 防止管理员被设置为零地址，这可能会永久失去代理合约的控制权
    function _setAdmin(address newAdmin) private {
        if (newAdmin == address(0)) {
            revert ERC1967InvalidAdmin(address(0));
        }
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = newAdmin;
    }
    // 先触发事件，再更新存储
    function changeAdmin(address newAdmin) internal {
        emit IERC1967.AdminChanged(getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /*
    error ERC1967InvalidBeacon(address beacon);
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;
    function getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(BEACON_SLOT).value;
    }
    function _setBeacon(address newBeacon) private {
        if (newBeacon.code.length == 0) {
            revert ERC1967InvalidBeacon(newBeacon);
        }

        StorageSlot.getAddressSlot(BEACON_SLOT).value = newBeacon;

        address beaconImplementation = IBeacon(newBeacon).implementation();
        if (beaconImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(beaconImplementation);
        }
    }
    function upgradeBeaconToAndCall(address newBeacon, bytes memory data) internal {
        _setBeacon(newBeacon);
        emit IERC1967.BeaconUpgraded(newBeacon);

        if (data.length > 0) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        } else {
            _checkNonPayable();
        }
    }
    */
}   
