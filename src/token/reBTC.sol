// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title ReBTC - Rebasing token backed by Bitcoin deposits
 * @notice Clean implementation using OpenZeppelin ERC20Permit and share-based accounting
 */
contract ReBTC is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant REBASER_ROLE = keccak256("REBASER_ROLE");

    uint256 private _totalShares;
    mapping(address => uint256) private _shares;

    uint256 private _totalPooledBTC; // Total BTC backing the shares

    uint256 public constant MAX_REBASE_INCREASE = 1000; // 10%
    uint256 public constant MAX_REBASE_DECREASE = 1000; // 10%

    event TotalPooledBTCUpdated(uint256 newTotal); // Emitted on rebase

    function initialize(
        string memory name_,
        string memory symbol_,
        address admin_,
        address operator_,
        address rebaser_
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __ERC20Permit_init(name_);
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(OPERATOR_ROLE, operator_);
        _grantRole(REBASER_ROLE, rebaser_);
    }

    // ========================= Core Logic =========================

    function totalSupply() public view override returns (uint256) {
        return _totalPooledBTC;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_totalShares == 0) return 0;
        return (_shares[account] * _totalPooledBTC) / _totalShares;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transferShares(msg.sender, recipient, _btcToShares(amount));
        return true;
    }

    function _transfer(address sender, address recipient, uint256) internal pure override {
        // Disable base ERC20 logic since we override transfer
        revert("Use _transferShares instead");
    }

    function _transferShares(address sender, address recipient, uint256 shareAmount) internal {
        require(sender != address(0) && recipient != address(0), "Zero address");
        _shares[sender] -= shareAmount;
        _shares[recipient] += shareAmount;
        emit Transfer(sender, recipient, (_totalPooledBTC * shareAmount) / _totalShares);
    }

    function mint(address account, uint256 btcAmount) external onlyRole(OPERATOR_ROLE) whenNotPaused {
        uint256 sharesToMint = _btcToShares(btcAmount);
        _totalShares += sharesToMint;
        _shares[account] += sharesToMint;
        _totalPooledBTC += btcAmount;
        emit Transfer(address(0), account, btcAmount);
    }

    function burn(address account, uint256 btcAmount) external onlyRole(OPERATOR_ROLE) whenNotPaused {
        uint256 sharesToBurn = _btcToShares(btcAmount);
        _shares[account] -= sharesToBurn;
        _totalShares -= sharesToBurn;
        _totalPooledBTC -= btcAmount;
        emit Transfer(account, address(0), btcAmount);
    }

    function updateTotalPooledBTC(uint256 newTotal) external onlyRole(REBASER_ROLE) whenNotPaused {
        require(newTotal > 0, "Invalid BTC total");
        
        // Rate limiting
        if (newTotal > _totalPooledBTC) {
            require(
                newTotal <= _totalPooledBTC * (10000 + MAX_REBASE_INCREASE) / 10000,
                "Rebase increase too large"
            );
        } else {
            require(
                newTotal >= _totalPooledBTC * (10000 - MAX_REBASE_DECREASE) / 10000,
                "Rebase decrease too large"
            );
        }
        
        _totalPooledBTC = newTotal;
        emit TotalPooledBTCUpdated(newTotal);
    }

    // ========================= View Helpers =========================

    function getShares(address account) external view returns (uint256) {
        return _shares[account];
    }

    function getTotalShares() external view returns (uint256) {
        return _totalShares;
    }

    function getExchangeRate() external view returns (uint256) {
        return _totalShares == 0 ? 1e18 : (_totalPooledBTC * 1e18) / _totalShares;
    }

    function _btcToShares(uint256 btcAmount) internal view returns (uint256) {
        return (_totalShares == 0 || _totalPooledBTC == 0)
            ? btcAmount
            : (btcAmount * _totalShares) / _totalPooledBTC;
    }

    // ========================= Additional Functions =========================

    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    mapping(address => bool) private _blacklisted;

    function blacklist(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _blacklisted[account] = true;
    }

    modifier whenNotBlacklisted(address account) {
        require(!_blacklisted[account], "Account is blacklisted");
        _;
    }
}
