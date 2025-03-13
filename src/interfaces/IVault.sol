// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IVault {
    function assignCurator(address _vaultOwner, address _curator) external;
    function mintReBTC(address user, uint256 amount) external;
    function burnReBTC(address user, uint256 amount) external;
    function mintShares(address _vaultOwner, uint256 amount) external;
    function burnShares(address _vaultOwner, uint256 amount) external;
    function rebalanceVault(address _vaultOwner, uint256 amount) external;
    function redeemSharesForBTC(address _vaultOwner, uint256 amount) external;
    
    event CuratorAssigned(address indexed curator, address indexed vaultOwner);
    event reBTCMinted(address indexed user, uint256 amount);
    event reBTCBurned(address indexed user, uint256 amount);
    event SharesMinted(address indexed vaultOwner, uint256 amount);
    event SharesBurned(address indexed vaultOwner, uint256 amount);
    event SharesRedeemedForBTC(address indexed vaultOwner, uint256 amount);
    event VaultRebalanced(address indexed vaultOwner, uint256 sharesBurned);
}
