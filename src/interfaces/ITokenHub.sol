// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface ITokenHub {
   
    
    function mintTokensForPod(address _podAddress, address _recipient) external returns (uint256);
    function burnTokensForPod(address _podAddress, uint256 _shares, address _owner) external returns (uint256);
    
    function isPodDelegated(address _podAddress) external view returns (bool);
   
}