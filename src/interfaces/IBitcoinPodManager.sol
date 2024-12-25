// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
/**
 * @title IBitcoinPodManager
 * @notice Interface for managing Bitcoin pods, which handle Bitcoin deposits and withdrawals
 * @dev This interface defines the core functionality for Bitcoin pod management including:
 * - Pod creation and delegation
 * - Bitcoin deposit verification and confirmation
 * - Bitcoin withdrawal requests and processing
 * - Pod locking/unlocking mechanisms
 */

interface IBitcoinPodManager {
    /// @notice Thrown when BTC address length is invalid
    error InvalidBTCAddressLength(uint256 length);
    /// @notice Thrown when BTC transaction length is invalid
    error InvalidBTCAddressInitialByte();
    /// @notice Thrown when BTC transaction is invalid
    error InvalidOperatorBTCKey(bytes, bytes);
    /// @notice Thrown when BTC transaction is invalid
    error InvalidKeyLength(uint256 length, uint256 expectedLength);
    /// @notice Thrown when script length is invalid
    error InvalidScriptLength(uint256 length);
    /// @notice Thrown when no withdrawal request to cancel
    error NoWithdrawalRequestToCancel(address pod);
    /// @notice Thrown when withdrawal transaction already submitted
    error WithdrawalTransactionAlreadySubmitted(address pod);
    /// @notice Thrown when withdrawal transaction is not submitted
    error WithdrawalTransactionNotSubmitted(address pod);

    /**
     * @notice Struct to store Bitcoin deposit request details
     * @param transactionId The Bitcoin transaction ID of the deposit
     * @param amount The amount of Bitcoin being deposited in satoshis
     * @param isPending deposit request status
     */
    struct BitcoinDepositRequest {
        bytes32 transactionId;
        uint256 amount;
        bool isPending;
    }

    /**
     * @notice Gets the pod address associated with a user
     * @param user The address of the user to lookup
     * @return address The address of the user's pod, or zero address if none exists
     */
    function getUserPod(address user) external view returns (address);

    /**
     * @notice Gets the app contract address that a pod is delegated to
     * @param pod The address of the pod to lookup
     * @return address The address of the app contract the pod is delegated to, or zero address if not delegated
     */
    function getPodApp(address pod) external view returns (address);

    /**
     * @notice Gets the deposit request details for a pod (alias of getPodDepositRequest)
     * @param pod The address of the pod to lookup
     * @return BitcoinDepositRequest struct containing the deposit transaction ID, amount and pending status
     */
    function getBitcoinDepositRequest(address pod) external view returns (BitcoinDepositRequest memory);
    /**
     * @notice Checks if a pod has a pending Bitcoin deposit request
     * @param pod The address of the pod to check
     * @return bool True if there is a pending deposit request, false otherwise
     */
    function hasPendingBitcoinDepositRequest(address pod) external view returns (bool);
    /**
     * @notice Gets the withdrawal address set for a pod (alias of getPodWithdrawalAddress)
     * @param pod The address of the pod to lookup
     * @return The Bitcoin withdrawal address as bytes
     */
    function getBitcoinWithdrawalAddress(address pod) external view returns (string memory);

    /**
     * @notice Gets the total value locked across all pods
     * @return uint256 The total value locked in satoshis
     */
    function getTotalTVL() external view returns (uint256);

    /**
     * @notice Gets the address of the BitDSM Service Manager contract
     * @return address The address of the BitDSM Service Manager contract
     */
    function getBitDSMServiceManager() external view returns (address);

    /**
     * @notice Gets the address of the App Registry contract
     * @return The address of the App Registry
     */
    function getAppRegistry() external view returns (address);

    /**
     * @notice Gets the address of the BitDSM Registry contract
     * @return The address of the BitDSM Registry
     */
    function getBitDSMRegistry() external view returns (address);

    /**
     * @notice Gets the total number of pods created
     * @return uint256 The total number of pods created
     */
    function getTotalPods() external view returns (uint256);
    /**
     * @notice Event emitted when a new pod is created
     * @param user The address of the user creating the pod
     * @param pod The address of the created pod
     * @param operator The address of the operator for the pod
     */

    event PodCreated(address indexed user, address indexed pod, address indexed operator);
    /**
     * @notice Event emitted when a pod is delegated to an app
     * @param pod The address of the pod being delegated
     * @param appContract The address of the app being delegated to
     */
    event PodDelegated(address indexed pod, address indexed appContract);
    /**
     * @notice Event emitted when a pod is undelegated
     * @param pod The address of the pod being undelegated
     */
    event PodUndelegated(address indexed pod);
    /**
     * @notice Event emitted when Bitcoin token value is set to a pod
     * @param pod The address of the pod receiving the token value
     * @param amount The amount of Bitcoin tokens set
     */
    event BitcoinMinted(address indexed pod, uint256 amount);
    /**
     * @notice Event emitted when Bitcoin tokens are cleared from a pod
     * @param pod The address of the pod burning the tokens
     * @param amount The amount of Bitcoin tokens burned
     */
    event BitcoinBurned(address indexed pod, uint256 amount);

