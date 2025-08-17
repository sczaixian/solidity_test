// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;



contract Voting{
    address public owner;
    // mapping 不能作为函数的返回值类型 ， 也不能做函数的入参，函数的返回类型只能是 calldata 或 memory
    // 不能删除mapping，只能删除值
    mapping (address => uint) public votSet;  // mapping 只能声明为状态变量，不能写到函数内声明，

    // mapping 不能放到结构体中
    // 候选人结构体  结构体可以删除
    struct Candidate{  // 嵌套映射不占用初始化存储槽 ？
        bytes32 nameHash;  // 比string存储更便宜  -- 静态数据
        // mapping(uint256 => uint256) voteCounts;  // 动态数据
        uint256 voteCounts;
    }

    // bytes32 [] nameHashArray; // 使用辅助数组来存储map的所有键来辅助便利map
    // 通过维护自增id来帮助便利，
    uint256 public condidateCount;  // 注册人数
    mapping(uint256 => Candidate) public candidates;  // 候选人hash到候选人的映射
    mapping(bytes32 => uint256) public candidateIds;  // 候选人名字
    mapping(address => bool) public hasVoted; // 是否投票

    /*
    什么是event： 它是一种允许合约在区块链上记录信息的机制，这些信息可以被外部监听（例如前端应用）并作出反应。
    事件不会在链上直接执行任何逻辑，
    它们主要用于日志记录和通知， 相比存储便利它更节省gas，历史查询
    这些记录信息被写入区块链中，但不会存储在合约存储中，因此成本远低于存储变量

    一旦事件被发出(emit)，就无法修改或删除 成为区块链永久记录的一部分

    event AnonymousEvent(uint indexed x, uint y) anonymous;  匿名事件 不生成事件签名的 topic，节省 gas：

    event 事件最终会以 EVM 日志条目形式存储 形式如下：
    [
        address: 合约地址,
        topics: [
            0: keccak256("Voted(address,uint256,uint256)"), // 事件签名哈希
            1: indexed voter (address),                     // 第一个indexed参数
            // 最多3个topics
        ],
        data: abi.encode(candidateId, round)              // 非indexed参数
    ]

        indexed 关键字
        1. 生成特殊的"主题"(topic)索引，存储在topics位置， 大小限制32字节，  ---  非索引存在 data， 大小没有限制搜索性差
        2. 允许在链下高效过滤和搜索事件
        3. 每个事件最多可以有 3 个 indexed 参数

        每个 indexed 参数增加约 375 Gas；  非 indexed 参数按数据大小计算 Gas

        哪些字段适合indexed
        1. 高频过滤字段​​：如用户地址、交易ID等
        2. 精确匹配字段​​：如状态码、类型标识
        哪些字段不适合indexed
        1. 大型数据字段​​：字符串、字节数组
        2. 高基数字段​​：如时间戳、随机数， 不需要查询的字段​

    */
    event Voted(address indexed voter, uint256 candidateId);  // 投票成功
    event CandidateRegistered(uint256 indexed candidateId, bytes32 nameHash);  // 新增候选人
    event VotesReset(address indexed resetBy);  // 重置投票

    /*
        错误处理方式
            require：用于验证输入和条件   返还剩余gas
            revert：无条件终止执行并回滚           返还剩余gas
            assert：用于检查内部错误      消耗所有gas

    */
    error OnlyOwner();  // 非本人操作错误
    error CandidateNotRegistered();  // 候选人未注册错误
    error AlreadyVoted();  // 重复投票问题
    error InvalidCandidateName();   // 无效候选人



    modifier onlyOwner(){
        if(owner != msg.sender) revert OnlyOwner();  // 如果当前调用者不是拥有者，执行回滚
        _;  // 如果当前调用者是拥有者，什么都不做继续执行
    }

    constructor(){  // 构造
        owner = msg.sender;
    }

    function _register(string memory name) private{
        /*
        abi.encode(xx)    没压缩的
        abi.encodePacked  压缩之后的，把零压缩掉，不能直接decode
        */
        bytes32 nameKey = keccak256(abi.encodePacked(_toLower(name)));

        if(candidateIds[nameKey] != 0) return; // 已经注册
        uint256 newId = ++condidateCount;
        candidates[newId].nameHash = nameKey;
        candidateIds[nameKey] = newId;

        emit CandidateRegistered(newId, nameKey);  // 触发事件
    }

    function vote(string memory condidateName) external {
        if(bytes(condidateName).length == 0) revert InvalidCandidateName();  // 名字无效
        if(hasVoted[msg.sender]) revert AlreadyVoted();  // 已经投票
        bytes32 nameKey = keccak256(abi.encodePacked(_toLower(condidateName)));  // 名字生成hash
        if(candidateIds[nameKey] == 0){  // 新候选人 注册
            _register(condidateName);
        }
        uint256 candidateId = candidateIds[nameKey];
        candidates[candidateId].voteCounts++;
        hasVoted[msg.sender] = true;
        emit Voted(msg.sender, candidateId);
    }

    function getVotes(string memory candidateName) external view returns(uint256) {
        bytes32 nameKey = keccak256(abi.encodePacked(_toLower(candidateName)));
        uint256 candidateId = candidateIds[nameKey];
        if(candidateId == 0) revert CandidateNotRegistered();
        return candidates[candidateId].voteCounts;
    }

    function resetVotes() public {
        //
    }

    function _toLower(string memory str) private pure returns(string memory){
        bytes memory bStr = bytes(str);
        bytes memory lowerStr = new bytes(bStr.length);
        for(uint256 i = 0; i < bStr.length; i++){
            if(uint8(bStr[i]) >= 64 && uint8(bStr[i]) <= 90){
                lowerStr[i] = bytes1(uint8(bStr[i]) + 32); // 大写转小写 
            }else{
                lowerStr[i] = bStr[i];
            }
        }
        return string(lowerStr);
    }
    // 反转字符串 (Reverse String)
    function revStr(string memory str) external pure returns(string memory ){
        bytes memory inp = bytes(str);
        uint256 length = inp.length;
        if(length < 2) return string(inp);
        uint256 left = 0;
        uint256 right = length - 1;
        while(left < right){
            bytes1 tmp = inp[left];
            inp[left] = inp[right];
            inp[right] = tmp;
            left ++;
            right--;
        }
        return string(inp);
    }
    
    /*
        I             1
        V             5
        X             10
        L             50
        C             100
        D             500
        M             1000
        IV            4
        IX            9
    */
    uint256 private constant MAX_NUM = 3999;
    // 3888：MMMDCCCLXXXVIII
    uint256 private constant MAX_POSSIBLE_LENGTH  = 15;
    // 存在storage中 gas 销毁高，每次读取需要消耗gas，相比动态数组消耗小
    uint16[13] private values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    bytes2[13] private symbols = [
        bytes2('M'),  // 1000
        bytes2('CM'), // 900
        bytes2('D'),  // 500
        bytes2('CD'), // 400
        bytes2('C'),  // 100
        bytes2('XC'), // 90
        bytes2('L'),  // 50
        bytes2('XL'), // 40
        bytes2('X'),  // 10
        bytes2('IX'), // 9
        bytes2('V'),  // 5
        bytes2('IV'), // 4
        bytes2('I')   // 1
    ];

    // 整数转罗马数字 核心要点将数字映射成 符号，
    // 如 3 小于4 ， 没次取一个 I 再给3 减去 1，最终得到 III 表示三
    function int2Rom(uint256 num) external pure returns(string memory){
        require(num >= 1 && num <= MAX_NUM, "数值范围越界");
        // 预分配内存，避免多次分配
        bytes memory roman = new bytes(0);
        // string memory roman = "";
        uint256 bufferIndex = 0;
        uint256 rema = num;

        for(uint256 i = 0; i < values.length; i++){
            while (rema >= values[i]){
                // buffer
                roman = string.concat(roman, symbols[i])
                rema -= values[i]
            }

            if(rema == 0){
                break;
            }
        }
        return string(roman);
    }

    // 罗马数字转数整数

    // 合并两个有序数组 (Merge Sorted Array)
    function merge() external pure returns(uint8[20] memory){  // 返回 必须是 uint8[20]
        uint8 [10] memory arr1 = [1,2,3,4,5,6,7,8,9,10];  
        uint8 [10] memory arr2 = [1,2,3,4,5,6,7,8,9,10];
        uint8 [20] memory resArr;  // 静态数组没有push pop
        // uint8 [] memory resArr2 = new uint8[](20); 可以存储 20 个 uint8 类型元素的动态数组
        uint256 len1 = 0;
        uint256 len2 = 0;
        uint256 len = 0;
        while(len1 < arr1.length && len2 < arr2.length){  // arr.length --> uint256
            if(arr1[len1] < arr2[len2]){
                resArr[len++] = arr1[len1++];
            }else{
                resArr[len++] = arr2[len2++];
            }
        }

        while(len1 < arr1.length){  
            resArr[len++] = arr1[len1++];
        }

        while(len2 < arr2.length){  
            resArr[len++] = arr2[len2++];
        }
        return resArr;
    }

    
    // 二分查找 (Binary Search)
    function binarySearch(uint256 num) external pure returns(bool, uint256){
        uint8 [10] memory arr = [1,2,3,4,5,6,7,8,9,10];  // 如果数组放外面需要使用view
        uint256 l = 0;
        uint256 r = arr.length;
        
        while(l < r){
            uint256 mid = l + (r - l) / 2;
            if(arr[mid] == num){
                return (true, mid);
            }else if(arr[mid] < num){
                l = mid+1;
            }else{
                r = mid;
            }
        }
        return (false, 0); // 没找到

    }

}
