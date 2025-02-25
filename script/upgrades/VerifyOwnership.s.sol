// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Script} from "forge-std/Script.sol";
//import {BitDSMServiceManager} from "../src/core/BitDSMServiceManager.sol";
import {AppRegistry} from "../../src/core/AppRegistry.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {console} from "forge-std/console.sol";

contract VerifyOwnership is Script {
    address constant _PROXY_ADMIN = 0x71e4eFEcF796bBBC562f639ADde036784F67a563;
    //address constant _SERVICE_MANAGER_PROXY = 0xD2a6d4e2F8FaF4Ee980be7Ff43Fb9e47b496b475;
    address constant _APP_REGISTRY = 0xF4E2f70806628040C19BC041192Be7F2C798AA9E;

    function run() external view {
        // Get ProxyAdmin instance
        ProxyAdmin proxyAdmin = ProxyAdmin(_PROXY_ADMIN);

        // Get current implementation address
        address implementationAddr =
            proxyAdmin.getProxyImplementation(TransparentUpgradeableProxy(payable(_APP_REGISTRY)));

        // Get proxy instance (points to implementation logic)
        AppRegistry proxy = AppRegistry(_APP_REGISTRY);

        // Get implementation instance (direct access)
        AppRegistry implementation = AppRegistry(implementationAddr);

        // Check ownership
        console.log("ProxyAdmin owner:", proxyAdmin.owner());
        console.log("Proxy admin address:", _PROXY_ADMIN);
        console.log("Implementation address:", implementationAddr);
        console.log("Proxy contract address:", _APP_REGISTRY);

        // Check contract ownership (through proxy)
        console.log("Contract owner (through proxy):", proxy.owner());

        // Check implementation ownership (direct)
        console.log("Implementation owner:", implementation.owner());
    }
}
