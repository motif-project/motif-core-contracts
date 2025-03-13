// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IMotifBitcoin.sol";
import "./interfaces/IBitcoinPodManager.sol";
import "./interfaces/IBitcoinPod.sol";
import "./interfaces/ITokenVault.sol";

/**
 * @title TokenHub
 * @notice Central coordinator for Bitcoin vaults and MotifBTC token minting/burning
 */
contract TokenHub is Initializable, AccessControlEnumerableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    // Constants
    uint256 public constant TOTAL_BASIS_POINTS = 10000;
    
    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // State variables
    IMotifBitcoin public motifBitcoin;
    IBitcoinPodManager public podManager;
    
    // Vault registry
    address[] public registeredVaults;
    mapping(address => bool) public isRegisteredVault;

    //   Error definitions
    // @notice VaultAlreadyRegistered
    error VaultAlreadyRegistered(address vault);
    // @notice VaultNotRegistered
    error VaultNotRegistered(address vault);
    // @notice VaultNotActive
    error VaultNotActive(address vault);
    // @notice VaultHasShares
    error VaultHasShares(address vault);
    // @notice InvalidVaultInterface
    error InvalidVaultInterface(address vault);
    // @notice PodAlreadyDelegated
    error PodAlreadyDelegated(address podAddress);
    // @notice PodNotDelegated
    error PodNotDelegated(address podAddress);
    // @notice PodAlreadyDelegatedToApp
    error PodAlreadyDelegatedToApp(address pod, address app);
    // @notice PodNotDelegatedToVault
    error PodNotDelegatedToVault(address pod, address vault);
    // @notice NoPodFound
    error NoPodFound(address user);
    // @notice ExceedsVaultShareLimit
    error ExceedsVaultShareLimit(address vault);
    // @notice ExceedsVaultShares
    error ExceedsVaultShares(address vault);
    // @notice ShareLimitBelowMinted
    error ShareLimitBelowMinted(address vault);
    // @notice BelowMinimumPodSize
    error BelowMinimumPodSize(uint256 size);
    // @notice ExceedsTotalBasisPoints
    error ExceedsTotalBasisPoints(string param);
    // @notice ZeroArgument
    error ZeroArgument(string param);
    // @notice SharesMismatch
    error SharesMismatch(uint256 expected, uint256 actual);
    /**
     * @notice VaultSocket structure to track vault-specific data
     */
    struct VaultSocket {
        uint96 shareLimit;      // Maximum shares this vault can mint
        uint96 sharesMinted;    // Current shares minted by this vault
        uint16 reserveRatioBP;  // Reserve ratio in basis points (e.g., 1000 = 10%)
        uint16 treasuryFeeBP;   // Fee taken on rewards in basis points
        bool isActive;          // Whether the vault is active
    }
    
    // Vault socket mapping
    mapping(address => VaultSocket) public vaultSocket;
    
    // Pod tracking
    mapping(address => address) public podToVault;
    mapping(address => address[]) public vaultPods;
    
    // Protocol limits
    uint256 public maxTotalBitcoin;
    uint256 public minPodSize;
    
    // Events
    event VaultRegistered(address indexed vault, uint96 shareLimit, uint16 reserveRatioBP);
    event VaultRemoved(address indexed vault);
    event VaultSocketUpdated(address indexed vault, uint96 shareLimit, uint16 reserveRatioBP);
    event PodDelegated(address indexed podAddress, address indexed vault, uint256 bitcoinAmount, uint256 shares);
    event PodReleased(address indexed podAddress, address indexed vault, uint256 bitcoinAmount);
    event SharesMinted(address indexed vault, address indexed recipient, uint256 shares, uint256 bitcoinAmount);
    event SharesBurned(address indexed vault, address indexed owner, uint256 shares, uint256 bitcoinAmount);
    
    /**
     * @notice Initialize the TokenHub contract
     * @param _motifBitcoin Address of the MotifBitcoin token
     * @param _podManager Address of the BitcoinPodManager
     * @param _admin Address of the admin
     * @param _maxTotalBitcoin Maximum total Bitcoin in the protocol
     * @param _minPodSize Minimum pod size
     */
    function initialize(
        address _motifBitcoin,
        address _podManager,
        address _admin,
        uint256 _maxTotalBitcoin,
        uint256 _minPodSize
    ) external initializer {
        if (_motifBitcoin == address(0)) revert ZeroArgument("_motifBitcoin");
        if (_podManager == address(0)) revert ZeroArgument("_podManager");
        if (_admin == address(0)) revert ZeroArgument("_admin");
        if (_maxTotalBitcoin == 0) revert ZeroArgument("_maxTotalBitcoin");
        if (_minPodSize == 0) revert ZeroArgument("_minPodSize");
        
        __AccessControlEnumerable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(VAULT_MANAGER_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);
        
        motifBitcoin = IMotifBitcoin(_motifBitcoin);
        podManager = IBitcoinPodManager(_podManager);
        maxTotalBitcoin = _maxTotalBitcoin;
        minPodSize = _minPodSize;
    }
    
    /**
     * @notice Register a new vault
     * @param _vault Address of the vault
     * @param _shareLimit Maximum shares this vault can mint
     * @param _reserveRatioBP Reserve ratio in basis points
     */
    function registerVault(
        address _vault,
        uint96 _shareLimit,
        uint16 _reserveRatioBP
    ) external onlyRole(VAULT_MANAGER_ROLE) {
        if (_vault == address(0)) revert ZeroArgument("_vault");
        if (isRegisteredVault[_vault]) revert VaultAlreadyRegistered(_vault);
        if (_reserveRatioBP > TOTAL_BASIS_POINTS) revert ExceedsTotalBasisPoints("_reserveRatioBP");
        
        // Verify vault interface
        try ITokenVault(_vault).supportsTokenHub() returns (bool supported) {
            if (!supported) revert InvalidVaultInterface(_vault);
        } catch {
            revert InvalidVaultInterface(_vault);
        }
        
        // Register vault
        isRegisteredVault[_vault] = true;
        registeredVaults.push(_vault);
        
        // Initialize vault socket
        vaultSocket[_vault] = VaultSocket({
            shareLimit: _shareLimit,
            sharesMinted: 0,
            reserveRatioBP: _reserveRatioBP,
            treasuryFeeBP: 0,
            isActive: true
        });
        
        emit VaultRegistered(_vault, _shareLimit, _reserveRatioBP);
    }
    
    /**
     * @notice Remove a vault
     * @param _vault Address of the vault
     */
    function removeVault(address _vault) external onlyRole(VAULT_MANAGER_ROLE) {
        if (!isRegisteredVault[_vault]) revert VaultNotRegistered(_vault);
        
        // Check vault has no shares
        VaultSocket storage socket = vaultSocket[_vault];
        if (socket.sharesMinted > 0) revert VaultHasShares(_vault);
        
        // Remove vault
        isRegisteredVault[_vault] = false;
        
        // Remove from registered vaults array
        for (uint i = 0; i < registeredVaults.length; i++) {
            if (registeredVaults[i] == _vault) {
                registeredVaults[i] = registeredVaults[registeredVaults.length - 1];
                registeredVaults.pop();
                break;
            }
        }
        
        // Delete vault socket
        delete vaultSocket[_vault];
        
        emit VaultRemoved(_vault);
    }
    
    /**
     * @notice Update vault socket
     * @param _vault Address of the vault
     * @param _shareLimit Maximum shares this vault can mint
     * @param _reserveRatioBP Reserve ratio in basis points
     */
    function updateVaultSocket(
        address _vault,
        uint96 _shareLimit,
        uint16 _reserveRatioBP
    ) external onlyRole(VAULT_MANAGER_ROLE) {
        if (!isRegisteredVault[_vault]) revert VaultNotRegistered(_vault);
        if (_reserveRatioBP > TOTAL_BASIS_POINTS) revert ExceedsTotalBasisPoints("_reserveRatioBP");
        
        VaultSocket storage socket = vaultSocket[_vault];
        
        // Check share limit is not below current minted shares
        if (_shareLimit < socket.sharesMinted) revert ShareLimitBelowMinted(_vault);
        
        // Update socket
        socket.shareLimit = _shareLimit;
        socket.reserveRatioBP = _reserveRatioBP;
        
        emit VaultSocketUpdated(_vault, _shareLimit, _reserveRatioBP);
    }
    
    /**
     * @notice Set vault active status
     * @param _vault Address of the vault
     * @param _isActive Whether the vault is active
     */
    function setVaultActive(address _vault, bool _isActive) external onlyRole(VAULT_MANAGER_ROLE) {
        if (!isRegisteredVault[_vault]) revert VaultNotRegistered(_vault);
        
        vaultSocket[_vault].isActive = _isActive;
    }
    
    /**
     * @notice Mint tokens for a pod
     * @param _podAddress Address of the pod
     * @param _bitcoinAmount Amount of Bitcoin in the pod
     * @param _recipient Address to receive the minted tokens
     * @return Amount of shares minted
     */
    function mintTokensForPod(
        address _podAddress,
        uint256 _bitcoinAmount,
        address _recipient
    ) external nonReentrant whenNotPaused returns (uint256) {
        // Check caller is a registered vault
        address _vault = msg.sender;
        if (!isRegisteredVault[_vault]) revert VaultNotRegistered(_vault);
        if (!vaultSocket[_vault].isActive) revert VaultNotActive(_vault);
        
        // Check pod is not already delegated
        if (podToVault[_podAddress] != address(0)) revert PodAlreadyDelegated(_podAddress);
        
        // Check pod size
        if (_bitcoinAmount < minPodSize) revert BelowMinimumPodSize(_bitcoinAmount);
        
        // Calculate shares to mint
        uint256 shares = motifBitcoin.getSharesByPooledBitcoin(_bitcoinAmount);
        if (shares == 0) revert ZeroArgument("shares");
        
        // Check vault share limit
        VaultSocket storage socket = vaultSocket[_vault];
        uint256 newSharesMinted = uint256(socket.sharesMinted) + shares;
        if (newSharesMinted > socket.shareLimit) revert ExceedsVaultShareLimit(_vault);
        
        // Delegate pod to vault through pod manager
        podManager.delegatePod(_podAddress, _vault);
        
        // Lock the pod
        podManager.lockPod(_podAddress);
        
        // Update state
        socket.sharesMinted = uint96(newSharesMinted);
        podToVault[_podAddress] = _vault;
        vaultPods[_vault].push(_podAddress);
        
        // Mint tokens
        uint256 mintedAmount = motifBitcoin.mintShares(_recipient, shares);
        
        emit PodDelegated(_podAddress, _vault, _bitcoinAmount, shares);
        emit SharesMinted(_vault, _recipient, shares, mintedAmount);
        
        return shares;
    }
    
    /**
     * @notice Release a pod from a vault and burn shares
     * @param _podAddress Address of the pod to release
     * @param _shares Amount of shares to burn
     * @return Amount of Bitcoin released
     */
    function burnTokensForPod(
        address _podAddress,
        uint256 _shares,
        address _owner
    ) external nonReentrant whenNotPaused returns (uint256) {
        // Check caller is a registered vault
        address vault = msg.sender;
        if (!isRegisteredVault[vault]) revert VaultNotRegistered(vault);
        
        // Check pod is delegated to the vault
        if (podToVault[_podAddress] != vault) revert PodNotDelegatedToVault(_podAddress, vault);
        
        // Get pod balance and verify shares match
        uint256 bitcoinAmount = IBitcoinPod(_podAddress).getBitcoinBalance();
        uint256 podShares = motifBitcoin.getSharesByPooledBitcoin(bitcoinAmount);
        if (podShares != _shares) revert SharesMismatch(podShares, _shares);
        
        // Check vault has enough shares
        VaultSocket storage socket = vaultSocket[vault];
        if (uint256(socket.sharesMinted) < _shares) revert ExceedsVaultShares(vault);
        
        // Burn tokens
        uint256 burnedAmount = motifBitcoin.burnShares(_owner, _shares);
        
        // Update state
        socket.sharesMinted = uint96(uint256(socket.sharesMinted) - _shares);
        delete podToVault[_podAddress];
        
        // Remove from vault pods array
        address[] storage pods = vaultPods[vault];
        for (uint i = 0; i < pods.length; i++) {
            if (pods[i] == _podAddress) {
                pods[i] = pods[pods.length - 1];
                pods.pop();
                break;
            }
        }
        
        // Unlock the pod
        podManager.unlockPod(_podAddress);
        
        // Undelegate pod from vault
        podManager.undelegatePod(_podAddress);
        
        emit PodReleased(_podAddress, vault, bitcoinAmount);
        emit SharesBurned(vault, _owner, _shares, burnedAmount);
        
        return bitcoinAmount;
    }
    
    /**
     * @notice Set protocol limits
     * @param _maxTotalBitcoin Maximum total Bitcoin in the protocol
     * @param _minPodSize Minimum pod size
     */
    function setProtocolLimits(
        uint256 _maxTotalBitcoin,
        uint256 _minPodSize
    ) external onlyRole(ADMIN_ROLE) {
        maxTotalBitcoin = _maxTotalBitcoin;
        minPodSize = _minPodSize;
    }
    
    /**
     * @notice Emergency pause
     */
    function emergencyPause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }
    
    /**
     * @notice Resume after pause
     */
    function resume() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Get all registered vaults
     * @return Array of vault addresses
     */
    function getRegisteredVaults() external view returns (address[] memory) {
        return registeredVaults;
    }
    
    /**
     * @notice Get all pods for a vault
     * @param _vault Vault address
     * @return Array of pod addresses
     */
    function getVaultPods(address _vault) external view returns (address[] memory) {
        return vaultPods[_vault];
    }
    
    /**
     * @notice Get total shares minted across all vaults
     * @return Total shares minted
     */
    function getTotalSharesMinted() external view returns (uint256) {
        uint256 total = 0;
        for (uint i = 0; i < registeredVaults.length; i++) {
            total += vaultSocket[registeredVaults[i]].sharesMinted;
        }
        return total;
    }
    
}
