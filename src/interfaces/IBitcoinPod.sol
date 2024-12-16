// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
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
     * @notice Returns the Bitcoin address of the pod
     * @dev This is the address where Bitcoin deposits are received on the Bitcoin Chain
     * @return bytes The Bitcoin address as a byte array
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
     * @param operator Address of the operator performing the minting
     * @param amount The amount of Bitcoin tokens to mint
     */
    function mint(address operator, uint256 amount) external;
      /**
     * @notice Removes Bitcoin token value from the pod
     * @dev This is used to clear the Bitcoin balance in the pod
     * @param operator Address of the operator performing the burning
     * @param amount The amount of Bitcoin tokens to burn
     */
    function burn(address operator, uint256 amount) external;
}
