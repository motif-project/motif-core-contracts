// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface ITokenHub {
    struct VaultSocket {
        uint96 shareLimit;      // Maximum shares this vault can mint
        uint96 sharesMinted;    // Current shares minted by this vault
        uint16 reserveRatioBP;  // Reserve ratio in basis points (e.g., 1000 = 10%)
        uint16 treasuryFeeBP;   // Fee taken on rewards in basis points
        bool isActive;          // Whether the vault is active
    }
    
    function mintTokensForPod(address _podAddress, uint256 _bitcoinAmount, address _recipient) external returns (uint256);
    function burnTokensForPod(address _podAddress, uint256 _shares, address _owner) external returns (uint256);
    function vaultSocket(address _vault) external view returns (VaultSocket memory);
    function isPodDelegated(address _podAddress) external view returns (bool);
    function podToVault(address _podAddress) external view returns (address);
}