// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../interfaces/IBitDSMRegistry.sol";
import "../libraries/ECDSAStakeRegistry.sol";

// @inheritdoc IBitDSMRegistry
// @inheritdoc ECDSAStakeRegistry
contract BitDSMRegistry is ECDSAStakeRegistry, PausableUpgradeable, IBitDSMRegistry {
    /// @notice mapping of operator addresses to their BTC public keys
    mapping(address => bytes) private _operatorToBtcPublicKey;

    /// @notice constructor for the BitDSMRegistry
    constructor(IDelegationManager _delegationManager) ECDSAStakeRegistry(_delegationManager) {}

    /**
     * @notice Initializes the BitDSMRegistry contract
     * @param _serviceManager The address of the service manager
     * @param _thresholdWeight The threshold weight in basis points
     * @param _quorum The quorum struct containing the details of the quorum thresholds
     */
    function initialize(address _serviceManager, uint256 _thresholdWeight, Quorum memory _quorum)
        external
        initializer
    {
        __ECDSAStakeRegistry_init(_serviceManager, _thresholdWeight, _quorum);
        __Pausable_init();
    }

    /**
     * @inheritdoc IBitDSMRegistry
     */
    function registerOperatorWithSignature(
        ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature,
        address _signingKey,
        bytes calldata btcPublicKey // Additional parameter
    ) external override {
        // Your custom logic goes here
        require(btcPublicKey.length == 33, "Invalid Bitcoin public key length");
        require(_operatorToBtcPublicKey[msg.sender].length == 0, "Operator already registered");
        // register operator with avs using signature
        _registerOperatorWithSig(msg.sender, _operatorSignature, _signingKey);

        // store the BTC key for each operator
        _operatorToBtcPublicKey[msg.sender] = btcPublicKey;

        emit OperatorBtcKeyRegistered(msg.sender, btcPublicKey);
    }

    /**
     * @inheritdoc IBitDSMRegistry
     */
    function deregisterOperator() external override(ECDSAStakeRegistry, IBitDSMRegistry) {
        require(_operatorToBtcPublicKey[msg.sender].length > 0, "Operator not registered");
        // deregister operator from avs
        _deregisterOperator(msg.sender);
        // delete the BTC key for the operator
        delete _operatorToBtcPublicKey[msg.sender];
        // emit the event
        emit OperatorBtckeyDeregistered(msg.sender);
    }

    /**
     * @inheritdoc IBitDSMRegistry
     */
    function isOperatorBtcKeyRegistered(address operator) external view returns (bool) {
        return _operatorToBtcPublicKey[operator].length > 0;
    }

    /**
     * @inheritdoc IBitDSMRegistry
     */
    function getOperatorBtcPublicKey(address operator) external view returns (bytes memory) {
        require(_operatorToBtcPublicKey[operator].length > 0, "Operator not registered");
        return _operatorToBtcPublicKey[operator];
    }

    /// @notice pause the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice unpause the contract
    function unpause() external onlyOwner {
        _unpause();
    }
}
