// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";

import { WrappedMyToken } from "./WrappedMyToken.sol" ;


contract NFTPoolBurnAndMint is CCIPReceiver, OwnerIsCreator {
    using SafeERC20 for IERC20;

    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance.
    error NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
    error FailedToWithdrawEth(address owner, address target, uint256 value); // Used when the withdrawal of Ether fails.
    
    error InvalidReceiverAddress(); // Used when the receiver address is 0.

    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        bytes text, // The text being sent.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the CCIP message.
    );

    event TokenMinited(uint256 tokenId, address newOwner);

    bytes32 private s_lastReceivedMessageId; // Store the last received messageId.
    string private s_lastReceivedText; // Store the last received text.
    IERC20 private s_linkToken;
    WrappedMyToken public  wnft;

    struct RequestData{
        uint256 tokenId;
        address newOwner;
    }

    constructor(address _router, address _link, address wnftAddress) CCIPReceiver(_router) {
        s_linkToken = IERC20(_link);
        wnft = WrappedMyToken(wnftAddress);
    }

    modifier validateReceiver(address _receiver) {
        if (_receiver == address(0)) revert InvalidReceiverAddress();
        _;
    }

    function burnAndSendNFT(
        uint256 tokenId, 
        address newOwner, 
        uint64 chainSelector,
        address receiver) public returns(bytes32) {
            /*
                1. 把 nft 传给 owner 地址，然后把他烧掉
                2. 把消息发回原链， 得到messageid
             */
            wnft.transferFrom(msg.sender, address(this), tokenId);
            wnft.burn(tokenId);
            bytes memory payload = abi.encode(tokenId, newOwner);
            bytes32 messageId = sendMessagePayLINK(chainSelector, receiver, payload);
            return messageId;
    }

    function sendMessagePayLINK(
        uint64 _destinationChainSelector,
        address _receiver,
        bytes memory _text
    )
        internal
        returns (bytes32 messageId)
    {
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _receiver,
            _text,
            address(s_linkToken)
        );

        IRouterClient router = IRouterClient(this.getRouter());
        uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

        if (fees > s_linkToken.balanceOf(address(this)))
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);

        s_linkToken.approve(address(router), fees);

        messageId = router.ccipSend(_destinationChainSelector, evm2AnyMessage);

        // Emit an event with message details
        emit MessageSent(
            messageId,
            _destinationChainSelector,
            _receiver,
            _text,
            address(s_linkToken),
            fees
        );

        // Return the CCIP message ID
        return messageId;
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
    {
        // 接收 hardhat_kl/contracts/NFTPoolLockAndRelease.sol 发过来的消息
        // abi.decode(any2EvmMessage.data, (string));
        // tokenId newOwner,由于多个参数，需要封装一个结构体
        RequestData memory rd = abi.decode(any2EvmMessage.data, (RequestData));
        uint256 tokenId = rd.tokenId;
        address newOwner = rd.newOwner;
        wnft.mintWithSpecificTokenId(newOwner, tokenId); // 给newOwner 铸造一个nft
        emit TokenMinited(tokenId, newOwner);
    }

    function _buildCCIPMessage(
        address _receiver,
        bytes memory _text,
        address _feeTokenAddress
    ) private pure returns (Client.EVM2AnyMessage memory) {
            return Client.EVM2AnyMessage({
                receiver: abi.encode(_receiver), 
                data: abi.encode(_text),
                tokenAmounts: new Client.EVMTokenAmount[](0), 
                extraArgs: Client._argsToBytes(
                    Client.GenericExtraArgsV2({
                        gasLimit: 200_000, 
                        allowOutOfOrderExecution: true 
                    })
                ),
                feeToken: _feeTokenAddress
            });
    }

    function getLastReceivedMessageDetails()
        external
        view
        returns (bytes32 messageId, string memory text)
    {
        return (s_lastReceivedMessageId, s_lastReceivedText);
    }

    receive() external payable {}

    function withdraw(address _beneficiary) public onlyOwner {
        uint256 amount = address(this).balance;
        if (amount == 0) revert NothingToWithdraw();
        (bool sent, ) = _beneficiary.call{value: amount}("");
        if (!sent) revert FailedToWithdrawEth(msg.sender, _beneficiary, amount);
    }

    function withdrawToken(
        address _beneficiary,
        address _token
    ) public onlyOwner {
        // Retrieve the balance of this contract
        uint256 amount = IERC20(_token).balanceOf(address(this));

        // Revert if there is nothing to withdraw
        if (amount == 0) revert NothingToWithdraw();

        IERC20(_token).safeTransfer(_beneficiary, amount);
    }
}
