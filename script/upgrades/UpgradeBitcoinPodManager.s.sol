// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {BitcoinPodManager} from "../../src/core/BitcoinPodManager.sol";
import {console} from "forge-std/console.sol";

contract UpgradeBitcoinPodManager is Script {
    uint256 deployerPrivateKey;
    address deployer;
    address constant _PROXY_ADMIN = 0xd8DE7ffD0F33e1149B8B902e41a17bb818c9f128;
    address constant _BITCOIN_POD_MANAGER_PROXY = 0x033253C94884fdeB529857a66D06047384164525;
    address constant _APP_REGISTRY = 0xe4FAb06cb45dE808894906146456c9f4D66Fad58;
    address constant _MOTIF_STAKE_REGISTRY = 0x83210B83d55fbCA44099972C358Bf8a4493352B1;
    address constant _SERVICE_MANAGER = 0xbf49e34a432EAaC181c7AA65b98A20d04353dadD;

    function upgradeBitcoinPodManager() public {
        // Deploy new implementation
        bitcoinPodManager = new BitcoinPodManager();

        bitcoinPodManager.initialize(_APP_REGISTRY, _MOTIF_STAKE_REGISTRY, _SERVICE_MANAGER);

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
