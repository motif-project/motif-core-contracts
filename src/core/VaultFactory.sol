// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./Vault.sol";
import "./VaultHub.sol";
import "./Permissions.sol";

contract VaultFactory {
    VaultHub public vaultHub;
    Permissions public permissionsContract;

    event VaultCreated(address indexed vault, address indexed owner);

    constructor(address _vaultHub, address _permissions) {
        require(_vaultHub != address(0), "Invalid VaultHub address");
        require(_permissions != address(0), "Invalid Permissions contract");

        vaultHub = VaultHub(_vaultHub);
        permissionsContract = Permissions(_permissions);
    }

    function createVault(
        address _owner,
        uint256 _shareLimit,
        uint16 _rebalanceThresholdBP,
        uint16 _treasuryFeeBP
    ) external returns (address) {
        require(permissionsContract.hasRole(permissionsContract.ADMIN_ROLE(), msg.sender), "Not an admin");

        Vault newVault = new Vault(_owner);
        vaultHub.registerVault(
            address(newVault),
            _owner,
            _shareLimit,
            _rebalanceThresholdBP,
            _treasuryFeeBP
        );

        // Mint initial shares to vault owner upon creation
        newVault.mintShares(_owner, _shareLimit);

        emit VaultCreated(address(newVault), _owner);
        return address(newVault);
    }
}