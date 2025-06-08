// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import "../modules/FeeManager.sol";
import "./BaseBitcoinPod.sol";
import "../interfaces/IEnhancedBitcoinPod.sol";
import "../interfaces/ITokenHub.sol";
import "../interfaces/IRewardsDistributor.sol";
import "../interfaces/ICuratorRegistry.sol";
import "../interfaces/IBitcoinPodManager.sol";
import "../libraries/PodSignatureLibrary.sol";
import "../libraries/PodRewardsLibrary.sol";

/**
 * @title EnhancedBitcoinPod
 * @notice A Bitcoin custody pod with token management and yield strategy capabilities
 * @dev Inherits core logic from BaseBitcoinPod and adds advanced features and role-based access control
 */
contract EnhancedBitcoinPod is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    FeeManager,
    BaseBitcoinPod,
    IEnhancedBitcoinPod   
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    // TokenHub integration
    address public tokenHub;
    bool public isDelegatedToTokenHub;

    // Rewards distributor
    IRewardsDistributor public rewardsDistributor;

    // Rewards address for aggregating rewards
    address public rewardsAddress;

    // Token tracking
    IERC20Upgradeable public reBTC;
    uint256 public podShares;

    // Reward tracking
    mapping(address => PodRewardsLibrary.RewardToken) public rewardTokens;
    EnumerableSetUpgradeable.AddressSet private rewardTokenList;
    address public podManager;
    
    // Curator-related variables
    ICuratorRegistry public curatorRegistry;
    
    // Pod-level curator-strategy approvals. Only one strategy can be approved for a pod
    // Strategy registry
    address private _podApprovedStrategy;

    // Keep only the domain separator (calculated once)
    bytes32 private immutable DOMAIN_SEPARATOR;

    // Keep nonces mapping
    mapping(address => uint256) public nonces;

    constructor() {
        _disableInitializers(); 
        // Use library to calculate domain separator
        DOMAIN_SEPARATOR = PodSignatureLibrary.calculateDomainSeparator(
            address(this),
            "EnhancedBitcoinPod"
        );
    }

    /**
     * @notice Initialize the EnhancedBitcoinPod
     * @param _admin Address of the admin
     * @param _owner Address of the owner
     * @param _operator Address of the operator
     * @param _operatorBtcPubKey Bitcoin public key of the operator
     * @param _bitcoinAddress Bitcoin address of the pod
     * @param _podManager Address of the BitcoinPodManager
     * @param _curatorRegistry Address of the curator registry
     * @param params The enhanced pod parameters including curator and strategy
     */
    function initialize(
        address _admin,
        address _owner,
        address _operator,
        bytes memory _operatorBtcPubKey,
        string memory _bitcoinAddress,
        address _podManager,
        address _curatorRegistry,
        EnhancedPodParams calldata params  // Use the struct from interface
    ) external initializer {
        // Now using interface-defined errors
        if (_admin == address(0)) revert ZeroAddress();
        if (_owner == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();
        if (_operatorBtcPubKey.length == 0) revert EmptyBTCPubKeyString();
        if (bytes(_bitcoinAddress).length == 0) revert EmptyBTCAddressString();
        if (params.remapBitcoin == address(0)) revert ZeroAddress();
        if (_podManager == address(0)) revert ZeroAddress();
        if (_curatorRegistry == address(0)) revert ZeroAddress();

        __Pausable_init();
        __Ownable_init();
        __ReentrancyGuard_init();
        _transferOwnership(_owner);
        // Initialize Base contracts
        __BaseBitcoinPod_init(_operator, _operatorBtcPubKey, _bitcoinAddress);
        __FeeManager_init(_admin, _owner, _operator, params.operatorFeeBP, params.curatorFeeBP, params.protocolFeeBP, params.protocolFeeRecipient);
        // Set token
        reBTC = IERC20Upgradeable(params.remapBitcoin);

        // Get TokenHub from PodManager instead of passing it directly
        podManager = _podManager;
        tokenHub = IBitcoinPodManager(podManager).getTokenHubAddress();
        isDelegatedToTokenHub = false;

        curatorRegistry = ICuratorRegistry(_curatorRegistry);
        
        if (params.curator != address(0)) {
            if (!curatorRegistry.isCuratorActive(params.curator)) revert CuratorNotActive();
            
            // Grant role to curator's forwarder
            address curatorForwarder = curatorRegistry.getCuratorInfo(params.curator).forwarder;
            _grantRole(CURATOR_ROLE, curatorForwarder);
            
            emit CuratorAssigned(params.curator, curatorForwarder);
        }

        emit PodInitialized(address(this), _owner, _operator);
    }

    // --- Access Control for BitcoinPod ---
    modifier onlyManager() override {
        if (!hasRole(ADMIN_ROLE, msg.sender) && msg.sender != podManager) revert NotPodManager();
        _;
    }
    // -- Access Control for Admin/Curator Role ----
    modifier onlyAdminOrCurator() {
    if (!hasRole(ADMIN_ROLE, msg.sender) && !hasRole(CURATOR_ROLE, msg.sender)) 
        revert NotAuthorized();
    _;
}

    // --- Advanced logic and overrides below ---

    // TokenHub/Delegation
    /**
     * @notice Set the TokenHub address for delegation
     * @param _tokenHub Address of the TokenHub contract
     * @dev Only callable by admin or pod manager
     */
    function setTokenHub(address _tokenHub) external onlyManager override {
        if (_tokenHub == address(0)) revert ZeroAddress();
        tokenHub = _tokenHub;
        emit TokenHubSet(_tokenHub);
    }

    /**
     * @notice Set the PodManager address
     * @param _podManager Address of the PodManager contract
     * @dev Only callable by admin
     */
    function setPodManager(address _podManager) external override onlyRole(ADMIN_ROLE) {
        if (_podManager == address(0)) revert ZeroAddress();
        podManager = _podManager;
        emit PodManagerSet(_podManager);
    }

    /**
     * @notice Set delegation status to TokenHub
     * @param _isDelegated True to delegate, false to undelegate
     * @dev Only callable by pod manager
    */
    function setDelegationStatus(bool _isDelegated) external override {
        if (msg.sender != podManager) revert NotPodManager();
        if (tokenHub == address(0)) revert TokenHubNotSet();
        isDelegatedToTokenHub = _isDelegated;
        if (_isDelegated) {
            emit TokenHubDelegated(tokenHub);
        } else {
            emit TokenHubUndelegated();
        }
    }
    /**
     * @notice Enhanced security modifier for curator operations
     */
    modifier onlyAuthorizedCuratorForStrategy(address strategy) {
        if (!hasRole(CURATOR_ROLE, msg.sender)) revert InvalidCuratorRole();
        
        address curator = curatorRegistry.getCuratorByForwarder(msg.sender);
        if (curator == address(0)) revert InvalidCuratorRole();
        if (!curatorRegistry.isCuratorActive(curator)) revert CuratorNotActive();
        if (!curatorRegistry.isStrategyApprovedForCurator(curator, strategy)) revert StrategyNotApproved();
        if (_podApprovedStrategy != strategy) revert StrategyNotApproved();
        _;
    }
   

     /**
     * @notice Report yield from a strategy
     * @param _amount Amount of yield
     * @dev Only callable by approved strategies or admin/curator
     */
    function reportYield(uint256 _amount) external override onlyAdminOrCurator whenNotPaused nonReentrant {
        //if (!hasRole(ADMIN_ROLE, msg.sender) && !hasRole(CURATOR_ROLE, msg.sender)) revert NotAuthorized();
        if (_amount == 0) revert ZeroAmount();
        _accrueFees(_amount);
        emit YieldReported(_amount);
    }

    // Token mint/burn via TokenHub
    /**
     * @notice Mint reBTC tokens 
     * @param _recipient Address to receive the minted tokens
     * @return shares Number of shares minted
     * @dev Only callable by owner or curator when delegated to TokenHub
     */
    function mintTokens(address _recipient) external override whenNotPaused nonReentrant returns (uint256) {
        if (!hasRole(OWNER_ROLE, msg.sender) && !hasRole(CURATOR_ROLE, msg.sender)) revert NotAuthorized();
        if (!isDelegatedToTokenHub) revert NotDelegatedToTokenHub();
        if (_recipient == address(0)) revert ZeroAddress();
        
        uint256 shares = ITokenHub(tokenHub).mintTokensForPod(address(this), _recipient);
        podShares += shares;
        emit SharesUpdated(podShares);
        return shares;
    }

    /**
     * @notice Burn reBTC tokens and add Bitcoin in Pod 
     * @param _shares Number of shares to burn
     * @param _recipient Address to receive the burned Bitcoin
     * @return bitcoinAmount Amount of Bitcoin burned
     * @dev Only callable by owner, curator, or the pod itself when delegated to TokenHub
     */
    function burnTokens(uint256 _shares, address _recipient) external override nonReentrant whenNotPaused returns (uint256) {
        if (!hasRole(OWNER_ROLE, msg.sender) && !hasRole(CURATOR_ROLE, msg.sender) && msg.sender != address(this)) revert NotAuthorized();
        if (!isDelegatedToTokenHub) revert NotDelegatedToTokenHub();
        if (_shares == 0) revert ZeroAmount();
        if (_recipient == address(0)) revert ZeroAddress();
        
        if (msg.sender == address(this)) {
            if (_shares > podShares) revert InsufficientShares();
            podShares -= _shares;
            emit SharesUpdated(podShares);
        }
        if (_shares != bitcoinBalance) revert SharesMismatch();
        
        uint256 bitcoinAmount = ITokenHub(tokenHub).burnTokensForPod(address(this), _shares, _recipient);
        return bitcoinAmount;
    }

    /**
     * @notice Add a reward token
     * @param _token Address of the reward token
     * @dev Only callable by admin
     */
    function addRewardToken(address _token) external override onlyRole(ADMIN_ROLE) {
        PodRewardsLibrary.addRewardToken(rewardTokens, rewardTokenList, _token);
        emit RewardTokenAdded(_token);
    }

    /**
     * @notice Remove a reward token
     * @param _token Address of the reward token
     * @dev Only callable by admin
     */    
    function removeRewardToken(address _token) external override onlyRole(ADMIN_ROLE) {
        PodRewardsLibrary.removeRewardToken(rewardTokens, rewardTokenList, _token);
        emit RewardTokenRemoved(_token);
    }

    /**
     * @notice Set the rewards address for collecting rewards
     * @param _rewardsAddress Address where rewards will be sent
     * @dev Only callable by admin
     */
    function setRewardsAddress(address _rewardsAddress) external override onlyRole(ADMIN_ROLE) {
        if (_rewardsAddress == address(0)) revert ZeroAddress();
        rewardsAddress = _rewardsAddress;
        emit RewardsAddressSet(_rewardsAddress);
    }

     /**
     * @notice Set the rewards distributor address
     * @param _rewardsDistributor Address of the rewards distributor
     * @dev Only callable by admin
     */
    function setRewardsDistributor(address _rewardsDistributor) external override onlyRole(ADMIN_ROLE) {
        if (_rewardsDistributor == address(0)) revert ZeroAddress();
        rewardsDistributor = IRewardsDistributor(_rewardsDistributor);
        emit RewardsDistributorSet(_rewardsDistributor);
    }

    /**
     * @notice Report rewards collected by a strategy
     * @param _token Address of the reward token
     * @param _amount Amount of rewards reported
     * @dev Only callable by approved strategies
     */
    function reportRewards(address _token, uint256 _amount) external override onlyAdminOrCurator whenNotPaused nonReentrant {
       // if (!hasRole(ADMIN_ROLE, msg.sender) && !hasRole(CURATOR_ROLE, msg.sender)) revert NotAuthorized();
        PodRewardsLibrary.reportRewards(rewardTokens, _token, _amount, rewardsAddress);
        emit RewardsReported(_token, _amount);
    }

    /**
     * @notice Notify rewards distributor about new rewards
     * @param _token Address of the reward token
     * @param _amount Amount of rewards
     * @param _merkleRoot Root of the Merkle tree for claim process (optional)
     * @param _airdropAddress Address to receive airdrop (optional)
     * @dev Only callable by admin or operator
     */
    function notifyRewards(
        address _token,
        uint256 _amount,
        bytes32 _merkleRoot,
        address _airdropAddress
    ) external override whenNotPaused nonReentrant {
        if (!hasRole(ADMIN_ROLE, msg.sender) && !hasRole(OPERATOR_ROLE, msg.sender)) revert NotAuthorized();
        
        PodRewardsLibrary.notifyRewards(
            rewardTokens,
            _token,
            _amount,
            rewardsAddress,
            rewardsDistributor,
            _merkleRoot,
            _airdropAddress
        );
        emit RewardsDistributed(_token, _amount);
    }

    /**
     * @notice Get reward token information
     * @param _token Address of the reward token
     * @return token Token address
     * @return totalRewards Total rewards collected
     * @return distributedRewards Rewards already distributed
     */
    function getRewardTokenInfo(address _token) external view override returns (
        address token,
        uint256 totalRewards,
        uint256 distributedRewards
    ) {
        PodRewardsLibrary.RewardToken memory rewardToken = PodRewardsLibrary.getRewardTokenInfo(rewardTokens, _token);
        return (rewardToken.token, rewardToken.totalRewards, rewardToken.distributedRewards);
    }
    
    /**
     * @notice Get list of reward tokens
     * @return List of reward token addresses
     */
    function getRewardTokenList() external view override returns (address[] memory) {
        return PodRewardsLibrary.getRewardTokenList(rewardTokenList);
    }

    /**
     * @notice Get available rewards for a token
     * @param _token Address of the reward token
     * @return Available rewards for distribution
     */
    function getAvailableRewards(address _token) external view returns (uint256) {
        return PodRewardsLibrary.getAvailableRewards(rewardTokens, _token);
    }

    /**
     * @notice Check if a token is supported for rewards
     * @param _token Address of the token to check
     * @return True if token is supported
     */
    function isRewardTokenSupported(address _token) external view returns (bool) {
        return PodRewardsLibrary.isTokenSupported(rewardTokens, _token);
    }

     /**
     * @notice Transfer fees to recipient
     * @param _recipient Address to receive the fees
     * @param _amount Amount to transfer
     * @dev Implements the abstract function from FeeManager
     */
    function _transferFees(address _recipient, uint256 _amount) internal override {
        reBTC.safeTransfer(_recipient, _amount);
    }

    /**
     * @notice Get the assigned curator for this pod
     * @return Address of the assigned curator, or address(0) if none
     */
    function getAssignedCurator() external view returns (address) {
        // Get curator forwarder with CURATOR_ROLE
        uint256 curatorRoleMembers = getRoleMemberCount(CURATOR_ROLE);
        if (curatorRoleMembers == 0) {
            return address(0);
        }
        
        // Should only have one curator role member
        address curatorForwarder = getRoleMember(CURATOR_ROLE, 0);
        return curatorRegistry.getCuratorByForwarder(curatorForwarder);
    }

    /**
     * @notice Approve a curator-strategy combination for this pod
     * @param strategy Address of the strategy
     * @dev Only callable by owner or admin
     * @dev Strategy must be approved for the assigned curator in the registry
     */
    function approveCuratorStrategyForPod(address strategy) external onlyAdminOrCurator{
        //if (!hasRole(OWNER_ROLE, msg.sender) && !hasRole(ADMIN_ROLE, msg.sender)) revert NotAuthorized();
    
        address assignedCurator = this.getAssignedCurator();
        if (assignedCurator == address(0)) revert NoCuratorAssigned();
        if (strategy == address(0)) revert ZeroAddress();
        if (!curatorRegistry.isStrategyApprovedForCurator(assignedCurator, strategy)) revert StrategyNotApproved();
        if (_podApprovedStrategy == strategy) revert StrategyAlreadyApproved();

        _podApprovedStrategy = strategy;

        emit CuratorStrategyApprovedForPod(assignedCurator, strategy);
    }

    /**
     * @notice Remove approval for a curator-strategy combination from this pod
     * @param strategy Address of the strategy
     */
    function removeCuratorStrategyFromPod(address strategy) external onlyAdminOrCurator{
       // if (!hasRole(OWNER_ROLE, msg.sender) && !hasRole(ADMIN_ROLE, msg.sender)) revert NotAuthorized();
        if (_podApprovedStrategy != strategy) revert StrategyNotApproved();

        address assignedCurator = this.getAssignedCurator();
        _podApprovedStrategy = address(0);

        emit CuratorStrategyRemovedFromPod(assignedCurator, strategy);
    }

    /**
     * @notice Set the curator for this pod
     * @param _curator Address of the new curator
     * @dev Only callable by the pod manager
     */
    function setPodCurator(address _curator) external {
        if (msg.sender != podManager) revert NotPodManager();
        if (_curator == address(0)) revert ZeroAddress();
        if (!curatorRegistry.isCuratorActive(_curator)) revert CuratorNotActive();
        
        // Remove old curator role if exists
        address oldCurator = this.getAssignedCurator();
        if (oldCurator != address(0)) {
            address oldCuratorForwarder = curatorRegistry.getCuratorInfo(oldCurator).forwarder;
            _revokeRole(CURATOR_ROLE, oldCuratorForwarder);
        }
        
        // Grant role to new curator's forwarder
        address curatorForwarder = curatorRegistry.getCuratorInfo(_curator).forwarder;
        _grantRole(CURATOR_ROLE, curatorForwarder);
        
        emit CuratorAssigned(_curator, curatorForwarder);
    }

    /**
     * @notice Transfer user's approved tokens to strategy
     * @param strategy Address of the strategy
     * @param amount Amount to transfer from user's wallet
     */
    function transferToStrategy(address strategy, uint256 amount) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
        onlyAuthorizedCuratorForStrategy(strategy)
    {
        if (amount == 0) revert ZeroAmount();        
        // Get pod owner
        address podOwner = getRoleMember(OWNER_ROLE, 0);
        
        // Transfer from user's wallet to strategy
        reBTC.safeTransferFrom(podOwner, strategy, amount);
        emit TokensTransferred(strategy, amount);
    }

    /**
     * @notice Owner directly transfers tokens to strategy
     * @param strategy Address of the strategy
     * @param amount Amount to transfer
     */
    function ownerTransferToStrategy(address strategy, uint256 amount) 
        external 
        onlyRole(OWNER_ROLE)
        whenNotPaused 
    {
        if (_podApprovedStrategy != strategy) revert StrategyNotApproved();
        reBTC.safeTransferFrom(msg.sender, strategy, amount);
        emit TokensTransferred(strategy, amount);
    }

    /**
     * @notice Get pod-approved strategies for the assigned curator
     */
    function getPodApprovedStrategy() external view returns (address) {
        return _podApprovedStrategy;
    }

    /**
     * @notice Check if a strategy is approved for this pod
     */
    function isStrategyApprovedForPod(address strategy) external view returns (bool) {
        return _podApprovedStrategy == strategy;
    }

    /**
     * @notice Get curator forwarder address for ERC20 approvals
     * @return Address that user should approve for token transfers
     */
    function getCuratorForwarderForApproval() external view returns (address) {
        uint256 curatorRoleMembers = getRoleMemberCount(CURATOR_ROLE);
        if (curatorRoleMembers == 0) return address(0);
        return getRoleMember(CURATOR_ROLE, 0); // This is the forwarder address
    }

    /**
     * @notice Execute presigned transfer to strategy
     * @param owner Address of the token owner (pod owner)
     * @param strategy Address of the strategy
     * @param amount Amount to transfer
     * @param deadline Signature expiry timestamp
     * @param v Signature parameter
     * @param r Signature parameter
     * @param s Signature parameter
     */
    function transferToStrategyWithSignature(
        address owner,
        address strategy,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external 
        whenNotPaused 
        nonReentrant 
        onlyAuthorizedCuratorForStrategy(strategy)
    {
        if (!hasRole(OWNER_ROLE, owner)) revert InvalidOwner();
        
        PodSignatureLibrary.verifyAndIncrementNonce(
            DOMAIN_SEPARATOR,
            nonces,
            owner,
            strategy,
            amount,
            deadline,
            v,
            r,
            s
        );
        
        reBTC.safeTransferFrom(owner, strategy, amount);
        emit TokensTransferred(strategy, amount);
    }

    /**
     * @notice Get the current nonce for an owner
     * @param owner Address to get nonce for
     * @return Current nonce value
     */
    function getNonce(address owner) external view returns (uint256) {
        return PodSignatureLibrary.getCurrentNonce(nonces, owner);
    }

    /**
     * @notice Calculate domain separator for signature verification
     * @return The domain separator for this contract
     */
    function getDomainSeparator() external view returns (bytes32) {
        return DOMAIN_SEPARATOR;
    }

    /**
     * @notice Get typed data hash for off-chain signing
     * @param owner Address of the token owner
     * @param strategy Address of the strategy
     * @param amount Amount to transfer
     * @param deadline Signature expiry timestamp
     * @return The hash that should be signed off-chain
     */
    function getTypedDataHash(
        address owner,
        address strategy,
        uint256 amount,
        uint256 deadline
    ) external view returns (bytes32) {
        return PodSignatureLibrary.getTypedDataHash(
            DOMAIN_SEPARATOR,
            owner,
            strategy,
            amount,
            nonces[owner], // Use current nonce
            deadline
        );
    }

    // Add a helper to check which method is available
    function getAvailableTransferMethods(address owner, address strategy, uint256 amount) 
        external view returns (bool canUseApproval, uint256 currentAllowance) 
    {
        address curatorForwarder = getRoleMember(CURATOR_ROLE, 0);
        currentAllowance = reBTC.allowance(owner, curatorForwarder);
        canUseApproval = currentAllowance >= amount;
    }

 
    /**
     * @notice Pause the pod
     * @dev Only callable by admin
     * @dev Pausing prevents any state-modifying actions
     */
    function pause() external override onlyRole(ADMIN_ROLE) {
        _pause();
    }
  
    /**
     * @notice Unpause the pod
     * @dev Only callable by admin
     */
    function unpause() external override onlyRole(ADMIN_ROLE) {
        _unpause();
    }


    // --- Storage gap for upgradeability ---
    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[50] private __gap;
}