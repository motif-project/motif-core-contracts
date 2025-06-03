// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
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
    bytes32 public constant TOKENHUB_ROLE = keccak256("TOKENHUB_ROLE");
    bytes32 public constant REBASER_ROLE = keccak256("REBASER_ROLE");

    uint256 private _totalShares;
    mapping(address => uint256) private _shares;

    uint256 private _totalPooledBTC; // Total BTC backing the shares
    bool private _bootstrapped;

    uint256 public constant MAX_REBASE_INCREASE = 1000; // 10%
    uint256 public constant MAX_REBASE_DECREASE = 1000; // 10%

    event TotalPooledBTCUpdated(uint256 newTotal); // Emitted on rebase

    function initialize(
        address admin_
    ) public initializer {
        __ERC20_init("Remap BTC", "reBTC");
        __ERC20Permit_init("Remap BTC");
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        // TokenHub and ebaser roles shall be setup at the time of deployment or
        // after the deployment of the token hub and rebaser contracts
        // Mint and Burn will only work if you have the TOKENHUB_ROLE and REBASER_ROLE defined
        //_grantRole(TOKENHUB_ROLE, tokenhub_);
        //_grantRole(REBASER_ROLE, rebaser_);
        _bootstrapped = false;
    }

    // ========================= Core Logic =========================

    /*
    * @notice Total supply function to get the total supply of the token
    * @dev This function is overridden to return the total pooled BTC scaled to 18 decimal precision
    * @return The total supply of the token
    */  
    function totalSupply() public view override returns (uint256) {
        return _totalPooledBTC;
    }

    /*
    * @notice Balance of function to get the balance of an address
    * @dev This function is overridden to return the balance of an address in amount of reBTC
    * @param account The address to get the balance of
    * @return The balance of the address in amount of reBTC
    */
    function balanceOf(address account) public view override returns (uint256) {
        if (_totalShares == 0) return 0;
        return (_shares[account] * _totalPooledBTC) / _totalShares;
    }

    /*
    * @notice Transfer function to transfer tokens
    * @dev This function is overridden to transfer tokens using shares
    * @param recipient The address to transfer the tokens to
    * @param amount The amount of tokens to transfer
    * @return True if the transfer was successful
    */
    function transfer(address recipient, uint256 amount) 
        public 
        override 
        whenNotPaused
        whenNotBlacklisted(msg.sender)
        whenNotBlacklisted(recipient)
        returns (bool) 
    {
        require(recipient != address(0), "Transfer to zero address");
        require(recipient != address(this), "Transfer to reBTC contract");
        require(amount > 0, "Transfer zero amount");
        _transferShares(msg.sender, recipient, _btcToShares(amount));
        return true;
    }

    /*
    * @notice Transfer function to transfer tokens
    * @dev This function is overridden to stop the base ERC20 transfer function
    */
    function _transfer(address , address , uint256) internal pure override {
        // Disable base ERC20 logic since we override transfer
        revert("Use _transferShares instead");
    }

    /*
    * @notice Transfer function to transfer shares
    * @param sender The address to transfer the shares from
    * @param recipient The address to transfer the shares to
    * @param shareAmount The amount of shares to transfer
    */
    function _transferShares(address sender, address recipient, uint256 shareAmount) internal {
        require(sender != address(0), "TRANSFER_FROM_ZERO_ADDR");
        require(recipient != address(0), "TRANSFER_TO_ZERO_ADDR");
        require(recipient != address(this), "TRANSFER_TO_REBTC_CONTRACT");
        require(shareAmount > 0, "TRANSFER_ZERO_AMOUNT");
        require(shareAmount <= _shares[sender], "BALANCE_EXCEEDED");
        
        _shares[sender] -= shareAmount;
        _shares[recipient] += shareAmount;
        
        emit Transfer(sender, recipient, (_totalPooledBTC * shareAmount) / _totalShares);
    }

    /*
    * @notice Mint function to mint tokens
    * @dev This function is only callable by the TOKENHUB_ROLE
    * @param account The address to mint the tokens to
    * @param btcAmount The amount of BTC scaled to 18 decimal precision to mint
    */
    function mint(address account, uint256 btcAmount) external onlyRole(TOKENHUB_ROLE) whenNotPaused {
        uint256 sharesToMint = _btcToShares(btcAmount);
        _totalShares += sharesToMint;
        _shares[account] += sharesToMint;
        _totalPooledBTC += btcAmount;
        emit Transfer(address(0), account, btcAmount);
    }

    /*
    * @notice Burn function to burn tokens
    * @dev This function is only callable by the TOKENHUB_ROLE
    * @param account The address to burn the tokens from
    * @param btcAmount The amount of BTC scaled to 18 decimal precision to burn
    */
    function burn(address account, uint256 btcAmount) external onlyRole(TOKENHUB_ROLE) whenNotPaused {
        uint256 sharesToBurn = _btcToShares(btcAmount);
        _shares[account] -= sharesToBurn;
        _totalShares -= sharesToBurn;
        _totalPooledBTC -= btcAmount;
        emit Transfer(account, address(0), btcAmount);
    }

    /*
    * @notice Burn function to burn shares
    * @dev This function is only callable by the TOKENHUB_ROLE
    * @param account The address to burn the shares from
    * @param shares The amount of shares to burn
    */
    function burnShares(address account, uint256 shares) external onlyRole(TOKENHUB_ROLE) whenNotPaused {
        // check if shares is greater than zero and less than or equal to the balance of the account
        require(shares > 0 && _shares[account] >= shares, "Invalid shares");
        _shares[account] -= shares;
        _totalShares -= shares;
        emit Transfer(account, address(0), shares);
    }

    /*
    * @notice Update total pooled BTC function to update the total pooled BTC
    * @dev This function is only callable by the REBASER_ROLE
    * @param newTotal The new total pooled BTC
    */
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

    function getTotalPooledBTC() external view returns (uint256) {
        return _totalPooledBTC;
    }

    /*
    * @notice Convert BTC to shares
    * @param btcAmount The amount of BTC scaled to 18 decimal precision to convert to shares
    * @return The amount of shares
    */
    function btcToShares(uint256 btcAmount) external view returns (uint256) {
        // return zero if btcAmount is zero
        if (btcAmount == 0) return 0;
        return _btcToShares(btcAmount);
    }

    /*
    * @notice Convert shares to BTC
    * @param shares The amount of shares to convert to BTC
    * @return The amount of BTC
    */
    function sharesToBTC(uint256 shares) external view returns (uint256) {
        // return zero if shares is zero
        if (shares == 0) return 0;
        return _sharesToBTC(shares);
    }

    /*
    * @notice Convert shares to BTC
    * @param shares The amount of shares to convert to BTC
    * @return The amount of BTC
    */
    function _sharesToBTC(uint256 shares) internal view returns (uint256) {
        return (_totalShares == 0 || _totalPooledBTC == 0)
            ? shares
            : (shares * _totalPooledBTC) / _totalShares;
    }

    /*
    * @notice Convert BTC to shares
    * @param btcAmount The amount of BTC scaled to 18 decimal precision to convert to shares
    * @return The amount of shares
    */
    function _btcToShares(uint256 btcAmount) internal view returns (uint256) {
        return (_totalShares == 0 || _totalPooledBTC == 0)
            ? btcAmount
            : (btcAmount * _totalShares) / _totalPooledBTC;
    }

    // ========================= Additional Functions =========================

    /*
    * @notice Emergency pause function to pause the token
    * @dev This function is only callable by the DEFAULT_ADMIN_ROLE
    */
    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    mapping(address => bool) private _blacklisted;

    /*
    * @notice Blacklist function to blacklist an address
    * @dev This function is only callable by the DEFAULT_ADMIN_ROLE
    */
    function blacklist(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _blacklisted[account] = true;
    }   

    /*
    * @notice Blacklist function to blacklist an address
    * @dev This function is only callable by the DEFAULT_ADMIN_ROLE
    */
    modifier whenNotBlacklisted(address account) {
        require(!_blacklisted[account], "Account is blacklisted");
        _;
    }

    /*
    * @notice Transfer function to transfer tokens
    * @dev This function is only callable when the token is not paused and the sender and recipient are not blacklisted
    */
    function transferFrom(address sender, address recipient, uint256 amount) 
        public 
        override 
        whenNotPaused
        whenNotBlacklisted(sender)
        whenNotBlacklisted(recipient)
        returns (bool) 
    {
        // Convert amount to shares
        uint256 shareAmount = _btcToShares(amount);
        
        // Check allowance
        uint256 currentAllowance = allowance(sender, msg.sender);
        require(currentAllowance >= amount, "ERC20: insufficient allowance");
        
        // Perform the transfer using shares
        _transferShares(sender, recipient, shareAmount);
        
        // Decrease allowance
        _approve(sender, msg.sender, currentAllowance - amount);
        
        return true;
    }

    /*
    * @notice Approve function to allow for ERC20 approvals
    * @dev This function is only callable when the token is not paused and the owner and spender are not blacklisted
    */
    function approve(address spender, uint256 amount) 
        public 
        override 
        whenNotPaused
        whenNotBlacklisted(msg.sender)
        whenNotBlacklisted(spender)
        returns (bool) 
    {
        require(spender != address(0), "Approve to zero address");
        require(spender != address(this), "Approve to reBTC contract");
        return super.approve(spender, amount);
    }

    /*
    * @notice Increase allowance function to allow for ERC20 approvals
    * @dev This function is only callable when the token is not paused and the owner and spender are not blacklisted
    */
    function increaseAllowance(address spender, uint256 addedValue) 
        public 
        override 
        whenNotPaused
        whenNotBlacklisted(msg.sender)
        whenNotBlacklisted(spender)
        returns (bool) 
    {
        require(spender != address(0), "Approve to zero address");
        require(spender != address(this), "Approve to reBTC contract");
        return super.increaseAllowance(spender, addedValue);
    }

    /*
    * @notice Decrease allowance function to allow for ERC20 approvals
    * @dev This function is only callable when the token is not paused and the owner and spender are not blacklisted
    */
    function decreaseAllowance(address spender, uint256 subtractedValue) 
        public 
        override 
        whenNotPaused
        whenNotBlacklisted(msg.sender)
        whenNotBlacklisted(spender)
        returns (bool) 
    {
        require(spender != address(0), "Approve to zero address");
        require(spender != address(this), "Approve to reBTC contract");
        return super.decreaseAllowance(spender, subtractedValue);
    }

    /*
    * @notice Permit function to allow for ERC20 approvals
    * @dev This function is only callable when the token is not paused and the owner and spender are not blacklisted
    */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public override whenNotPaused whenNotBlacklisted(owner) whenNotBlacklisted(spender) {
        require(deadline >= block.timestamp, "Permit expired");
        require(spender != address(0), "Approve to zero address");
        require(spender != address(this), "Approve to reBTC contract");
        super.permit(owner, spender, value, deadline, v, r, s);
    }
    /*
    * @notice Bootstrap the token with 1 sat in the contract
    * 1 satoshi is scaled to 10^10 to support 18 decimal precision for reBTC
    * @dev This function is only callable by the DEFAULT_ADMIN_ROLE
    */
    function bootstrap() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!_bootstrapped, "Already bootstrapped");

        uint256 oneSatScaled = 1e10; // 1 sat scaled to 18 decimals
        uint256 initialShares = 1e10;

        _totalPooledBTC = oneSatScaled;
        _totalShares = initialShares;
        _shares[address(0)] = initialShares;

        emit Transfer(address(0), address(0), 0);

        _bootstrapped = true;
    }

}
