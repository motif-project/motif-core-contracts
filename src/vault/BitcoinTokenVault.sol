// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math256} from "../common/lib/Math256.sol";
import "../interfaces/ITokenHub.sol";
import "../interfaces/IBitcoinPodManager.sol";
import "../interfaces/IBitcoinPod.sol";

/**
 * @title BitcoinTokenVault
 * @notice Manages Bitcoin pods and integrates with TokenHub for minting/burning MotifBTC
 * @dev Implements delegation pattern for fee distribution between curator and node operator
 */
contract BitcoinTokenVault is Initializable, AccessControlEnumerableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    // Constants
    uint256 public constant TOTAL_BASIS_POINTS = 10000;
    uint256 private constant MAX_FEE_BP = TOTAL_BASIS_POINTS;
    
    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FUND_ROLE = keccak256("FUND_ROLE");
    bytes32 public constant WITHDRAW_ROLE = keccak256("WITHDRAW_ROLE");
    bytes32 public constant DELEGATE_POD_ROLE = keccak256("DELEGATE_POD_ROLE");
    bytes32 public constant RELEASE_POD_ROLE = keccak256("RELEASE_POD_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant CURATOR_FEE_SET_ROLE = keccak256("CURATOR_FEE_SET_ROLE");
    bytes32 public constant CURATOR_FEE_CLAIM_ROLE = keccak256("CURATOR_FEE_CLAIM_ROLE");
    bytes32 public constant NODE_OPERATOR_MANAGER_ROLE = keccak256("NODE_OPERATOR_MANAGER_ROLE");
    bytes32 public constant NODE_OPERATOR_FEE_CLAIM_ROLE = keccak256("NODE_OPERATOR_FEE_CLAIM_ROLE");
    
    // State variables
    ITokenHub public tokenHub;
    IBitcoinPodManager public podManager;
    
    // Pod tracking
    struct PodInfo {
        address podAddress;
        uint256 bitcoinAmount;
        uint256 shares;
        address owner;
        uint256 delegationTime;
        bool active;
    }
    
    mapping(address => PodInfo) public pods;
    address[] public activePods;
    uint256 public totalBitcoin;
    uint256 public totalShares;
    
    // Fee management
    uint256 public curatorFeeBP;
    uint256 public nodeOperatorFeeBP;
    
    // Report structure for tracking rewards
    struct Report {
        uint256 timestamp;
        uint256 valuation;
        int128 inOutDelta;
    }
    
    Report public latestReport;
    Report public curatorFeeClaimedReport;
    Report public nodeOperatorFeeClaimedReport;
    
    // Strategy parameters
    string public strategyDescription;
    
    // Events
    event PodDelegated(address indexed podAddress, address indexed owner, uint256 bitcoinAmount, uint256 shares);
    event PodReleased(address indexed podAddress, address indexed owner, uint256 bitcoinAmount);
    event StrategyUpdated(string description);
    event ReportGenerated(uint256 timestamp, uint256 valuation, int128 inOutDelta);
    event CuratorFeeBPSet(address indexed sender, uint256 oldCuratorFeeBP, uint256 newCuratorFeeBP);
    event NodeOperatorFeeBPSet(address indexed sender, uint256 oldNodeOperatorFeeBP, uint256 newNodeOperatorFeeBP);
    event CuratorFeeClaimed(address indexed recipient, uint256 amount);
    event NodeOperatorFeeClaimed(address indexed recipient, uint256 amount);
    event Initialized(address defaultAdmin);
    event Funded(address indexed sender, uint256 amount);
    event Withdrawn(address indexed recipient, uint256 amount);
    
    /**
     * @notice Initialize the BitcoinTokenVault contract
     * @param _tokenHub Address of the TokenHub
     * @param _podManager Address of the BitcoinPodManager
     * @param _admin Address of the admin
     * @param _strategyDescription Description of the strategy
     */
    function initialize(
        address _tokenHub,
        address _podManager,
        address _admin,
        string memory _strategyDescription
    ) external initializer {
        if (_tokenHub == address(0)) revert ZeroArgument("_tokenHub");
        if (_podManager == address(0)) revert ZeroArgument("_podManager");
        if (_admin == address(0)) revert ZeroArgument("_admin");
        
        __AccessControlEnumerable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        
        tokenHub = ITokenHub(_tokenHub);
        podManager = IBitcoinPodManager(_podManager);
        strategyDescription = _strategyDescription;
        
        // Initialize report
        latestReport.timestamp = block.timestamp;
        latestReport.valuation = 0;
        latestReport.inOutDelta = 0;
        
        // Initialize fee claimed reports
        curatorFeeClaimedReport = latestReport;
        nodeOperatorFeeClaimedReport = latestReport;
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        
        emit Initialized(_admin);
        emit StrategyUpdated(_strategyDescription);
    }
    
    /**
     * @notice Delegate a Bitcoin pod to this vault
     * @param _podAddress Address of the Bitcoin pod
     * @param _recipient Address to receive minted tokens
     * @return Amount of shares minted
     */
    function delegatePod(address _podAddress, address _recipient) 
        external 
        nonReentrant 
        whenNotPaused 
        onlyRole(DELEGATE_POD_ROLE) 
        returns (uint256) 
    {
        if (_podAddress == address(0)) revert ZeroArgument("_podAddress");
        if (_recipient == address(0)) revert ZeroArgument("_recipient");
        
        // Check if pod is already delegated
        if (tokenHub.isPodDelegated(_podAddress)) revert PodAlreadyDelegated(_podAddress);
        
        // Verify pod ownership
        IBitcoinPod pod = IBitcoinPod(_podAddress);
        if (!podManager.isPodOwner(_podAddress, msg.sender)) revert NotPodOwner(_podAddress);
        
        // Check pod state
        if (pod.getPodState() != IBitcoinPod.PodState.Active) revert PodNotActive(_podAddress);
        
        // Check if pod is already locked
        if (pod.isLocked()) revert PodAlreadyLocked(_podAddress);
        
        // Get Bitcoin balance
        uint256 bitcoinAmount = pod.bitcoinBalance();
        if (bitcoinAmount == 0) revert ZeroBitcoinBalance(_podAddress);
        
        // Lock the pod
        podManager.lockPod(_podAddress);
        
        // Mint tokens through TokenHub
        uint256 shares = tokenHub.mintTokensForPod(_podAddress, bitcoinAmount, _recipient);
        
        // Record pod information
        pods[_podAddress] = PodInfo({
            podAddress: _podAddress,
            bitcoinAmount: bitcoinAmount,
            shares: shares,
            owner: msg.sender,
            delegationTime: block.timestamp,
            active: true
        });
        
        activePods.push(_podAddress);
        totalBitcoin += bitcoinAmount;
        totalShares += shares;
        
        // Update report
        _updateReport(int128(int256(bitcoinAmount)));
        
        emit PodDelegated(_podAddress, msg.sender, bitcoinAmount, shares);
        
        return shares;
    }
    
    /**
     * @notice Release a Bitcoin pod from this vault
     * @param _podAddress Address of the Bitcoin pod
     * @return Amount of Bitcoin released
     */
    function releasePod(address _podAddress) 
        external 
        nonReentrant 
        onlyRole(RELEASE_POD_ROLE) 
        returns (uint256) 
    {
        PodInfo storage podInfo = pods[_podAddress];
        if (!podInfo.active) revert PodNotActive(_podAddress);
        if (podInfo.owner != msg.sender) revert NotPodOwner(_podAddress);
        
        // Check if pod is delegated to this vault
        if (tokenHub.podToVault(_podAddress) != address(this)) revert NotPodVault(_podAddress);
        
        // Burn tokens through TokenHub
        uint256 bitcoinAmount = tokenHub.burnTokensForPod(_podAddress, podInfo.shares, msg.sender);
        
        // Unlock the pod
        podManager.unlockPod(_podAddress);
        
        // Update state
        totalBitcoin -= podInfo.bitcoinAmount;
        totalShares -= podInfo.shares;
        podInfo.active = false;
        
        // Update report
        _updateReport(-int128(int256(podInfo.bitcoinAmount)));
        
        // Remove from active pods array
        for (uint i = 0; i < activePods.length; i++) {
            if (activePods[i] == _podAddress) {
                activePods[i] = activePods[activePods.length - 1];
                activePods.pop();
                break;
            }
        }
        
        emit PodReleased(_podAddress, msg.sender, bitcoinAmount);
        
        return bitcoinAmount;
    }
    
    /**
     * @notice Set curator fee in basis points
     * @param _curatorFeeBP Curator fee in basis points
     */
    function setCuratorFeeBP(uint256 _curatorFeeBP) 
        external 
        onlyRole(CURATOR_FEE_SET_ROLE) 
    {
        if (_curatorFeeBP + nodeOperatorFeeBP > MAX_FEE_BP) revert CombinedFeesExceed100Percent();
        
        uint256 oldCuratorFeeBP = curatorFeeBP;
        curatorFeeBP = _curatorFeeBP;
        
        emit CuratorFeeBPSet(msg.sender, oldCuratorFeeBP, _curatorFeeBP);
    }
    
    /**
     * @notice Set node operator fee in basis points
     * @param _nodeOperatorFeeBP Node operator fee in basis points
     */
    function setNodeOperatorFeeBP(uint256 _nodeOperatorFeeBP) 
        external 
        onlyRole(NODE_OPERATOR_MANAGER_ROLE) 
    {
        if (curatorFeeBP + _nodeOperatorFeeBP > MAX_FEE_BP) revert CombinedFeesExceed100Percent();
        
        uint256 oldNodeOperatorFeeBP = nodeOperatorFeeBP;
        nodeOperatorFeeBP = _nodeOperatorFeeBP;
        
        emit NodeOperatorFeeBPSet(msg.sender, oldNodeOperatorFeeBP, _nodeOperatorFeeBP);
    }
    
    /**
     * @notice Claim curator fee
     * @param _recipient Address to receive the fee
     * @return Amount of fee claimed
     */
    function claimCuratorFee(address _recipient) 
        external 
        nonReentrant 
        onlyRole(CURATOR_FEE_CLAIM_ROLE) 
        returns (uint256) 
    {
        uint256 fee = _calculateFee(curatorFeeBP, curatorFeeClaimedReport);
        if (fee == 0) revert NoFeeAccrued("curator");
        
        curatorFeeClaimedReport = latestReport;
        _claimFee(_recipient, fee);
        
        emit CuratorFeeClaimed(_recipient, fee);
        
        return fee;
    }
    
    /**
     * @notice Claim node operator fee
     * @param _recipient Address to receive the fee
     * @return Amount of fee claimed
     */
    function claimNodeOperatorFee(address _recipient) 
        external 
        nonReentrant 
        onlyRole(NODE_OPERATOR_FEE_CLAIM_ROLE) 
        returns (uint256) 
    {
        uint256 fee = _calculateFee(nodeOperatorFeeBP, nodeOperatorFeeClaimedReport);
        if (fee == 0) revert NoFeeAccrued("nodeOperator");
        
        nodeOperatorFeeClaimedReport = latestReport;
        _claimFee(_recipient, fee);
        
        emit NodeOperatorFeeClaimed(_recipient, fee);
        
        return fee;
    }
    
    /**
     * @notice Generate a new report
     * @param _valuation Current valuation of the vault
     */
    function generateReport(uint256 _valuation) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        latestReport.timestamp = block.timestamp;
        latestReport.valuation = _valuation;
        
        emit ReportGenerated(block.timestamp, _valuation, latestReport.inOutDelta);
    }
    
    /**
     * @notice Update strategy description
     * @param _strategyDescription New strategy description
     */
    function updateStrategy(string memory _strategyDescription) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        strategyDescription = _strategyDescription;
        
        emit StrategyUpdated(_strategyDescription);
    }
    
    /**
     * @notice Returns the unreserved amount of Bitcoin
     * @return The unreserved amount
     */
    function unreserved() public view returns (uint256) {
        uint256 curatorFee = _calculateFee(curatorFeeBP, curatorFeeClaimedReport);
        uint256 nodeOperatorFee = _calculateFee(nodeOperatorFeeBP, nodeOperatorFeeClaimedReport);
        
        return totalBitcoin > (curatorFee + nodeOperatorFee) ? totalBitcoin - (curatorFee + nodeOperatorFee) : 0;
    }
    
    /**
     * @notice Returns the curator unclaimed fee
     * @return The unclaimed fee amount
     */
    function curatorUnclaimedFee() external view returns (uint256) {
        return _calculateFee(curatorFeeBP, curatorFeeClaimedReport);
    }
    
    /**
     * @notice Returns the node operator unclaimed fee
     * @return The unclaimed fee amount
     */
    function nodeOperatorUnclaimedFee() external view returns (uint256) {
        return _calculateFee(nodeOperatorFeeBP, nodeOperatorFeeClaimedReport);
    }
    
    /**
     * @notice Pause the vault
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause the vault
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Get all active pods
     * @return Array of active pod addresses
     */
    function getActivePods() external view returns (address[] memory) {
        return activePods;
    }
    
    /**
     * @notice Get total Bitcoin managed by this vault
     * @return Total Bitcoin amount
     */
    function getTotalBitcoin() external view returns (uint256) {
        return totalBitcoin;
    }
    
    /**
     * @notice Get total shares managed by this vault
     * @return Total shares
     */
    function getTotalShares() external view returns (uint256) {
        return totalShares;
    }
    
    /**
     * @notice Get vault socket from TokenHub
     * @return VaultSocket struct
     */
    function vaultSocket() public view returns (ITokenHub.VaultSocket memory) {
        return tokenHub.vaultSocket(address(this));
    }
    
    /**
     * @notice Check if vault supports TokenHub interface
     * @return Always true for compatible vaults
     */
    function supportsTokenHub() external pure returns (bool) {
        return true;
    }
    
    /**
     * @dev Calculates the curator/node operator fee amount based on the fee and the last claimed report
     * @param _feeBP The fee in basis points
     * @param _lastClaimedReport The last claimed report
     * @return The accrued fee amount
     */
    function _calculateFee(
        uint256 _feeBP,
        Report memory _lastClaimedReport
    ) internal view returns (uint256) {
        int128 rewardsAccrued = int128(latestReport.valuation - _lastClaimedReport.valuation) -
            (latestReport.inOutDelta - _lastClaimedReport.inOutDelta);
        
        return rewardsAccrued > 0 ? (uint256(uint128(rewardsAccrued)) * _feeBP) / TOTAL_BASIS_POINTS : 0;
    }
    
    /**
     * @dev Claims the curator/node operator fee amount
     * @param _recipient The address to which the fee will be sent
     * @param _fee The accrued fee amount
     */
    function _claimFee(address _recipient, uint256 _fee) internal {
        if (_recipient == address(0)) revert ZeroArgument("_recipient");
        if (_fee == 0) revert ZeroArgument("_fee");
        
        // Implementation depends on how Bitcoin is handled
        // This would typically involve creating a withdrawal request
        // or transferring tokens to the recipient
    }
    
    /**
     * @dev Updates the report with a new inOutDelta
     * @param _delta The delta to add to the inOutDelta
     */
    function _updateReport(int128 _delta) internal {
        latestReport.inOutDelta += _delta;
    }
    
    // Error definitions
    // @notice ZeroArgument
    error ZeroArgument(string param);
    // @notice PodNotFound
    error PodNotFound(address podAddress);
    // @notice NotPodOwner
    error NotPodOwner(address podAddress);
    // @notice PodNotActive
    error PodNotActive(address podAddress);
    // @notice PodAlreadyLocked
    error PodAlreadyLocked(address podAddress);
    // @notice PodAlreadyDelegated
    error PodAlreadyDelegated(address podAddress);
    // @notice ZeroBitcoinBalance
    error ZeroBitcoinBalance(address podAddress);
    // @notice NotPodVault
    error NotPodVault(address podAddress);
    // @notice NoFeeAccrued
    error NoFeeAccrued(string feeType);
    // @notice CombinedFeesExceed100Percent
    error CombinedFeesExceed100Percent();
}
