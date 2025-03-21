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
    PausableUpgradeable,
    FeeManager,
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
    event BitcoinBalanceUpdated(uint256 newBalance);
    event ERC20Recovered(address indexed token, address indexed to, uint256 amount);
    event ERC721Recovered(address indexed token, address indexed to, uint256 tokenId);
    
    /**
     * @notice Initialize the EnhancedBitcoinPod
     * @param _admin Address of the admin
     * @param _owner Address of the owner
     * @param _operator Address of the operator
     * @param _operatorBtcPubKey Bitcoin public key of the operator
     * @param _bitcoinAddress Bitcoin address of the pod
     * @param _operatorFeeBP Operator fee in basis points
     * @param _curatorFeeBP Curator fee in basis points
     * @param _protocolFeeBP Protocol fee in basis points
     * @param _protocolFeeRecipient Address to receive protocol fees
     * @param _motifBitcoin Address of the MotifBitcoin token
     * @param _podManager Address of the BitcoinPodManager
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
        require(_admin != address(0), "Admin cannot be zero address");
        require(_owner != address(0), "Owner cannot be zero address");
        require(_operator != address(0), "Operator cannot be zero address");
        require(_operatorBtcPubKey.length > 0, "Operator BTC public key cannot be empty");
        require(bytes(_bitcoinAddress).length > 0, "Bitcoin address cannot be empty");
        require(_motifBitcoin != address(0), "MotifBitcoin cannot be zero address");
        require(_podManager != address(0), "PodManager cannot be zero address");
        
        __Pausable_init();
        __FeeManager_init(_admin, _owner, _operator, _operatorFeeBP, _curatorFeeBP, _protocolFeeBP, _protocolFeeRecipient);
        
        // Set roles
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _owner);
        _grantRole(OPERATOR_ROLE, _operator);
        
        // Set pod state
        podState = PodState.Active;
        locked = false;
        bitcoinAddress = _bitcoinAddress;
        operatorBtcPubKey = _operatorBtcPubKey;
        
        // Set token
        motifBitcoin = IERC20Upgradeable(_motifBitcoin);
        
        // Set pod manager
        podManager = _podManager;
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
    function getOperatorBtcPubKey() external view returns (bytes memory) {
        return operatorBtcPubKey;
    }
    function isLocked() external view returns (bool) {
        return locked;
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
        require(_recipient != address(0), "Recipient cannot be zero address");

        // check if the pod is locked
        require(!locked, "Pod is locked");
       
        // Call TokenHub to mint tokens
        uint256 shares = ITokenHub(tokenHub).mintTokensForPod(
            address(this),  
            _recipient
        );
        // lock the pod after minting tokens 
        locked = true;
        emit PodLocked(address(this));
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
        // unlock the pod after burning tokens 
        locked = false;
        emit PodUnlocked(address(this));
        return bitcoinAmount;
    }
    /**
     * @notice Set delegation status to TokenHub
     * @param _isDelegated Whether the pod is delegated to TokenHub
     * @dev Only callable by pod manager
     */
    function setDelegationStatus(bool _isDelegated) external {
        require(msg.sender == podManager, "Only pod manager can delegate");
        require(tokenHub != address(0), "TokenHub not set");
        
        // Update internal state
        isDelegatedToTokenHub = _isDelegated;
        
        // Emit appropriate event
        if (_isDelegated) {
            emit TokenHubDelegated(tokenHub);
        } else {
            emit TokenHubUndelegated();
        }
    }
    
    // @inheritdoc IBitcoinPod
    function lock() external override {
        require(
            msg.sender == podManager, 
            "Only Pod Manager can lock"
        );
        require(podState == PodState.Active, "Pod is not active");
        locked = true;
        emit PodLocked(address(this));
    }
    
    // @inheritdoc IBitcoinPod
    function unlock() external override {
        require(
            msg.sender == podManager,
            "Only Pod Manager can unlock"
        );
        require(podState == PodState.Active, "Pod is not active");
        locked = false;
        emit PodUnlocked(address(this));
    }
    
    /**
     * @notice Approve a strategy
     * @param _strategy Address of the strategy
     * @param _approved Whether the strategy is approved
     * @dev Only callable by admin
     */
    function approveStrategy(address _strategy, bool _approved) external onlyRole(ADMIN_ROLE) {
        require(_strategy != address(0), "Strategy cannot be zero address");
        
        approvedStrategies[_strategy] = _approved;
        
        emit StrategyApproved(_strategy, _approved);
    }
    
    /**
     * @notice Transfer tokens to a strategy
     * @param _strategy Address of the strategy
     * @param _amount Amount of tokens to transfer
     * @dev Only callable by admin or operator
     * @dev Pod must not be locked
     */
    function transferToStrategy(address _strategy, uint256 _amount) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || 
            hasRole(OPERATOR_ROLE, msg.sender), 
            "Not authorized"
        );
        require(!locked, "Pod is locked");
        require(approvedStrategies[_strategy], "Strategy not approved");
        require(_amount > 0, "Amount must be greater than 0");
        
        // Transfer tokens to strategy
        motifBitcoin.safeTransfer(_strategy, _amount);
        
        emit TokensTransferred(_strategy, _amount);
    }
    
    /**
     * @notice Report yield from a strategy
     * @param _amount Amount of yield
     * @dev Only callable by approved strategies or admin/curator
     */
    function reportYield(uint256 _amount) external whenNotPaused nonReentrant {
        require(
            approvedStrategies[msg.sender] || 
            hasRole(ADMIN_ROLE, msg.sender) || 
            hasRole(CURATOR_ROLE, msg.sender), 
            "Not authorized"
        );
        require(_amount > 0, "Amount must be greater than 0");
        // update the fee manager
        _accrueFees(_amount);
        
        
        emit YieldReported(_amount);
    }
    
    /**
     * @notice Recover ERC20 tokens
     * @param _token Address of the token
     * @param _to Address to send the tokens to
     * @param _amount Amount of tokens to recover
     * @dev Only callable by admin
     * @dev Cannot recover motifBitcoin unless paused
     */
    function recoverERC20(address _token, address _to, uint256 _amount) external onlyRole(ADMIN_ROLE) {
        require(_to != address(0), "Cannot recover to zero address");
        require(_amount > 0, "Amount must be greater than 0");
        
        // If token is motifBitcoin, only allow recovery when paused
        if (_token == address(motifBitcoin)) {
            require(paused(), "Must be paused to recover motifBitcoin");
        }
        
        IERC20Upgradeable(_token).safeTransfer(_to, _amount);
        
        emit ERC20Recovered(_token, _to, _amount);
    }
    
    /**
     * @notice Recover ERC721 tokens
     * @param _token Address of the token
     * @param _to Address to send the token to
     * @param _tokenId ID of the token to recover
     * @dev Only callable by admin
     */
    function recoverERC721(address _token, address _to, uint256 _tokenId) external onlyRole(ADMIN_ROLE) {
        require(_to != address(0), "Cannot recover to zero address");
        
        IERC721Upgradeable(_token).safeTransferFrom(address(this), _to, _tokenId);
        
        emit ERC721Recovered(_token, _to, _tokenId);
    }
    
    /**
     * @notice Get the Bitcoin balance
     * @return Bitcoin balance
     */
    function getBitcoinBalance() external view override returns (uint256) {
        return _bitcoinBalance;
    }
    
    /**
     * @notice Get the pod state
     * @return Pod state
     */
    function getPodState() external view override returns (PodState) {
        return podState;
    }
    
    /**
     * @notice Get the Bitcoin address
     * @return Bitcoin address
     */
    function getBitcoinAddress() external view override returns (string memory) {
        return bitcoinAddress;
    }
    
    /**
     * @notice Get the signed Bitcoin withdrawal transaction
     * @return Signed Bitcoin withdrawal transaction
     */
    function getSignedBitcoinWithdrawTransaction() external view override returns (bytes memory) {
        return _signedBitcoinWithdrawTransaction;
    }
    
    /**
     * @notice Set the signed Bitcoin withdrawal transaction
     * @param signedTransaction Signed Bitcoin withdrawal transaction
     */
    function setSignedBitcoinWithdrawTransaction(bytes calldata signedTransaction) external override {
        require(
            hasRole(OPERATOR_ROLE, msg.sender), 
            "Only operator can set signed transaction"
        );
        
        _signedBitcoinWithdrawTransaction = signedTransaction;
    }
    
    /**
     * @notice Set the pod state
     * @param state New pod state
     */
    function setPodState(PodState state) external override {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || 
            msg.sender == podManager, 
            "Not authorized"
        );
        
        podState = state;
    }
    
    /**
     * @notice Adds Bitcoin value to the pod
     * @param amount The amount to add
     */
    function mint(uint256 amount) external override {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || 
            msg.sender == podManager, 
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
            msg.sender == podManager, 
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
    function getOperator() external view override (RoleManager, IBitcoinPod) returns (address) {
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
     * @notice ERC721 receiver function
     * @dev Required for ERC721 token recovery
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
    
    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[50] private __gap;
} 