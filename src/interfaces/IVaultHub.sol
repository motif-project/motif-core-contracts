// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IVaultHub {
    function registerVault(
        address _vault,
        address _owner,
        uint256 _shareLimit,
        uint16 _rebalanceThresholdBP,
        uint16 _treasuryFeeBP
    ) external;

    function updateVaultShares(address _vault, uint256 _newShares) external;

    function disconnectVault(address _vault) external;

    function getVaults() external view returns (address[] memory);
}

