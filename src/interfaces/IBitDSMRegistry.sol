// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {ISignatureUtils} from "@eigenlayer/src/contracts/interfaces/ISignatureUtils.sol";
/**
 * @title BitDSM Registry
 * @notice Registry contract for Bitcoin DSM (Decentralized Service Manager) operators
 * @dev THIS CONTRACT IS NOT AUDITED.
 * @dev Extends ECDSAStakeRegistry to handle Bitcoin-specific operator registration
 *
 *
 * This contract manages:
 * - Registration of operators with their Bitcoin public keys
 * - Integration with EigenLayer's delegation system
 * - Operator deregistration
 *
 * Key features:
 * - Secure storage of operator Bitcoin public keys
 * - Validation of Bitcoin public key format
 * - Integration with EigenLayer staking
 *
 * The contract works in conjunction with:
 * - BitDSMServiceManager: For operator task management
 * - BitcoinPodManager: For pod operations
 * - EigenLayer: For staking and delegation
 */

interface IBitDSMRegistry {
    /**
     * @notice Emitted when an operator registers their Bitcoin public key
     * @param operator Address of the operator registering their key
     * @param btcPublicKey The Bitcoin public key being registered
     */
    event OperatorBtcKeyRegistered(address indexed operator, bytes btcPublicKey);
    /**
     * @notice Emitted when an operator deregisters and removes their Bitcoin public key
     * @param operator Address of the operator deregistering
     */
    event OperatorBtckeyDeregistered(address indexed operator);

    /**
     * @notice Registers a new operator using a provided signature and signing key
     * @param _operatorSignature Contains the operator's ECDSA signature, salt, and expiry
     * @param _signingKey The signing key to add to the operator's history
     * @param btcPublicKey The Bitcoin public key to register for the operator
     * @dev caller must be the operator itself
     * @dev Only interface for registering an operator with BitDSM AVS
     */
    function registerOperatorWithSignature(
        ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature,
        address _signingKey,
        bytes calldata btcPublicKey
    ) external;

    /**
     * @notice Deregisters an operator and removes their Bitcoin public key
     * @dev Only interface for deregistering an operator with BitDSM AVS
     */
    function deregisterOperator() external;

    /**
     * @notice Checks if an operator has a registered Bitcoin public key
     * @param operator Address of the operator to check
     * @return True if the operator has a registered Bitcoin public key, false otherwise
     */
    function isOperatorBtcKeyRegistered(address operator) external view returns (bool);

    /**
     * @notice Retrieves the Bitcoin public key for a registered operator
     * @param operator Address of the operator to retrieve the key for
     * @return The Bitcoin public key associated with the operator
     */
    function getOperatorBtcPublicKey(address operator) external view returns (bytes memory);
}
