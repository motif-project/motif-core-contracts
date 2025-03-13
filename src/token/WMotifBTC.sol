// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./MotifBitcoin.sol";

/**
 * @title WrappedMotifBitcoin - Non-rebasing wrapper for MotifBitcoin
 * @notice Provides a fixed-balance ERC20 wrapper around the rebasing MotifBitcoin token
 */
contract WrappedMotifBitcoin is 
    Initializable, 
    ERC20Upgradeable, 
    AccessControlUpgradeable, 
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMathUpgradeable for uint256;

    // ================ Constants ================
    
    /// @notice Role that can pause the contract
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
    
    /// @notice Role that can unpause the contract
    bytes32 public constant RESUME_ROLE = keccak256("RESUME_ROLE");

    // ================ Storage ================
    
    /// @notice Reference to the MotifBitcoin token
    MotifBitcoin public mBTC;
    
    /// @notice Tracks the shares corresponding to each wrapped token
    mapping(address => uint256) private wrappedShares;
    
    /// @notice Total shares wrapped in this contract
    uint256 private totalWrappedShares;

    // Add gap for future storage variables
    uint256[50] private __gap;

    // ================ Events ================
    
    /**
     * @notice Emitted when tokens are wrapped
     * @param account User who wrapped tokens
     * @param mBTCAmount Amount of mBTC wrapped
     * @param wMBTCAmount Amount of wMBTC received
     * @param sharesAmount Amount of shares wrapped
     */
    event TokensWrapped(
        address indexed account,
        uint256 mBTCAmount,
        uint256 wMBTCAmount,
        uint256 sharesAmount
    );
    
    /**
     * @notice Emitted when tokens are unwrapped
     * @param account User who unwrapped tokens
     * @param wMBTCAmount Amount of wMBTC unwrapped
     * @param mBTCAmount Amount of mBTC received
     * @param sharesAmount Amount of shares unwrapped
     */
    event TokensUnwrapped(
        address indexed account,
        uint256 wMBTCAmount,
        uint256 mBTCAmount,
        uint256 sharesAmount
    );

    // ================ Initializer ================
    
    /**
     * @notice Initializes the contract
     * @param admin Address that will have admin role
     * @param _mBTC Address of the MotifBitcoin token
     */
    function initialize(address admin, address _mBTC) public initializer {
        require(admin != address(0), "Admin cannot be zero address");
        require(_mBTC != address(0), "mBTC cannot be zero address");
        __ERC20_init("Wrapped Motif Bitcoin", "wMBTC");
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(PAUSE_ROLE, admin);
        _setupRole(RESUME_ROLE, admin);
        
        mBTC = MotifBitcoin(_mBTC);
    }

    // ================ External Functions ================
    
    /**
     * @notice Wraps mBTC tokens to receive wMBTC
     * @param _mBTCAmount Amount of mBTC to wrap
     * @return Amount of wMBTC received
     */
    function wrap(uint256 _mBTCAmount) 
        external 
        whenNotPaused 
        nonReentrant 
        returns (uint256) 
    {
        require(_mBTCAmount > 0, "Amount must be greater than 0");
        
        uint256 balanceBefore = mBTC.balanceOf(address(this));
        require(
            mBTC.transferFrom(msg.sender, address(this), _mBTCAmount),
            "mBTC transfer failed"
        );
        uint256 balanceAfter = mBTC.balanceOf(address(this));
        require(
            balanceAfter == balanceBefore.add(_mBTCAmount),
            "Transfer amount mismatch"
        );
        
        // Calculate shares equivalent to mBTC amount
        uint256 sharesToWrap = mBTC.getSharesByPooledBitcoin(_mBTCAmount);
        
        // Calculate wMBTC amount to mint (1:1 with mBTC)
        uint256 wMBTCToMint = _mBTCAmount;
        
        // Update wrapped shares for user
        wrappedShares[msg.sender] = wrappedShares[msg.sender].add(sharesToWrap);
        totalWrappedShares = totalWrappedShares.add(sharesToWrap);
        
        // Mint wMBTC to user
        _mint(msg.sender, wMBTCToMint);
        
        emit TokensWrapped(msg.sender, _mBTCAmount, wMBTCToMint, sharesToWrap);
        
        return wMBTCToMint;
    }
    
    /**
     * @notice Unwraps wMBTC tokens to receive mBTC
     * @param _wMBTCAmount Amount of wMBTC to unwrap
     * @return Amount of mBTC received
     */
    function unwrap(uint256 _wMBTCAmount) 
        external 
        whenNotPaused 
        nonReentrant 
        returns (uint256) 
    {
        require(_wMBTCAmount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= _wMBTCAmount, "Insufficient wMBTC balance");
        
        // Calculate proportion of shares to unwrap
        uint256 userWrappedShares = wrappedShares[msg.sender];
        uint256 userWMBTCBalance = balanceOf(msg.sender);
        
        uint256 sharesToUnwrap = userWrappedShares.mul(_wMBTCAmount).div(userWMBTCBalance);
        
        // Calculate mBTC amount based on current share value
        uint256 mBTCToReturn = mBTC.getPooledBitcoinByShares(sharesToUnwrap);
        
        // Update wrapped shares for user
        wrappedShares[msg.sender] = wrappedShares[msg.sender].sub(sharesToUnwrap);
        totalWrappedShares = totalWrappedShares.sub(sharesToUnwrap);
        
        // Burn wMBTC from user
        _burn(msg.sender, _wMBTCAmount);
        
        // Transfer mBTC to user
        require(
            mBTC.transfer(msg.sender, mBTCToReturn),
            "mBTC transfer failed"
        );
        
        emit TokensUnwrapped(msg.sender, _wMBTCAmount, mBTCToReturn, sharesToUnwrap);
        
        return mBTCToReturn;
    }
    
    /**
     * @notice Returns the amount of mBTC that would be received for unwrapping
     * @param _wMBTCAmount Amount of wMBTC to unwrap
     * @param _account Account to check for
     * @return Amount of mBTC that would be received
     */
    function getUnwrapAmount(uint256 _wMBTCAmount, address _account) external view returns (uint256) {
        if (_wMBTCAmount == 0 || balanceOf(_account) == 0) {
            return 0;
        }
        
        uint256 userWrappedShares = wrappedShares[_account];
        uint256 userWMBTCBalance = balanceOf(_account);
        
        uint256 sharesToUnwrap = userWrappedShares.mul(_wMBTCAmount).div(userWMBTCBalance);
        return mBTC.getPooledBitcoinByShares(sharesToUnwrap);
    }
    
    /**
     * @notice Returns the total amount of mBTC held by this contract
     * @return Total mBTC balance
     */
    function getTotalWrappedMBTC() external view returns (uint256) {
        return mBTC.balanceOf(address(this));
    }
    
    /**
     * @notice Returns the total shares wrapped in this contract
     * @return Total wrapped shares
     */
    function getTotalWrappedShares() external view returns (uint256) {
        return totalWrappedShares;
    }
    
    /**
     * @notice Returns the shares wrapped by a specific account
     * @param _account Account to check
     * @return Wrapped shares
     */
    function getWrappedShares(address _account) external view returns (uint256) {
        return wrappedShares[_account];
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

    // ================ Internal Functions ================
    
    /**
     * @notice Returns the number of decimals for display purposes
     * @return Number of decimals
     */
    function decimals() public pure override returns (uint8) {
        return 8; // Bitcoin uses 8 decimals
    }
}
