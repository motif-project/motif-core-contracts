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
    
    /**
     * @notice Emitted when a Bitcoin withdrawal transaction is signed by an operator
     * @param pod Address of the Bitcoin pod processing the withdrawal
     * @param operator Address of the operator signing the transaction
     * @param amount Amount of Bitcoin being withdrawn
     */
    event BitcoinWithdrawalTransactionSigned(address indexed pod, address indexed operator, uint256 amount);
  
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
    
    function withdrawBitcoinPSBT(address pod, uint256 amount, bytes calldata psbtTransaction, bytes calldata  signature) external;
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
    
    function withdrawBitcoinCompleteTx(address pod, uint256 amount, bytes calldata completeTx, bytes calldata  signature) external;
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
    /**
     * @notice Verify if a BTC address is correct for a given scriptPubKey
     * @param btcAddress The bech32 BTC address to verify
     * @param script The scriptPubKey to verify against
     * @param operatorBtcPubKey The operator's BTC public key
     */
    function verifyBTCAddress(string calldata btcAddress, bytes calldata script, bytes calldata operatorBtcPubKey) external returns (bool);
}