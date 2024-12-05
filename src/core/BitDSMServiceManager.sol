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
    IBitcoinPodManager _bitcoinPodManager;

    modifier onlyRegisteredOperator(address operator) {
        require(
            ECDSAStakeRegistry(stakeRegistry).operatorRegistered(operator),
            "Operator must be registered"
        );
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
    constructor(
        address _avsDirectory,
        address _bitDSMRegistry,
        address _rewardsCoordinator,
        address _delegationManager
    ) ECDSAServiceManagerBase(
        _avsDirectory,
        _bitDSMRegistry,
        _rewardsCoordinator,
        _delegationManager
    ) {}

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

    function setBitcoinPodManager(address bitcoinPodManager) external {
        _bitcoinPodManager = IBitcoinPodManager(bitcoinPodManager);
    }

    /**
    * @inheritdoc IBitDSMServiceManager
     */
    function confirmDeposit(
        address pod,
        bytes calldata signature
    ) external {
        require(
            IBitcoinPod(pod).getOperator() == msg.sender,
            "Only operator that owns the pod can confirm deposit"
        );
      //  require(
        //    podToBitcoinDepositRequest[pod].length > 0,
          //  "No deposit requests to confirm"
       // );
        IBitcoinPodManager.BitcoinDepositRequest memory bitcoinDepositRequest = 
        _bitcoinPodManager.getBitcoinDepositRequest(pod);

        bytes32 messageHash = keccak256(abi.encodePacked(pod, msg.sender, bitcoinDepositRequest.amount, bitcoinDepositRequest.transactionId, true));
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);
        address signer = ECDSA.recover(ethSignedMessageHash, signature);

        require(signer == msg.sender, "Invalid Operator signature");
        _bitcoinPodManager.confirmBitcoinDeposit(pod, bitcoinDepositRequest.transactionId, bitcoinDepositRequest.amount ) ;
    }

   /**
    * @inheritdoc IBitDSMServiceManager
     */
    function withdrawBitcoinPSBT(address pod, uint256 amount, bytes calldata psbtTransaction, bytes calldata signature) external {
        require(
            IBitcoinPod(pod).getOperator() == msg.sender,
            "Only operator that owns the pod can process withdrawal"
        );
        // check if the pod has a withdrawal request
       require(bytes(_bitcoinPodManager.getBitcoinWithdrawalAddress(pod)).length == 0, "Withdrawal request already exists");  
        string memory withdrawAddress = _bitcoinPodManager.getBitcoinWithdrawalAddress(pod);

        // verify the PSBT is constructed correctly
        require(_verifyPSBTOutputs(psbtTransaction, withdrawAddress, amount), "Invalid PSBT");
        // verify the operator sign over psbt
        bytes32 messageHash = keccak256(abi.encodePacked(pod, amount, psbtTransaction, withdrawAddress));
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);
        address signer = ECDSA.recover(ethSignedMessageHash, signature);
        require(signer == msg.sender, "Invalid Operator signature");

       
        // store the psbt in the pod
        _bitcoinPodManager.setSignedBitcoinWithdrawTransactionPod(pod, psbtTransaction);
        // emit the event
        emit BitcoinWithdrawalTransactionSigned(pod, msg.sender, amount);
    }

    /**
    * @inheritdoc IBitDSMServiceManager
     */
    function withdrawBitcoinCompleteTx(address pod, uint256 amount, bytes calldata completeTx, bytes calldata signature) external {
        require(
            IBitcoinPod(pod).getOperator() == msg.sender,
            "Only operator that owns the pod can process withdrawal"
        );
        // get withdraw address from the pod
        string memory withdrawAddress = _bitcoinPodManager.getBitcoinWithdrawalAddress(pod);
            // decode the transaction
        // check if the transaction is a withdrawal transaction
        // check if the withdrawal address appear as the recipient in the transaction 
        // and amount is greater than 0
        // verify the operator sign over completeTx 
        bytes32 messageHash = keccak256(abi.encodePacked(pod, amount, completeTx, withdrawAddress));
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);
        address signer = ECDSA.recover(ethSignedMessageHash, signature);
        require(signer == msg.sender, "Invalid Operator signature");

        // send the completeTx to the pod owner
        _bitcoinPodManager.setSignedBitcoinWithdrawTransactionPod(pod, completeTx);
        // emit the event
        emit BitcoinWithdrawalTransactionSigned(pod, msg.sender, amount);
    }

     /**
    * @inheritdoc IBitDSMServiceManager
     */
    function confirmWithdrawal(address pod, bytes calldata transaction, bytes calldata signature) external {
        require(
            IBitcoinPod(pod).getOperator() == msg.sender,
            "Only operator that owns the pod can confirm withdrawal"
        );
       require(
           bytes(_bitcoinPodManager.getBitcoinWithdrawalAddress(pod)).length > 0 ,
           "No withdrawal request to confirm"
        );

        string memory withdrawAddress = _bitcoinPodManager.getBitcoinWithdrawalAddress(pod);
    
        bytes32 messageHash = keccak256(abi.encodePacked(pod, transaction, withdrawAddress));
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);
        address signer = ECDSA.recover(ethSignedMessageHash, signature);

        require(signer == msg.sender, "Invalid signature");
        _bitcoinPodManager.withdrawBitcoinAsTokens(pod);
    }
   
    /**
    * @inheritdoc IBitDSMServiceManager
     */
    function verifyBTCAddress(string calldata btcAddress, bytes calldata script) external onlyRegisteredOperator(msg.sender) {
        // extract publickeys from the script
        (bytes memory operatorKey, bytes memory userKey) = BitcoinUtils.extractPublicKeys(script);
        // check if userKey is 33 bytes
        require(userKey.length == 33, "Invalid user key length. It should be 33 bytes");
        // verify correct operator BTC key is used in script
        require(_areEqual(operatorKey, IBitDSMRegistry(stakeRegistry).getOperatorBtcPublicKey(msg.sender)), "Invalid operator BTC key");
        // get scriptPubKey
        bytes memory scriptPubKey = BitcoinUtils.getScriptPubKey(script);
        // convert scriptPubKey to bech32address
        string memory bech32Address = BitcoinUtils.convertScriptPubKeyToBech32Address(scriptPubKey);
        // verify the address is correct
        require(_areEqual(bytes(bech32Address), bytes(btcAddress)), "Invalid BTC address");
        emit BTCAddressVerified(msg.sender, btcAddress);
    }

    /**
    * @notice Compare two bytes arrays of same size
    * @param key1 The first bytes array to compare
    * @param key2 The second bytes array to compare
    * @return bool True if the arrays are equal, false otherwise
    */
    function _areEqual(bytes memory key1, bytes memory key2) internal pure returns (bool) {
        if (key1.length != key2.length) return false; // Early exit for length mismatch
        for (uint256 i = 0; i < key1.length; i++) {
            if (key1[i] != key2[i]) return false; // Compare each byte
        }
        return true;
    }

   function _verifyPSBTOutputs(bytes calldata psbtBytes, string memory withdrawAddress, uint256 withdrawAmount) internal pure returns (bool) {
        // Direct library call to extract outputs from the PSBT
        BitcoinUtils.Output[] memory outputs = BitcoinUtils.extractVoutFromPSBT(psbtBytes);
        
        // Process each output
        for(uint256 i = 0; i < outputs.length; i++) {
            // convert the scriptPubKey to bech32 address
            string memory bech32Address = BitcoinUtils.convertScriptPubKeyToBech32Address(outputs[i].scriptPubKey);
            // return true if the address is correct and the amount is correct
            if (_areEqual(bytes(bech32Address), bytes(withdrawAddress)) && outputs[i].value == withdrawAmount) {
                return true;
            }
        }
        return false;
    }

}
