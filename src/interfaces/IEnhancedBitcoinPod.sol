// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./IBitcoinPod.sol";

interface IEnhancedBitcoinPod is IBitcoinPod {
    // TokenHub/Delegation
    function setTokenHub(address _tokenHub) external;
    function setPodManager(address _podManager) external;
    function setDelegationStatus(bool _isDelegated) external;

    // Strategies
    function approveStrategy(address _strategy, bool _approved) external;
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

    // Recovery
    function recoverERC20(address _token, address _to, uint256 _amount) external;
    function recoverERC721(address _token, address _to, uint256 _tokenId) external;

    // Pause
    function pause() external;
    function unpause() external;

    // Events (optional, for completeness)
    event TokenHubSet(address tokenHub);
    event PodManagerSet(address podManager);
    event TokenHubDelegated(address tokenHub);
    event TokenHubUndelegated();
    event SharesUpdated(uint256 newShares);
    event TokensTransferred(address indexed to, uint256 amount);
    event StrategyApproved(address indexed strategy, bool approved);
    event YieldReported(uint256 amount);
    event BitcoinBalanceUpdated(uint256 newBalance);
    event ERC20Recovered(address indexed token, address indexed to, uint256 amount);
    event ERC721Recovered(address indexed token, address indexed to, uint256 tokenId);
    event RewardTokenAdded(address indexed token);
    event RewardTokenRemoved(address indexed token);
    event RewardsDistributed(address indexed token, uint256 amount);
    event RewardsAddressSet(address indexed rewardsAddress);
    event RewardsDistributorSet(address indexed rewardsDistributor);
}