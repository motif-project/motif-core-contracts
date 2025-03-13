// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Vault.sol";
import "./VaultHub.sol";

/**
 * @title Permissions for Motif Vaults
 * @notice Manages access control for vault operations (minting, burning, rebalancing)
 */
contract Permissions is AccessControl {
    bytes32 public constant CURATOR_ROLE = keccak256("CURATOR_ROLE");
    bytes32 public constant MINT_ROLE = keccak256("MINT_ROLE");
    bytes32 public constant BURN_ROLE = keccak256("BURN_ROLE");
    bytes32 public constant REBALANCE_ROLE = keccak256("REBALANCE_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    VaultHub public vaultHub;

    constructor(address _vaultHub) {
        require(_vaultHub != address(0), "Invalid VaultHub address");
        vaultHub = VaultHub(_vaultHub);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Assigns curator role to manage reBTC in a vault.
     */
    function assignCurator(address _vault, address _curator) external onlyRole(ADMIN_ROLE) {
        require(_vault != address(0), "Invalid vault");
        require(_curator != address(0), "Invalid curator");

        _grantRole(CURATOR_ROLE, _curator);
    }

    /**
     * @notice Grants permission to mint reBTC.
     */
    function grantMinting(address _account) external onlyRole(ADMIN_ROLE) {
        _grantRole(MINT_ROLE, _account);
    }

    /**
     * @notice Grants permission to burn reBTC.
     */
    function grantBurning(address _account) external onlyRole(ADMIN_ROLE) {
        _grantRole(BURN_ROLE, _account);
    }

    /**
     * @notice Grants permission to rebalance vault assets.
     */
    function grantRebalancing(address _account) external onlyRole(ADMIN_ROLE) {
        _grantRole(REBALANCE_ROLE, _account);
    }

    /**
     * @notice Curators can rebalance a vault, but only with the assigned permissions.
     */
    function rebalanceVault(address _vault, uint256 _amount) external onlyRole(REBALANCE_ROLE) {
        vaultHub.rebalanceVault(_vault, _amount);
    }

    /**
     * @notice Mints reBTC for a vault.
     */
    function mintReBTC(address _vault, uint256 _amount) external onlyRole(MINT_ROLE) {
        vaultHub.mintShares(_vault, _amount);
    }

    /**
     * @notice Burns reBTC from a vault.
     */
    function burnReBTC(address _vault, uint256 _amount) external onlyRole(BURN_ROLE) {
        vaultHub.burnShares(_vault, _amount);
    }
}
