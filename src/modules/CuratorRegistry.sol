// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "../interfaces/IAppRegistry.sol";
import "../interfaces/ICuratorRegistry.sol";
import "../libraries/EIP1271SignatureUtils.sol";
import "./CuratorForwarder.sol";

/**
 * @title CuratorRegistry
 * @notice Registry that manages curators with metadata and strategy approvals
 */
contract CuratorRegistry is 
    ICuratorRegistry,
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    using ClonesUpgradeable for address;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    // Constants
    uint256 public constant MAX_METADATA_URI_LENGTH = 2048;
    uint256 public constant MIN_EXPIRY_DURATION = 5 minutes;
    
    // EIP-712 constants
    bytes32 private constant CURATOR_REGISTRATION_TYPEHASH =
        keccak256("CuratorRegistration(address curator,address curatorRegistry,bytes32 salt,uint256 expiry)");
    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    bytes32 private immutable DOMAIN_SEPARATOR;

    // State variables
    IAppRegistry public immutable appRegistry;
    address public immutable curatorForwarderImpl;
    
    
    // Mappings
    mapping(address => CuratorInfo) public curators;
    mapping(address => mapping(bytes32 => bool)) public curatorSaltIsSpent;
    mapping(address => address) public forwarderToCurator;
    
    // Curator-Strategy relationships
    mapping(address => mapping(address => bool)) public curatorStrategies; // curator => strategy => approved
    mapping(address => EnumerableSetUpgradeable.AddressSet) private _curatorStrategyList;
    
    address[] public allCurators;
    uint256 public totalCurators;


    constructor(address _appRegistry, address _curatorForwarderImpl) {
        require(_appRegistry != address(0), "AppRegistry cannot be zero");
        require(_curatorForwarderImpl != address(0), "Forwarder impl cannot be zero");
        
        appRegistry = IAppRegistry(_appRegistry);
        curatorForwarderImpl = _curatorForwarderImpl;
        
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes("MOTIF_CURATOR")),
                block.chainid,
                address(this)
            )
        );
    }

    function initialize(address _owner) external initializer {
        __Ownable_init();
        __Pausable_init();
        _transferOwnership(_owner);
    }

    /**
     * @notice Register a new curator with EIP-712 signature
     * @param curator Address of the curator
     * @param metadataURI Metadata URI for the curator
     * @param signature EIP-712 signature
     * @param salt Unique salt for replay protection
     * @param expiry Signature expiry timestamp
     */
    function registerCurator(
        address curator,
        string calldata metadataURI,
        bytes memory signature,
        bytes32 salt,
        uint256 expiry
    ) external whenNotPaused {
        if (curator == address(0)) revert ZeroAddress();
        if (curators[curator].curator != address(0)) revert CuratorAlreadyRegistered();
        if (expiry < block.timestamp + MIN_EXPIRY_DURATION) revert SignatureExpired();
        if (curatorSaltIsSpent[curator][salt]) revert SaltAlreadySpent();
        if (bytes(metadataURI).length == 0 || bytes(metadataURI).length > MAX_METADATA_URI_LENGTH) {
            revert InvalidMetadataURI();
        }

        // Verify EIP-712 signature
        bytes32 digestHash = calculateCuratorRegistrationDigestHash(curator, address(this), salt, expiry);
        EIP1271SignatureUtils.checkSignature_EIP1271(curator, digestHash, signature);

        // Deploy forwarder
        address forwarder = curatorForwarderImpl.clone();
        CuratorForwarder(forwarder).initialize(curator, address(this));

        // Store curator info
        curators[curator] = CuratorInfo({
            curator: curator,
            metadataURI: metadataURI,
            isActive: true,
            registrationTimestamp: block.timestamp,
            forwarder: forwarder,
            totalStrategies: 0
        });

        forwarderToCurator[forwarder] = curator;
        curatorSaltIsSpent[curator][salt] = true;
        allCurators.push(curator);
        totalCurators++;

        emit CuratorRegistered(curator, forwarder, metadataURI);
    }

    /**
     * @notice Approve a strategy for a specific curator
     * @param curator Address of the curator
     * @param strategy Address of the strategy (must be registered in AppRegistry)
     */
    function approveStrategyForCurator(address curator, address strategy) external onlyOwner {
        if (curator == address(0) || strategy == address(0)) revert ZeroAddress();
        if (curators[curator].curator == address(0)) revert CuratorNotRegistered();
        if (!curators[curator].isActive) revert CuratorNotActive();
        if (!appRegistry.isAppRegistered(strategy)) revert("Strategy not registered in AppRegistry");
        if (curatorStrategies[curator][strategy]) revert StrategyAlreadyApproved();

        curatorStrategies[curator][strategy] = true;
        _curatorStrategyList[curator].add(strategy);
        curators[curator].totalStrategies++;

        emit StrategyApprovedForCurator(curator, strategy);
    }

    /**
     * @notice Forward call to approved strategy (called by CuratorForwarder)
     * @param curator Address of the curator making the call
     * @param target Target strategy address
     * @param data Call data
     */
    function forwardCall(address curator, address target, bytes calldata data) 
        external 
        whenNotPaused 
        returns (bytes memory) 
    {
        require(msg.sender == curators[curator].forwarder, "Only curator forwarder");
        require(curators[curator].isActive, "Curator not active");
        require(appRegistry.isAppRegistered(target), "Target not registered in AppRegistry");
        require(curatorStrategies[curator][target], "Strategy not approved for curator");

        emit CallForwarded(curator, target, data);

        (bool success, bytes memory result) = target.call(data);
        require(success, "Forward call failed");
        
        return result;
    }

    /**
     * @notice Calculate EIP-712 digest hash for curator registration
     */
    function calculateCuratorRegistrationDigestHash(
        address curator,
        address curatorRegistry,
        bytes32 salt,
        uint256 expiry
    ) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(CURATOR_REGISTRATION_TYPEHASH, curator, curatorRegistry, salt, expiry)
        );
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }

    /**
     * @notice Cancel a salt to prevent future use
     */
    function cancelSalt(bytes32 salt) external {
        if (curatorSaltIsSpent[msg.sender][salt]) revert SaltAlreadySpent();
        curatorSaltIsSpent[msg.sender][salt] = true;
        emit SaltCancelled(msg.sender, salt);
    }

    // View functions
    function isCurator(address curator) external view returns (bool) {
        return curators[curator].curator != address(0);
    }

    function isCuratorActive(address curator) external view returns (bool) {
        return curators[curator].curator != address(0) && curators[curator].isActive;
    }

    function getCuratorInfo(address curator) external view returns (CuratorInfo memory) {
        return curators[curator];
    }

    function getCuratorStrategies(address curator) external view returns (address[] memory) {
        return _curatorStrategyList[curator].values();
    }

    function getCuratorByForwarder(address forwarder) external view returns (address) {
        return forwarderToCurator[forwarder];
    }

    function getAllCurators() external view returns (address[] memory) {
        return allCurators;
    }

    // Admin functions for status management
    function updateCuratorStatus(address curator, bool isActive) external onlyOwner {
        if (curators[curator].curator == address(0)) revert CuratorNotRegistered();
        curators[curator].isActive = isActive;
        emit CuratorStatusUpdated(curator, isActive);
    }

    function removeStrategyFromCurator(address curator, address strategy) external onlyOwner {
        if (!curatorStrategies[curator][strategy]) revert StrategyNotApproved();

        curatorStrategies[curator][strategy] = false;
        _curatorStrategyList[curator].remove(strategy);
        curators[curator].totalStrategies--;

        emit StrategyRemovedFromCurator(curator, strategy);
    }

    function getAppRegistry() external view returns (address) {
        return address(appRegistry);
    }

    function getCuratorForwarderImpl() external view returns (address) {
        return address(curatorForwarderImpl);
    }
    
    function getTotalCurators() external view returns (uint256) {
        return totalCurators;
    }

    function getCuratorSaltIsSpent(address curator, bytes32 salt) external view returns (bool) {
        return curatorSaltIsSpent[curator][salt];
    }

    function updateCuratorMetadata(string calldata metadataURI) external {
        if (curators[msg.sender].curator == address(0)) revert CuratorNotRegistered();
        if (bytes(metadataURI).length == 0 || bytes(metadataURI).length > MAX_METADATA_URI_LENGTH) {
            revert InvalidMetadataURI();
        }
        curators[msg.sender].metadataURI = metadataURI;
        emit CuratorMetadataUpdated(msg.sender, metadataURI);
    }

    function isStrategyApprovedForCurator(address curator, address strategy) external view returns (bool) {
        return curatorStrategies[curator][strategy];
    }
    
}