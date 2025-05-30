// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title ICuratorForwarder
 * @notice Interface for curator forwarder contracts
 */
interface ICuratorForwarder {
    /**
     * @notice Initialize the forwarder
     * @param _curator Address of the curator this forwarder represents
     * @param _registry Address of the curator registry
     */
    function initialize(address _curator, address _registry) external;

    /**
     * @notice Forward a call to a target contract through the registry
     * @param target Address of the target contract
     * @param data Call data to forward
     * @return Result of the forwarded call
     */
    function forward(address target, bytes calldata data) external returns (bytes memory);

    /**
     * @notice Get the curator address this forwarder represents
     * @return Address of the curator
     */
    function curator() external view returns (address);

    /**
     * @notice Get the registry address this forwarder uses
     * @return Address of the curator registry
     */
    function registry() external view returns (address);
}