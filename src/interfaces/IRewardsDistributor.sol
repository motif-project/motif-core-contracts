// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title IRewardsDistributor
 * @notice Interface for rewards distribution
 */
interface IRewardsDistributor {
    /**
     * @notice Notify about new rewards to be distributed
     * @param _token Address of the reward token
     * @param _amount Amount of rewards
     * @param _merkleRoot Root of the Merkle tree for claim process (optional)
     * @param _airdropAddress Address to receive airdrop (optional)
     */
    function notifyRewards(
        address _token,
        uint256 _amount,
        bytes32 _merkleRoot,
        address _airdropAddress
    ) external;
} 