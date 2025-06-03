// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import "../modules/FeeManager.sol";
import "./BaseBitcoinPod.sol";
import "../interfaces/IEnhancedBitcoinPod.sol";
import "../interfaces/ITokenHub.sol";
import "../interfaces/IRewardsDistributor.sol";
import "../interfaces/ICuratorRegistry.sol";
import "../interfaces/IBitcoinPodManager.sol";

/**
 * @title EnhancedBitcoinPod
 * @notice A Bitcoin custody pod with token management and yield strategy capabilities
 * @dev Inherits core logic from BaseBitcoinPod and adds advanced features and role-based access control
 */
contract EnhancedBitcoinPod is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    IERC721ReceiverUpgradeable,
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

    // Strategy registry
    mapping(address => bool) public approvedStrategies;

    // Reward tracking
    struct RewardToken {
        address token;
        uint256 totalRewards;
        uint256 distributedRewards;
    }
    
    mapping(address => RewardToken) public rewardTokens;
    EnumerableSetUpgradeable.AddressSet private rewardTokenList;
    address public podManager;
    
    // Curator-related variables
    ICuratorRegistry public curatorRegistry;
    
    // Pod-level curator-strategy approvals. Only one strategy can be approved for a pod
    address private _podApprovedStrategy;

    // Events
    event CuratorAssigned(address indexed curator, address indexed forwarder);
    event CuratorStrategyApprovedForPod(address indexed curator, address indexed strategy);
    event CuratorStrategyRemovedFromPod(address indexed curator, address indexed strategy);

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
        require(_admin != address(0), "Admin cannot be zero address");
        require(_owner != address(0), "Owner cannot be zero address");
        require(_operator != address(0), "Operator cannot be zero address");
        require(_operatorBtcPubKey.length > 0, "Operator BTC public key cannot be empty");
        require(bytes(_bitcoinAddress).length > 0, "Bitcoin address cannot be empty");
        require(params.remapBitcoin != address(0), "remapBitcoin cannot be zero address");
        require(_podManager != address(0), "PodManager cannot be zero address");
        require(_curatorRegistry != address(0), "CuratorRegistry cannot be zero");
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
            require(curatorRegistry.isCuratorActive(params.curator), "Curator not active");
            
            // Grant role to curator's forwarder
            address curatorForwarder = curatorRegistry.getCuratorInfo(params.curator).forwarder;
            _grantRole(CURATOR_ROLE, curatorForwarder);
            
            emit CuratorAssigned(params.curator, curatorForwarder);
        }

        emit PodInitialized(address(this), _owner, _operator);
    }

    // --- Access Control for BaseBitcoinPod ---
    modifier onlyManager() override {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || msg.sender == podManager,
            "Not authorized"
        );
        _;
    }

    // --- Advanced logic and overrides below ---

    // TokenHub/Delegation
    /**
     * @notice Set the TokenHub address for delegation
     * @param _tokenHub Address of the TokenHub contract
     * @dev Only callable by admin or pod manager
     */
    function setTokenHub(address _tokenHub) external override {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || msg.sender == podManager,
            "Not authorized"
        );
        require(_tokenHub != address(0), "TokenHub cannot be zero address");
        tokenHub = _tokenHub;
        emit TokenHubSet(_tokenHub);
    }

    /**
     * @notice Set the PodManager address
     * @param _podManager Address of the PodManager contract
     * @dev Only callable by admin
     */
    function setPodManager(address _podManager) external override onlyRole(ADMIN_ROLE) {
        require(_podManager != address(0), "PodManager cannot be zero address");
        podManager = _podManager;
        emit PodManagerSet(_podManager);
    }

    /**
     * @notice Set delegation status to TokenHub
     * @param _isDelegated True to delegate, false to undelegate
     * @dev Only callable by pod manager
    */
    function setDelegationStatus(bool _isDelegated) external override {
        require(msg.sender == podManager, "Only pod manager can delegate");
        require(tokenHub != address(0), "TokenHub not set");
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
        require(hasRole(CURATOR_ROLE, msg.sender), "Not curator role");
        
        // Verify this is the curator forwarder
        address curator = curatorRegistry.getCuratorByForwarder(msg.sender);
        require(curator != address(0), "Invalid forwarder");
        require(curatorRegistry.isCuratorActive(curator), "Curator not active");
        
        // Verify strategy is approved at registry level
        require(
            curatorRegistry.isStrategyApprovedForCurator(curator, strategy),
            "Strategy not approved for curator"
        );
        
        // Verify strategy is approved at pod level
        require(_podApprovedStrategy == strategy, "Strategy not approved for pod");
        _;
    }
   

     /**
     * @notice Report yield from a strategy
     * @param _amount Amount of yield
     * @dev Only callable by approved strategies or admin/curator
     */
    function reportYield(uint256 _amount) external override whenNotPaused nonReentrant {
        require(
            approvedStrategies[msg.sender] || 
            hasRole(ADMIN_ROLE, msg.sender) || 
            hasRole(CURATOR_ROLE, msg.sender), 
            "Not authorized"
        );
        require(_amount > 0, "Amount must be greater than 0");
        // update the fee manager
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
        require(
            hasRole(OWNER_ROLE, msg.sender) || hasRole(CURATOR_ROLE, msg.sender),
            "Not authorized"
        );
        require(isDelegatedToTokenHub, "Not delegated to TokenHub");
        require(_recipient != address(0), "Recipient cannot be zero address");
        //require(!isLocked(), "Pod is locked");
        uint256 shares = ITokenHub(tokenHub).mintTokensForPod(address(this), _recipient);
       // BaseBitcoinPod.lock(); // lock the pod after minting tokens
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
        require(
            hasRole(OWNER_ROLE, msg.sender) || hasRole(CURATOR_ROLE, msg.sender) || msg.sender == address(this),
            "Not authorized"
        );
        require(isDelegatedToTokenHub, "Not delegated to TokenHub");
        require(_shares > 0, "Shares must be greater than 0");
        require(_recipient != address(0), "Recipient cannot be zero address");
        if (msg.sender == address(this)) {
            require(_shares <= podShares, "Insufficient shares in pod");
            podShares -= _shares;
            emit SharesUpdated(podShares);
        }
        require(_shares == bitcoinBalance, "Shares burned do not match Bitcoin balance in pod");
        uint256 bitcoinAmount = ITokenHub(tokenHub).burnTokensForPod(address(this), _shares, _recipient);
       // BaseBitcoinPod.unlock(); // unlock the pod after burning tokens
        return bitcoinAmount;
    }

    /**
     * @notice Add a reward token
     * @param _token Address of the reward token
     * @dev Only callable by admin
     */
    function addRewardToken(address _token) external override onlyRole(ADMIN_ROLE) {
        require(_token != address(0), "Token cannot be zero address");
        require(rewardTokens[_token].token == address(0), "Token already added");
        rewardTokens[_token] = RewardToken({token: _token, totalRewards: 0, distributedRewards: 0});
        rewardTokenList.add(_token);
        emit RewardTokenAdded(_token);
    }

    /**
     * @notice Remove a reward token
     * @param _token Address of the reward token
     * @dev Only callable by admin
     */    
    function removeRewardToken(address _token) external override onlyRole(ADMIN_ROLE) {
        require(rewardTokenList.contains(_token), "Token not found");
        require(rewardTokens[_token].totalRewards == rewardTokens[_token].distributedRewards, "Rewards not fully distributed");
        
        delete rewardTokens[_token];
        rewardTokenList.remove(_token);
        emit RewardTokenRemoved(_token);
    }

    /**
     * @notice Set the rewards address for collecting rewards
     * @param _rewardsAddress Address where rewards will be sent
     * @dev Only callable by admin
     */
    function setRewardsAddress(address _rewardsAddress) external override onlyRole(ADMIN_ROLE) {
        require(_rewardsAddress != address(0), "Rewards address cannot be zero");
        rewardsAddress = _rewardsAddress;
        emit RewardsAddressSet(_rewardsAddress);
    }

     /**
     * @notice Set the rewards distributor address
     * @param _rewardsDistributor Address of the rewards distributor
     * @dev Only callable by admin
     */
    function setRewardsDistributor(address _rewardsDistributor) external override onlyRole(ADMIN_ROLE) {
        require(_rewardsDistributor != address(0), "Rewards distributor cannot be zero");
        rewardsDistributor = IRewardsDistributor(_rewardsDistributor);
        emit RewardsDistributorSet(_rewardsDistributor);
    }

    /**
     * @notice Report rewards collected by a strategy
     * @param _token Address of the reward token
     * @param _amount Amount of rewards reported
     * @dev Only callable by approved strategies
     */
    function reportRewards(address _token, uint256 _amount) external override whenNotPaused nonReentrant {
        require(approvedStrategies[msg.sender], "Not an approved strategy");
        require(rewardTokens[_token].token != address(0), "Token not supported");
        require(_amount > 0, "Amount must be greater than 0");
        require(rewardsAddress != address(0), "Rewards address not set");
        require(address(rewardsDistributor) != address(0), "Rewards distributor not set");
        rewardTokens[_token].totalRewards += _amount;
        IERC20Upgradeable(_token).safeTransferFrom(msg.sender, rewardsAddress, _amount);
        emit YieldReported(_amount);
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
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(OPERATOR_ROLE, msg.sender),
            "Not authorized"
        );
        require(rewardTokens[_token].token != address(0), "Token not supported");
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= rewardTokens[_token].totalRewards - rewardTokens[_token].distributedRewards, "Insufficient rewards");
        require(rewardsAddress != address(0), "Rewards address not set");
        require(address(rewardsDistributor) != address(0), "Rewards distributor not set");
        require(_merkleRoot != bytes32(0) || _airdropAddress != address(0), "Must specify either Merkle root or airdrop address");
        rewardTokens[_token].distributedRewards += _amount;
        IERC20Upgradeable(_token).safeTransferFrom(rewardsAddress, address(rewardsDistributor), _amount);
        rewardsDistributor.notifyRewards(_token, _amount, _merkleRoot, _airdropAddress);
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
        RewardToken memory rewardToken = rewardTokens[_token];
        return (rewardToken.token, rewardToken.totalRewards, rewardToken.distributedRewards);
    }
    
    /**
     * @notice Get list of reward tokens
     * @return List of reward token addresses
     */
    function getRewardTokenList() external view override returns (address[] memory) {
        uint256 length = rewardTokenList.length();
        address[] memory tokens = new address[](length);
    
        for (uint256 i = 0; i < length; i++) {
            tokens[i] = rewardTokenList.at(i);
        }
    
        return tokens;
    }

    // Recovery
      /**
     * @notice Recover ERC20 tokens
     * @param _token Address of the token
     * @param _to Address to send the tokens to
     * @param _amount Amount of tokens to recover
     * @dev Only callable by admin
     */
    function recoverERC20(address _token, address _to, uint256 _amount) external override onlyRole(ADMIN_ROLE) {
        require(_to != address(0), "Cannot recover to zero address");
        require(_amount > 0, "Amount must be greater than 0");
        if (_token == address(reBTC)) {
            require(paused(), "Must be paused to recover reBTC");
        }
        IERC20Upgradeable(_token).safeTransfer(_to, _amount);
        emit ERC20Recovered(_token, _to, _amount);
    }
    
   /**
    * @notice Recover ERC721 tokens from the pod
    * @param _token Address of the ERC721 token contract
    * @param _to Address to send the recovered token to
    * @param _tokenId ID of the token to recover
    * @dev Only callable by admin
    * @dev Emits ERC721Recovered event on successful recovery
    */
    function recoverERC721(address _token, address _to, uint256 _tokenId) external override onlyRole(ADMIN_ROLE) {
        require(_to != address(0), "Cannot recover to zero address");
        IERC721Upgradeable(_token).safeTransferFrom(address(this), _to, _tokenId);
        emit ERC721Recovered(_token, _to, _tokenId);
    }

    // Pause
    /**
     * @notice Pause the pod
     * @dev Only callable by admin
     * @dev Pausing prevents any state-modifying actions
     */
    function pause() external override onlyRole(ADMIN_ROLE) {
        _pause();
    }
    // Unpause
    /**
     * @notice Unpause the pod
     * @dev Only callable by admin
     */
    function unpause() external override onlyRole(ADMIN_ROLE) {
        _unpause();
    }

     /**
     * @notice ERC721 receiver function
     * @dev Required for ERC721 token recovery
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
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
    function approveCuratorStrategyForPod(address strategy) external {
        require(
            hasRole(OWNER_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        
        address assignedCurator = this.getAssignedCurator();
        require(assignedCurator != address(0), "No curator assigned");
        require(strategy != address(0), "Strategy cannot be zero");
        require(
            curatorRegistry.isStrategyApprovedForCurator(assignedCurator, strategy),
            "Strategy not approved for curator in registry"
        );
        require(_podApprovedStrategy != strategy, "Strategy already approved for pod");

        _podApprovedStrategy = strategy;

        emit CuratorStrategyApprovedForPod(assignedCurator, strategy);
    }

    /**
     * @notice Remove approval for a curator-strategy combination from this pod
     * @param strategy Address of the strategy
     */
    function removeCuratorStrategyFromPod(address strategy) external {
        require(
            hasRole(OWNER_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        require(_podApprovedStrategy == strategy, "Strategy not approved for pod");

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
        require(msg.sender == podManager, "Only pod manager can set curator");
        require(_curator != address(0), "Curator cannot be zero address");
        require(curatorRegistry.isCuratorActive(_curator), "Curator not active");
        
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
     * @notice Transfer funds to an approved strategy
     * @param strategy Address of the strategy
     * @param amount Amount to transfer
     */
    function transferToStrategy(address strategy, uint256 amount) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
        onlyAuthorizedCuratorForStrategy(strategy)
    {
        require(amount > 0, "Amount must be greater than 0");
        
        reBTC.safeTransfer(strategy, amount);
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

        
     // --- Storage gap for upgradeability ---
    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[50] private __gap;
}