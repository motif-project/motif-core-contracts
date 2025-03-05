// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Script} from "forge-std/Script.sol";
import {MotifServiceManager} from "../../src/core/MotifServiceManager.sol";
import {console} from "forge-std/console.sol";

contract VerifyMetadataUpdate is Script {
    address constant _SERVICE_MANAGER_PROXY = 0xbf49e34a432EAaC181c7AA65b98A20d04353dadD;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        MotifServiceManager proxy = MotifServiceManager(_SERVICE_MANAGER_PROXY);

        // Verify owner
        address owner = proxy.owner();
        console.log("Contract owner:", owner);
        console.log("Deployer:", deployer);
        require(owner == deployer, "Not owner");

        vm.startBroadcast(deployerPrivateKey);

        // Update metadata
        proxy.updateAVSMetadataURI(
            "https://raw.githubusercontent.com/motif-project/motif-core-contracts/5779be5cfb5053472de74ce2cfda4643d96af556/assets/uri/avs_uri.json"
        );

        vm.stopBroadcast();

        console.log("Metadata URI updated successfully");
    }
}
