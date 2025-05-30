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
    address public curator;
    address public registry;

    function initialize(address _curator, address _registry) external initializer {
        curator = _curator;
        registry = _registry;
    }

    /**
     * @notice Forward call to strategy through registry
     */
    function forward(address target, bytes calldata data) 
        external 
        returns (bytes memory) 
    {
        require(msg.sender == curator, "Only curator");
        return ICuratorRegistry(registry).forwardCall(curator, target, data);
    }

    /**
     * @notice Get the curator address. EOA or Gnosis Safe
     * @return Address of the curator
     */
    function curator() external view returns (address) {
        return curator;
    }

    /**
     * @notice Get the curator registry address
     * @return Address of the curator registry
     */
    function registry() external view returns (address) {
        return registry;
    }
}