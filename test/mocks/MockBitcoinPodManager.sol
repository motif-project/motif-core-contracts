// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IBitcoinPodManager} from "../../src/interfaces/IBitcoinPodManager.sol";
import {IBitcoinPod} from "../../src/interfaces/IBitcoinPod.sol";
import {MockBitcoinPod} from "./MockBitcoinPod.sol";


contract MockBitcoinPodManager is IBitcoinPodManager {
    mapping(address => BitcoinDepositRequest) public podToBitcoinDepositRequest;
    mapping(address => string) public podToWithdrawalAddress;
    mapping(address => address) public podToApp;
    mapping(address => address) public userToPod;
    address public bitDSMServiceManager;
    uint256 public totalTVL;

    constructor(address _bitDSMServiceManager) {
        bitDSMServiceManager = _bitDSMServiceManager;
    }
    function updateServiceManager(address _bitDSMServiceManager) external {
        bitDSMServiceManager = _bitDSMServiceManager;
    }
    function getBitcoinDepositRequest(address pod) external view returns (BitcoinDepositRequest memory) {
        return podToBitcoinDepositRequest[pod];
    }

    function getBitcoinWithdrawalAddress(address pod) external view returns (string memory) {
        return podToWithdrawalAddress[pod];
    }

    function createPod(address operator, bytes memory /*_btcAddress*/) external returns (address) {
        require(userToPod[msg.sender] == address(0), "User already has a pod");
        
        address pod = address(new MockBitcoinPod(operator, address(this)));
        userToPod[msg.sender] = pod;
        return pod;
    }

    function delegatePod(address pod, address appContract) external {
        require(userToPod[msg.sender] == pod, "Not pod owner");
        require(podToApp[pod] == address(0), "Already delegated");
        podToApp[pod] = appContract;
    }

    function undelegatePod(address pod) external {
        require(userToPod[msg.sender] == pod, "Not pod owner");
        delete podToApp[pod];
    }

    function lockPod(address pod) external {
        require(msg.sender == podToApp[pod], "Only delegated app can lock");
        IBitcoinPod(pod).lock();
    }

    function unlockPod(address pod) external {
        require(msg.sender == podToApp[pod], "Only delegated app can unlock");
        IBitcoinPod(pod).unlock();
    }

    function verifyBitcoinDepositRequest(address pod, bytes32 transactionId, uint256 amount) external {
        require(userToPod[msg.sender] == pod, "Not pod owner");
        require(!podToBitcoinDepositRequest[pod].isPending, "Request already pending");

        podToBitcoinDepositRequest[pod] = BitcoinDepositRequest({
            transactionId: transactionId,
            amount: amount,
            isPending: true
        });
    }

    function confirmBitcoinDeposit(address pod, bytes32 transactionId, uint256 amount) external {
        require(msg.sender == bitDSMServiceManager, "Only service manager");
        require(podToBitcoinDepositRequest[pod].transactionId == transactionId, "Invalid tx id");

        IBitcoinPod(pod).mint(IBitcoinPod(pod).getOperator(), amount);
        totalTVL += amount;
        delete podToBitcoinDepositRequest[pod];
    }

    function withdrawBitcoinPSBTRequest(address pod, string memory withdrawAddress) external {
        require(userToPod[msg.sender] == pod, "Not pod owner");
        require(bytes(podToWithdrawalAddress[pod]).length == 0, "Withdrawal pending");
        require(!IBitcoinPod(pod).isLocked(), "Pod locked");
       

        podToWithdrawalAddress[pod] = withdrawAddress;
    }

    function withdrawBitcoinCompleteTxRequest(address pod, bytes memory /*_preSignedWithdrawTransaction*/, string memory withdrawAddress) external {
        require(userToPod[msg.sender] == pod, "Not pod owner");
        require(bytes(podToWithdrawalAddress[pod]).length == 0, "Withdrawal pending");
        require(!IBitcoinPod(pod).isLocked(), "Pod locked");
        require(podToApp[pod] == address(0), "Pod delegated");

        podToWithdrawalAddress[pod] = withdrawAddress;
    }

    function withdrawBitcoinAsTokens(address pod) external {
        require(msg.sender == bitDSMServiceManager, "Only service manager");
        require(bytes(podToWithdrawalAddress[pod]).length != 0, "No withdrawal request");

        uint256 balance = IBitcoinPod(pod).getBitcoinBalance();
        IBitcoinPod(pod).burn(IBitcoinPod(pod).getOperator(), balance);
        totalTVL -= balance;
        delete podToWithdrawalAddress[pod];
    }

    function setSignedBitcoinWithdrawTransactionPod(address pod, bytes memory signedBitcoinWithdrawTransaction) external {
        require(msg.sender == bitDSMServiceManager, "Only service manager");
        IBitcoinPod(pod).setSignedBitcoinWithdrawTransaction(signedBitcoinWithdrawTransaction);
    }

    function getUserPod(address user) external view returns (address) {
        return userToPod[user];
    }

    function getPodApp(address pod) external view returns (address) {
        return podToApp[pod];
    }

    function getTotalTVL() external view returns (uint256) {
        return totalTVL;
    }

    function getBitDSMServiceManager() external view returns (address) {
        return bitDSMServiceManager;
    }

    function getAppRegistry() external pure returns (address) {
        return address(0);
    }

    function getBitDSMRegistry() external pure returns (address) {
        return address(0);
    }
}