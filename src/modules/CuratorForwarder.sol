// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interfaces/ICuratorRegistry.sol";
import "../interfaces/ICuratorForwarder.sol";

/**
 * @title CuratorForwarder
 * @notice Forwards curator calls through registry validation
 */
contract CuratorForwarder is Initializable {
    address public curatorAddress;
    address public registryAddress;

    function initialize(address _curator, address _registry) external initializer {
        curatorAddress = _curator;
        registryAddress = _registry;
    }

    /**
     * @notice Forward call to strategy through registry
     */
    function forward(address target, bytes calldata data) 
        external 
        returns (bytes memory) 
    {
        require(msg.sender == curatorAddress, "Only curator");
        return ICuratorRegistry(registryAddress).forwardCall(curatorAddress, target, data);
    }

    /**
     * @notice Get the curator address. EOA or Gnosis Safe
     * @return Address of the curator
     */
    function getCuratorAddress() external view returns (address) {
        return curatorAddress;
    }

    /**
     * @notice Get the curator registry address
     * @return Address of the curator registry
     */
    function getCuratorRegistryAddress() external view returns (address) {
        return registryAddress;
    }
}