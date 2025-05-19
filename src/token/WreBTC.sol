// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20Permit.sol";
import "./reBTC.sol";

/**
 * @title WrappedReBTC
 * @notice Non-rebasing wrapper token for the rebasing reBTC token.
 */
contract WrappedReBTC is 
    Initializable, 
    ERC20Upgradeable, 
    AccessControlUpgradeable, 
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC20Permit
{
    using SafeMathUpgradeable for uint256;

    // ================ Constants ================
    
    /// @notice Role that can pause the contract
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
    
    /// @notice Role that can unpause the contract
    bytes32 public constant RESUME_ROLE = keccak256("RESUME_ROLE");

    // ================ Storage ================
    
    /// @notice Reference to the reBTC token
    reBTC public reBTC;
    
    // Add gap for future storage variables
    uint256[50] private __gap;

    // Keep blacklist functionality as it's useful for security
    mapping(address => bool) private _blacklisted;

    // ================ Events ================
    
    /**
     * @notice Emitted when tokens are wrapped
     * @param account User who wrapped tokens
     * @param reBTCAmount Amount of reBTC wrapped
     * @param wrapReBTCAmount Amount of wrapReBTC received
     */
    event TokensWrapped(
        address indexed account,
        uint256 reBTCAmount,
        uint256 wrapReBTCAmount
    );
    
    /**
     * @notice Emitted when tokens are unwrapped
     * @param account User who unwrapped tokens
     * @param reBTCAmount Amount of reBTC unwrapped
     * @param unwrapReBTCAmount Amount of unwrapReBTC received
     */
    event TokensUnwrapped(
        address indexed account,
        uint256 reBTCAmount,
        uint256 unwrapReBTCAmount
    );

    event AccountBlacklisted(address indexed account);
    event EmergencyPaused(address indexed pauser);

    // ================ Initializer ================
    
    /**
     * @notice Initializes the contract
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param admin_ Address that will have admin role
     * @param _reBTC Address of the reBTC token
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        address admin_,
        address _reBTC
    ) public initializer {
        require(admin_ != address(0), "Admin cannot be zero address");
        require(_reBTC != address(0), "mBTC cannot be zero address");

        __ERC20_init(name_, symbol_);
        __ERC20Permit_init(name_);
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        
        _setupRole(DEFAULT_ADMIN_ROLE, admin_);
        _setupRole(PAUSE_ROLE, admin_);
        _setupRole(RESUME_ROLE, admin_);
        
        reBTC = reBTC(_reBTC);
    }

    // ================ External Functions ================
    
    /**
     * @notice Wraps reBTC tokens to receive wrapReBTC
     * @param _reBTCAmount Amount of reBTC to wrap
     * @return Amount of wrapReBTC received
     */
    function wrap(uint256 _reBTCAmount) 
        external 
        whenNotPaused 
        whenNotBlacklisted(msg.sender)
        nonReentrant 
        validAmount(_reBTCAmount)
        returns (uint256) 
    {
        require(_reBTCAmount > 0, "Amount must be greater than 0");
        
        // Transfer reBTC to this contract
        require(
            reBTC.transferFrom(msg.sender, address(this), _reBTCAmount),
            "reBTC transfer failed"
        );
        
        // Mint 1:1 WreBTC
        _mint(msg.sender, _reBTCAmount);
        
        emit TokensWrapped(msg.sender, _reBTCAmount, _reBTCAmount);
        
        return _reBTCAmount;
    }
    
    /**
     * @notice Unwraps wrapReBTC tokens to receive reBTC
     * @param _wrapReBTCAmount Amount of wrapReBTC to unwrap
     * @return Amount of reBTC received
     */
    function unwrap(uint256 _wrapReBTCAmount) 
        external 
        whenNotPaused 
        whenNotBlacklisted(msg.sender)
        nonReentrant 
        validAmount(_wrapReBTCAmount)
        returns (uint256) 
    {
        require(_wrapReBTCAmount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= _wrapReBTCAmount, "Insufficient wrapReBTC balance");
        
        // Burn WreBTC
        _burn(msg.sender, _wrapReBTCAmount);
        
        // Transfer reBTC back to user
        require(
            reBTC.transfer(msg.sender, _wrapReBTCAmount),
            "reBTC transfer failed"
        );
        
        emit TokensUnwrapped(msg.sender, _wrapReBTCAmount, _wrapReBTCAmount);
        
        return _wrapReBTCAmount;
    }
    
    /**
     * @notice Returns the amount of reBTC that would be received for unwrapping
     * @param _wrapReBTCAmount Amount of wrapReBTC to unwrap
     * @param _account Account to check for
     * @return Amount of reBTC that would be received
     */
    function getUnwrapAmount(uint256 _wrapReBTCAmount, address _account) external view returns (uint256) {
        if (_wrapReBTCAmount == 0 || balanceOf(_account) == 0) {
            return 0;
        }
        
        return _wrapReBTCAmount;
    }
    
    /**
     * @notice Returns the total amount of mBTC held by this contract
     * @return Total mBTC balance
     */
    function getTotalWrappedReBTC() external view returns (uint256) {
        return reBTC.balanceOf(address(this));
    }
    
    /**
     * @notice Pauses the contract
     */
    function pause() external onlyRole(PAUSE_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpauses the contract
     */
    function unpause() external onlyRole(RESUME_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Recovers any ERC20 tokens accidentally sent to this contract
     * @param _token Address of the token to recover
     * @param _recipient Address to send the tokens to
     * @param _amount Amount of tokens to recover
     */
    function recoverERC20(address _token, address _recipient, uint256 _amount) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        nonReentrant
    {
        require(_token != address(mBTC), "Cannot recover mBTC");
        require(_recipient != address(0), "Recipient cannot be zero address");
        require(_amount > 0, "Amount must be greater than 0");
        
        IERC20Upgradeable(_token).transfer(_recipient, _amount);
    }

    function isBlacklisted(address account) external view returns (bool) {
        return _blacklisted[account];
    }

    // ================ Internal Functions ================
    
    /**
     * @notice Returns the number of decimals for display purposes
     * @return Number of decimals
     */
    function decimals() public pure override returns (uint8) {
        return 8; // Bitcoin uses 8 decimals
    }

    // Keep emergency pause
    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    modifier whenNotBlacklisted(address account) {
        require(!_blacklisted[account], "Account is blacklisted");
        _;
    }

    function blacklist(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _blacklisted[account] = true;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0, "Amount must be greater than 0");
        _;
    }

    function transfer(address recipient, uint256 amount) 
        public 
        override 
        whenNotBlacklisted(msg.sender)
        whenNotBlacklisted(recipient)
        returns (bool) 
    {
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) 
        public 
        override 
        whenNotBlacklisted(sender)
        whenNotBlacklisted(recipient)
        returns (bool) 
    {
        return super.transferFrom(sender, recipient, amount);
    }
}
