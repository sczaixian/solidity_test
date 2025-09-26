



1. 打算以  MyToken  合约作为基础合约
2. 使用 MemeToken.sol 作为升级合约

MemeToken ：
   初始铸造量 1000亿， 锁定总资产为 100亿usd，初始兑换比例是10:1， 随时间发展 MemeToken 总量越少每个 MemeToken 折算的 usd 越多
   合约用户可以参与社区活动获取代币奖励，还可以使用其它任意的币兑换社区币

主要功能：   
    交易扣除的税收纳入社区共同基金
    提款扣除的 MemeToken 会燃烧掉
    每日交易次数和交易额度有一定的限制
    会有意外情况的紧急冻结取款开关
    存款后会有约7天的冻结期
    取款时优先扣除 用户账户中的 未冻结 usd， 
                如果用户账户中的 usd 清零则会扣除 Pool 中的 usd，
                如果用户账户中存在 usd，那么不能从 池子中支取

对向 pool 中注入流动性的用户开放更高级的权限，并且参与平台利益分配，可以设计一套vip策略
                        
vip策略：
    存入一定的金额可以给予 一定的vip经验
    使用 MemeToken 可以购买 vip 经验（但是有限制）



主要功能函数：
    initialize：    初始化 MemeToken、交易和取款税率、每日限额和最大交易笔次
    withdraw：      取款
    memeToUsd：     计算平台币可以兑换多少usd
    stakeToken：    质押token兑换 MemeToken
    _mergeDeposit： 合并用户的存款数组
    _transfer：     交易扣税
    convertTokenToUsd： 通过喂价合约获取等量价值的 USD 数量
    modifier txLimit：  检查交易限制