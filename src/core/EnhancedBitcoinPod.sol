// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "../modules/FeeManager.sol";
import "../interfaces/IBitcoinPod.sol";
import "../interfaces/ITokenHub.sol";

/**
 * @title EnhancedBitcoinPod
 * @notice A Bitcoin custody pod with token management and yield strategy capabilities
 * @dev Implements IBitcoinPod interface and extends FeeManager for role-based access control and fee management
 */
contract EnhancedBitcoinPod is 
    Initializable, 
    FeeManager, 
    PausableUpgradeable,
    IBitcoinPod,
    IERC721ReceiverUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    
    // Pod state
    PodState public podState;
    bool public locked;
    string public bitcoinAddress;
    bytes public operatorBtcPubKey;
    
    // Bitcoin balance
    uint256 private _bitcoinBalance;
    
    // TokenHub integration
    address public tokenHub;
    address public podManager;
    bool public isDelegatedToTokenHub;
    
    // Token tracking
    IERC20Upgradeable public motifBitcoin;
    uint256 public podShares;
    
    // Withdrawal transaction
    bytes private _signedBitcoinWithdrawTransaction;
    
    // Strategy registry
    mapping(address => bool) public approvedStrategies;
    
    // Events
    event TokenHubSet(address tokenHub);
    event PodManagerSet(address podManager);
    event TokenHubDelegated(address tokenHub);
    event TokenHubUndelegated();
    event SharesUpdated(uint256 newShares);
    event TokensTransferred(address indexed to, uint256 amount);
    event StrategyApproved(address indexed strategy, bool approved);
    event YieldReported(uint256 amount);
    event TokensRecovered(address indexed token, address indexed recipient, uint256 amount);
    event ERC721Recovered(address indexed token, address indexed recipient, uint256 tokenId);
    event BitcoinBalanceUpdated(uint256 newBalance);
    
    /**
     * @notice Initialize the EnhancedBitcoinPod
     * @param _admin Address of the pod admin
     * @param _owner Address of the pod owner
     * @param _operator Address of the pod operator
     * @param _operatorBtcPubKey Bitcoin public key of the operator
     * @param _bitcoinAddress Bitcoin address of the pod
     * @param _operatorFeeBP Operator fee in basis points
     * @param _curatorFeeBP Curator fee in basis points
     * @param _protocolFeeBP Protocol fee in basis points
     * @param _protocolFeeRecipient Address to receive protocol fees
     * @param _motifBitcoin Address of the MotifBitcoin token
     * @param _podManager Address of the pod manager
     */
    function initialize(
        address _admin,
        address _owner,
        address _operator,
        bytes memory _operatorBtcPubKey,
        string memory _bitcoinAddress,
        uint256 _operatorFeeBP,
        uint256 _curatorFeeBP,
        uint256 _protocolFeeBP,
        address _protocolFeeRecipient,
        address _motifBitcoin,
        address _podManager
    ) external initializer {
        __FeeManager_init(
            _admin, 
            _owner, 
            _operator, 
            _operatorFeeBP, 
            _curatorFeeBP, 
            _protocolFeeBP, 
            _protocolFeeRecipient
        );
        __Pausable_init();
        
        require(bytes(_bitcoinAddress).length > 0, "Bitcoin address cannot be empty");
        require(_operatorBtcPubKey.length > 0, "Operator BTC pubkey cannot be empty");
        require(_motifBitcoin != address(0), "MotifBitcoin cannot be zero address");
        require(_podManager != address(0), "PodManager cannot be zero address");
        
        bitcoinAddress = _bitcoinAddress;
        operatorBtcPubKey = _operatorBtcPubKey;
        podState = PodState.Active;
        locked = false;
        _bitcoinBalance = 0;
        isDelegatedToTokenHub = false;
        podShares = 0;
        motifBitcoin = IERC20Upgradeable(_motifBitcoin);
        podManager = _podManager;
        
        emit PodInitialized(address(this), _owner, _operator);
        emit PodManagerSet(_podManager);
    }
    
    /**
     * @notice Set the TokenHub address
     * @param _tokenHub Address of the TokenHub
     * @dev Only callable by admin or pod manager
     */
    function setTokenHub(address _tokenHub) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || 
            msg.sender == podManager, 
            "Not authorized"
        );
        require(_tokenHub != address(0), "TokenHub cannot be zero address");
        
        tokenHub = _tokenHub;
        emit TokenHubSet(_tokenHub);
    }
    
    /**
     * @notice Set the pod manager address
     * @param _podManager Address of the pod manager
     * @dev Only callable by admin
     */
    function setPodManager(address _podManager) external onlyRole(ADMIN_ROLE) {
        require(_podManager != address(0), "PodManager cannot be zero address");
        
        podManager = _podManager;
        emit PodManagerSet(_podManager);
    }
    
    /**
     * @notice Set delegation status to TokenHub
     * @param _isDelegated Whether the pod is delegated to TokenHub
     * @dev Only callable by pod manager
     */
    function setDelegationStatus(bool _isDelegated) external {
        require(msg.sender == podManager, "Only pod manager can delegate");
        
        isDelegatedToTokenHub = _isDelegated;
        
        if (_isDelegated) {
            emit TokenHubDelegated(tokenHub);
        } else {
            emit TokenHubUndelegated();
        }
    }
    
    /**
     * @notice Mint motifBTC tokens
     * @param _recipient Address to receive the tokens
     * @return Amount of shares minted
     * @dev Only callable by owner or curator when delegated to TokenHub
     */
    function mintTokens(address _recipient) 
        external 
        whenNotPaused 
        returns (uint256) 
    {
        require(
            hasRole(OWNER_ROLE, msg.sender) || 
            hasRole(CURATOR_ROLE, msg.sender), 
            "Not authorized"
        );
        require(isDelegatedToTokenHub, "Not delegated to TokenHub");
        require(_bitcoinBalance > 0, "Amount must be greater than 0");
        require(_recipient != address(0), "Recipient cannot be zero address");

        // check if the pod is locked
        require(!locked, "Pod is locked");
       
        // Call TokenHub to mint tokens
        uint256 shares = ITokenHub(tokenHub).mintTokensForPod(
            address(this),  
            _recipient
        );
        
        // Update pod shares
        podShares += shares;
        emit SharesUpdated(podShares);
        
        return shares;
    }
    
    /**
     * @notice Burn motifBTC tokens
     * @param _shares Amount of shares to burn
     * @param _recipient Address to receive the Bitcoin (on Bitcoin network)
     * @return Amount of Bitcoin to be received
     * @dev Only callable by owner or curator when delegated to TokenHub
     */
    function burnTokens(uint256 _shares, address _recipient) 
        external 
        whenNotPaused 
        returns (uint256) 
    {
        require(
            hasRole(OWNER_ROLE, msg.sender) || 
            hasRole(CURATOR_ROLE, msg.sender) || 
            msg.sender == address(this), 
            "Not authorized"
        );
        require(isDelegatedToTokenHub, "Not delegated to TokenHub");
        require(_shares > 0, "Shares must be greater than 0");
        require(_recipient != address(0), "Recipient cannot be zero address");
        
        // If burning from pod's balance, check if we have enough
        if (msg.sender == address(this)) {
            require(_shares <= podShares, "Insufficient shares in pod");
            podShares -= _shares;
            emit SharesUpdated(podShares);
        }
        // check If the same amount of shares is burned as the bitcoin balance in the pod
        // Should be updated later. Assuming the motifBTC token is not rebased.
        require(_shares == _bitcoinBalance, "Shares burned do not match Bitcoin balance in pod");
        
        // Call TokenHub to burn tokens
        uint256 bitcoinAmount = ITokenHub(tokenHub).burnTokensForPod(
            address(this), 
            _shares, 
            _recipient
        );
        
        return bitcoinAmount;
    }
    
    /**
     * @notice Transfer motifBTC tokens from pod to recipient
     * @param _recipient Address to receive the tokens
     * @param _amount Amount of tokens to transfer
     * @dev Only callable by owner or curator
     */
    function transferTokens(address _recipient, uint256 _amount) 
        external 
        whenNotPaused 
    {
        require(
            hasRole(OWNER_ROLE, msg.sender) || 
            hasRole(CURATOR_ROLE, msg.sender), 
            "Not authorized"
        );
        require(_recipient != address(0), "Recipient cannot be zero address");
        require(_amount > 0, "Amount must be greater than 0");
        
        // Transfer tokens
        motifBitcoin.safeTransfer(_recipient, _amount);
        
        emit TokensTransferred(_recipient, _amount);
    }
    
    /**
     * @notice Approve or revoke a strategy
     * @param _strategy Address of the strategy
     * @param _approved Whether the strategy is approved
     * @dev Only callable by owner or curator
     */
    function approveStrategy(address _strategy, bool _approved) 
        external 
        whenNotPaused 
    {
        require(
            hasRole(OWNER_ROLE, msg.sender) || 
            hasRole(CURATOR_ROLE, msg.sender), 
            "Not authorized"
        );
        require(_strategy != address(0), "Strategy cannot be zero address");
        
        approvedStrategies[_strategy] = _approved;
        
        emit StrategyApproved(_strategy, _approved);
    }
    
    /**
     * @notice Report yield from a strategy
     * @param _yieldAmount Amount of yield generated
     * @dev Only callable by approved strategies or curator
     */
    function reportYield(uint256 _yieldAmount) 
        external 
        whenNotPaused 
    {
        require(
            approvedStrategies[msg.sender] || 
            hasRole(CURATOR_ROLE, msg.sender), 
            "Not authorized"
        );
        require(_yieldAmount > 0, "Yield must be greater than 0");
        
        // Accrue fees on yield
        _accrueFees(_yieldAmount);
        
        emit YieldReported(_yieldAmount);
    }
    
    /**
     * @notice Recover ERC20 tokens accidentally sent to this contract
     * @param _token Address of the token
     * @param _recipient Address to receive the tokens
     * @dev Only callable by admin
     */
    function recoverERC20(address _token, address _recipient) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(_recipient != address(0), "Recipient cannot be zero address");
        
        // Don't allow recovery of motifBitcoin unless in emergency
        if (_token == address(motifBitcoin)) {
            require(paused(), "Contract must be paused to recover motifBitcoin");
        }
        
        uint256 balance = IERC20Upgradeable(_token).balanceOf(address(this));
        IERC20Upgradeable(_token).safeTransfer(_recipient, balance);
        
        emit TokensRecovered(_token, _recipient, balance);
    }
    
    /**
     * @notice Recover ERC721 tokens accidentally sent to this contract
     * @param _token Address of the token
     * @param _tokenId ID of the token
     * @param _recipient Address to receive the token
     * @dev Only callable by admin
     */
    function recoverERC721(address _token, uint256 _tokenId, address _recipient) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(_recipient != address(0), "Recipient cannot be zero address");
        
        // Transfer the token
        IERC721Upgradeable(_token).safeTransferFrom(address(this), _recipient, _tokenId);
        
        emit ERC721Recovered(_token, _recipient, _tokenId);
    }
    
    /**
     * @notice Implementation of IERC721Receiver
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
    
    // IBitcoinPod Interface Implementation
    
    /**
     * @notice Sets the state of the pod
     * @param _newState The new state of the pod
     */
    function setPodState(PodState _newState) external override {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || 
            podManager == msg.sender, 
            "Not authorized"
        );
        
        PodState previousState = podState;
        podState = _newState;
        
        emit PodStateChanged(previousState, _newState);
    }
    
    /**
     * @notice Returns the Bitcoin address of the pod
     * @return The Bitcoin address
     */
    function getBitcoinAddress() external view override returns (string memory) {
        return bitcoinAddress;
    }
    
    /**
     * @notice Returns the Bitcoin public key of the operator
     * @return The Bitcoin public key
     */
    function getOperatorBtcPubKey() external view override returns (bytes memory) {
        return operatorBtcPubKey;
    }
    
    /**
     * @notice Returns the current Bitcoin balance
     * @return The Bitcoin balance
     */
    function getBitcoinBalance() external view override returns (uint256) {
        return _bitcoinBalance;
    }
    
    /**
     * @notice Returns the signed Bitcoin withdrawal transaction
     * @return The signed transaction
     */
    function getSignedBitcoinWithdrawTransaction() external view override returns (bytes memory) {
        return _signedBitcoinWithdrawTransaction;
    }
    
    /**
     * @notice Sets the signed Bitcoin withdrawal transaction
     * @param _signedBitcoinWithdrawTx The signed transaction
     */
    function setSignedBitcoinWithdrawTransaction(bytes memory _signedBitcoinWithdrawTx) 
        external 
        override 
        onlyRole(OPERATOR_ROLE) 
    {
        _signedBitcoinWithdrawTransaction = _signedBitcoinWithdrawTx;
        
        emit WithdrawTransactionSet(_signedBitcoinWithdrawTransaction);
    }
    
    /**
     * @notice Returns the current state of the pod
     * @return The pod state
     */
    function getPodState() external view override returns (PodState) {
        return podState;
    }
    
    /**
     * @notice Locks the pod
     */
    function lock() external override {
        require(
            tokenHub == msg.sender || 
            podManager == msg.sender, 
            "Only TokenHub or PodManager can lock"
        );
        
        locked = true;
        
        emit PodLocked(address(this));
    }
    
    /**
     * @notice Unlocks the pod
     */
    function unlock() external override {
        require(
            tokenHub == msg.sender || 
            podManager == msg.sender, 
            "Only TokenHub or PodManager can unlock"
        );
        
        locked = false;
        
        emit PodUnlocked(address(this));
    }
    
    /**
     * @notice Checks if the pod is locked
     * @return Whether the pod is locked
     */
    function isLocked() external view override returns (bool) {
        return locked;
    }
    
    /**
     * @notice Adds Bitcoin value to the pod
     * @param amount The amount to add
     */
    function mint(uint256 amount) external override {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || 
            podManager == msg.sender || 
            tokenHub == msg.sender, 
            "Not authorized"
        );
        require(amount > 0, "Amount must be greater than 0");
        
        _bitcoinBalance += amount;
        
        emit MintPodValue(address(this), amount);
        emit BitcoinBalanceUpdated(_bitcoinBalance);
    }
    
    /**
     * @notice Removes Bitcoin value from the pod
     * @param amount The amount to remove
     */
    function burn(uint256 amount) external override {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || 
            podManager == msg.sender || 
            tokenHub == msg.sender, 
            "Not authorized"
        );
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= _bitcoinBalance, "Insufficient balance");
        
        _bitcoinBalance -= amount;
        
        emit BurnPodValue(address(this), amount);
        emit BitcoinBalanceUpdated(_bitcoinBalance);
    }
    
    /**
     * @notice Get the operator
     * @return Operator address
     */
    function getOperator() external view override returns (address) {
        uint256 operatorCount = getRoleMemberCount(OPERATOR_ROLE);
        if (operatorCount == 0) {
            return address(0);
        }
        return getRoleMember(OPERATOR_ROLE, 0);
    }
    
    /**
     * @notice Transfer fees to recipient
     * @param _recipient Address to receive the fees
     * @param _amount Amount to transfer
     * @dev Implements the abstract function from FeeManager
     */
    function _transferFees(address _recipient, uint256 _amount) internal override {
        motifBitcoin.safeTransfer(_recipient, _amount);
    }
    
    /**
     * @notice Pause the pod
     * @dev Only callable by admin
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause the pod
     * @dev Only callable by admin
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[50] private __gap;
} 