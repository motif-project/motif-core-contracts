// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title ICuratorRegistry
 * @notice Interface for managing curator registrations, metadata, and strategy approvals
 */
interface ICuratorRegistry {
    // Structs
    struct CuratorInfo {
        address curator;
        string metadataURI;
        bool isActive;
        uint256 registrationTimestamp;
        address forwarder;
        uint256 totalStrategies;
    }

    // Events
    event CuratorRegistered(address indexed curator, address indexed forwarder, string metadataURI);
    event CuratorDeregistered(address indexed curator);
    event CuratorStatusUpdated(address indexed curator, bool isActive);
    event CuratorMetadataUpdated(address indexed curator, string metadataURI);
    event StrategyApprovedForCurator(address indexed curator, address indexed strategy);
    event StrategyRemovedFromCurator(address indexed curator, address indexed strategy);
    event CallForwarded(address indexed curator, address indexed target, bytes data);
    event SaltCancelled(address indexed curator, bytes32 indexed salt);

    // Errors
    error CuratorAlreadyRegistered();
    error CuratorNotRegistered();
    error CuratorNotActive();
    error StrategyAlreadyApproved();
    error StrategyNotApproved();
    error InvalidMetadataURI();
    error ZeroAddress();
    error InvalidSignature();
    error SignatureExpired();
    error SaltAlreadySpent();

    // Core registration functions
    /**
     * @notice Register a new curator with EIP-712 signature verification
     * @param curator Address of the curator to register
     * @param metadataURI Metadata URI for the curator
     * @param signature EIP-712 signature proving ownership
     * @param salt Unique salt for replay protection
     * @param expiry Signature expiry timestamp
     */
    function registerCurator(
        address curator,
        string calldata metadataURI,
        bytes memory signature,
        bytes32 salt,
        uint256 expiry
    ) external;

    /**
     * @notice Update curator metadata URI
     * @param metadataURI New metadata URI
     * @dev Only callable by the curator themselves
     */
    function updateCuratorMetadata(string calldata metadataURI) external;

    /**
     * @notice Cancel a salt to prevent its future use
     * @param salt The salt to cancel
     */
    function cancelSalt(bytes32 salt) external;

    // Strategy management functions
    /**
     * @notice Approve a strategy for a specific curator
     * @param curator Address of the curator
     * @param strategy Address of the strategy (must be registered in AppRegistry)
     * @dev Only callable by contract owner
     */
    function approveStrategyForCurator(address curator, address strategy) external;

    /**
     * @notice Remove strategy approval from a curator
     * @param curator Address of the curator
     * @param strategy Address of the strategy to remove
     * @dev Only callable by contract owner
     */
    function removeStrategyFromCurator(address curator, address strategy) external;

    // Admin functions
    /**
     * @notice Update curator active status
     * @param curator Address of the curator
     * @param isActive New active status
     * @dev Only callable by contract owner
     */
    function updateCuratorStatus(address curator, bool isActive) external;

    // Core forwarder function
    /**
     * @notice Forward call to approved strategy (called by CuratorForwarder)
     * @param curator Address of the curator making the call
     * @param target Target strategy address
     * @param data Call data
     * @return Result of the forwarded call
     */
    function forwardCall(address curator, address target, bytes calldata data)
        external
        returns (bytes memory);

    // View functions - Basic curator info
    /**
     * @notice Check if an address is a registered curator
     * @param curator Address to check
     * @return True if curator is registered
     */
    function isCurator(address curator) external view returns (bool);

    /**
     * @notice Check if a curator is active
     * @param curator Address to check
     * @return True if curator is active
     */
    function isCuratorActive(address curator) external view returns (bool);

    /**
     * @notice Get complete curator information
     * @param curator Address of the curator
     * @return CuratorInfo struct containing all curator data
     */
    function getCuratorInfo(address curator) external view returns (CuratorInfo memory);

    /**
     * @notice Get curator address by their forwarder address
     * @param forwarder Address of the forwarder
     * @return Address of the curator
     */
    function getCuratorByForwarder(address forwarder) external view returns (address);

    // View functions - Strategy relationships
    /**
     * @notice Check if a strategy is approved for a specific curator
     * @param curator Address of the curator
     * @param strategy Address of the strategy
     * @return True if strategy is approved for curator
     */
    function isStrategyApprovedForCurator(address curator, address strategy) external view returns (bool);

    /**
     * @notice Get all strategies approved for a curator
     * @param curator Address of the curator
     * @return Array of strategy addresses
     */
    function getCuratorStrategies(address curator) external view returns (address[] memory);

    // View functions - Registry stats
    /**
     * @notice Get total number of registered curators
     * @return Total curator count
     */
    function getTotalCurators() external view returns (uint256);

    /**
     * @notice Get all registered curator addresses
     * @return Array of curator addresses
     */
    function getAllCurators() external view returns (address[] memory);

    // EIP-712 utility
    /**
     * @notice Calculate EIP-712 digest hash for curator registration
     * @param curator Address of the curator
     * @param curatorRegistry Address of this registry contract
     * @param salt Unique salt value
     * @param expiry Signature expiry timestamp
     * @return Calculated digest hash
     */
    function calculateCuratorRegistrationDigestHash(
        address curator,
        address curatorRegistry,
        bytes32 salt,
        uint256 expiry
    ) external view returns (bytes32);


    /**
     * @notice Mapping to track spent salts for replay protection
     */
    function curatorSaltIsSpent(address curator, bytes32 salt) external view returns (bool);

    /**
     * @notice Address of the AppRegistry contract
     */
    function getAppRegistry() external view returns (address);

    /**
     * @notice Address of the CuratorForwarder implementation contract
     */
    function getCuratorForwarderImpl() external view returns (address);

}