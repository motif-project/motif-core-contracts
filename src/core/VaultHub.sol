// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IVaultHub.sol";
import "./Vault.sol";
import "./Permissions.sol";

contract VaultHub is Ownable, Pausable, IVaultHub {
    using SafeMath for uint256;

    Permissions public permissionsContract;

    struct VaultInfo {
        address vaultAddress;
        address owner;
        uint256 sharesMinted;
        uint256 shareLimit;
        uint16 rebalanceThresholdBP;
        uint16 treasuryFeeBP;
        bool active;
    }

    mapping(address => VaultInfo) public vaults;
    address[] public allVaults;

    event VaultRegistered(address indexed vault, address indexed owner);
    event VaultUpdated(address indexed vault, uint256 sharesMinted);
    event VaultDisconnected(address indexed vault);

    constructor(address _permissions) {
        require(_permissions != address(0), "Invalid Permissions contract");
        permissionsContract = Permissions(_permissions);
    }

    function registerVault(
        address _vault,
        address _owner,
        uint256 _shareLimit,
        uint16 _rebalanceThresholdBP,
        uint16 _treasuryFeeBP
    ) external onlyOwner {
        require(permissionsContract.hasRole(permissionsContract.ADMIN_ROLE(), msg.sender), "Not an admin");
        require(_vault != address(0), "Invalid vault address");
        require(vaults[_vault].vaultAddress == address(0), "Vault already registered");

        vaults[_vault] = VaultInfo({
            vaultAddress: _vault,
            owner: _owner,
            sharesMinted: 0,
            shareLimit: _shareLimit,
            rebalanceThresholdBP: _rebalanceThresholdBP,
            treasuryFeeBP: _treasuryFeeBP,
            active: true
        });

        allVaults.push(_vault);
        emit VaultRegistered(_vault, _owner);
    }

    function updateVaultShares(address _vault, uint256 _newShares) external onlyOwner {
        require(vaults[_vault].vaultAddress != address(0), "Vault not registered");
        vaults[_vault].sharesMinted = _newShares;
        emit VaultUpdated(_vault, _newShares);
    }

    function disconnectVault(address _vault) external onlyOwner {
        require(vaults[_vault].vaultAddress != address(0), "Vault not registered");
        vaults[_vault].active = false;
        emit VaultDisconnected(_vault);
    }

    function getVaults() external view returns (address[] memory) {
        return allVaults;
    }
}
