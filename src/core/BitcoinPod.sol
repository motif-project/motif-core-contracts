// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/IBitcoinPod.sol";

/**
 * @title BitcoinPod
 * @notice A contract that represents a Bitcoin custody pod managed by an Client and an Operator
 * @dev This contract handles Bitcoin deposits and withdrawals through a designated operator,
 * tracks balances, and manages pod locking/unlocking functionality
 *
 * Key features:
 * - Links a Bitcoin address to an Ethereum address
 * - Tracks Bitcoin balances in the pod
 * - Allows only authorized operator actions
 * - Supports locking mechanism for security
 * - Manages withdrawal transaction storage
 *
 * Security considerations:
 * - Only the designated operator can perform sensitive actions
 * - Pod can be locked to prevent unauthorized withdrawals
 * - Manager contract has privileged access for administrative functions
 */

contract BitcoinPod is IBitcoinPod, OwnableUpgradeable {
    address public operator;
    bytes public operatorBtcPubKey;
    string public bitcoinAddress;
    uint256 public bitcoinBalance;
    bool public locked;
    address public immutable manager;
    bytes public signedBitcoinWithdrawTransaction;

    /**
     * @notice Modifier to ensure only the designated operator can perform an action
     * @param _operator Address of the operator to check against
     */
    modifier onlyOperator(address _operator) {
        require(_operator == operator, "Only designated operator can perform this action");
        _;
    }
    /**
     * @notice Modifier to ensure the pod is not locked before execution
     */
    modifier lockedPod() {
        require(!locked, "Pod is locked");
        _;
    }
    /**
     * @notice Modifier to ensure only the manager contract can perform an action
     */
    modifier onlyManager() {
        require(msg.sender == manager, "Only manager can perform this action");
        _;
    }
    /**
     * @notice Initializes the immutable manager address
     * @param _manager Address of the BitcoinPodManager contract that manages this pod
     */
    constructor(address _manager) {
        manager = _manager;
        //_disableInitializers();
    }
    /**
     * @notice Initializes a new Bitcoin pod with the specified parameters
     * @param _owner Address that will own this pod contract
     * @param _operator Address of the designated operator who can perform sensitive actions
     * @param _operatorBtcPubKey Bitcoin public key of the operator for multisig address generation
     * @param _btcAddress Multisig Bitcoin address associated with this pod
     * @dev Sets initial state:
     * - Transfers ownership to _owner
     * - Sets operator and their BTC public key
     * - Sets the pod's Bitcoin address
     * - Initializes pod as unlocked
     */
    function initialize(address _owner, address _operator, bytes memory _operatorBtcPubKey, string memory _btcAddress) external initializer {
        __Ownable_init();
        _transferOwnership(_owner);
        operator = _operator;
        operatorBtcPubKey = _operatorBtcPubKey;
        bitcoinAddress = _btcAddress;
        locked = false;
    }
    // @inheritdoc IBitcoinPod
    function getBitcoinAddress() external view returns (string memory) {
        return bitcoinAddress;
    }
    // @inheritdoc IBitcoinPod
    function getOperatorBtcPubKey() external view returns (bytes memory) {
        return operatorBtcPubKey;
    }
    // @inheritdoc IBitcoinPod
    function getOperator() external view returns (address) {
        return operator;
    }
    // @inheritdoc IBitcoinPod
    function getBitcoinBalance() external view returns (uint256) {
        return bitcoinBalance;
    }
    // @inheritdoc IBitcoinPod
    function getSignedBitcoinWithdrawTransaction() external view returns (bytes memory) {
        return signedBitcoinWithdrawTransaction;
    }
    // @inheritdoc IBitcoinPod
    function setSignedBitcoinWithdrawTransaction(bytes memory _signedBitcoinWithdrawTransaction) external onlyManager(){
        signedBitcoinWithdrawTransaction = _signedBitcoinWithdrawTransaction;
    }
    // @inheritdoc IBitcoinPod
    function lock() external onlyManager lockedPod {
        locked = true;
    }
    // @inheritdoc IBitcoinPod
    function unlock() external onlyManager {
        locked = false;
    }
    // @inheritdoc IBitcoinPod
    function isLocked() external view returns (bool) {
        return locked;
    }
    // @inheritdoc IBitcoinPod
    function mint(address _operator, uint256 amount) external onlyManager onlyOperator(_operator) lockedPod {

        bitcoinBalance += amount;
    }
   // @inheritdoc IBitcoinPod
    function burn(address _operator, uint256 amount) external onlyManager onlyOperator(_operator) lockedPod {
        require(bitcoinBalance >= amount, "Insufficient balance");
        bitcoinBalance -= amount;
    }

}
