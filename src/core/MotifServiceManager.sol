// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@eigenlayer-middleware/src/unaudited/ECDSAServiceManagerBase.sol";
import "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import "../interfaces/IBitDSMServiceManager.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../interfaces/IBitcoinPodManager.sol";
import "../interfaces/IBitDSMRegistry.sol";
import "../interfaces/IBitcoinPod.sol";
import "../libraries/BitcoinUtils.sol";

/**
 * @title BitDSM Service Manager
 * @dev This contract manages Bitcoin DSM (Decentralized Service Manager) operations
 * @notice Extends ECDSAServiceManagerBase to handle Bitcoin pod operations and deposits
 *
 * Key components:
 * - Manages Bitcoin pod operations through IBitcoinPodManager
 * - Handles deposit confirmations from operators
 * - Integrates with EigenLayer for staking and delegation
 *
 * Dependencies:
 * - ECDSAServiceManagerBase: Base contract for ECDSA service management
 * - IBitcoinPodManager: Interface for Bitcoin pod management
 * - IBitDSMRegistry: Registry interface for BitDSM services and handling EigenLayer staking and delegation
 */
contract BitDSMServiceManager is ECDSAServiceManagerBase, IBitDSMServiceManager {
    // Attach library to bytes type for direct usage with bytes variables
    using BitcoinUtils for bytes;
    // State variables

    IBitcoinPodManager private _bitcoinPodManager;
    mapping(bytes32 => bool) private _usedSignatures;
    uint256 private constant MAX_PSBT_OUTPUTS = 10;
    /**
     * @notice Modifier to ensure only the pod operator can call the function
     * @param pod The address of the Bitcoin pod
     */

    modifier onlyPodOperator(address pod) {
        if (IBitcoinPod(pod).getOperator() != msg.sender) {
            revert UnauthorizedPodOperator(msg.sender, pod);
        }
        _;
    }
    /**
     * @notice Constructor for BitDSMServiceManager contract
     * @dev Initializes the contract with required dependencies from EigenLayer and BitDSM
     * @param _avsDirectory Address of the EigenLayer AVS Directory contract
     * @param _bitDSMRegistry Address of the BitDSM Registry contract for operator management
     * @param _rewardsCoordinator Address of the rewards coordinator contract
     * @param _delegationManager Address of EigenLayer's delegation manager contract
     *
     */

    constructor(address _avsDirectory, address _bitDSMRegistry, address _rewardsCoordinator, address _delegationManager)
        ECDSAServiceManagerBase(_avsDirectory, _bitDSMRegistry, _rewardsCoordinator, _delegationManager)
    {}

    /**
     * @notice Initializes the BitDSMServiceManager contract
     * @param _owner Address of the owner of the contract
     * @param _rewardsInitiator Address of the rewards initiator
     * @param bitcoinPodManager Address of the BitcoinPodManager contract
     */
    function initialize(address _owner, address _rewardsInitiator, address bitcoinPodManager) public initializer {
        __ServiceManagerBase_init(_owner, _rewardsInitiator);
        _bitcoinPodManager = IBitcoinPodManager(bitcoinPodManager);
    }
    /**
     * @inheritdoc IBitDSMServiceManager
     */

    function setBitcoinPodManager(address bitcoinPodManager) external onlyOwner {
        if (bitcoinPodManager == address(0)) {
            revert ZeroBitcoinPodManagerAddress();
        }
        _bitcoinPodManager = IBitcoinPodManager(bitcoinPodManager);
    }
    /**
     * @inheritdoc IBitDSMServiceManager
     */

    function getBitcoinPodManager() external view returns (address) {
        return address(_bitcoinPodManager);
    }

    /**
     * @inheritdoc IBitDSMServiceManager
     */
    function confirmDeposit(address pod, bytes calldata signature) external onlyPodOperator(pod) {
        if (!_bitcoinPodManager.hasPendingBitcoinDepositRequest(pod)) {
            revert NoDepositRequestToConfirm(pod);
        }
        // check signature size
        if (signature.length != 65) {
            revert InvalidSignatureLength(signature.length);
        }
        bytes32 sigHash = keccak256(abi.encodePacked(signature));
        require(!_usedSignatures[sigHash], "Signature already used");
        IBitcoinPodManager.BitcoinDepositRequest memory bitcoinDepositRequest =
            _bitcoinPodManager.getBitcoinDepositRequest(pod);

        bytes32 messageHash = keccak256(
            abi.encodePacked(pod, msg.sender, bitcoinDepositRequest.amount, bitcoinDepositRequest.transactionId, true)
        );
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);
        address signer = ECDSA.recover(ethSignedMessageHash, signature);

        if (signer != msg.sender) {
            revert InvalidOperatorSignature(signer);
        }
        _usedSignatures[sigHash] = true;
        _bitcoinPodManager.confirmBitcoinDeposit(pod, bitcoinDepositRequest.transactionId, bitcoinDepositRequest.amount);
    }

    /**
     * @inheritdoc IBitDSMServiceManager
     */
    function withdrawBitcoinPSBT(address pod, uint256 amount, bytes calldata psbtTransaction, bytes calldata signature)
        external
        onlyPodOperator(pod)
    {
        if (psbtTransaction.length == 0 || psbtTransaction.length > 10000) {
            revert InvalidPSBTTransaction(psbtTransaction.length);
        }
        string memory withdrawAddress = _bitcoinPodManager.getBitcoinWithdrawalAddress(pod);
        // check if the pod has a valid withdrawal request
        if (bytes(withdrawAddress).length == 0) {
            revert NoWithdrawalRequestToProcess(pod);
        }
        // check signature size
        if (signature.length != 65) {
            revert InvalidSignatureLength(signature.length);
        }
        bytes32 sigHash = keccak256(abi.encodePacked(signature));

        require(!_usedSignatures[sigHash], "Signature already used");
        // verify the PSBT is constructed correctly
        if (!_verifyPSBTOutputs(psbtTransaction, withdrawAddress, amount)) {
            revert InvalidPSBTOutputs();
        }

        // verify the operator sign over psbt
        bytes32 messageHash = keccak256(abi.encodePacked(pod, amount, psbtTransaction, withdrawAddress));
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);
        address signer = ECDSA.recover(ethSignedMessageHash, signature);
        if (signer != msg.sender) {
            revert InvalidOperatorSignature(signer);
        }

        _usedSignatures[sigHash] = true;
        // store the psbt in the pod
        _bitcoinPodManager.setSignedBitcoinWithdrawTransactionPod(pod, psbtTransaction);
        // emit the event
        emit BitcoinWithdrawalTransactionSigned(pod, msg.sender, amount);
    }

    /**
     * @inheritdoc IBitDSMServiceManager
     */
    function withdrawBitcoinCompleteTx(address pod, uint256 amount, bytes calldata completeTx, bytes calldata signature)
        external
        onlyPodOperator(pod)
    {
        // get withdraw address from the pod
        string memory withdrawAddress = _bitcoinPodManager.getBitcoinWithdrawalAddress(pod);
        // check if the pod has a valid withdrawal request
        if (bytes(withdrawAddress).length == 0) {
            revert NoWithdrawalRequestToProcess(pod);
        }
        // check signature size
        if (signature.length != 65) {
            revert InvalidSignatureLength(signature.length);
        }
        bytes32 sigHash = keccak256(abi.encodePacked(signature));
        require(!_usedSignatures[sigHash], "Signature already used");

        // decode the transaction
        // check if the transaction is a withdrawal transaction
        // check if the withdrawal address appear as the recipient in the transaction
        // and amount is greater than 0
        // verify the operator sign over completeTx
        // check signature size

        bytes32 messageHash = keccak256(abi.encodePacked(pod, amount, completeTx, withdrawAddress));
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);
        address signer = ECDSA.recover(ethSignedMessageHash, signature);
        if (signer != msg.sender) {
            revert InvalidOperatorSignature(signer);
        }
        _usedSignatures[sigHash] = true;
        // send the completeTx to the pod owner
        _bitcoinPodManager.setSignedBitcoinWithdrawTransactionPod(pod, completeTx);
        // emit the event
        emit BitcoinWithdrawalTransactionSigned(pod, msg.sender, amount);
    }

    /**
     * @inheritdoc IBitDSMServiceManager
     */
    function confirmWithdrawal(address pod, bytes calldata transaction, bytes calldata signature)
        external
        onlyPodOperator(pod)
    {
        // check tx size
        if (transaction.length == 0 || transaction.length > 10000) {
            revert InvalidTransaction(transaction.length);
        }
        // get the withdrawal address from the pod
        string memory withdrawAddress = _bitcoinPodManager.getBitcoinWithdrawalAddress(pod);
        // check if the pod has a withdrawal request
        if (bytes(withdrawAddress).length == 0) {
            revert NoWithdrawalRequestToConfirm(pod);
        }
        // check signature size
        if (signature.length != 65) {
            revert InvalidSignatureLength(signature.length);
        }
        // check if the signature is already used
        bytes32 sigHash = keccak256(abi.encodePacked(signature));
        require(!_usedSignatures[sigHash], "Signature already used");

        bytes32 messageHash = keccak256(abi.encodePacked(pod, transaction, withdrawAddress));
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);
        address signer = ECDSA.recover(ethSignedMessageHash, signature);

        if (signer != msg.sender) {
            revert InvalidOperatorSignature(signer);
        }
        _usedSignatures[sigHash] = true;
        _bitcoinPodManager.withdrawBitcoinAsTokens(pod);
    }

    /**
     * @notice Verify if the PSBT outputs contain the correct withdraw address and amount
     * @param psbtBytes The PSBT data to verify
     * @param withdrawAddress The expected withdraw address
     * @param withdrawAmount The expected withdraw amount
     * @return bool True if the PSBT outputs are correct, false otherwise
     * @dev Validates:
     *      - Single matching output with exact amount
     *      - Valid PSBT format and version
     * @dev Reverts if:
     *      - Invalid inputs
     */
    function _verifyPSBTOutputs(bytes calldata psbtBytes, string memory withdrawAddress, uint256 withdrawAmount)
        internal
        pure
        returns (bool)
    {
        if (bytes(withdrawAddress).length == 0) {
            revert EmptyWithdrawAddress();
        }
        if (withdrawAmount == 0) {
            revert ZeroWithdrawAmount();
        }
        // Direct library call to extract outputs from the PSBT
        BitcoinUtils.Output[] memory outputs = BitcoinUtils.extractVoutFromPSBT(psbtBytes);
        if (outputs.length == 0) {
            revert NoPSBTOutputs();
        }
        if (outputs.length > MAX_PSBT_OUTPUTS) {
            revert TooManyPSBTOutputs(outputs.length);
        }

        //Process each output and find the first instance that matches the withdraw address and amount
        for (uint256 i = 0; i < outputs.length; i++) {
            // convert the scriptPubKey to bech32 address
            string memory bech32Address = BitcoinUtils.convertScriptPubKeyToBech32Address(outputs[i].scriptPubKey);
            // return true if the address is correct and the amount is correct
            if (
                BitcoinUtils.areEqualStrings(bytes(bech32Address), bytes(withdrawAddress))
                    && outputs[i].value == withdrawAmount
            ) {
                return true;
            }
        }
        return false;
    }
}
