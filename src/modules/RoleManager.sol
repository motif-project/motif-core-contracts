// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title RoleManager
 * @notice Base contract for role-based access control in Bitcoin pods
 * @dev Provides role management for pod operations
 */
contract RoleManager is Initializable, AccessControlEnumerableUpgradeable {
    // Standard roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant CURATOR_ROLE = keccak256("CURATOR_ROLE");
    
    // Events
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event AdminSet(address indexed previousAdmin, address indexed newAdmin);
    event CuratorSet(address indexed previousCurator, address indexed newCurator);
    
    /**
     * @notice Initialize the RoleManager
     * @param _admin Address to receive admin role
     * @param _owner Address to receive owner role
     * @param _operator Address to receive operator role
     */
    function __RoleManager_init(address _admin, address _owner, address _operator) internal onlyInitializing {
        __AccessControlEnumerable_init();
        
        // Set up DEFAULT_ADMIN_ROLE (OpenZeppelin's role for managing other roles)
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        
        // Set up our custom roles
        _setupRole(ADMIN_ROLE, _admin);
        _setupRole(OWNER_ROLE, _owner);
        
        if (_operator != address(0)) {
            _setupRole(OPERATOR_ROLE, _operator);
        }
    }
    
    /**
     * @notice Set a new admin
     * @param _newAdmin Address of the new admin
     * @dev Only callable by current admin
     */
    function setAdmin(address _newAdmin) external onlyRole(ADMIN_ROLE) {
        require(_newAdmin != address(0), "Admin cannot be zero address");
        
        address previousAdmin = address(0);
        // Get current admin (should be only one)
        uint256 adminCount = getRoleMemberCount(ADMIN_ROLE);
        if (adminCount > 0) {
            previousAdmin = getRoleMember(ADMIN_ROLE, 0);
            if (previousAdmin != _newAdmin) {
                _revokeRole(ADMIN_ROLE, previousAdmin);
                _revokeRole(DEFAULT_ADMIN_ROLE, previousAdmin);
            }
        }
        
        // Grant to new admin
        _setupRole(ADMIN_ROLE, _newAdmin);
        _setupRole(DEFAULT_ADMIN_ROLE, _newAdmin);
        
        emit AdminSet(previousAdmin, _newAdmin);
        emit RoleGranted(ADMIN_ROLE, _newAdmin, msg.sender);
    }
    
    /**
     * @notice Set curator for the pod
     * @param _curator Address of the curator
     * @dev The curator is responsible for managing yield strategies with motifBTC tokens
     * @dev Only callable by owner or admin
     */
    function setCurator(address _curator) external {
        require(hasRole(OWNER_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Not authorized");
        require(_curator != address(0), "Curator cannot be zero address");
        
        address previousCurator = address(0);
        // Revoke from previous curators
        uint256 curatorCount = getRoleMemberCount(CURATOR_ROLE);
        for (uint256 i = 0; i < curatorCount; i++) {
            previousCurator = getRoleMember(CURATOR_ROLE, 0);
            _revokeRole(CURATOR_ROLE, previousCurator);
        }
        
        // Grant to new curator
        _grantRole(CURATOR_ROLE, _curator);
        
        emit CuratorSet(previousCurator, _curator);
        emit RoleGranted(CURATOR_ROLE, _curator, msg.sender);
    }
    
    /**
     * @notice Check if an address is an admin
     * @param _account Address to check
     * @return True if address is an admin
     */
    function isAdmin(address _account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, _account);
    }
    
    /**
     * @notice Check if an address is the pod owner
     * @param _account Address to check
     * @return True if address is the owner
     */
    function isOwner(address _account) external view returns (bool) {
        return hasRole(OWNER_ROLE, _account);
    }
    
    /**
     * @notice Check if an address is an operator
     * @param _account Address to check
     * @return True if address is an operator
     */
    function isOperator(address _account) external view returns (bool) {
        return hasRole(OPERATOR_ROLE, _account);
    }
    
    /**
     * @notice Check if an address is a curator
     * @param _account Address to check
     * @return True if address is a curator
     */
    function isCurator(address _account) external view returns (bool) {
        return hasRole(CURATOR_ROLE, _account);
    }
    
    /**
     * @notice Get the current admin
     * @return Address of the current admin
     */
    function getAdmin() external view returns (address) {
        uint256 adminCount = getRoleMemberCount(ADMIN_ROLE);
        if (adminCount == 0) {
            return address(0);
        }
        return getRoleMember(ADMIN_ROLE, 0);
    }
    
    /**
     * @notice Get the current curator
     * @return Address of the current curator
     */
    function getCurator() external view returns (address) {
        uint256 curatorCount = getRoleMemberCount(CURATOR_ROLE);
        if (curatorCount == 0) {
            return address(0);
        }
        return getRoleMember(CURATOR_ROLE, 0);
    }
    
    /**
     * @notice Get the current operator
     * @return Address of the current operator
     */
    function getOperator() external view returns (address) {
        uint256 operatorCount = getRoleMemberCount(OPERATOR_ROLE);
        if (operatorCount == 0) {
            return address(0);
        }
        return getRoleMember(OPERATOR_ROLE, 0);
    }
    
    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[50] private __gap;
} 