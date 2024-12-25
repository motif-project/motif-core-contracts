// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
/**
 * @title IBitcoinPod
 * @notice Interface for individual Bitcoin pods that handle Bitcoin deposits and withdrawals
 * @dev This interface defines the core functionality for Bitcoin pods including:
 * - Balance tracking
 * - Withdrawal transaction handling
 * - Pod locking/unlocking mechanisms
 * - Pod owner management
 */

interface IBitcoinPod {
    /**
     * @notice Enum to represent the state of the pod
     * @dev Inactive: The pod is not active and cannot be used for deposits or withdrawals
     * @dev Active: The pod is active and can be used for deposits and withdrawals
     */
    enum PodState {
        Inactive,
        Active
    }

    /**
     * @notice Event emitted when the pod is initialized
     * @dev This event is emitted when the pod is initialized
     * @param pod The address of the pod
     * @param owner The owner of the pod
     * @param operator The operator of the pod
     */
    event PodInitialized(address indexed pod, address indexed owner, address indexed operator);
    /**
     * @notice Event emitted when the pod is locked
     * @dev This event is emitted when the pod is locked
     * @param pod The address of the pod
     */
    event PodLocked(address indexed pod);

    /**
     * @notice Event emitted when the pod is unlocked
     * @dev This event is emitted when the pod is unlocked
     * @param pod The address of the pod
     */
    event PodUnlocked(address indexed pod);
    /**
     * @notice Event emitted when the pod value is minted
     * @dev This event is emitted when the pod value is minted
     * @param pod The address of the pod
     * @param amount The amount of pod value minted
     */
    event MintPodValue(address indexed pod, uint256 amount);

    /**
     * @notice Event emitted when the pod value is burned
     * @dev This event is emitted when the pod value is burned
     * @param pod The address of the pod
     * @param amount The amount of pod value burned
     */
    event BurnPodValue(address indexed pod, uint256 amount);
    /**
     * @notice Event emitted when the pod state is changed
     * @dev This event is emitted when the pod state is changed
     * @param previousState The previous state of the pod
     * @param newState The new state of the pod
     */
    event PodStateChanged(PodState previousState, PodState newState);

    /**
     * @notice Event emitted when the signed Bitcoin withdrawal transaction is set
     * @dev This event is emitted when the signed Bitcoin withdrawal transaction is set
     * @param signedTransaction The signed Bitcoin withdrawal transaction as a byte array
     */
    event WithdrawTransactionSet(bytes signedTransaction);

    /**
     * @notice Sets the state of the pod
     * @dev This function is used to set the state of the pod
     * @dev Only callable by pod manager
     * @dev State transition rules:
     *      - Active -> Inactive: Always allowed
     *      - Inactive -> Active: Only if pod meets activation requirements (e.g., BitcoinWithdrawal request is cancelled)
     * @param _newState The new state of the pod
     */
    function setPodState(PodState _newState) external;

    /**
     * @notice Returns the Bitcoin address of the pod
     * @dev This is the address where Bitcoin deposits are received on the Bitcoin Chain
     * @return string The Bitcoin address as a string
     */
    function getBitcoinAddress() external view returns (string memory);
    /**
     * @notice Returns the Bitcoin public key of the operator associated with this pod
     * @dev This operator key is used to generate the multisig Bitcoin address
     * @return bytes The Bitcoin public key as a byte array
     */
    function getOperatorBtcPubKey() external view returns (bytes memory);
    /**
     * @notice Returns the Ethereum address of the operator associated with this pod
     * @dev This is the address of the operator who can perform sensitive actions
     * @return address The operator's Ethereum address
     */
    function getOperator() external view returns (address);

    /**
     * @notice Returns the current Bitcoin balance tracked in the pod
     * @dev This balance is updated through minting and burning actions
     * @return uint256 The current Bitcoin balance
     */
    function getBitcoinBalance() external view returns (uint256);

    /**
     * @notice Returns the signed Bitcoin withdrawal transaction stored in the pod
     * @dev This transaction is used in the process of withdrawing Bitcoin from the pod
     * @dev The transaction can either be a partially signed PSBT created by the operator or a completely signed raw transaction depending on the withdrawal path taken by the client
     * @return bytes The signed Bitcoin transaction as a byte array
     */
    function getSignedBitcoinWithdrawTransaction() external view returns (bytes memory);

    /**
     * @notice Sets the signed Bitcoin withdrawal psbt or raw transaction in the pod
     * @dev This transaction is used by the client to create and broadcast the final signed transaction on the Bitcoin Network
     * @param _signedBitcoinWithdrawTransaction The signed Bitcoin transaction as a byte array
     */
    function setSignedBitcoinWithdrawTransaction(bytes memory _signedBitcoinWithdrawTransaction) external;

    /**
     * @notice Returns the current state of the pod
     * @dev This is used to check if the pod is active or inactive
     * @return PodState The current state of the pod
     */
    function getPodState() external view returns (PodState);

    /**
     * @notice Locks the pod to prevent further withdrawals
     * @dev This is a security measure to prevent unauthorized withdrawals
     * @dev The pod can only be locked by the BitcoinPodManager
     */
    function lock() external;

    /**
     * @notice Unlocks the pod to allow withdrawals
     * @dev This is used when the pod is ready to be used again
     * @dev The pod can only be unlocked by the BitcoinPodManager
     */
    function unlock() external;

    /**
     * @notice Checks if the pod is currently locked
     * @dev This is used to ensure the pod is not locked before performing actions
     * @return bool True if the pod is locked, false otherwise
     */
    function isLocked() external view returns (bool);

    /**
     * @notice Adds Bitcoin value to the pod
     * @dev This is used to set the Bitcoin balance in the pod
     * @dev Only callable by pod manager
     * @dev Must be called with reentrancy protection
     * @param amount The amount of Bitcoin tokens to mint (must be > 0)
     */
    function mint(uint256 amount) external;

    /**
     * @notice Removes Bitcoin token value from the pod
     * @dev This is used to clear the Bitcoin balance in the pod
     * @dev Only callable by pod manager
     * @dev Must be called with reentrancy protection
     * @param amount The amount of Bitcoin tokens to burn (must be > 0 and <= current balance)
     */
    function burn(uint256 amount) external;
}
