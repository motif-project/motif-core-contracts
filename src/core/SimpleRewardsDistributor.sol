// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../interfaces/IRewardsDistributor.sol";

/**
 * @title SimpleRewardsDistributor
 * @notice A simple placeholder implementation of rewards distribution
 * @dev This is a temporary implementation that will be replaced with a more sophisticated one
 */
contract SimpleRewardsDistributor is Initializable, IRewardsDistributor {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    
    // Events
    event RewardsReceived(address indexed token, uint256 amount);
    event RewardsDistributed(address indexed token, address indexed recipient, uint256 amount);
    
    /**
     * @notice Initialize the contract
     */
    function initialize() external initializer {
        // No initialization needed for now
    }
    
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
    ) external override {
        require(_token != address(0), "Token cannot be zero address");
        require(_amount > 0, "Amount must be greater than 0");
        
        emit RewardsReceived(_token, _amount);
        
        // If airdrop address is provided, send rewards directly
        if (_airdropAddress != address(0)) {
            IERC20Upgradeable(_token).safeTransfer(_airdropAddress, _amount);
            emit RewardsDistributed(_token, _airdropAddress, _amount);
        }
        // If Merkle root is provided, keep rewards in contract for future claims
        // This will be implemented in the full version
        else if (_merkleRoot != bytes32(0)) {
            // Store rewards for future claims
            // This will be implemented in the full version
        }
    }
    
    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[50] private __gap;
} 