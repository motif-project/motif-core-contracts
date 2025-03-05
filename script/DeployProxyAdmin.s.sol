// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {IAVSDirectory} from "@eigenlayer/src/contracts/interfaces/IAVSDirectory.sol";
import {IDelegationManager} from "@eigenlayer/src/contracts/interfaces/IDelegationManager.sol";
import {IRewardsCoordinator} from "@eigenlayer/src/contracts/interfaces/IRewardsCoordinator.sol";
import {MotifServiceManager} from "../src/core/MotifServiceManager.sol";
import {AppRegistry} from "../src/core/AppRegistry.sol";
import {BitcoinPodManager} from "../src/core/BitcoinPodManager.sol";
import {MotifStakeRegistry} from "../src/core/MotifStakeRegistry.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {
    Quorum,
    StrategyParams,
    IStrategy
} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistryEventsAndErrors.sol";

contract DeployProxyAdmin is Script {
    uint256 deployerPrivateKey;
    address deployer;

    function run() external {
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
       // deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy ProxyAdmin
        ProxyAdmin proxyAdmin = new ProxyAdmin();

        vm.stopBroadcast();

        console.log("ProxyAdmin deployed at:", address(proxyAdmin));
    }
}
