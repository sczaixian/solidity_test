

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;



interface IMERC20 {
    // 发行量
    function totalSupply() external view returns(uint256);
    // 查询额度
    function balanceOf(address) external view returns(uint256);
    // 转账
    function transfer(address, uint256) external returns(bool);
    // 查询授权额度
    function allowance(address owner, address spender) external view returns(uint256);
    // 授权三方操作一定数量的代币，不需要你确认
    function approve(address, uint256) external returns(bool);
    // 代扣转账
    function transferFrom(address,address,uint256) external returns(bool);
}

contract MERC20 is IMERC20{
    string public name;  // 代币的名称
    string public symbol; // 代币的符号
    uint8 public decimals = 18; // 代币的小数位

    address public owner; // 拥有者

    uint256 public totalSupp ;  // 代币的总供应量
    mapping(address => uint256) private _balance;  // 余额映射

    mapping (address => mapping(address => uint256)) private _allowAmount; // 授权代扣

    // 转账事件（当发生转账时触发）
    event Transfer(address indexed from, address indexed to, uint256 value);
    // 授权事件（当设置授权额度时触发）
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error OnlyOwner();
    error InsufficientBalance();
    error  InsufficientAllowance();

    constructor (string memory _name, string memory _symbol, uint8 _decimals, uint256 _initSupply) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        owner = msg.sender;
        _mint(msg.sender, _initSupply);
    }


    modifier onlyOwner(){
        if(msg.sender != owner) revert OnlyOwner();
        _;
    }

    function balanceOf(address addr) external view returns(uint256){
        return _balance[addr];
    }

    function totalSupply() external view returns(uint256){
        return totalSupp;
    }

    function transfer(address to, uint256 amount) external returns(bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns(bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns(bool){
        uint256 currAmount = _allowAmount[from][msg.sender];
        if(currAmount < amount) revert InsufficientAllowance();

        unchecked {  // 减少授权额度
            _approve(from , msg.sender, currAmount - amount);
        }
        _transfer(from, to, amount);
        return true;
    }
    // 查询授权额度
    function allowance(address _owner, address spender) external view returns(uint256){
        return _allowAmount[_owner][spender];
    }

    function _transfer(address from, address to, uint256 amount) internal returns(bool){
        if(_balance[from] < amount) revert InsufficientBalance();
        unchecked {
            _balance[from] -= amount;
            _balance[to] += amount;
        }
        emit Transfer(from, to, amount);
        return true;
    }

    // 铸币，只有拥有者可以调用
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function _approve(address _owner, address spender, uint256 amount) private {
        _allowAmount[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
    }

    function _mint(address account, uint256 amount) private{
        totalSupp += amount;
        unchecked { // 显式禁用算术运算的溢出检查, 会增加gas消耗，在明知道不会溢出的情况下可以不检查
            _balance[account] += amount;
        }
        emit Transfer(address(0), account, amount);  // 铸币事件（从零地址发出）
    }
}