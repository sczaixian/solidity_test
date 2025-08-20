// import ethers.js
// create main function,创建一个 函数，通过ethers包获取这个合约
// execute mian function 执行这个函数

import {network} from "hardhat";
const {ethers} = await network.connect({
    network: "sepolia"
});

console.log("sending transaction using sepolia ");

const [owner, user1, user2, user3] = await ethers.getSigners(); 

console.log("users: ->  owner:",owner, ", user1:", user1, ", user2:", user2, ", user3:", user3);

// const tx = await owner