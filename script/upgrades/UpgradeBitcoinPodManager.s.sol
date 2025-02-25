// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {BitcoinPodManager} from "../../src/core/BitcoinPodManager.sol";
import {console} from "forge-std/console.sol";

contract UpgradeBitcoinPodManager is Script {
    uint256 deployerPrivateKey;
    address deployer;
    address constant _PROXY_ADMIN = 0x71e4eFEcF796bBBC562f639ADde036784F67a563;
    address constant _BITCOIN_POD_MANAGER_PROXY = 0x3FAB0A58446da7a0703c0856A7c05abfa5a0F964;
    address constant _APP_REGISTRY = 0xD2a6d4e2F8FaF4Ee980be7Ff43Fb9e47b496b475;
    address constant _BITDSM_REGISTRY = 0x9619E0B51531ba2607d55422D66b14c570d5DE7a;
    address constant _SERVICE_MANAGER = 0x3E091B2318356b1AA1D5F0Bd846E956b48beB238;

    function upgradeBitcoinPodManager() public {
        // Deploy new implementation
        bitcoinPodManager = new BitcoinPodManager();

        bitcoinPodManager.initialize(_APP_REGISTRY, _BITDSM_REGISTRY, _SERVICE_MANAGER);

        // initialize the new implementation

        bytes memory upgradeCallData =
            abi.encodeWithSignature("upgrade(address,address)", _BITCOIN_POD_MANAGER_PROXY, address(bitcoinPodManager));

        // Call upgrade on proxy admin
        (bool success,) = _PROXY_ADMIN.call(upgradeCallData);
        require(success, "Upgrade failed");
        // display the new implementation address
        console.log("BitcoinPodManager upgraded successfully");
        console.log("New implementation address: %s", address(bitcoinPodManager));
    }

    BitcoinPodManager public bitcoinPodManager;

    function run() external {
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        upgradeBitcoinPodManager();
        vm.stopBroadcast();
    }
}
