// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IBitcoinPod} from "../../src/interfaces/IBitcoinPod.sol";

contract MockBitcoinPod is IBitcoinPod {
    bool public locked;
    bytes public signedWithdrawTx;
    address public operator;
    bytes public operatorBtcPubKey;
    string public bitcoinAddress;
    uint256 public bitcoinBalance;
    address public immutable podManager;
    bytes public signedBitcoinWithdrawTransaction;
    PodState public podState;

    constructor(address _owner, address _manager) {
        operator = _owner;
        podManager = _manager;
        locked = false;
        podState = PodState.Active;
    }

    function setPodState(PodState _newState) external {
        require(msg.sender == podManager, "Only manager can set state");
        PodState previousState = podState;
        podState = _newState;
        emit PodStateChanged(previousState, _newState);
    }

    function getBitcoinAddress() external view returns (string memory) {
        return bitcoinAddress;
    }

    function getOperatorBtcPubKey() external view returns (bytes memory) {
        return operatorBtcPubKey;
    }

    function getOperator() external view returns (address) {
        return operator;
    }

    function getBitcoinBalance() external view returns (uint256) {
        return bitcoinBalance;
    }

    function lock() external {
        require(msg.sender == podManager, "Only manager can lock");
        locked = true;
    }

    function unlock() external {
        require(msg.sender == podManager, "Only manager can unlock");
        locked = false;
    }

    function isLocked() external view returns (bool) {
        return locked;
    }

    function mint(uint256 amount) external {
        require(msg.sender == podManager, "Only manager can mint");
        require(!locked, "Pod is locked");
        bitcoinBalance += amount;
    }

    function burn(uint256 amount) external {
        require(msg.sender == podManager, "Only manager can burn");
        require(!locked, "Pod is locked");
        require(bitcoinBalance >= amount, "Insufficient balance");
        bitcoinBalance -= amount;
    }

    function setSignedBitcoinWithdrawTransaction(bytes memory _signedBitcoinWithdrawTransaction) external {
        require(msg.sender == podManager, "Only manager can set signed tx");
        signedBitcoinWithdrawTransaction = _signedBitcoinWithdrawTransaction;
    }

    function getSignedBitcoinWithdrawTransaction() external view returns (bytes memory) {
        return signedBitcoinWithdrawTransaction;
    }

    function getPodState() external view returns (PodState) {
        return podState;
    }
}