    /**
     * @notice Event emitted when the total TVL is updated
     * @param newTVL The new total TVL
     */
    event TotalTVLUpdated(uint256 newTVL);
    /**
     * @notice Event emitted when a Bitcoin deposit request is initiated
     * @param pod The address of the pod where the deposit is requested
     * @param operator The address of the operator verifying the deposit request
     * @param bitcoinDepositRequest The details of the deposit request
     */
    event VerifyBitcoinDepositRequest(
        address indexed pod, address indexed operator, BitcoinDepositRequest bitcoinDepositRequest
    );
    /**
     * @notice Event emitted when a deposit is confirmed on Bitcoin Network
     * @param pod The address of the pod receiving the deposit
     * @param amount The amount of Bitcoin deposited
     */
    event BitcoinDepositConfirmed(address indexed pod, uint256 amount);
    /**
     * @notice Event emitted when Bitcoin is withdrawn from a pod
     * @param pod The address of the pod
     * @param withdrawAddress The address to which the Bitcoin is withdrawn
     */
    event BitcoinWithdrawnFromPod(address indexed pod, string withdrawAddress);
    /**
     * @notice Event emitted when a Bitcoin withdrawal PSBT request is initiated
     * @param pod The address of the pod from where the Bitcoin is requested to be withdrawn
     * @param operator The address of the operator that will create and sign the PSBT
     * @param withdrawAddress The address to which the Bitcoin is withdrawn
     */
    event BitcoinWithdrawalPSBTRequest(address indexed pod, address indexed operator, string withdrawAddress);
    /**
     * @notice Event emitted when a Bitcoin withdrawal complete transaction request is initiated
     * @param pod The address of the pod from where the Bitcoin is requested to be withdrawn
     * @param operator The address of the operator whose sign is required
     * @param preSignedBitcoinTx The pre-signed Bitcoin transaction sent from the client
     */
    event BitcoinWithdrawalCompleteTxRequest(address indexed pod, address indexed operator, bytes preSignedBitcoinTx);
    /**
     * @notice Emitted when a BTC address is verified for a given scriptPubKey
     * @param operator Address of the operator verifying the address
     * @param btcAddress The verified BTC address
     */
    event BTCAddressVerified(address indexed operator, string btcAddress);

    /**
     * @notice Emitted when a withdrawal request is cancelled
     * @param pod The address of the pod where the withdrawal request is cancelled
     */
    event WithdrawalRequestCancelled(address indexed pod);
    /**
     * @notice Creates a new pod
     * @param operator The address of the operator creating the pod
     * @param btcAddress The Bitcoin address for the pod
     * @return address The address of the created pod
     * @dev Checks that:
     * - User doesn't already have a pod
     * - Operator is registered in BitDSM Registry
     */

    function createPod(address operator, string memory btcAddress, bytes calldata script) external returns (address);

    /**
     * @notice Delegates a pod to an app
     * @param pod The address of the pod to be delegated
     * @param appContract The address of the app to delegate the pod to
     * @dev Only the pod owner can delegate the pod
     * @dev The app must be registered in the App Registry
     */
    function delegatePod(address pod, address appContract) external;
    /**
     * @notice Undelegates a pod
     * @param pod The address of the pod to be undelegated
     * @dev Only the pod owner can undelegate the pod
     */
    function undelegatePod(address pod) external;
    /**
     * @notice Locks a pod
     * @param pod The address of the pod to be locked
     * @dev Only the delegated app can lock the pod
     */
    function lockPod(address pod) external;
    /**
     * @notice Unlocks a pod
     * @param pod The address of the pod to be unlocked
     * @dev Only the delegated app can unlock the pod
     */
    function unlockPod(address pod) external;

    /**
     * @notice Client request to verify the deposit
     * @param pod The address of the pod
     * @param transactionId The Bitcoin transaction ID
     * @param amount The amount deposited
     * @dev can only be requested by pod owner
     */
    function verifyBitcoinDepositRequest(address pod, bytes32 transactionId, uint256 amount) external;
    /**
     * @notice Confirms the deposit on Bitcoin Network
     * @param pod The address of the pod
     * @param transactionId The Bitcoin transaction ID
     * @param amount The amount deposited
     * @dev can only be requested by the BitDSM Service Manager
     * @dev Updates the pod balance
     */
    function confirmBitcoinDeposit(address pod, bytes32 transactionId, uint256 amount) external;
    /**
     * @notice Initiates a Bitcoin withdrawal request using PSBT (Partially Signed Bitcoin Transaction) from pod owner
     * @param pod The address of the pod where the withdrawal is requested
     * @param withdrawAddress The Bitcoin address where funds should be withdrawn to
     */
    function withdrawBitcoinPSBTRequest(address pod, string memory withdrawAddress) external;
    /**
     * @notice Initiates a Bitcoin withdrawal request from the pod owner
     * @param pod The address of the pod where the withdrawal is requested
     * @param preSignedWithdrawTransaction The pre-signed Bitcoin transaction sent from the pod owner
     * @param withdrawAddress The Bitcoin address where funds should be withdrawn to
     */
    function withdrawBitcoinCompleteTxRequest(
        address pod,
        bytes memory preSignedWithdrawTransaction,
        string memory withdrawAddress
    ) external;
    /**
     * @notice Withdraws Bitcoin as tokens from the pod
     * @param pod The address of the pod where the withdrawal is requested
     */
    function withdrawBitcoinAsTokens(address pod) external;
    /**
     * @notice Sets the signed Bitcoin withdrawal transaction in the pod
     * @param pod The address of the pod
     * @param signedBitcoinWithdrawTransaction The signed Bitcoin PSBT or raw transaction
     */
    function setSignedBitcoinWithdrawTransactionPod(address pod, bytes memory signedBitcoinWithdrawTransaction)
        external;
}
