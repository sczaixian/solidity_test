// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FixedProxy {
    // EIP-1967 存储槽
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    
    constructor(address _implementation) {
        _setAdmin(msg.sender);
        _setImplementation(_implementation);
    }
    
    modifier onlyAdmin() {
        require(msg.sender == _getAdmin(), "Only admin");
        _;
    }
    
    function upgrade(address newImplementation) external onlyAdmin {
        _setImplementation(newImplementation);
    }
    
    function getImplementation() external view returns (address) {
        return _getImplementation();
    }
    
    function getAdmin() external view returns (address) {
        return _getAdmin();
    }
    
    function _setImplementation(address newImplementation) internal {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }
    
    function _getImplementation() internal view returns (address impl) {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }
    
    function _setAdmin(address admin) internal {
        bytes32 slot = _ADMIN_SLOT;
        assembly {
            sstore(slot, admin)
        }
    }
    
    function _getAdmin() internal view returns (address admin) {
        bytes32 slot = _ADMIN_SLOT;
        assembly {
            admin := sload(slot)
        }
    }
    
    fallback() external payable {
        address impl = _getImplementation();
        require(impl != address(0), "Implementation not set");
        
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
    
    receive() external payable {}
}