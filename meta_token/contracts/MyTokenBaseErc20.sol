// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface MyTokenInterface{

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns(uint256);
    function balanceOf(address account) external view returns(uint256);
    function transfer(address to, uint256 value) external returns(bool);
    function allowance(address owner, address spender) external view returns(uint256);
    function approve(address spender, uint256 value) external returns(bool);
    function transferFrom(address from, address to, uint256 value) external returns(bool);
}


contract MyToken is MyTokenInterface{
    constant string private _name = "MyToken";
    constant private _symbol = "MTK";
    constant string private _decimals = 18;
    uint256 private _totalSupply;

    mapping(address => uint256) public _balances;

    mapping(address => mapping(address => uint256)) private _allowAmount;

    constructor(uint256 totalSupply){
        _totalSupply = totalSupply;
    }

    function name() public view virtual returns(string){
        return _name;
    }

    function totalSupply() external view returns(uint256){
        return _totalSupply;
    }
    
    function balanceOf(address account) external view returns(uint256){
        return _balance[account];
    }
    
    function _msgSender() internal view returns(address) {
        return msg.sender;
    }
    function transfer(address to, uint256 value) external returns(bool){
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }
    
    function allowance(address owner, address spender) external view returns(uint256){
        return _allowAmount[owner][spender];
    }
    
    function approve(address spender, uint256 value) external returns(bool){
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    function _approve()
    
    function transferFrom(address from, address to, uint256 value) external returns(bool){
        address owner = _msgSender();
        
    }

    function _transfer(address from, address to, uint256 value) internal returns(bool) {
        require(from != address(0), "");
        require(to != address(0), "");
        _update(from, to, value);
    }

    function _update(address from, address to, uint256 value) internal virtual {
        if( address(0) == from){
            _totalSupply += value;
        }else{
            uint256 fromBalance = _balance[from];
            if(fromBalance < value){
                // err
            }
            unchecked {
                _balance[from] = fromBalance - value;
            }
        }

        if(address(0) == to){
            unchecked {
                _totalSupply -= value;
            }
        } else {
            unchecked {
                _balance[to] += value;
            }
        }
        emit Transfer(from, to, value);
    }
}


contract ImpErc20 is IERC20{

    string private _name;
    string private _symbol;
    uint8 private _decimals = 18;

    mapping(address => mapping(address => uint256)) private _allowAmount;

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value){

    }

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value){

    }

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256){

    }

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256){

    }

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool){

    }

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256){

    }

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool){

    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool){

    }
}