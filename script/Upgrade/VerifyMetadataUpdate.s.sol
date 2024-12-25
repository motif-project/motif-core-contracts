// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Script} from "forge-std/Script.sol";
import {BitDSMServiceManager} from "../../src/core/BitDSMServiceManager.sol";
import {console} from "forge-std/console.sol";

contract VerifyMetadataUpdate is Script {
    address constant _SERVICE_MANAGER_PROXY = 0x3E091B2318356b1AA1D5F0Bd846E956b48beB238;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        BitDSMServiceManager proxy = BitDSMServiceManager(_SERVICE_MANAGER_PROXY);

        // Verify owner
        address owner = proxy.owner();
        console.log("Contract owner:", owner);
        console.log("Deployer:", deployer);
        require(owner == deployer, "Not owner");

        vm.startBroadcast(deployerPrivateKey);

        // Update metadata
        proxy.updateAVSMetadataURI(
            "https://raw.githubusercontent.com/BitDSM/BitDSM/refs/heads/implement-v1-ecdsa/script/uri/avs_uri.json"
        );

        vm.stopBroadcast();

        console.log("Metadata URI updated successfully");
    }
}
