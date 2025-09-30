// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract UUPSProxy {
    address public implementation;
    
    function upgradeTo(address newImplementation) external virtual;
    
    fallback() external payable {
        address _impl = implementation;
        
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), _impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
    
    receive() external payable {}
}

contract UUPSImplementation is UUPSProxy {
    address public admin;
    uint256 public value;
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }
    
    function initialize() public {
        admin = msg.sender;
    }
    
    function upgradeTo(address newImplementation) external override onlyAdmin {
        implementation = newImplementation;
    }
    
    function setValue(uint256 _value) public onlyAdmin {
        value = _value;
    }
    
    function version() public pure returns (string memory) {
        return "V1";
    }
}