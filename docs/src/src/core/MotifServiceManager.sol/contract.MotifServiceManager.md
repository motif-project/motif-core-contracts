# MotifServiceManager
[Git Source](https://github.com/motif-project/motif-core-contracts/blob/2d5ca1db3b104b68bfb25c8e4e92709909e5d1c7/src/core/MotifServiceManager.sol)

**Inherits:**
ECDSAServiceManagerBase, [IMotifServiceManager](/src/interfaces/IMotifServiceManager.sol/interface.IMotifServiceManager.md)

Extends ECDSAServiceManagerBase to handle Bitcoin pod operations and deposits
Key components:
- Manages Bitcoin pod operations through IBitcoinPodManager
- Handles deposit confirmations from operators
- Integrates with EigenLayer for staking and delegation
Dependencies:
- ECDSAServiceManagerBase: Base contract for ECDSA service management
- IBitcoinPodManager: Interface for Bitcoin pod management
- IMotifStakeRegistry: Registry interface for Motif services and handling EigenLayer staking and delegation

*This contract manages Bitcoin DSM (Decentralized Service Manager) operations*


## State Variables
### _bitcoinPodManager

```solidity
IBitcoinPodManager private _bitcoinPodManager;
```


### _usedSignatures

```solidity
mapping(bytes32 => bool) private _usedSignatures;
```


### MAX_PSBT_OUTPUTS

```solidity
uint256 private constant MAX_PSBT_OUTPUTS = 10;
```


## Functions
### onlyPodOperator

Modifier to ensure only the pod operator can call the function


```solidity
modifier onlyPodOperator(address pod);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|The address of the Bitcoin pod|


### constructor

Constructor for MotifServiceManager contract

*Initializes the contract with required dependencies from EigenLayer and Motif*


```solidity
constructor(address _avsDirectory, address _motifStakeRegistry, address _rewardsCoordinator, address _delegationManager)
    ECDSAServiceManagerBase(_avsDirectory, _motifStakeRegistry, _rewardsCoordinator, _delegationManager);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_avsDirectory`|`address`|Address of the EigenLayer AVS Directory contract|
|`_motifStakeRegistry`|`address`|Address of the Motif Stake Registry contract for operator management|
|`_rewardsCoordinator`|`address`|Address of the rewards coordinator contract|
|`_delegationManager`|`address`|Address of EigenLayer's delegation manager contract|


### initialize

Initializes the MotifServiceManager contract


```solidity
function initialize(address _owner, address _rewardsInitiator, address bitcoinPodManager) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|Address of the owner of the contract|
|`_rewardsInitiator`|`address`|Address of the rewards initiator|
|`bitcoinPodManager`|`address`|Address of the BitcoinPodManager contract|


### setBitcoinPodManager

Set the BitcoinPodManager contract address


```solidity
function setBitcoinPodManager(address bitcoinPodManager) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`bitcoinPodManager`|`address`|The address of the BitcoinPodManager contract|


### getBitcoinPodManager

Get the BitcoinPodManager contract address


```solidity
function getBitcoinPodManager() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the BitcoinPodManager contract|


### confirmDeposit

Confirms a Bitcoin chain deposit by verifying operator signature and updating pod state

*Only callable by the operator assigned to the pod*


```solidity
function confirmDeposit(address pod, bytes calldata signature) external onlyPodOperator(pod);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|Address of the Bitcoin pod receiving the deposit|
|`signature`|`bytes`|Operator's signature over the deposit confirmation message|


### withdrawBitcoinPSBT

Aids in processing a Bitcoin withdrawal by storing signed PSBT transaction created by the operator

*Only callable by the operator assigned to the pod*


```solidity
function withdrawBitcoinPSBT(address pod, uint256 amount, bytes calldata psbtTransaction, bytes calldata signature)
    external
    onlyPodOperator(pod);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|Address of the Bitcoin pod processing the withdrawal|
|`amount`|`uint256`|Amount of Bitcoin being withdrawn|
|`psbtTransaction`|`bytes`|Partially Signed Bitcoin Transaction (PSBT) data created by the operator|
|`signature`|`bytes`|Operator's signature over the withdrawal data|


### withdrawBitcoinCompleteTx

Aids in completing a Bitcoin withdrawal by processing the final transaction signed by the operator

*Only callable by the operator assigned to the pod*


```solidity
function withdrawBitcoinCompleteTx(address pod, uint256 amount, bytes calldata completeTx, bytes calldata signature)
    external
    onlyPodOperator(pod);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|Address of the Bitcoin pod processing the withdrawal|
|`amount`|`uint256`|Amount of Bitcoin being withdrawn|
|`completeTx`|`bytes`|Complete Bitcoin transaction data signed by the operator|
|`signature`|`bytes`|Operator's signature over the complete transaction|


### confirmWithdrawal

Confirms a Bitcoin chain withdrawal on by verifying operator signature and updating pod state

*Only callable by the operator assigned to the pod*


```solidity
function confirmWithdrawal(address pod, bytes calldata transaction, bytes calldata signature)
    external
    onlyPodOperator(pod);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|Address of the Bitcoin pod processing the withdrawal|
|`transaction`|`bytes`|Complete Bitcoin transaction data|
|`signature`|`bytes`|Operator's signature over the transaction data|


### _verifyPSBTOutputs

Verify if the PSBT outputs contain the correct withdraw address and amount

*Validates:
- Single matching output with exact amount
- Valid PSBT format and version*

*Reverts if:
- Invalid inputs*


```solidity
function _verifyPSBTOutputs(bytes calldata psbtBytes, string memory withdrawAddress, uint256 withdrawAmount)
    internal
    pure
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`psbtBytes`|`bytes`|The PSBT data to verify|
|`withdrawAddress`|`string`|The expected withdraw address|
|`withdrawAmount`|`uint256`|The expected withdraw amount|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if the PSBT outputs are correct, false otherwise|


