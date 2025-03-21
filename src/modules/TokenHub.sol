// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../token/MotifBitcoin.sol";
import "../interfaces/IBitcoinPodManager.sol";
import "../interfaces/IBitcoinPod.sol";
import "../interfaces/ITokenHub.sol";

/**
 * @title TokenHub
 * @notice Central coordinator for Enhanced Bitcoin pod shares and MotifBTC token minting/burning
 */
contract TokenHub is 
    Initializable, 
    AccessControlEnumerableUpgradeable, 
    PausableUpgradeable, 
    ReentrancyGuardUpgradeable,
    ITokenHub
{
    // Constants
    uint256 public constant TOTAL_BASIS_POINTS = 10000;
    
    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // State variables
    MotifBitcoin public motifBitcoin;
    IBitcoinPodManager public podManager;
    
    // Pod tracking
    mapping(address => bool) public isDelegatedPod;
    mapping(address => uint256) public podShares;
    uint256 public totalShares;
    
    // Protocol limits
    uint256 public maxTotalBitcoin;
    uint256 public minPodSize;
    
    // Events
    event PodDelegatedToTokenHub(address indexed podAddress);
    event PodUndelegatedFromTokenHub(address indexed podAddress);
    event SharesMinted(address indexed recipient, uint256 shares, uint256 bitcoinAmount);
    event SharesBurned(address indexed owner, uint256 shares, uint256 bitcoinAmount);
    
    // Errors
    error PodAlreadyDelegated(address pod);
    error PodNotDelegated(address pod);
    error BelowMinimumPodSize(uint256 size);
    error ExceedsMaxTotalBitcoin(uint256 amount);
    error ZeroArgument(string param);
    error SharesMismatch(uint256 expected, uint256 actual);
    error NotPodManager();
    error InsufficientShares(address pod, uint256 requested, uint256 available);
    error NotEnhancedBitcoinPod();
    
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
        _grantRole(EMERGENCY_ROLE, _admin);
        
        motifBitcoin = MotifBitcoin(_motifBitcoin);
        podManager = IBitcoinPodManager(_podManager);
        maxTotalBitcoin = _maxTotalBitcoin;
        minPodSize = _minPodSize;
    }

    // delegate pod to the token hub
    function delegatePodToTokenHub(address _podAddress) external nonReentrant whenNotPaused {
        // Check caller is the pod manager
        if (msg.sender != address(podManager)) revert NotPodManager();

        // Check pod is not already delegated
        if (isDelegatedPod[_podAddress]) revert PodAlreadyDelegated(_podAddress);

        uint256 _bitcoinAmount = IBitcoinPod(_podAddress).getBitcoinBalance();
        // Check pod size
        if (_bitcoinAmount < minPodSize) revert BelowMinimumPodSize(_bitcoinAmount);
        
        // Check total Bitcoin limit
        if (totalShares + _bitcoinAmount > maxTotalBitcoin) revert ExceedsMaxTotalBitcoin(_bitcoinAmount);


        // delegate pod to the token hub
        isDelegatedPod[_podAddress] = true;
        emit PodDelegatedToTokenHub(_podAddress);

    }
    function undelegatePodFromTokenHub(address _podAddress) external nonReentrant whenNotPaused {
        // Check caller is the pod manager
        if (msg.sender != address(podManager)) revert NotPodManager();

        // Check pod is delegated
        if (!isDelegatedPod[_podAddress]) revert PodNotDelegated(_podAddress);

        // undelegate pod from the token hub
        isDelegatedPod[_podAddress] = false;
        delete isDelegatedPod[_podAddress];
        emit PodUndelegatedFromTokenHub(_podAddress);
    }
    /**
     * @notice Mint tokens for a pod
     * @param _podAddress Address of the pod
     * @param _recipient Address to receive the minted tokens
     * @return Amount of shares minted
     */
    function mintTokensForPod(
        address _podAddress,
        address _recipient
    ) external nonReentrant whenNotPaused returns (uint256) {
        // Check caller is the EnhancedBitcoinPod
        if (msg.sender != _podAddress) revert NotEnhancedBitcoinPod();
        
        //  revert if pod is not delegated
        if (!isDelegatedPod[_podAddress]) revert PodNotDelegated(_podAddress);

        // Calculate shares to mint. Mint the amount in the Pod 
        uint256 _bitcoinAmount = IBitcoinPod(_podAddress).getBitcoinBalance();
        uint256 shares = motifBitcoin.getSharesByPooledBitcoin(_bitcoinAmount);
        if (shares == 0) revert ZeroArgument("shares");
        
        totalShares += shares;
        
        // Mint tokens
        motifBitcoin.mintShares(_recipient, shares);
        // lock the pod // lock the bitcoinpod
        IBitcoinPod(_podAddress).lock(); // lock the pod to prevent any further minting or burning. Stops withdrawal of Bitcoin from the pod
        emit SharesMinted(_recipient, shares, _bitcoinAmount);
        
        return shares;
    }
    
    /**
     * @notice Burn tokens for a pod
     * @param _podAddress Address of the pod
     * @param _shares Amount of shares to burn
     * @param _owner Address of the token owner
     * @return Amount of Bitcoin released
     */
    function burnTokensForPod(
        address _podAddress,
        uint256 _shares,
        address _owner
    ) external nonReentrant whenNotPaused returns (uint256) {
        // Check caller is the EnhancedBitcoinPod
        if (msg.sender != _podAddress) revert NotEnhancedBitcoinPod();
        
        // Check pod is delegated
        if (!isDelegatedPod[_podAddress]) revert PodNotDelegated(_podAddress);
        
        // Check shares match
        if (podShares[_podAddress] != _shares) revert SharesMismatch(podShares[_podAddress], _shares);
        
        // Get Bitcoin amount
        uint256 bitcoinAmount = IBitcoinPod(_podAddress).getBitcoinBalance();
        
        // Burn tokens
        uint256 burnedAmount = motifBitcoin.burnShares(_owner, _shares);
        
        
        totalShares -= _shares;
        delete podShares[_podAddress];
        emit SharesBurned(_owner, _shares, burnedAmount);
        IBitcoinPod(_podAddress).unlock(); // unlock the pod to allow withdrawal of Bitcoin from the pod after burning
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
     * @notice Check if a pod is delegated
     * @param _podAddress Address of the pod
     * @return Whether the pod is delegated
     */
    function isPodDelegated(address _podAddress) external view override returns (bool) {
        return isDelegatedPod[_podAddress];
    }
    
    /**
     * @notice Get shares for a pod
     * @param _podAddress Address of the pod
     * @return Number of shares
     */
    function getSharesForPod(address _podAddress) external view returns (uint256) {
        return podShares[_podAddress];
    }
    
    /**
     * @notice Get shares by pooled Bitcoin
     * @param _bitcoinAmount Amount of Bitcoin
     * @return Number of shares
     */
    function getSharesByPooledBitcoin(uint256 _bitcoinAmount) external view returns (uint256) {
        return motifBitcoin.getSharesByPooledBitcoin(_bitcoinAmount);
    }
    
    /**
     * @notice Get Bitcoin by shares
     * @param _shares Number of shares
     * @return Amount of Bitcoin
     */
    function getBitcoinByShares(uint256 _shares) external view returns (uint256) {
        return motifBitcoin.getBitcoinByShares(_shares);
    }
    
    /**
     * @notice Get total shares
     * @return Total shares
     */
    function getTotalShares() external view returns (uint256) {
        return totalShares;
    }
    
}
