// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./RoleManager.sol";

/**
 * @title FeeManager
 * @notice Manages fee calculation and distribution for operators and curators
 * @dev Extends RoleManager to use role-based access control
 */
contract FeeManager is Initializable, RoleManager, ReentrancyGuardUpgradeable {
    // Constants
    uint256 public constant TOTAL_BASIS_POINTS = 10000;
    uint256 public constant MAX_FEE_BP = 3000; // 30% maximum fee
    
    // Fee configuration
    uint256 public operatorFeeBP;
    uint256 public curatorFeeBP;
    uint256 public protocolFeeBP;
    address public protocolFeeRecipient;
    
    // Fee accrual tracking
    uint256 public operatorAccruedFees;
    uint256 public curatorAccruedFees;
    uint256 public protocolAccruedFees;
    
    // Events
    event FeesUpdated(uint256 operatorFeeBP, uint256 curatorFeeBP, uint256 protocolFeeBP);
    event ProtocolFeeRecipientUpdated(address previousRecipient, address newRecipient);
    event FeesAccrued(uint256 operatorFees, uint256 curatorFees, uint256 protocolFees);
    event FeesClaimed(address indexed recipient, uint256 amount, string feeType);
    
    /**
     * @notice Initialize the FeeManager
     * @param _admin Address to receive admin role
     * @param _owner Address to receive owner role
     * @param _operator Address to receive operator role
     * @param _operatorFeeBP Operator fee in basis points
     * @param _curatorFeeBP Curator fee in basis points
     * @param _protocolFeeBP Protocol fee in basis points
     * @param _protocolFeeRecipient Address to receive protocol fees
     */
    function __FeeManager_init(
        address _admin,
        address _owner,
        address _operator,
        uint256 _operatorFeeBP,
        uint256 _curatorFeeBP,
        uint256 _protocolFeeBP,
        address _protocolFeeRecipient
    ) internal onlyInitializing {
        __RoleManager_init(_admin, _owner, _operator);
        __ReentrancyGuard_init();
        
        require(_operatorFeeBP + _curatorFeeBP + _protocolFeeBP <= MAX_FEE_BP, "Total fees too high");
        require(_protocolFeeRecipient != address(0), "Protocol fee recipient cannot be zero address");
        
        operatorFeeBP = _operatorFeeBP;
        curatorFeeBP = _curatorFeeBP;
        protocolFeeBP = _protocolFeeBP;
        protocolFeeRecipient = _protocolFeeRecipient;
        
        operatorAccruedFees = 0;
        curatorAccruedFees = 0;
        protocolAccruedFees = 0;
    }
    
    /**
     * @notice Update fee configuration
     * @param _operatorFeeBP New operator fee in basis points
     * @param _curatorFeeBP New curator fee in basis points
     * @param _protocolFeeBP New protocol fee in basis points
     * @dev Only callable by admin
     */
    function updateFees(
        uint256 _operatorFeeBP, 
        uint256 _curatorFeeBP, 
        uint256 _protocolFeeBP
    ) external onlyRole(ADMIN_ROLE) {
        require(_operatorFeeBP + _curatorFeeBP + _protocolFeeBP <= MAX_FEE_BP, "Total fees too high");
        
        operatorFeeBP = _operatorFeeBP;
        curatorFeeBP = _curatorFeeBP;
        protocolFeeBP = _protocolFeeBP;
        
        emit FeesUpdated(_operatorFeeBP, _curatorFeeBP, _protocolFeeBP);
    }
    
    /**
     * @notice Update protocol fee recipient
     * @param _protocolFeeRecipient New protocol fee recipient
     * @dev Only callable by admin
     */
    function updateProtocolFeeRecipient(address _protocolFeeRecipient) external onlyRole(ADMIN_ROLE) {
        require(_protocolFeeRecipient != address(0), "Protocol fee recipient cannot be zero address");
        
        address previousRecipient = protocolFeeRecipient;
        protocolFeeRecipient = _protocolFeeRecipient;
        
        emit ProtocolFeeRecipientUpdated(previousRecipient, _protocolFeeRecipient);
    }
    
    /**
     * @notice Accrue fees based on yield generated
     * @param _yieldAmount Amount of yield generated
     * @dev Called internally when yield is harvested
     */
    function _accrueFees(uint256 _yieldAmount) internal {
        if (_yieldAmount == 0) return;
        
        uint256 operatorFee = (_yieldAmount * operatorFeeBP) / TOTAL_BASIS_POINTS;
        uint256 curatorFee = (_yieldAmount * curatorFeeBP) / TOTAL_BASIS_POINTS;
        uint256 protocolFee = (_yieldAmount * protocolFeeBP) / TOTAL_BASIS_POINTS;
        
        operatorAccruedFees += operatorFee;
        curatorAccruedFees += curatorFee;
        protocolAccruedFees += protocolFee;
        
        emit FeesAccrued(operatorFee, curatorFee, protocolFee);
    }
    
    /**
     * @notice Claim accrued operator fees
     * @dev Only callable by operator
     */
    function claimOperatorFees() external nonReentrant onlyRole(OPERATOR_ROLE) {
        uint256 amount = operatorAccruedFees;
        require(amount > 0, "No fees to claim");
        
        operatorAccruedFees = 0;
        _transferFees(msg.sender, amount);
        
        emit FeesClaimed(msg.sender, amount, "operator");
    }
    
    /**
     * @notice Claim accrued curator fees
     * @dev Only callable by curator
     */
    function claimCuratorFees() external nonReentrant onlyRole(CURATOR_ROLE) {
        uint256 amount = curatorAccruedFees;
        require(amount > 0, "No fees to claim");
        
        curatorAccruedFees = 0;
        _transferFees(msg.sender, amount);
        
        emit FeesClaimed(msg.sender, amount, "curator");
    }
    
    /**
     * @notice Claim accrued protocol fees
     * @dev Only callable by admin
     */
    function claimProtocolFees() external nonReentrant onlyRole(ADMIN_ROLE) {
        uint256 amount = protocolAccruedFees;
        require(amount > 0, "No fees to claim");
        
        protocolAccruedFees = 0;
        _transferFees(protocolFeeRecipient, amount);
        
        emit FeesClaimed(protocolFeeRecipient, amount, "protocol");
    }
    
    /**
     * @notice Get total accrued fees
     * @return Total accrued fees (operator + curator + protocol)
     */
    function getTotalAccruedFees() external view returns (uint256) {
        return operatorAccruedFees + curatorAccruedFees + protocolAccruedFees;
    }
    
    /**
     * @notice Transfer fees to recipient
     * @param _recipient Address to receive the fees
     * @param _amount Amount to transfer
     * @dev Must be implemented by derived contracts
     */
    function _transferFees(address _recipient, uint256 _amount) internal virtual {
        // This is a placeholder that should be overridden by derived contracts
        // The implementation will depend on the token being used for fees
    }
    
    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[50] private __gap;
} 