// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "../src/core/BitDSMRegistry.sol";
import {IDelegationManager} from "@eigenlayer/src/contracts/interfaces/IDelegationManager.sol";
import {
    Quorum,
    StrategyParams,
    IStrategy
} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistryEventsAndErrors.sol";

contract DeployBitDSMRegistry is Script {
    uint256 _deployerPrivateKey;
    address _delegationManagerAddress;
    address _serviceManagerAddress;
    Quorum _quorum;

    function _setup() internal {
        _deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        _delegationManagerAddress = vm.envAddress("DELEGATION_MANAGER");
        _serviceManagerAddress = vm.envAddress("SERVICE_MANAGER");
        address _strategyAddress = vm.envAddress("STRATEGY_ADDRESS");
        StrategyParams memory strategyParams =
            StrategyParams({strategy: IStrategy(_strategyAddress), multiplier: 10_000});
        _quorum.strategies.push(strategyParams);
    }

    function run() external {
        // setup the environment
        _setup();

        vm.startBroadcast(_deployerPrivateKey);
        // initialize the delegataion manager
        IDelegationManager _delegationManager = IDelegationManager(_delegationManagerAddress);

        BitDSMRegistry registry = new BitDSMRegistry(_delegationManager);
        // initialize the registry
        registry.initialize(_serviceManagerAddress, 0, _quorum);

        vm.stopBroadcast();

        console.log("BitDSMRegistry deployed at:", address(registry));
    }
}
