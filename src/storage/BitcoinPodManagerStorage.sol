// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../interfaces/IBitcoinPodManager.sol";
/**
 * @title BitcoinPodManagerStorage
 * @notice Storage contract for BitcoinPodManager
 * @dev Contains all state variables used by BitcoinPodManager
 */

contract BitcoinPodManagerStorage {
    /// @notice Total number of pods created
    uint256 internal _totalPods;

    /// @notice Total Value Locked in all pods (in satoshis)
    uint256 internal _totalTVL;

    /// @notice Address of the BitDSMService manager contract
    address internal _bitDSMServiceManager;

    /// @notice Address of the App Registry contract
    address internal _appRegistry;

    /// @notice Address of the BitDSM Registry contract
    address internal _bitDSMRegistry;

    /// @notice Mapping of user address to their pod address
    mapping(address => address) internal _userToPod;

    /// @notice Mapping of pod address to the app address it is delegated to
    mapping(address => address) internal _podToApp;

    /// @notice Mapping of pod address to the Bitcoin deposit request
    mapping(address => IBitcoinPodManager.BitcoinDepositRequest) internal _podToBitcoinDepositRequest;

    /// @notice Mapping of pod address to the withdrawal address
    mapping(address => string) internal _podToWithdrawalAddress;

    /// @dev Gap for future storage variables
    uint256[50] private __gap;

    /// @dev Internal setters
    function _setUserPod(address user, address pod) internal {
        _userToPod[user] = pod;
    }

    function _setPodApp(address pod, address app) internal {
        _podToApp[pod] = app;
    }

    // ... other internal setters
}
