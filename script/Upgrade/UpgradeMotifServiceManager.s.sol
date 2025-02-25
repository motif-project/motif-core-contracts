// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {BitDSMServiceManager} from "../../src/core/BitDSMServiceManager.sol";
import {console} from "forge-std/console.sol";

contract UpgradeBitDSMServiceManager is Script {
    uint256 deployerPrivateKey;
    address deployer;
    address constant _PROXY_ADMIN = 0xBEccF8e2FdDC4b82bfC28Fb37997aBAE53E54082;
    address constant _BITCOIN_POD_MANAGER_PROXY = 0x3a8DF58c0B3D5A1d8f4D8046D8531A9433ee5255;
    address constant _SERVICE_MANAGER_PROXY = 0x3a2F63a724b42DeA06B548C81C3C219FE2529624;
    address constant _REWARDS_COORDINATOR = 0xAcc1fb458a1317E886dB376Fc8141540537E68fE;
    address constant _DELEGATION_MANAGER = 0xA44151489861Fe9e3055d95adC98FbD462B948e7;
    address constant _AVS_DIRECTORY = 0x055733000064333CaDDbC92763c58BF0192fFeBf;
    address constant _BITDSM_REGISTRY_PROXY = 0x2b50637B799e38Fc55596829DB1126A57681E012;

    function upgradeBitDSMServiceManager() public {
        // Deploy new implementation
        BitDSMServiceManager serviceManagerImpl =
            new BitDSMServiceManager(_AVS_DIRECTORY, _BITDSM_REGISTRY_PROXY, _REWARDS_COORDINATOR, _DELEGATION_MANAGER);
        // initialize the new implementation
        serviceManagerImpl.setBitcoinPodManager(_BITCOIN_POD_MANAGER_PROXY);

        bytes memory upgradeCallData =
            abi.encodeWithSignature("upgrade(address,address)", _SERVICE_MANAGER_PROXY, address(serviceManagerImpl));

        // Call upgrade on proxy admin
        (bool success,) = _PROXY_ADMIN.call(upgradeCallData);
        require(success, "Upgrade failed");
        // display the new implementation address
        console.log("BitDSMServiceManager upgraded successfully");
        console.log("New implementation address: %s", address(serviceManagerImpl));
    }

    function run() external {
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        upgradeBitDSMServiceManager();
        vm.stopBroadcast();
    }
}
