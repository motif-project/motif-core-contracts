// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {CuratorRegistry} from "../src/modules/CuratorRegistry.sol";
import {CuratorForwarder} from "../src/modules/CuratorForwarder.sol";
import {TokenHub} from "../src/modules/TokenHub.sol";
import {ReBTC} from "../src/token/reBTC.sol";
import {BitcoinPodManager} from "../src/core/BitcoinPodManager.sol";

// Comment This is a temporary script used to to deploy the newly introduced modules with the existing Holesky implementation 
// Using the existing Motif except BitcoinPodManager
// New implementation
// - CuratorRegistry
// - CuratorForwarder
// - TokenHub
// - reBTC ERC20 Token
// - BitcoinPodManager

contract DeployCuratorPodManager is Script {
    uint256 deployerPrivateKey;
    address deployer;
    address constant _PROXY_ADMIN = 0xd8DE7ffD0F33e1149B8B902e41a17bb818c9f128;
    address constant _APP_REGISTRY = 0xe4FAb06cb45dE808894906146456c9f4D66Fad58;
    address constant _MOTIF_STAKE_REGISTRY = 0x83210B83d55fbCA44099972C358Bf8a4493352B1;
    address constant _SERVICE_MANAGER = 0xbf49e34a432EAaC181c7AA65b98A20d04353dadD;
    
    function run() public {
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy CuratorForwarder implementation
        CuratorForwarder curatorForwarderImpl = new CuratorForwarder();
        console.log("CuratorForwarder implementation deployed at:", address(curatorForwarderImpl));

        // 2. Deploy CuratorRegistry
        CuratorRegistry curatorRegistryImpl = new CuratorRegistry(_APP_REGISTRY, address(curatorForwarderImpl));
        TransparentUpgradeableProxy curatorRegistryProxy = new TransparentUpgradeableProxy(
            address(curatorRegistryImpl), 
            _PROXY_ADMIN, 
            abi.encodeCall(CuratorRegistry.initialize, (deployer))
        );
        console.log("CuratorRegistry deployed at:", address(curatorRegistryProxy));

        // 3. Deploy reBTC
        ReBTC reBTCImpl = new ReBTC();
        TransparentUpgradeableProxy reBTCProxy = new TransparentUpgradeableProxy(
            address(reBTCImpl), 
            _PROXY_ADMIN, 
            abi.encodeCall(ReBTC.initialize, (deployer))
        );
        console.log("reBTC deployed at:", address(reBTCProxy));

        // 4. Deploy BitcoinPodManager WITHOUT TokenHub initially
        BitcoinPodManager podManagerImpl = new BitcoinPodManager();
        TransparentUpgradeableProxy podManagerProxy = new TransparentUpgradeableProxy(
            address(podManagerImpl),
            _PROXY_ADMIN,
            abi.encodeCall(
                BitcoinPodManager.initialize,
                (
                    _APP_REGISTRY,
                    _MOTIF_STAKE_REGISTRY,
                    _SERVICE_MANAGER,
                    address(0), // TokenHub address - set to 0 initially
                    address(curatorRegistryProxy)
                )
            )
        );
        console.log("BitcoinPodManager deployed at:", address(podManagerProxy));

        // 5. Deploy TokenHub with PodManager address
        TokenHub tokenHubImpl = new TokenHub();
        TransparentUpgradeableProxy tokenHubProxy = new TransparentUpgradeableProxy(
            address(tokenHubImpl),
            _PROXY_ADMIN,
            abi.encodeCall(
                TokenHub.initialize,
                (
                    address(reBTCProxy),
                    address(podManagerProxy),
                    deployer,
                    1000000e8, // maxTotalBitcoin (example: 10M BTC)
                    1 // minPodSize (example: 1 BTC)
                )
            )
        );
        console.log("TokenHub deployed at:", address(tokenHubProxy));

        // 6. Set TokenHub address in PodManager (two-phase initialization)
        BitcoinPodManager(address(podManagerProxy)).setTokenHub(address(tokenHubProxy));
        console.log("TokenHub address set in PodManager");

        // 7. Grant roles to TokenHub in reBTC (fix the role name here)
        // check if deployer has Admin role in reBTC
        if (ReBTC(address(reBTCProxy)).hasRole(ReBTC(address(reBTCProxy)).DEFAULT_ADMIN_ROLE(), deployer)) {
            bytes32 tokenhubRole = ReBTC(address(reBTCProxy)).TOKENHUB_ROLE();
            ReBTC(address(reBTCProxy)).grantRole(tokenhubRole, address(tokenHubProxy));
        } else {
            console.log("Deployer does not have DEFAULT_ADMIN_ROLE in reBTC");
        }
        
        console.log("TOKENHUB_ROLE granted to TokenHub");

        // 8. Bootstrap reBTC with initial liquidity
        ReBTC(address(reBTCProxy)).bootstrap();
        console.log("reBTC bootstrapped");

        console.log("\n=== Deployment Summary ===");
        console.log("CuratorRegistry:", address(curatorRegistryProxy));
        console.log("reBTC:", address(reBTCProxy));
        console.log("BitcoinPodManager:", address(podManagerProxy));
        console.log("TokenHub:", address(tokenHubProxy));

        vm.stopBroadcast();
    }
}

