// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../Interfaces/IAppRegistry.sol";
import "../libraries/EIP1271SignatureUtils.sol";

/**
 * @title AppRegistry
 * @notice A registry contract for managing application registrations in the BitDSM protocol
 * @dev Implements EIP-1271 signature verification for secure app registration
 *
 * The AppRegistry contract provides the following key functionality:
 * - Secure app registration using EIP-1271 signatures
 * - App deregistration by owner
 * - Registration status tracking
 *
 * Security features:
 * - Reentrancy protection on state-modifying functions
 * - Expiry-based signature validation
 * - Salt tracking to prevent replay attacks
 * - Owner-only deregistration
 * - Circuit breaker (pause) functionality
 */
contract AppRegistry is
    IAppRegistry,
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    // @notice total number of apps registered
    uint256 public totalAppsRegistered;
    // @notice Mapping of app address to registration status
    mapping(address => AppRegistrationStatus) public appStatus;
    // @notice Mapping of app address and salt to usage status
    mapping(address => mapping(bytes32 => bool)) public appSaltIsSpent;
    // @notice EIP-712 typehash for app registration
    bytes32 private constant APP_REGISTRATION_TYPEHASH =
        keccak256("AppRegistration(address app,address appRegistry, bytes32 salt,uint256 expiry)");
    // @notice EIP-712 typehash for domain separator
    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    // @notice Unique domain separator for this contract instance
    bytes32 private DOMAIN_SEPARATOR;
    /**
     * @notice Maximum length for metadata URI
     */
    uint256 constant MAX_METADATA_URI_LENGTH = 2048;
    /**
     * @notice Minimum time before expiry (1 hour)
     */
    uint256 constant MIN_EXPIRY_DURATION = 5 minutes;
    /**
     * @notice Constructor to initialize the domain separator
     */

    constructor() {
        DOMAIN_SEPARATOR =
            keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes("BitDSM")), block.chainid, address(this)));
    }

    /**
     * @notice Initialization function to set the initial owner and initialize Ownable, Pausable, and ReentrancyGuard
     * @param initialOwner The address of the initial owner
     * @dev This function performs the following:
     * - Validates that initialOwner is not zero address
     * - Initializes the Ownable, Pausable, and ReentrancyGuard contracts
     * - Transfers ownership to initialOwner
     */
    function initialize(address initialOwner) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        transferOwnership(initialOwner);
        totalAppsRegistered = 0;
    }

    /**
     * @inheritdoc IAppRegistry
     * @dev This function performs the following:
     * - Validates that the app is not already registered
     * - Validates that the salt has not been spent
     * - Validates that the signature is valid for the provided expiry
     * - Updates the app's registration status
     * - Emits an AppRegistrationStatusUpdated event
     */
    function registerApp(address app, bytes memory signature, bytes32 salt, uint256 expiry)
        external
        override
        whenNotPaused
        nonReentrant
    {
        if (app == address(0)) revert ZeroAddress();
        if (expiry < block.timestamp + MIN_EXPIRY_DURATION) revert SignatureExpired();
        if (appStatus[app] != AppRegistrationStatus.UNREGISTERED) revert AppAlreadyRegistered();
        if (appSaltIsSpent[app][salt]) revert SaltAlreadySpent();

        bytes32 digestHash = calculateAppRegistrationDigestHash(app, address(this), salt, expiry);

        EIP1271SignatureUtils.checkSignature_EIP1271(app, digestHash, signature);

        appStatus[app] = AppRegistrationStatus.REGISTERED;
        appSaltIsSpent[app][salt] = true;
        totalAppsRegistered++;
        emit AppRegistrationStatusUpdated(app, AppRegistrationStatus.REGISTERED);
    }

    /**
     * @inheritdoc IAppRegistry
     * @dev This function performs the following:
     * - Validates that the app is registered
     * - Updates the app's registration status
     * - Emits an AppRegistrationStatusUpdated event
     */
    function deregisterApp(address app) external override onlyOwner whenNotPaused {
        if (appStatus[app] != AppRegistrationStatus.REGISTERED) revert AppNotRegistered();

        appStatus[app] = AppRegistrationStatus.UNREGISTERED;
        totalAppsRegistered--;
        emit AppRegistrationStatusUpdated(app, AppRegistrationStatus.UNREGISTERED);
    }

    /**
     * @inheritdoc IAppRegistry
     */
    function isAppRegistered(address app) external view override returns (bool) {
        if (app == address(0)) revert ZeroAddress();
        return appStatus[app] == AppRegistrationStatus.REGISTERED;
    }

    /**
     * @inheritdoc IAppRegistry
     * @dev This function performs the following:
     * - Validates that the salt has not been spent
     * - Updates the salt's usage status
     */
    function cancelSalt(bytes32 salt) external override {
        if (appSaltIsSpent[msg.sender][salt]) revert SaltAlreadySpent();
        appSaltIsSpent[msg.sender][salt] = true;
        emit SaltCancelled(msg.sender, salt);
    }

    /**
     * @inheritdoc IAppRegistry
     * @dev This function performs the following:
     * - Validates that the app is registered
     * - Emits an AppMetadataURIUpdated event
     */
    function updateAppMetadataURI(string calldata metadataURI) external override {
        if (appStatus[msg.sender] != AppRegistrationStatus.REGISTERED) revert AppNotRegistered();
        if (bytes(metadataURI).length > MAX_METADATA_URI_LENGTH) revert InvalidMetadataURILength();
        if (bytes(metadataURI).length == 0) revert InvalidMetadataURILength();
        emit AppMetadataURIUpdated(msg.sender, metadataURI);
    }
    // @inheritdoc IAppRegistry

    function calculateAppRegistrationDigestHash(address app, address appRegistry, bytes32 salt, uint256 expiry)
        public
        view
        override
        returns (bytes32)
    {
        // check if appRegistry is not zero address
        if (appRegistry == address(0)) revert ZeroAddress();
        if (app == address(0)) revert ZeroAddress();

        bytes32 structHash = keccak256(abi.encode(APP_REGISTRATION_TYPEHASH, app, appRegistry, salt, expiry));
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }

    /**
     * @notice Pauses the contract
     * @dev This function performs the following:
     * - Validates that the caller is the owner
     * - Pauses the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the contract
     * @dev This function performs the following:
     * - Validates that the caller is the owner
     * - Unpauses the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @inheritdoc IAppRegistry
     * @dev This function performs the following:
     * - Validates that the app is registered
     * - Emits an AppMetadataURIUpdated event
     */
    function isSaltCancelled(address app, bytes32 salt) external view override returns (bool) {
        if (appStatus[app] != AppRegistrationStatus.REGISTERED) revert AppNotRegistered();
        return appSaltIsSpent[app][salt];
    }

    function getVersion() external pure override returns (string memory) {
        return "1.0.0";
    }

    function getTotalAppsRegistered() external view returns (uint256) {
        return totalAppsRegistered;
    }
}
