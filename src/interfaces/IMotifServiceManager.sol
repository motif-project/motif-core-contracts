// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@eigenlayer-middleware/src/interfaces/IServiceManager.sol";

/**
 * @title BitDSM Service Manager Interface
 * @notice Interface for managing Bitcoin DSM (Decentralized Service Manager) operations
 * @dev THIS CONTRACT IS NOT AUDITED.
 * @dev Extends IServiceManager from EigenLayer middleware
 *
 * This interface defines the core functionality for:
 * - Managing Bitcoin deposits and withdrawals through pods
 * - Handling operator signatures and transaction verification
 * - Integrating with EigenLayer's staking and delegation system
 *
 * Key operations:
 * - Deposit confirmation by operators
 * - Two-phase Bitcoin withdrawals (PSBT + complete transaction)
 * - Signature verification for security
 *
 * The contract works in conjunction with:
 * - BitcoinPodManager: For pod state management
 * - BitcoinPod: Individual Bitcoin custody pods
 * - EigenLayer: For staking and operator management
 */
interface IBitDSMServiceManager is IServiceManager {
    // Custom errors

    /// @dev Thrown when caller is not the authorized operator for a pod
    error UnauthorizedPodOperator(address caller, address pod);

    /// @dev Thrown when a signature verification fails
    error InvalidOperatorSignature(address operator);
    /// @dev Thrown when a key length is invalid
    error InvalidKeyLength(uint256 length);
    /// @dev Thrown when a operator BTC key is invalid
    error InvalidOperatorBTCKey(bytes operatorKey, bytes operatorBtcPubKey);

    /// @dev Thrown when there is no withdrawal request to confirm
    error NoWithdrawalRequestToConfirm(address pod);
    /// @dev Thrown when there is no withdrawal request to process
    error NoWithdrawalRequestToProcess(address pod);
    /// @dev Thrown when a withdrawal request already exists
    error WithdrawalRequestAlreadyExists(address pod);
    /// @dev Thrown when there is no deposit request to confirm
    error NoDepositRequestToConfirm(address pod);
    /// @dev Thrown when PSBT outputs are invalid
    error InvalidPSBTOutputs();
    /// @dev Thrown when the BitcoinPodManager address is zero
    error ZeroBitcoinPodManagerAddress();
    /// @dev Thrown when the signature length is invalid
    error InvalidSignatureLength(uint256 length);
    /// @dev Thrown when the withdraw address is empty
    error EmptyWithdrawAddress();
    /// @dev Thrown when the withdraw amount is zero
    error ZeroWithdrawAmount();
    /// @dev Thrown when there are too many PSBT outputs
    error TooManyPSBTOutputs(uint256 length);
    /// @dev Thrown when there are no PSBT outputs
    error NoPSBTOutputs();
    /// @dev Thrown when the PSBT transaction is empty
    error EmptyPSBTTransaction();
    /// @dev Thrown when the PSBT transaction is too long or too short
    error InvalidPSBTTransaction(uint256 length);
    /// @dev Thrown when the BTC transaction is invalid
    error InvalidTransaction(uint256 length);

    /**
     * @notice Emitted when a Bitcoin withdrawal transaction is signed by an operator
     * @param pod Address of the Bitcoin pod processing the withdrawal
     * @param operator Address of the operator signing the transaction
     * @param amount Amount of Bitcoin being withdrawn
     */
    event BitcoinWithdrawalTransactionSigned(address indexed pod, address indexed operator, uint256 amount);
    /**
     * @notice Set the BitcoinPodManager contract address
     * @param bitcoinPodManager The address of the BitcoinPodManager contract
     */

    function setBitcoinPodManager(address bitcoinPodManager) external;
    /**
     * @notice Get the BitcoinPodManager contract address
     * @return The address of the BitcoinPodManager contract
     */
    function getBitcoinPodManager() external view returns (address);
    /**
     * @notice Confirms a Bitcoin chain deposit by verifying operator signature and updating pod state
     * @param pod Address of the Bitcoin pod receiving the deposit
     * @param signature Operator's signature over the deposit confirmation message
     * @dev Only callable by the operator assigned to the pod
     * @dev Verifies operator signature over deposit details
     * @dev Updates pod state via BitcoinPodManager when deposit is confirmed
     * @dev Emits BitcoinDepositConfirmed event via BitcoinPodManager
     */
    function confirmDeposit(address pod, bytes calldata signature) external;

    /**
     * @notice Aids in processing a Bitcoin withdrawal by storing signed PSBT transaction created by the operator
     * @param pod Address of the Bitcoin pod processing the withdrawal
     * @param amount Amount of Bitcoin being withdrawn
     * @param psbtTransaction Partially Signed Bitcoin Transaction (PSBT) data created by the operator
     * @param signature Operator's signature over the withdrawal data
     * @dev Only callable by the operator assigned to the pod
     * @dev Verifies pod has pending withdrawal request
     * @dev Validates operator signature over withdrawal details
     * @dev Stores PSBT in pod state and emits BitcoinWithdrawalTransactionSigned event
     */
    function withdrawBitcoinPSBT(address pod, uint256 amount, bytes calldata psbtTransaction, bytes calldata signature)
        external;
    /**
     * @notice Aids in completing a Bitcoin withdrawal by processing the final transaction signed by the operator
     * @param pod Address of the Bitcoin pod processing the withdrawal
     * @param amount Amount of Bitcoin being withdrawn
     * @param completeTx Complete Bitcoin transaction data signed by the operator
     * @param signature Operator's signature over the complete transaction
     * @dev Only callable by the operator assigned to the pod
     * @dev Verifies operator controls pod before processing
     * @dev Retrieves withdrawal address from pod state for verification
     */
    function withdrawBitcoinCompleteTx(address pod, uint256 amount, bytes calldata completeTx, bytes calldata signature)
        external;
    /**
     * @notice Confirms a Bitcoin chain withdrawal on by verifying operator signature and updating pod state
     * @param pod Address of the Bitcoin pod processing the withdrawal
     * @param transaction Complete Bitcoin transaction data
     * @param signature Operator's signature over the transaction data
     * @dev Only callable by the operator assigned to the pod
     * @dev Verifies operator signature matches transaction details
     * @dev Updates pod state via BitcoinPodManager when withdrawal is confirmed
     * @dev Emits BitcoinWithdrawalConfirmed event via BitcoinPodManager
     */
    function confirmWithdrawal(address pod, bytes calldata transaction, bytes calldata signature) external;
}
