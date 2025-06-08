// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./IBitcoinPod.sol";

// Add the struct to IEnhancedBitcoinPod
struct EnhancedPodParams {
    address curator;
    uint256 operatorFeeBP;
    uint256 curatorFeeBP;
    uint256 protocolFeeBP;
    address protocolFeeRecipient;
    address remapBitcoin;
    address tokenHub;
}

interface IEnhancedBitcoinPod is IBitcoinPod {
    // ========== CUSTOM ERRORS ==========
    // Input validation errors
    error ZeroAddress();
    error EmptyBTCPubKeyString();
    error EmptyBTCAddressString();
    error ZeroAmount();
    
    // Authorization errors
    error NotPodManager();
    error NotAuthorized();
    error InvalidOwner();
    error InvalidCuratorRole();
    error NoCuratorAssigned();

    
    // State validation errors
    error CuratorNotActive();
    error StrategyNotApproved();
    error StrategyAlreadyApproved();
    error RemapTokenNotSet();
    error TokenHubNotSet();
    error NotDelegatedToTokenHub();
    error PodManagerNotSet();
    error CuratorRegistryNotSet();
    error RewardsAddressNotSet();
    error RewardsDistributorNotSet();
    
    // Operation errors
    error ContractPaused();
    error ContractNotPaused();
    error InsufficientBalance();
    error InsufficientShares();
    error SharesMismatch();

    // ========== EVENTS ==========
    // TokenHub/Delegation events
    event TokenHubSet(address indexed tokenHub);
    event PodManagerSet(address indexed podManager);
    event TokenHubDelegated(address indexed tokenHub);
    event TokenHubUndelegated();
    
    // Token/Shares events
    event SharesUpdated(uint256 newShares);
    event TokensTransferred(address indexed to, uint256 amount);
    event BitcoinBalanceUpdated(uint256 newBalance);
    
    // Strategy events
    event StrategyApproved(address indexed strategy, bool approved);
    event CuratorAssigned(address indexed curator, address indexed forwarder);
    event CuratorStrategyApprovedForPod(address indexed curator, address indexed strategy);
    event CuratorStrategyRemovedFromPod(address indexed curator, address indexed strategy);
    
    // Rewards events
    event YieldReported(uint256 amount);
    event RewardsReported(address indexed token, uint256 amount);
    event RewardTokenAdded(address indexed token);
    event RewardTokenRemoved(address indexed token);
    event RewardsDistributed(address indexed token, uint256 amount);
    event RewardsAddressSet(address indexed rewardsAddress);
    event RewardsDistributorSet(address indexed rewardsDistributor);

    // ========== FUNCTIONS ==========
    // TokenHub/Delegation
    function setTokenHub(address _tokenHub) external;
    function setPodManager(address _podManager) external;
    function setDelegationStatus(bool _isDelegated) external;

    // Strategies
    function approveCuratorStrategyForPod(address strategy) external;
    function transferToStrategy(address _strategy, uint256 _amount) external;

    // Token mint/burn via TokenHub
    function mintTokens(address _recipient) external returns (uint256);
    function burnTokens(uint256 _shares, address _recipient) external returns (uint256);

    // Rewards
    function addRewardToken(address _token) external;
    function removeRewardToken(address _token) external;
    function setRewardsAddress(address _rewardsAddress) external;
    function setRewardsDistributor(address _rewardsDistributor) external;
    function reportRewards(address _token, uint256 _amount) external;
    function reportYield(uint256 _amount) external;
    function notifyRewards(address _token, uint256 _amount, bytes32 _merkleRoot, address _airdropAddress) external;
    function getRewardTokenInfo(address _token) external view returns (
        address token,
        uint256 totalRewards,
        uint256 distributedRewards
    );
    function getRewardTokenList() external view returns (address[] memory);

    // Control functions
    function pause() external;
    function unpause() external;

    // Initialization
    function initialize(
        address admin,
        address owner,
        address operator,
        bytes memory operatorBtcPubKey,
        string memory bitcoinAddress,
        address podManager,
        address curatorRegistry,
        EnhancedPodParams calldata params
    ) external;
}