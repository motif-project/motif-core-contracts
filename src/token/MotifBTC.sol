// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

/**
 * @title MotifBTC - Rebasing token representing staked Bitcoin
 * @notice Interest-bearing ERC20-like token for Motif Bitcoin Staking protocol
 * @dev This contract implements a share-based accounting system similar to Lido's StETH
 */
contract MotifBTC is 
    Initializable, 
    IERC20Upgradeable, 
    AccessControlUpgradeable, 
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMathUpgradeable for uint256;

    // ================ Constants ================

    /// @notice Role that can pause the contract
    bytes32 public constant PAUSE_ROLE = keccak256("token.motifBitcoin.Pause");
    
    /// @notice Role that can unpause the contract
    bytes32 public constant RESUME_ROLE = keccak256("token.motifBitcoin.Resume");
    
    /// @notice Role that can trigger rebases
    bytes32 public constant REBASE_ROLE = keccak256("token.motifBitcoin.Rebase");
    
    /// @notice Role that can mint shares
    bytes32 public constant MINT_ROLE = keccak256("token.motifBitcoin.Mint");
    
    /// @notice Role that can burn shares
    bytes32 public constant BURN_ROLE = keccak256("token.motifBitcoin.Burn");
    

    /// @notice Address for initial token holder
    address constant internal INITIAL_TOKEN_HOLDER = address(0xdead);
    
    /// @notice Value representing infinite allowance
    uint256 constant internal INFINITE_ALLOWANCE = type(uint256).max;
    
    /// @notice Total basis points for fee calculations
    uint256 constant internal TOTAL_BASIS_POINTS = 10000;

    // Add minimum deposit/withdrawal amounts
    uint256 public constant MIN_DEPOSIT = 10**4; // 0.0001 BTC

    // Add a minimum initial deposit requirement
    uint256 public constant MINIMUM_INITIAL_DEPOSIT = 10**6; // 0.01 BTC

    // ================ Storage ================

    /// @notice Total shares in existence
    uint256 private _totalShares;
    
    /// @notice Shares owned by each account
    mapping(address => uint256) private shares;
    
    /// @notice Allowances are nominated in tokens, not shares
    mapping(address => mapping(address => uint256)) private allowances;

    // Add gap for future storage variables
    uint256[50] private __gap;

    // ================ Events ================

    /**
     * @notice An executed shares transfer
     * @dev Emitted in pair with an ERC20-defined Transfer event
     * @param from Address sending shares
     * @param to Address receiving shares
     * @param sharesValue Amount of shares transferred
     */
    event TransferShares(
        address indexed from,
        address indexed to,
        uint256 sharesValue
    );
    
    /**
     * @notice An executed shares burn
     * @dev Reports burnt shares amount and corresponding mBTC amount
     * @param account Address whose shares were burnt
     * @param preRebaseTokenAmount Token amount before rebase
     * @param postRebaseTokenAmount Token amount after rebase
     * @param sharesAmount Amount of shares burnt
     */
    event SharesBurnt(
        address indexed account,
        uint256 preRebaseTokenAmount,
        uint256 postRebaseTokenAmount,
        uint256 sharesAmount
    );
    
    /**
     * @notice Token rebased event
     * @dev Emitted when the total supply changes due to rewards or penalties
     * @param reportTimestamp Timestamp of the report triggering rebase
     * @param timeElapsed Time elapsed since last rebase
     * @param preTotalShares Total shares before rebase
     * @param preTotalBitcoin Total Bitcoin before rebase
     * @param postTotalShares Total shares after rebase
     * @param postTotalBitcoin Total Bitcoin after rebase
     * @param sharesMintedAsFees Shares minted as fees during rebase
     */
    event TokenRebased(
        uint256 indexed reportTimestamp,
        uint256 timeElapsed,
        uint256 preTotalShares,
        uint256 preTotalBitcoin,
        uint256 postTotalShares,
        uint256 postTotalBitcoin,
        uint256 sharesMintedAsFees
    );

    // ================ Initializer ================

    /// @notice Use constructor + initializer pattern
    address private immutable _initializer;

    constructor() {
        _initializer = msg.sender;
    }

    /**
     * @notice Initializes the contract
     * @param admin Address that will have admin role
     */
    function initialize(address admin) public initializer {
        require(msg.sender == _initializer, "Only initializer can initialize");
        require(admin != address(0), "Admin cannot be zero address");
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(PAUSE_ROLE, admin);
        _setupRole(RESUME_ROLE, admin);
        _setupRole(REBASE_ROLE, admin);
        _setupRole(MINT_ROLE, admin);
        _setupRole(BURN_ROLE, admin);
    }

    // ================ View Functions ================

    /**
     * @notice Returns the name of the token
     * @return Token name
     */
    function name() external pure returns (string memory) {
        return "Motif Bitcoin";
    }
    
    /**
     * @notice Returns the symbol of the token
     * @return Token symbol
     */
    function symbol() external pure returns (string memory) {
        return "motifBTC";
    }
    
    /**
     * @notice Returns the number of decimals for display purposes
     * @return Number of decimals
     */
    function decimals() external pure returns (uint8) {
        return 8; // Bitcoin uses 8 decimals
    }
    
    /**
     * @notice Returns the total supply of tokens
     * @return Total supply
     */
    function totalSupply() external view override returns (uint256) {
        return _getTotalPooledBitcoin();
    }
    
    /**
     * @notice Returns the total amount of Bitcoin controlled by the protocol
     * @return Total pooled Bitcoin
     */
    function getTotalPooledBitcoin() external view returns (uint256) {
        return _getTotalPooledBitcoin();
    }
    
    /**
     * @notice Returns the total amount of shares in existence
     * @return Total shares
     */
    function getTotalShares() external view returns (uint256) {
        return _getTotalShares();
    }
    
    /**
     * @notice Returns the amount of shares owned by an account
     * @param _account Address to check
     * @return Amount of shares
     */
    function sharesOf(address _account) external view returns (uint256) {
        return _sharesOf(_account);
    }
    
    /**
     * @notice Returns the amount of tokens owned by an account
     * @param _account Address to check
     * @return Token balance
     */
    function balanceOf(address _account) external view override returns (uint256) {
        return getPooledBitcoinByShares(_sharesOf(_account));
    }
    
    /**
     * @notice Returns the remaining allowance of spender
     * @param _owner Owner of the tokens
     * @param _spender Spender address
     * @return Remaining allowance
     */
    function allowance(address _owner, address _spender) external view override returns (uint256) {
        return allowances[_owner][_spender];
    }
    
    /**
     * @notice Converts shares amount to corresponding pooled Bitcoin amount
     * @param _sharesAmount Amount of shares to convert
     * @return Bitcoin amount
     */
    function getPooledBitcoinByShares(uint256 _sharesAmount) public view returns (uint256) {
        uint256 totalShares = _getTotalShares();
        require(totalShares > 0, "No shares exist");
        return _sharesAmount
                    .mul(_getTotalPooledBitcoin())
                    .div(totalShares);
    }
    
    /**
     * @notice Converts Bitcoin amount to corresponding shares amount
     * @param _bitcoinAmount Amount of Bitcoin to convert
     * @return Shares amount
     */
    function getSharesByPooledBitcoin(uint256 _bitcoinAmount) public view returns (uint256) {
        uint256 totalPooledBitcoin = _getTotalPooledBitcoin();
        if (totalPooledBitcoin == 0) {
            // Require a minimum initial deposit to prevent dust attacks
            require(_bitcoinAmount >= MINIMUM_INITIAL_DEPOSIT, "Initial deposit too small");
            return _bitcoinAmount; // First depositor gets shares 1:1 with Bitcoin
        }
        
        // Use higher precision for intermediate calculations
        uint256 precision = 10**18;
        uint256 shareRatio = _getTotalShares().mul(precision).div(totalPooledBitcoin);
        return _bitcoinAmount.mul(shareRatio).div(precision);
    }

    // ================ External Functions ================

    /**
     * @notice Transfers tokens to recipient
     * @param _recipient Recipient address
     * @param _amount Amount to transfer
     * @return Success flag
     */
    function transfer(address _recipient, uint256 _amount) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
        returns (bool) 
    {
        require(_recipient != address(0), "Recipient cannot be zero address");
        require(_amount > 0, "Cannot transfer 0 tokens");
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }
    
    /**
     * @notice Approves spender to spend tokens
     * @param _spender Spender address
     * @param _amount Amount to approve
     * @return Success flag
     */
    function approve(address _spender, uint256 _amount) external override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }
    
    /**
     * @notice Transfers tokens from sender to recipient using allowance
     * @param _sender Sender address
     * @param _recipient Recipient address
     * @param _amount Amount to transfer
     * @return Success flag
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
        returns (bool) 
    {
        require(_sender != address(0), "Sender cannot be zero address");
        require(_recipient != address(0), "Recipient cannot be zero address");
        require(_amount > 0, "Cannot transfer 0 tokens");
        
        uint256 currentAllowance = allowances[_sender][msg.sender];
        require(currentAllowance >= _amount, "Transfer amount exceeds allowance");
        
        // Decrease allowance before transfer to prevent reentrancy
        if (currentAllowance != type(uint256).max) { // Skip for infinite allowance
            _approve(_sender, msg.sender, currentAllowance - _amount);
        }
        
        _transfer(_sender, _recipient, _amount);
        return true;
    }
    
    /**
     * @notice Increases allowance of spender
     * @param _spender Spender address
     * @param _addedValue Amount to add to allowance
     * @return Success flag
     */
    function increaseAllowance(address _spender, uint256 _addedValue) external returns (bool) {
        _approve(msg.sender, _spender, allowances[msg.sender][_spender].add(_addedValue));
        return true;
    }
    
    /**
     * @notice Decreases allowance of spender
     * @param _spender Spender address
     * @param _subtractedValue Amount to subtract from allowance
     * @return Success flag
     */
    function decreaseAllowance(address _spender, uint256 _subtractedValue) external returns (bool) {
        uint256 currentAllowance = allowances[msg.sender][_spender];
        require(currentAllowance >= _subtractedValue, "ALLOWANCE_BELOW_ZERO");
        _approve(msg.sender, _spender, currentAllowance.sub(_subtractedValue));
        return true;
    }
    
    /**
     * @notice Transfers shares to recipient
     * @param _recipient Recipient address
     * @param _sharesAmount Amount of shares to transfer
     * @return Amount of tokens transferred
     */
    function transferShares(address _recipient, uint256 _sharesAmount) 
        external 
        whenNotPaused 
        nonReentrant 
        returns (uint256) 
    {
        require(_recipient != address(0), "Recipient cannot be zero address");
        require(_sharesAmount > 0, "Cannot transfer 0 shares");
        _transferShares(msg.sender, _recipient, _sharesAmount);
        uint256 tokensAmount = getPooledBitcoinByShares(_sharesAmount);
        _emitTransferEvents(msg.sender, _recipient, tokensAmount, _sharesAmount);
        return tokensAmount;
    }
    
    /**
     * @notice Transfers shares from sender to recipient using allowance
     * @param _sender Sender address
     * @param _recipient Recipient address
     * @param _sharesAmount Amount of shares to transfer
     * @return Amount of tokens transferred
     */
    function transferSharesFrom(address _sender, address _recipient, uint256 _sharesAmount) 
        external 
        whenNotPaused 
        nonReentrant 
        returns (uint256) 
    {
        require(_sender != address(0), "Sender cannot be zero address");
        require(_recipient != address(0), "Recipient cannot be zero address");
        require(_sharesAmount > 0, "Cannot transfer 0 shares");
        uint256 tokensAmount = getPooledBitcoinByShares(_sharesAmount);
        _spendAllowance(_sender, msg.sender, tokensAmount);
        _transferShares(_sender, _recipient, _sharesAmount);
        _emitTransferEvents(_sender, _recipient, tokensAmount, _sharesAmount);
        return tokensAmount;
    }
    
    /**
     * @notice Mints new shares to recipient
     * @param _recipient Recipient address
     * @param _sharesAmount Amount of shares to mint
     * @return Amount of tokens minted
     */
    function mintShares(address _recipient, uint256 _sharesAmount) 
        external 
        whenNotPaused 
        nonReentrant 
        onlyRole(MINT_ROLE) 
        returns (uint256) 
    {
        require(_recipient != address(0), "Recipient cannot be zero address");
        uint256 tokensAmount = getPooledBitcoinByShares(_sharesAmount);
        require(tokensAmount >= MIN_DEPOSIT, "Amount too small");
        
        _totalShares = _totalShares.add(_sharesAmount);
        shares[_recipient] = shares[_recipient].add(_sharesAmount);
        
        _emitTransferEvents(address(0), _recipient, tokensAmount, _sharesAmount);
        
        return tokensAmount;
    }
    
    /**
     * @notice Burns shares from account
     * @param _account Account to burn shares from
     * @param _sharesAmount Amount of shares to burn
     * @return Amount of tokens burned
     */
    function burnShares(address _account, uint256 _sharesAmount) 
        external 
        whenNotPaused 
        nonReentrant 
        onlyRole(BURN_ROLE) 
        returns (uint256) 
    {
        require(_account != address(0), "Account cannot be zero address");
        
        uint256 accountShares = shares[_account];
        require(_sharesAmount <= accountShares, "BALANCE_EXCEEDED");
        
        uint256 preRebaseTokenAmount = getPooledBitcoinByShares(_sharesAmount);
        
        _totalShares = _totalShares.sub(_sharesAmount);
        shares[_account] = accountShares.sub(_sharesAmount);
        
        uint256 postRebaseTokenAmount = getPooledBitcoinByShares(_sharesAmount);
        
        emit SharesBurnt(_account, preRebaseTokenAmount, postRebaseTokenAmount, _sharesAmount);
        
        return preRebaseTokenAmount;
    }
    
    /**
     * @notice Triggers a rebase of the token
     * @param _reportTimestamp Timestamp of the report
     * @param _timeElapsed Time elapsed since last rebase
     * @param _preTotalBitcoin Total Bitcoin before rebase
     * @param _postTotalBitcoin Total Bitcoin after rebase
     * @param _sharesMintedAsFees Shares minted as fees
     */
    function rebase(
        uint256 _reportTimestamp,
        uint256 _timeElapsed,
        uint256 _preTotalBitcoin,
        uint256 _postTotalBitcoin,
        uint256 _sharesMintedAsFees
    ) external onlyRole(REBASE_ROLE) {
        uint256 preTotalShares = _getTotalShares();
        
        // If shares were minted as fees, add them to the total
        if (_sharesMintedAsFees > 0) {
            _totalShares = preTotalShares.add(_sharesMintedAsFees);
        }
        
        emit TokenRebased(
            _reportTimestamp,
            _timeElapsed,
            preTotalShares,
            _preTotalBitcoin,
            _getTotalShares(),
            _postTotalBitcoin,
            _sharesMintedAsFees
        );
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
     * @notice Initializes the contract with initial shares
     * @param _initialBitcoin Initial amount of Bitcoin to bootstrap the token
     */
    function initializeShares(uint256 _initialBitcoin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_getTotalShares() == 0, "Already initialized");
        require(_initialBitcoin > 0, "Initial amount must be > 0");
        
        // Bootstrap with initial shares to INITIAL_TOKEN_HOLDER
        _totalShares = _initialBitcoin;
        shares[INITIAL_TOKEN_HOLDER] = _initialBitcoin;
        
        emit Transfer(address(0), INITIAL_TOKEN_HOLDER, _initialBitcoin);
        emit TransferShares(address(0), INITIAL_TOKEN_HOLDER, _initialBitcoin);
    }

    // ================ Internal Functions ================

    /**
     * @notice Returns the total amount of Bitcoin controlled by the protocol
     * @return Total pooled Bitcoin
     * @dev This function must be implemented by derived contracts
     */
    function _getTotalPooledBitcoin() internal view virtual returns (uint256) {
        // This should be implemented by the contract that inherits from this one
        revert("Not implemented");
    }
    
    /**
     * @notice Returns the total amount of shares in existence
     * @return Total shares
     */
    function _getTotalShares() internal view returns (uint256) {
        return _totalShares;
    }
    
    /**
     * @notice Returns the amount of shares owned by an account
     * @param _account Address to check
     * @return Amount of shares
     */
    function _sharesOf(address _account) internal view returns (uint256) {
        return shares[_account];
    }
    
    /**
     * @notice Transfers tokens from sender to recipient
     * @param _sender Sender address
     * @param _recipient Recipient address
     * @param _amount Amount to transfer
     */
    function _transfer(address _sender, address _recipient, uint256 _amount) internal {
        uint256 _sharesToTransfer = getSharesByPooledBitcoin(_amount);
        _transferShares(_sender, _recipient, _sharesToTransfer);
        _emitTransferEvents(_sender, _recipient, _amount, _sharesToTransfer);
    }
    
    /**
     * @notice Approves spender to spend tokens
     * @param _owner Owner address
     * @param _spender Spender address
     * @param _amount Amount to approve
     */
    function _approve(address _owner, address _spender, uint256 _amount) internal {
        require(_owner != address(0), "APPROVE_FROM_ZERO_ADDR");
        require(_spender != address(0), "APPROVE_TO_ZERO_ADDR");
        
        allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }
    
    /**
     * @notice Spends allowance
     * @param _owner Owner address
     * @param _spender Spender address
     * @param _amount Amount to spend
     */
    function _spendAllowance(address _owner, address _spender, uint256 _amount) internal {
        uint256 currentAllowance = allowances[_owner][_spender];
        if (currentAllowance != INFINITE_ALLOWANCE) {
            require(currentAllowance >= _amount, "ALLOWANCE_EXCEEDED");
            _approve(_owner, _spender, currentAllowance.sub(_amount));
        }
    }
    
    /**
     * @notice Transfers shares from sender to recipient
     * @param _sender Sender address
     * @param _recipient Recipient address
     * @param _sharesAmount Amount of shares to transfer
     */
    function _transferShares(address _sender, address _recipient, uint256 _sharesAmount) internal {
        require(_sender != address(0), "TRANSFER_FROM_ZERO_ADDR");
        require(_recipient != address(0), "TRANSFER_TO_ZERO_ADDR");
        require(_recipient != address(this), "TRANSFER_TO_MBTC_CONTRACT");
        
        uint256 currentSenderShares = shares[_sender];
        require(_sharesAmount <= currentSenderShares, "BALANCE_EXCEEDED");
        
        shares[_sender] = currentSenderShares.sub(_sharesAmount);
        shares[_recipient] = shares[_recipient].add(_sharesAmount);
    }
    
    /**
     * @notice Emits transfer events
     * @param _from Sender address
     * @param _to Recipient address
     * @param _tokenAmount Amount of tokens
     * @param _sharesAmount Amount of shares
     */
    function _emitTransferEvents(
        address _from, 
        address _to, 
        uint256 _tokenAmount, 
        uint256 _sharesAmount
    ) internal {
        emit Transfer(_from, _to, _tokenAmount);
        emit TransferShares(_from, _to, _sharesAmount);
    }

    // Add protected accessor methods
    function _getShares(address _account) internal view returns (uint256) {
        return shares[_account];
    }

    function _setShares(address _account, uint256 _amount) internal {
        shares[_account] = _amount;
    }

    function _setTotalShares(uint256 _amount) internal {
        _totalShares = _amount;
    }
}
