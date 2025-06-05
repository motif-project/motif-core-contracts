// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface ITokenHub {
    /**
     * @notice Delegate a pod to the TokenHub
     * @param _podAddress Address of the pod to delegate
     */
    function delegatePodToTokenHub(address _podAddress) external;
    
    /**
     * @notice Undelegate a pod from the TokenHub
     * @param _podAddress Address of the pod to undelegate
     */
    function undelegatePodFromTokenHub(address _podAddress) external;
    
    /**
     * @notice Mint tokens for a pod
     * @param _podAddress Address of the pod
     * @param _recipient Address to receive the minted tokens
     * @return Amount of shares minted
     */
    function mintTokensForPod(address _podAddress, address _recipient) external returns (uint256);
    
    /**
     * @notice Burn tokens for a pod
     * @param _podAddress Address of the pod
     * @param _shares Amount of shares to burn
     * @param _owner Address of the token owner
     * @return Amount of Bitcoin released
     */
    function burnTokensForPod(address _podAddress, uint256 _shares, address _owner) external returns (uint256);
    
    /**
     * @notice Check if a pod is delegated
     * @param _podAddress Address of the pod
     * @return Whether the pod is delegated
     */
    function isPodDelegated(address _podAddress) external view returns (bool);
    
    /**
     * @notice Get shares for a pod
     * @param _podAddress Address of the pod
     * @return Number of shares
     */
    function getSharesForPod(address _podAddress) external view returns (uint256);
    
    /**
     * @notice Get shares by pooled Bitcoin
     * @param _bitcoinAmount Amount of Bitcoin in 8 decimals
     * @return Number of shares
     */
    function getSharesByPooledBitcoin(uint256 _bitcoinAmount) external view returns (uint256);
    
    /**
     * @notice Get total shares
     * @return Total shares
     */
    function getTotalShares() external view returns (uint256);
}