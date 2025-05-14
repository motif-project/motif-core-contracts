// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./reBTC.sol";

/**
 * @title MotifBitcoin - Concrete implementation of MotifBTC
 * @notice Tracks the actual Bitcoin in the protocol and implements rebasing logic
 */
contract MotifBitcoin is reBTC
{
    using SafeMathUpgradeable for uint256;

    // ================ Constants ================
    
    /// @notice Minimum time between Bitcoin amount updates
    uint256 public constant MIN_UPDATE_INTERVAL = 1 hours;
    
    /// @notice Maximum Bitcoin amount change per update
    uint256 public constant MAX_AMOUNT_CHANGE = 1000 * 10**8; // 1,000 BTC

    // ================ Storage ================
    
    /// @notice Total pooled Bitcoin tracked by the protocol
    uint256 private _totalPooledBitcoin;
    
    /// @notice Address authorized to update total pooled Bitcoin
    address public bitcoinReporter;

    /// @notice Last update timestamp
    uint256 private _lastUpdateTimestamp;
    
    /// @notice Last Bitcoin amount
    uint256 private _lastBitcoinAmount;

    // ================ Events ================
    
    /**
     * @notice Emitted when total pooled Bitcoin is updated
     * @param previousAmount Previous total pooled Bitcoin
     * @param newAmount New total pooled Bitcoin
     * @param reporter Address that reported the update
     */
    event TotalPooledBitcoinUpdated(
        uint256 previousAmount,
        uint256 newAmount,
        address indexed reporter
    );
    
    /**
     * @notice Emitted when Bitcoin reporter is updated
     * @param previousReporter Previous reporter address
     * @param newReporter New reporter address
     */
    event BitcoinReporterUpdated(
        address indexed previousReporter,
        address indexed newReporter
    );

    /// @notice Emitted when rate limit is exceeded
    event RateLimitExceeded(
        address indexed caller,
        uint256 attemptedChange,
        uint256 maxAllowedChange,
        uint256 timestamp
    );

    // ================ Initializer ================
    
    /**
     * @notice Initializes the implementation contract
     * @param admin Address that will have admin role
     * @param _bitcoinReporter Address authorized to update total pooled Bitcoin
     * @param initialBitcoin Initial amount of Bitcoin to track
     */
    function initialize(
        address admin,
        address _bitcoinReporter,
        uint256 initialBitcoin
    ) public initializer {
        super.initialize(admin);        
        bitcoinReporter = _bitcoinReporter;
        _totalPooledBitcoin = initialBitcoin;
        
        emit BitcoinReporterUpdated(address(0), _bitcoinReporter);
        emit TotalPooledBitcoinUpdated(0, initialBitcoin, msg.sender);
    }

    // ================ Modifiers ================
    
    /// @notice Modifier to enforce rate limiting
    modifier rateLimited(uint256 newAmount) {
        require(
            block.timestamp >= _lastUpdateTimestamp + MIN_UPDATE_INTERVAL,
            "Update too soon"
        );
        
        uint256 change = newAmount > _lastBitcoinAmount 
            ? newAmount - _lastBitcoinAmount 
            : _lastBitcoinAmount - newAmount;
        
        if (change > MAX_AMOUNT_CHANGE) {
            emit RateLimitExceeded(
                msg.sender,
                change,
                MAX_AMOUNT_CHANGE,
                block.timestamp
            );
            revert("Amount change too large");
        }
        
        _;
        _lastUpdateTimestamp = block.timestamp;
        _lastBitcoinAmount = newAmount;
    }

    // ================ External Functions ================
    
    /**
     * @notice Updates the Bitcoin reporter address
     * @param _newReporter New reporter address
     */
    function setBitcoinReporter(address _newReporter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newReporter != address(0), "Reporter cannot be zero address");
        
        address oldReporter = bitcoinReporter;
        bitcoinReporter = _newReporter;
        
        emit BitcoinReporterUpdated(oldReporter, _newReporter);
    }
    
    /**
     * @notice Updates the total pooled Bitcoin amount
     * @param _newTotalPooledBitcoin New total amount of Bitcoin
     */
    function updateTotalPooledBitcoin(uint256 _newTotalPooledBitcoin) 
        external 
        whenNotPaused 
        rateLimited(_newTotalPooledBitcoin)
    {
        require(
            msg.sender == bitcoinReporter || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Not authorized to update Bitcoin amount"
        );
        
        uint256 oldAmount = _totalPooledBitcoin;
        _totalPooledBitcoin = _newTotalPooledBitcoin;
        
        emit TotalPooledBitcoinUpdated(oldAmount, _newTotalPooledBitcoin, msg.sender);
    }
    
    /**
     * @notice Processes a rebase based on new total pooled Bitcoin
     * @param _reportTimestamp Timestamp of the report
     * @param _newTotalPooledBitcoin New total pooled Bitcoin
     * @param _feeRecipient Address to receive fee shares
     * @param _feeBasisPoints Fee in basis points
     */
    function processRebase(
        uint256 _reportTimestamp,
        uint256 _newTotalPooledBitcoin,
        address _feeRecipient,
        uint256 _feeBasisPoints
    ) external whenNotPaused onlyRole(REBASE_ROLE) {
        require(_feeRecipient != address(0), "Fee recipient cannot be zero address");
        require(_feeBasisPoints <= TOTAL_BASIS_POINTS, "Fee exceeds 100%");
        
        uint256 oldTotalPooledBitcoin = _totalPooledBitcoin;
        uint256 preTotalShares = _getTotalShares();
        
        // Calculate rewards (if any)
        if (_newTotalPooledBitcoin <= oldTotalPooledBitcoin) {
            // No rewards or losses, just update the total
            _totalPooledBitcoin = _newTotalPooledBitcoin;
            
            emit TokenRebased(
                _reportTimestamp,
                block.timestamp - _reportTimestamp,
                preTotalShares,
                oldTotalPooledBitcoin,
                preTotalShares,
                _newTotalPooledBitcoin,
                0
            );
            
            return;
        }
        
        // Calculate rewards
        uint256 rewards = _newTotalPooledBitcoin.sub(oldTotalPooledBitcoin);
        
        // Calculate fee shares
        uint256 feeAmount = rewards.mul(_feeBasisPoints).div(TOTAL_BASIS_POINTS);
        uint256 feeShares = 0;
        
        if (feeAmount > 0) {
            // Convert fee amount to shares
            feeShares = getSharesByPooledBitcoin(feeAmount);
            
            // Mint fee shares to recipient
            _setShares(_feeRecipient, _getShares(_feeRecipient).add(feeShares));
            _setTotalShares(_getTotalShares().add(feeShares));
            
            // Emit transfer events for fee
            emit Transfer(address(0), _feeRecipient, feeAmount);
            emit TransferShares(address(0), _feeRecipient, feeShares);
        }
        
        // Update total pooled Bitcoin
        _totalPooledBitcoin = _newTotalPooledBitcoin;
        
        // Emit rebase event
        emit TokenRebased(
            _reportTimestamp,
            block.timestamp - _reportTimestamp,
            preTotalShares,
            oldTotalPooledBitcoin,
            _getTotalShares(),
            _newTotalPooledBitcoin,
            feeShares
        );
        
        // Emit total updated event
        emit TotalPooledBitcoinUpdated(oldTotalPooledBitcoin, _newTotalPooledBitcoin, msg.sender);
    }

    // ================ Internal Functions ================
    
    /**
     * @notice Returns the total amount of Bitcoin controlled by the protocol
     * @return Total pooled Bitcoin
     * @dev Implements the virtual function from MotifBTC
     */
    function _getTotalPooledBitcoin() internal view override returns (uint256) {
        return _totalPooledBitcoin;
    }
}
