// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Context} from "./Context.sol";

interface MyTokenInterface {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

contract MyToken is MyTokenInterface, Context {
    string private _name;
    string private _symbol;
    uint8 private constant _decimals = 18;
    uint256 private _totalSupply;

    mapping(address => uint256) public _balances;

    mapping(address => mapping(address => uint256)) private _allowAmount;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) public returns (bool) {
        address owner = _messageSender();
        _transfer(owner, to, value);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowAmount[owner][spender];
    }

    function approve(address spender, uint256 value) public returns (bool) {
        address owner = _messageSender();
        _approve(owner, spender, value);
        return true;
    }

    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (address(0) == owner) {
            // ..
        }

        if (address(0) == spender) {
            // ...
        }

        _allowAmount[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    function transferFrom( address from, address to, uint256 value ) public returns (bool) {
        address spender = _messageSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(from != address(0), "");
        require(to != address(0), "");
        _update(from, to, value);
    }

    function _update(address from, address to, uint256 value) internal virtual {
        if (address(0) == from) {
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                // err
            }
            unchecked {
                _balances[from] = fromBalance - value;
            }
        }

        if (address(0) == to) {
            unchecked {
                _totalSupply -= value;
            }
        } else {
            unchecked {
                _balances[to] += value;
            }
        }
        emit Transfer(from, to, value);
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) {
                //
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}
