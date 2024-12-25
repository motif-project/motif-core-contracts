// script/DeployAppRegistry.s.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {AppRegistry} from "../src/core/AppRegistry.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployAppRegistry is Script {
    // Store deployed addresses in a json file
    // string constant CONFIG_PATH = "deployments/appregistry.json";

    // Your existing ProxyAdmin address
    address constant PROXY_ADMIN = 0x71e4eFEcF796bBBC562f639ADde036784F67a563; // Replace with your ProxyAdmin address

    struct Addresses {
        address implementation;
        address proxy;
    }

    function run() public returns (Addresses memory addresses) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Verify ProxyAdmin exists and deployer has admin rights
        ProxyAdmin proxyAdmin = ProxyAdmin(PROXY_ADMIN);
        require(proxyAdmin.owner() == deployer, "Deployer is not ProxyAdmin owner");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Implementation
        AppRegistry implementation = new AppRegistry();
        console.log("Implementation deployed at:", address(implementation));

        // 2. Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            AppRegistry.initialize.selector,
            deployer // initialOwner
        );

        // 3. Deploy Proxy using existing ProxyAdmin
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(implementation), PROXY_ADMIN, initData);
        console.log("Proxy deployed at:", address(proxy));

        // Store addresses
        addresses = Addresses({implementation: address(implementation), proxy: address(proxy)});

        // Save deployment addresses
        //string memory json = vm.serializeAddress("deployments", "implementation", address(implementation));
        //json = vm.serializeAddress("deployments", "proxy", address(proxy));
        //vm.writeJson(json, CONFIG_PATH);

        vm.stopBroadcast();
    }
}

// Separate script for upgrades
contract UpgradeAppRegistry is Script {
    //address constant PROXY_ADMIN = 0x71e4efecf796bbbc562f639adde036784f67a563;  // Same ProxyAdmin address

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Load existing proxy address
        string memory json = vm.readFile("script/bitdsm_addresses.json");
        address PROXY_ADMIN = abi.decode(vm.parseJson(json, ".ProxyAdmin"), (address));
        address proxy = abi.decode(vm.parseJson(json, ".AppRegistryProxy"), (address));

        // Verify ProxyAdmin ownership
        ProxyAdmin proxyAdmin = ProxyAdmin(PROXY_ADMIN);
        require(proxyAdmin.owner() == deployer, "Deployer is not ProxyAdmin owner");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy new implementation
        AppRegistry newImplementation = new AppRegistry();
        console.log("New implementation deployed at:", address(newImplementation));

        // 2. Upgrade proxy to new implementation
        proxyAdmin.upgrade(TransparentUpgradeableProxy(payable(proxy)), address(newImplementation));

        // Update json with new implementation
        //json = vm.serializeAddress("deployments", "implementation", address(newImplementation));
        //vm.writeJson(json, "deployments/appregistry.json");

        vm.stopBroadcast();
    }
}

// Optional: Script to verify current implementation
contract VerifyAppRegistry is Script {
    //address constant PROXY_ADMIN = 0x71e4efecf796bbbc562f639adde036784f67a563;  // Same ProxyAdmin address

    function run() public view {
        string memory json = vm.readFile("script/bitdsm_addresses.json");
        address PROXY_ADMIN = abi.decode(vm.parseJson(json, ".ProxyAdmin"), (address));
        address proxy = abi.decode(vm.parseJson(json, ".AppRegistryProxy"), (address));

        ProxyAdmin proxyAdmin = ProxyAdmin(PROXY_ADMIN);
        address currentImpl = proxyAdmin.getProxyImplementation(TransparentUpgradeableProxy(payable(proxy)));

        console.log("Current implementation:", currentImpl);
        console.log("Proxy address:", proxy);
        console.log("ProxyAdmin:", PROXY_ADMIN);
    }
}
