// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./BaseBitcoinPod.sol";

/**
 * @title BitcoinPod
 * @notice A contract that represents a Standard Bitcoin custody pod managed by a Client and an Operator
 * @dev Inherits core logic from BaseBitcoinPod and implements access control and initialization
 * @dev This contract handles Bitcoin deposits and withdrawals through a designated operator,
 * tracks balances, and manages pod locking/unlocking functionality
 * Key features:
 * - Links a Bitcoin address to an Ethereum address
 * - Tracks Bitcoin balances in the pod
 * - Allows only authorized operator actions
 * - Supports locking mechanism for security
 * - Manages withdrawal transaction storage
 *
 * Security considerations:
 * - Pod can be locked to prevent unauthorized withdrawals
 * - Manager contract has privileged access for administrative functions
 *
 * @dev Security assumptions:
 * - All state-modifying functions are only callable by the PodManager contract
 * - The PodManager is trusted and implements necessary security measures
 * - No direct external calls are made from these functions
 */
contract BitcoinPod is Initializable, BaseBitcoinPod, OwnableUpgradeable {
    /// @notice Address of the BitcoinPodManager contract that manages this pod
    address public manager;

    /**
     * @notice Modifier to ensure only the manager contract can perform an action
     */
    modifier onlyManager() override {
        require(msg.sender == manager, "Only manager can perform this action");
        _;
    }

    /**
     * @notice Initializes a new Bitcoin pod with the specified parameters
     * @param _owner Address that will own this pod contract
     * @param _operator Address of the designated operator who can perform sensitive actions
     * @param _operatorBtcPubKey Bitcoin public key of the operator for multisig address generation
     * @param _btcAddress Multisig Bitcoin address associated with this pod
     * @dev Sets initial state:
     * - Transfers ownership to _owner
     * - Sets operator and their BTC public key
     * - Sets the pod's Bitcoin address
     * - Initializes pod as unlocked and active
     */
    function initialize(
        address _manager,
        address _owner,
        address _operator,
        bytes memory _operatorBtcPubKey,
        string memory _btcAddress
    ) external initializer {
        require(_operatorBtcPubKey.length > 0, "Operator BTC public key cannot be empty");
        require(bytes(_btcAddress).length > 0, "Bitcoin address cannot be empty");
        require(_operator != address(0), "Operator cannot be the zero address");
        require(_owner != address(0), "Owner cannot be the zero address");
        require(_manager != address(0), "Manager address cannot be zero");
        require(_manager != msg.sender, "Manager cannot be the pod itself");
        
        __Ownable_init();
        __ReentrancyGuard_init();
        _transferOwnership(_owner);
        // ...Base initializers...
        __BaseBitcoinPod_init(_operator, _operatorBtcPubKey, _btcAddress);
        manager = _manager;
        emit PodInitialized(address(this), _owner, _operator);
    }
}
