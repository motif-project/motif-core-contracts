// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title IAppRegistry
 * @notice Interface for managing application registrations in the BitDSM protocol
 * @dev Implements app registration, deregistration and status tracking functionality
 *
 * The IAppRegistry interface provides the following key functionality:
 * - App registration with signature verification
 * - App deregistration by owner
 * - Registration status checks
 * - Salt cancellation for security
 * - Metadata URI updates
 */
interface IAppRegistry {
    // Custom errors for validation failures
    error ZeroAddress();
    error InvalidSignature();
    error SignatureExpired();
    error SignatureNotYetValid();
    error SaltAlreadySpent();
    error AppAlreadyRegistered();
    error AppNotRegistered();
    error InvalidMetadataURILength();
    error UnauthorizedCaller();
    error InvalidExpiryTime();

    enum AppRegistrationStatus {
        UNREGISTERED,
        REGISTERED
    }
    /**
     * @notice Emitted when registration status changes
     * @param app The address of the app
     * @param status The new registration status
     */

    event AppRegistrationStatusUpdated(address indexed app, AppRegistrationStatus status);

    /**
     * @notice Emitted when metadata URI is updated
     * @param app The address of the app
     * @param metadataURI The new metadata URI
     */
    event AppMetadataURIUpdated(address indexed app, string metadataURI);
    /**
     * @notice Emitted when a salt is cancelled
     * @param app The address of the app
     * @param salt The salt value
     */
    event SaltCancelled(address indexed app, bytes32 indexed salt);

    /**
     * @notice Registers a new app with signature verification
     * @param app The address of the app to register
     * @param signature The EIP-712 signature proving ownership
     * @param salt Unique value to prevent replay attacks
     * @param expiry Timestamp when signature expires
     * @dev Requirements:
     * - `app` must not be zero address, reverts with `ZeroAddress`
     * - `app` must not be already registered, reverts with `AppAlreadyRegistered`
     * - `signature` must be valid EIP-712 signature, reverts with `InvalidSignature`
     * - `salt` must not be previously used, reverts with `SaltAlreadyUsed`
     * - `expiry` must be at least MIN_EXPIRY_DURATION from current time, reverts with `InvalidExpiryTime`
     * - `expiry` must not be in the past, reverts with `SignatureExpired`
     */
    function registerApp(address app, bytes memory signature, bytes32 salt, uint256 expiry) external;

    /**
     * @notice Deregisters an app from the registry
     * @param app The address of the app to deregister
     * @dev Requirements:
     * - Caller must be contract owner, reverts with `UnauthorizedCaller`
     * - `app` must be registered, reverts with `AppNotRegistered`
     */
    function deregisterApp(address app) external;

    /**
     * @notice Checks if an app is registered
     * @param app The address of the app to check
     * @return bool True if registered, false otherwise
     * @dev Requirements:
     * - `app` must not be zero address, reverts with `ZeroAddress`
     */
    function isAppRegistered(address app) external view returns (bool);

    /**
     * @notice Cancels a salt to prevent its future use
     * @param salt The salt to cancel
     * @dev Requirements:
     * - Salt must not be already cancelled, reverts with `SaltAlreadyUsed`
     * - Caller must be the app that would use this salt, reverts with `UnauthorizedCaller`
     */
    function cancelSalt(bytes32 salt) external;

    /**
     * @notice Updates the metadata URI for an app
     * @param metadataURI The new metadata URI
     * @dev Requirements:
     * - Caller must be a registered app, reverts with `AppNotRegistered`
     * - URI length must not exceed MAX_METADATA_URI_LENGTH, reverts with `InvalidMetadataURILength`
     * - URI must not be empty, reverts with `InvalidMetadataURILength`
     */
    function updateAppMetadataURI(string calldata metadataURI) external;
    /**
     * @notice Calculates the EIP-712 digest hash for app registration
     * @param app The address of the app
     * @param appRegistry The address of this registry contract
     * @param salt The salt value
     * @param expiry The expiration timestamp
     * @return bytes32 The calculated EIP-712 digest hash
     * @dev Requirements:
     * - All parameters must not be zero values, reverts with `ZeroAddress`
     */
    function calculateAppRegistrationDigestHash(address app, address appRegistry, bytes32 salt, uint256 expiry)
        external
        view
        returns (bytes32);

    /**
     * @notice Checks if a salt has been cancelled
     * @dev Requirements:
     * - `app` must be registered, reverts with `AppNotRegistered`
     */
    function isSaltCancelled(address app, bytes32 salt) external view returns (bool);

    /**
     * @notice Gets the interface version
     * @return string The semantic version string
     */
    function getVersion() external pure returns (string memory);

    /**
     * @notice Gets the total number of apps registered
     * @return uint256 The total number of apps registered
     */
    function getTotalAppsRegistered() external view returns (uint256);
}
