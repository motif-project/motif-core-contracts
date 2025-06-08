// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "../interfaces/IRewardsDistributor.sol";

/**
 * @title PodRewardsLibrary
 * @notice Pure library for managing reward tokens in Bitcoin pods
 * @dev Handles reward token registration, reporting, and distribution logic
 */
library PodRewardsLibrary {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    // Reward token structure
    struct RewardToken {
        address token;
        uint256 totalRewards;
        uint256 distributedRewards;
    }

    // Custom errors for gas efficiency
    error TokenAlreadyAdded();
    error TokenNotFound();
    error RewardsNotFullyDistributed();
    error ZeroAmount();
    error InsufficientRewards();
    error RewardsAddressNotSet();
    error RewardsDistributorNotSet();
    error InvalidMerkleProof();

    /**
     * @notice Add a new reward token
     * @param rewardTokens Storage reference to reward tokens mapping
     * @param rewardTokenList Storage reference to reward token list
     * @param token Address of the token to add
     */
    function addRewardToken(
        mapping(address => RewardToken) storage rewardTokens,
        EnumerableSetUpgradeable.AddressSet storage rewardTokenList,
        address token
    ) internal {
        if (token == address(0)) revert TokenNotFound();
        if (rewardTokens[token].token != address(0)) revert TokenAlreadyAdded();
        
        rewardTokens[token] = RewardToken({
            token: token,
            totalRewards: 0,
            distributedRewards: 0
        });
        
        rewardTokenList.add(token);
    }

    /**
     * @notice Remove a reward token
     * @param rewardTokens Storage reference to reward tokens mapping
     * @param rewardTokenList Storage reference to reward token list
     * @param token Address of the token to remove
     */
    function removeRewardToken(
        mapping(address => RewardToken) storage rewardTokens,
        EnumerableSetUpgradeable.AddressSet storage rewardTokenList,
        address token
    ) internal {
        if (!rewardTokenList.contains(token)) revert TokenNotFound();
        
        RewardToken storage rewardToken = rewardTokens[token];
        if (rewardToken.totalRewards != rewardToken.distributedRewards) {
            revert RewardsNotFullyDistributed();
        }
        
        delete rewardTokens[token];
        rewardTokenList.remove(token);
    }

    /**
     * @notice Report rewards collected by a strategy
     * @param rewardTokens Storage reference to reward tokens mapping
     * @param token Address of the reward token
     * @param amount Amount of rewards reported
     * @param rewardsAddress Address where rewards should be transferred
     */
    function reportRewards(
        mapping(address => RewardToken) storage rewardTokens,
        address token,
        uint256 amount,
        address rewardsAddress
    ) internal {
        if (rewardTokens[token].token == address(0)) revert TokenNotFound();
        if (amount == 0) revert ZeroAmount();
        if (rewardsAddress == address(0)) revert RewardsAddressNotSet();
        
        rewardTokens[token].totalRewards += amount;
        
        // Transfer from strategy to rewards address
        IERC20Upgradeable(token).safeTransferFrom(msg.sender, rewardsAddress, amount);
    }

    /**
     * @notice Notify rewards distributor about new rewards
     * @param rewardTokens Storage reference to reward tokens mapping
     * @param token Address of the reward token
     * @param amount Amount of rewards to distribute
     * @param rewardsAddress Address where rewards are stored
     * @param rewardsDistributor Rewards distributor contract
     * @param merkleRoot Root of the Merkle tree for claim process (optional)
     * @param airdropAddress Address to receive airdrop (optional)
     */
    function notifyRewards(
        mapping(address => RewardToken) storage rewardTokens,
        address token,
        uint256 amount,
        address rewardsAddress,
        IRewardsDistributor rewardsDistributor,
        bytes32 merkleRoot,
        address airdropAddress
    ) internal {
        if (rewardTokens[token].token == address(0)) revert TokenNotFound();
        if (amount == 0) revert ZeroAmount();
        if (rewardsAddress == address(0)) revert RewardsAddressNotSet();
        if (address(rewardsDistributor) == address(0)) revert RewardsDistributorNotSet();
        
        RewardToken storage rewardToken = rewardTokens[token];
        uint256 availableRewards = rewardToken.totalRewards - rewardToken.distributedRewards;
        if (amount > availableRewards) revert InsufficientRewards();
        
        // Validate that either merkle root or airdrop address is provided
        if (merkleRoot == bytes32(0) && airdropAddress == address(0)) {
            revert InvalidMerkleProof();
        }
        
        // Update distributed amount
        rewardToken.distributedRewards += amount;
        
        // Transfer to rewards distributor
        IERC20Upgradeable(token).safeTransferFrom(
            rewardsAddress, 
            address(rewardsDistributor), 
            amount
        );
        
        // Notify distributor
        rewardsDistributor.notifyRewards(token, amount, merkleRoot, airdropAddress);
    }

    /**
     * @notice Get reward token information
     * @param rewardTokens Storage reference to reward tokens mapping
     * @param token Address of the reward token
     * @return rewardToken The reward token information
     */
    function getRewardTokenInfo(
        mapping(address => RewardToken) storage rewardTokens,
        address token
    ) internal view returns (RewardToken memory rewardToken) {
        return rewardTokens[token];
    }

    /**
     * @notice Get list of all reward tokens
     * @param rewardTokenList Storage reference to reward token list
     * @return tokens Array of reward token addresses
     */
    function getRewardTokenList(
        EnumerableSetUpgradeable.AddressSet storage rewardTokenList
    ) internal view returns (address[] memory tokens) {
        uint256 length = rewardTokenList.length();
        tokens = new address[](length);
        
        for (uint256 i = 0; i < length; i++) {
            tokens[i] = rewardTokenList.at(i);
        }
        
        return tokens;
    }

    /**
     * @notice Get available rewards for distribution
     * @param rewardTokens Storage reference to reward tokens mapping
     * @param token Address of the reward token
     * @return availableRewards Amount of rewards available for distribution
     */
    function getAvailableRewards(
        mapping(address => RewardToken) storage rewardTokens,
        address token
    ) internal view returns (uint256 availableRewards) {
        RewardToken storage rewardToken = rewardTokens[token];
        return rewardToken.totalRewards - rewardToken.distributedRewards;
    }

    /**
     * @notice Check if a token is supported for rewards
     * @param rewardTokens Storage reference to reward tokens mapping
     * @param token Address of the token to check
     * @return isSupported True if token is supported
     */
    function isTokenSupported(
        mapping(address => RewardToken) storage rewardTokens,
        address token
    ) internal view returns (bool isSupported) {
        return rewardTokens[token].token != address(0);
    }

    /**
     * @notice Get total number of reward tokens
     * @param rewardTokenList Storage reference to reward token list
     * @return count Total number of reward tokens
     */
    function getRewardTokenCount(
        EnumerableSetUpgradeable.AddressSet storage rewardTokenList
    ) internal view returns (uint256 count) {
        return rewardTokenList.length();
    }
}