// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../interfaces/IBitcoinPod.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @title BaseBitcoinPod
 * @notice Abstract base contract for Bitcoin custody pods
 * @dev Implements core logic for BitcoinPod, with abstract access control and initialization
 */
abstract contract BaseBitcoinPod is IBitcoinPod, ReentrancyGuardUpgradeable {
    /// @notice Ethereum address of the operator
    address public operator;

    /// @notice Bitcoin public key of the operator
    bytes public operatorBtcPubKey;

    /// @notice Multisig Bitcoin address associated with this pod
    string public bitcoinAddress;

    /// @notice Current Bitcoin balance tracked in the pod
    uint256 public bitcoinBalance;

    /// @notice Pod lock status
    bool public locked;

    /// @notice Signed Bitcoin withdrawal transaction (PSBT or raw)
    bytes public signedBitcoinWithdrawTransaction;

    /// @notice Current state of the pod (Active/Inactive)
    PodState public podState;

    /// @dev Maximum allowed transaction size (100KB)
    uint256 private constant _MAX_TX_SIZE = 1024 * 100;


    /**
     * @notice Modifier to ensure only the manager contract can perform an action
     * @dev Must be implemented by the derived contract
     */
    modifier onlyManager() virtual;

    /** 
     * @notice Modifier to ensure the pod is active before execution
     */
    modifier onlyActive() {
        require(podState == PodState.Active, "Pod is not active");
        _;
    }

    /**
     * @notice Modifier to ensure the pod is not locked before execution
     */
    modifier lockedPod() {
        require(!locked, "Pod is locked");
        _;
    }


    /**
     *
     */
    function __BaseBitcoinPod_init(
        address _operator,
        bytes memory _operatorBtcPubKey,
        string memory _bitcoinAddress
    ) internal onlyInitializing {
        operator = _operator;
        operatorBtcPubKey = _operatorBtcPubKey;
        bitcoinAddress = _bitcoinAddress;
        podState = PodState.Active;
    }

    /**
     * @notice Returns the Bitcoin address of the pod
     * @inheritdoc IBitcoinPod
     */
    function getBitcoinAddress() external view override returns (string memory) {
        return bitcoinAddress;
    }

    /**
     * @notice Returns the Bitcoin public key of the operator associated with this pod
     * @inheritdoc IBitcoinPod
     */
    function getOperatorBtcPubKey() external view override returns (bytes memory) {
        return operatorBtcPubKey;
    }

    /**
     * @notice Returns the Ethereum address of the operator associated with this pod
     * @inheritdoc IBitcoinPod
     */
    function getOperator() external view override returns (address) {
        return operator;
    }

    /**
     * @notice Returns the current Bitcoin balance tracked in the pod
     * @inheritdoc IBitcoinPod
     */
    function getBitcoinBalance() external view override returns (uint256) {
        return bitcoinBalance;
    }

    /**
     * @notice Returns the signed Bitcoin withdrawal transaction stored in the pod
     * @inheritdoc IBitcoinPod
     */
    function getSignedBitcoinWithdrawTransaction() external view override returns (bytes memory) {
        return signedBitcoinWithdrawTransaction;
    }

    /**
     * @notice Sets the signed Bitcoin withdrawal transaction in the pod
     * @dev Only callable by the manager
     * @param _signedBitcoinWithdrawTransaction The signed Bitcoin withdrawal transaction as a byte array
     */
    function setSignedBitcoinWithdrawTransaction(bytes memory _signedBitcoinWithdrawTransaction)
        external
        override
        onlyManager
        nonReentrant
    {
        require(_signedBitcoinWithdrawTransaction.length > 0, "Signed transaction cannot be empty");
        require(podState == PodState.Inactive, "Pod is not inactive");
        require(_signedBitcoinWithdrawTransaction.length <= _MAX_TX_SIZE, "Signed transaction exceeds max size");
        signedBitcoinWithdrawTransaction = _signedBitcoinWithdrawTransaction;
        emit WithdrawTransactionSet(_signedBitcoinWithdrawTransaction);
    }

    /**
     * @notice Sets the state of the pod
     * @dev Only callable by the manager
     * @param _newState The new state of the pod
     */
    function setPodState(PodState _newState) external override onlyManager nonReentrant {
        require(_isValidStateTransition(podState, _newState), "Invalid state transition");
        PodState previousState = podState;
        podState = _newState;
        emit PodStateChanged(previousState, _newState);
    }

    /**
     * @notice Locks the pod to prevent unauthorized withdrawals
     * @dev Only callable by the manager
     */
    function lock() external override onlyManager onlyActive lockedPod {
        locked = true;
        emit PodLocked(address(this));
    }

    /**
     * @notice Unlocks the pod
     * @dev Only callable by the manager
     */
    function unlock() external override onlyManager {
        locked = false;
        emit PodUnlocked(address(this));
    }

    /**
     * @notice Returns whether the pod is locked
     * @inheritdoc IBitcoinPod
     */
    function isLocked() external view override returns (bool) {
        return locked;
    }

    /**
     * @notice Mints Bitcoin value into the pod
     * @dev Only callable by the manager
     * @param amount The amount to mint
     */
    function mint(uint256 amount) external override onlyManager onlyActive lockedPod nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        bitcoinBalance += amount;
        emit MintPodValue(address(this), amount);
    }

    /**
     * @notice Burns Bitcoin value from the pod
     * @dev Only callable by the manager
     * @param amount The amount to burn
     */
    function burn(uint256 amount) external override onlyManager lockedPod nonReentrant {
        require(podState == PodState.Inactive, "Pod is active");
        require(bitcoinBalance >= amount, "Insufficient balance");
        bitcoinBalance -= amount;
        emit BurnPodValue(address(this), amount);
    }

    /**
     * @notice Returns the current state of the pod
     * @inheritdoc IBitcoinPod
     */
    function getPodState() external view override returns (PodState) {
        return podState;
    }

    /**
     * @notice Checks if a state transition is valid
     * @param _from The current state
     * @param _to The new state
     * @return bool True if the transition is valid, false otherwise
     */
    function _isValidStateTransition(PodState _from, PodState _to) internal pure returns (bool) {
        return (_from == PodState.Active && _to == PodState.Inactive)
            || (_from == PodState.Inactive && _to == PodState.Active);
    }

    // storage gap
    uint256[50] private __gap;
}