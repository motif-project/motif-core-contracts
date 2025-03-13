// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IBitcoinPodManager.sol";
import "./interfaces/IAppRegistry.sol";
import "./Permissions.sol";
import "./reBTC.sol";
import "./interfaces/IVault.sol";

contract Vault is Ownable, Pausable, AccessControl, IVault {
    using SafeMath for uint256;

    reBTC public remappedBTC;
    IBitcoinPodManager public bitcoinPodManager;
    IAppRegistry public appRegistry;
    Permissions public permissionsContract;
    
    bytes32 public constant CURATOR_ROLE = keccak256("CURATOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINT_ROLE = keccak256("MINT_ROLE");
    bytes32 public constant BURN_ROLE = keccak256("BURN_ROLE");

    struct VaultSocket {
        address owner;
        address curator;
        uint256 sharesMinted;
        uint256 shareLimit;
        uint16 rebalanceThresholdBP;
        uint16 treasuryFeeBP;
        bool pendingDisconnect;
    }

    mapping(address => VaultSocket) public vaults;
    mapping(address => uint256) public shares;

    event BitcoinPodLocked(address indexed user, uint256 amount);
    event SharesMinted(address indexed vaultOwner, uint256 amount);
    event SharesBurned(address indexed vaultOwner, uint256 amount);
    event SharesRedeemedForBTC(address indexed vaultOwner, uint256 amount);
    event reBTCMinted(address indexed user, uint256 amount);
    event reBTCBurned(address indexed user, uint256 amount);
    event CuratorAssigned(address indexed curator, address indexed vaultOwner);
    event VaultConnected(address indexed vaultOwner);
    event VaultRebalanced(address indexed vaultOwner, uint256 sharesBurned);
    event VaultWithdrawn(address indexed vaultOwner, uint256 amount);

    constructor(
        address _reBTC,
        address _bitcoinPodManager,
        address _appRegistry,
        address _permissions
    ) {
        remappedBTC = reBTC(_reBTC);
        bitcoinPodManager = IBitcoinPodManager(_bitcoinPodManager);
        appRegistry = IAppRegistry(_appRegistry);
        permissionsContract = Permissions(_permissions);
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    function assignCurator(address _vaultOwner, address _curator) external override onlyRole(ADMIN_ROLE) {
        require(_vaultOwner != address(0), "Invalid vault owner");
        require(_curator != address(0), "Invalid curator address");
        vaults[_vaultOwner].curator = _curator;
        _grantRole(CURATOR_ROLE, _curator);
        emit CuratorAssigned(_curator, _vaultOwner);
    }

    function mintReBTC(address user, uint256 amount) external override onlyRole(MINT_ROLE) {
        remappedBTC.mint(user, amount);
        mintShares(user, amount);
        emit reBTCMinted(user, amount);
    }

    function burnReBTC(address user, uint256 amount) external override onlyRole(BURN_ROLE) {
        remappedBTC.burn(user, amount);
        burnShares(user, amount);
        emit reBTCBurned(user, amount);
    }

    function mintShares(address _vaultOwner, uint256 amount) public override onlyRole(ADMIN_ROLE) {
        require(_vaultOwner != address(0), "Invalid vault owner");
        require(amount > 0, "Amount must be greater than zero");

        vaults[_vaultOwner].sharesMinted = vaults[_vaultOwner].sharesMinted.add(amount);
        shares[_vaultOwner] = shares[_vaultOwner].add(amount);

        emit SharesMinted(_vaultOwner, amount);
    }

    function burnShares(address _vaultOwner, uint256 amount) public override onlyRole(ADMIN_ROLE) {
        require(_vaultOwner != address(0), "Invalid vault owner");
        require(shares[_vaultOwner] >= amount, "Not enough shares to burn");

        vaults[_vaultOwner].sharesMinted = vaults[_vaultOwner].sharesMinted.sub(amount);
        shares[_vaultOwner] = shares[_vaultOwner].sub(amount);

        emit SharesBurned(_vaultOwner, amount);
    }

    function redeemSharesForBTC(address _vaultOwner, uint256 amount) external override onlyRole(ADMIN_ROLE) {
        require(_vaultOwner != address(0), "Invalid vault owner");
        require(shares[_vaultOwner] >= amount, "Not enough shares to redeem");

        burnShares(_vaultOwner, amount);
        remappedBTC.mint(_vaultOwner, amount); // Convert shares back to reBTC

        emit SharesRedeemedForBTC(_vaultOwner, amount);
    }

    function rebalanceVault(address _vaultOwner, uint256 amount) external override onlyRole(CURATOR_ROLE) {
        require(vaults[_vaultOwner].owner != address(0), "Vault not found");
        require(amount > 0, "Amount must be greater than zero");

        remappedBTC.burn(_vaultOwner, amount);
        emit VaultRebalanced(_vaultOwner, amount);
    }
}