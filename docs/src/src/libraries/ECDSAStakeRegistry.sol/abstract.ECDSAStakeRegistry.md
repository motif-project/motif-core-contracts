# ECDSAStakeRegistry
[Git Source](https://github.com/motif-project/motif-core-contracts/blob/2d5ca1db3b104b68bfb25c8e4e92709909e5d1c7/src/libraries/ECDSAStakeRegistry.sol)

**Inherits:**
OwnableUpgradeable, IERC1271Upgradeable, ECDSAStakeRegistryStorage

Manages operator registration and quorum updates for an AVS using ECDSA signatures.

*THIS CONTRACT IS NOT AUDITED. The code is taken from eigenlayer-middleware repository tagged # v0.2.1.*

*This contract is reproduced here to make the contract Inheritable for operator register and deregister functions.*


## Functions
### constructor

*Constructor to create ECDSAStakeRegistry.*


```solidity
constructor(IDelegationManager _delegationManager) ECDSAStakeRegistryStorage(_delegationManager);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_delegationManager`|`IDelegationManager`|Address of the DelegationManager contract that this registry interacts with.|


### registerOperatorWithSignature

Registers a new operator using a provided signature


```solidity
function registerOperatorWithSignature() external virtual;
```

### deregisterOperator

Deregisters an existing operator


```solidity
function deregisterOperator() external virtual;
```

### updateOperatorSigningKey

Updates the signing key for an operator

*Only callable by the operator themselves*


```solidity
function updateOperatorSigningKey(address _newSigningKey) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newSigningKey`|`address`|The new signing key to set for the operator|


### updateOperators

Updates the StakeRegistry's view of one or more operators' stakes adding a new entry in their history of stake checkpoints,

*Queries stakes from the Eigenlayer core DelegationManager contract*


```solidity
function updateOperators(address[] memory _operators) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operators`|`address[]`|A list of operator addresses to update|


### updateQuorumConfig

Updates the quorum configuration and the set of operators

*Only callable by the contract owner.
It first updates the quorum configuration and then updates the list of operators.*


```solidity
function updateQuorumConfig(Quorum memory _quorum, address[] memory _operators) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_quorum`|`Quorum`|The new quorum configuration, including strategies and their new weights|
|`_operators`|`address[]`|The list of operator addresses to update stakes for|


### updateMinimumWeight

Updates the weight an operator must have to join the operator set

*Access controlled to the contract owner*


```solidity
function updateMinimumWeight(uint256 _newMinimumWeight, address[] memory _operators) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newMinimumWeight`|`uint256`|The new weight an operator must have to join the operator set|
|`_operators`|`address[]`||


### updateStakeThreshold

Sets a new cumulative threshold weight for message validation by operator set signatures.

*This function can only be invoked by the owner of the contract. It delegates the update to
an internal function `_updateStakeThreshold`.*


```solidity
function updateStakeThreshold(uint256 _thresholdWeight) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_thresholdWeight`|`uint256`|The updated threshold weight required to validate a message. This is the cumulative weight that must be met or exceeded by the sum of the stakes of the signatories for a message to be deemed valid.|


### isValidSignature

Verifies if the provided signature data is valid for the given data hash.


```solidity
function isValidSignature(bytes32 _dataHash, bytes memory _signatureData) external view returns (bytes4);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_dataHash`|`bytes32`|The hash of the data that was signed.|
|`_signatureData`|`bytes`|Encoded signature data consisting of an array of operators, an array of signatures, and a reference block number.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes4`|The function selector that indicates the signature is valid according to ERC1271 standard.|


### quorum

Retrieves the current stake quorum details.


```solidity
function quorum() external view returns (Quorum memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Quorum`|Quorum - The current quorum of strategies and weights|


### getLastestOperatorSigningKey

Retrieves the latest signing key for a given operator.


```solidity
function getLastestOperatorSigningKey(address _operator) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operator`|`address`|The address of the operator.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The latest signing key of the operator.|


### getOperatorSigningKeyAtBlock

Retrieves the latest signing key for a given operator at a specific block number.


```solidity
function getOperatorSigningKeyAtBlock(address _operator, uint256 _blockNumber) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operator`|`address`|The address of the operator.|
|`_blockNumber`|`uint256`|The block number to get the operator's signing key.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The signing key of the operator at the given block.|


### getLastCheckpointOperatorWeight

Retrieves the last recorded weight for a given operator.


```solidity
function getLastCheckpointOperatorWeight(address _operator) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operator`|`address`|The address of the operator.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 - The latest weight of the operator.|


### getLastCheckpointTotalWeight

Retrieves the last recorded total weight across all operators.


```solidity
function getLastCheckpointTotalWeight() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 - The latest total weight.|


### getLastCheckpointThresholdWeight

Retrieves the last recorded threshold weight


```solidity
function getLastCheckpointThresholdWeight() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 - The latest threshold weight.|


### getOperatorWeightAtBlock

Retrieves the operator's weight at a specific block number.


```solidity
function getOperatorWeightAtBlock(address _operator, uint32 _blockNumber) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operator`|`address`|The address of the operator.|
|`_blockNumber`|`uint32`|The block number to get the operator weight for the quorum|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 - The weight of the operator at the given block.|


### getLastCheckpointTotalWeightAtBlock

Retrieves the total weight at a specific block number.


```solidity
function getLastCheckpointTotalWeightAtBlock(uint32 _blockNumber) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_blockNumber`|`uint32`|The block number to get the total weight for the quorum|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 - The total weight at the given block.|


### getLastCheckpointThresholdWeightAtBlock

Retrieves the threshold weight at a specific block number.


```solidity
function getLastCheckpointThresholdWeightAtBlock(uint32 _blockNumber) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_blockNumber`|`uint32`|The block number to get the threshold weight for the quorum|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 - The threshold weight the given block.|


### operatorRegistered


```solidity
function operatorRegistered(address _operator) external view returns (bool);
```

### minimumWeight

Returns the weight an operator must have to contribute to validating an AVS


```solidity
function minimumWeight() external view returns (uint256);
```

### getOperatorWeight

Calculates the current weight of an operator based on their delegated stake in the strategies considered in the quorum


```solidity
function getOperatorWeight(address _operator) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operator`|`address`|The address of the operator.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 - The current weight of the operator; returns 0 if below the threshold.|


### __ECDSAStakeRegistry_init

Initializes state for the StakeRegistry


```solidity
function __ECDSAStakeRegistry_init(address _serviceManagerAddr, uint256 _thresholdWeight, Quorum memory _quorum)
    internal
    onlyInitializing;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_serviceManagerAddr`|`address`|The AVS' ServiceManager contract's address|
|`_thresholdWeight`|`uint256`||
|`_quorum`|`Quorum`||


### updateOperatorsForQuorum

Updates the set of operators for the first quorum.

*This interface maintains compatibility with avs-sync which handles multiquorums while this registry has a single quorum*


```solidity
function updateOperatorsForQuorum(address[][] memory operatorsPerQuorum, bytes memory) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operatorsPerQuorum`|`address[][]`|An array of operator address arrays, one for each quorum.|
|`<none>`|`bytes`||


### _updateAllOperators

*Updates the list of operators if the provided list has the correct number of operators.
Reverts if the provided list of operators does not match the expected total count of operators.*


```solidity
function _updateAllOperators(address[] memory _operators) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operators`|`address[]`|The list of operator addresses to update.|


### _updateOperators

*Updates the weights for a given list of operator addresses.
When passing an operator that isn't registered, then 0 is added to their history*


```solidity
function _updateOperators(address[] memory _operators) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operators`|`address[]`|An array of addresses for which to update the weights.|


### _updateStakeThreshold

*Updates the stake threshold weight and records the history.*


```solidity
function _updateStakeThreshold(uint256 _thresholdWeight) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_thresholdWeight`|`uint256`|The new threshold weight to set and record in the history.|


### _updateMinimumWeight

*Updates the weight an operator must have to join the operator set*


```solidity
function _updateMinimumWeight(uint256 _newMinimumWeight) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newMinimumWeight`|`uint256`|The new weight an operator must have to join the operator set|


### _updateQuorumConfig

Updates the quorum configuration

*Replaces the current quorum configuration with `_newQuorum` if valid.
Reverts with `InvalidQuorum` if the new quorum configuration is not valid.
Emits `QuorumUpdated` event with the old and new quorum configurations.*


```solidity
function _updateQuorumConfig(Quorum memory _newQuorum) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newQuorum`|`Quorum`|The new quorum configuration to set.|


### _deregisterOperator

*Internal function to deregister an operator*


```solidity
function _deregisterOperator(address _operator) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operator`|`address`|The operator's address to deregister|


### _registerOperatorWithSig

*registers an operator through a provided signature*


```solidity
function _registerOperatorWithSig(
    address _operator,
    ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature,
    address _signingKey
) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operator`|`address`||
|`_operatorSignature`|`ISignatureUtils.SignatureWithSaltAndExpiry`|Contains the operator's signature, salt, and expiry|
|`_signingKey`|`address`|The signing key to add to the operator's history|


### _updateOperatorSigningKey

*Internal function to update an operator's signing key*


```solidity
function _updateOperatorSigningKey(address _operator, address _newSigningKey) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operator`|`address`|The address of the operator to update the signing key for|
|`_newSigningKey`|`address`|The new signing key to set for the operator|


### _updateOperatorWeight

Updates the weight of an operator and returns the previous and current weights.


```solidity
function _updateOperatorWeight(address _operator) internal virtual returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operator`|`address`|The address of the operator to update the weight of.|


### _updateTotalWeight

*Internal function to update the total weight of the stake*


```solidity
function _updateTotalWeight(int256 delta) internal returns (uint256 oldTotalWeight, uint256 newTotalWeight);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`delta`|`int256`|The change in stake applied last total weight|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`oldTotalWeight`|`uint256`|The weight before the update|
|`newTotalWeight`|`uint256`|The updated weight after applying the delta|


### _isValidQuorum

*Verifies that a specified quorum configuration is valid. A valid quorum has:
1. Weights that sum to exactly 10,000 basis points, ensuring proportional representation.
2. Unique strategies without duplicates to maintain quorum integrity.*


```solidity
function _isValidQuorum(Quorum memory _quorum) internal pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_quorum`|`Quorum`|The quorum configuration to be validated.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if the quorum configuration is valid, otherwise false.|


### _checkSignatures

Common logic to verify a batch of ECDSA signatures against a hash, using either last stake weight or at a specific block.


```solidity
function _checkSignatures(
    bytes32 _dataHash,
    address[] memory _operators,
    bytes[] memory _signatures,
    uint32 _referenceBlock
) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_dataHash`|`bytes32`|The hash of the data the signers endorsed.|
|`_operators`|`address[]`|A collection of addresses that endorsed the data hash.|
|`_signatures`|`bytes[]`|A collection of signatures matching the signers.|
|`_referenceBlock`|`uint32`|The block number for evaluating stake weight; use max uint32 for latest weight.|


### _validateSignaturesLength

Validates that the number of signers equals the number of signatures, and neither is zero.


```solidity
function _validateSignaturesLength(uint256 _signersLength, uint256 _signaturesLength) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_signersLength`|`uint256`|The number of signers.|
|`_signaturesLength`|`uint256`|The number of signatures.|


### _validateSortedSigners

Ensures that signers are sorted in ascending order by address.


```solidity
function _validateSortedSigners(address _lastSigner, address _currentSigner) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_lastSigner`|`address`|The address of the last signer.|
|`_currentSigner`|`address`|The address of the current signer.|


### _validateSignature

Validates a given signature against the signer's address and data hash.


```solidity
function _validateSignature(address _signer, bytes32 _dataHash, bytes memory _signature) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_signer`|`address`|The address of the signer to validate.|
|`_dataHash`|`bytes32`|The hash of the data that is signed.|
|`_signature`|`bytes`|The signature to validate.|


### _getOperatorSigningKey

Retrieves the operator weight for a signer, either at the last checkpoint or a specified block.


```solidity
function _getOperatorSigningKey(address _operator, uint32 _referenceBlock) internal view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operator`|`address`|The operator to query their signing key history for|
|`_referenceBlock`|`uint32`|The block number to query the operator's weight at, or the maximum uint32 value for the last checkpoint.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The weight of the operator.|


### _getOperatorWeight

Retrieves the operator weight for a signer, either at the last checkpoint or a specified block.


```solidity
function _getOperatorWeight(address _signer, uint32 _referenceBlock) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_signer`|`address`|The address of the signer whose weight is returned.|
|`_referenceBlock`|`uint32`|The block number to query the operator's weight at, or the maximum uint32 value for the last checkpoint.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The weight of the operator.|


### _getTotalWeight

Retrieve the total stake weight at a specific block or the latest if not specified.

*If the `_referenceBlock` is the maximum value for uint32, the latest total weight is returned.*


```solidity
function _getTotalWeight(uint32 _referenceBlock) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_referenceBlock`|`uint32`|The block number to retrieve the total stake weight from.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total stake weight at the given block or the latest if the given block is the max uint32 value.|


### _getThresholdStake

Retrieves the threshold stake for a given reference block.


```solidity
function _getThresholdStake(uint32 _referenceBlock) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_referenceBlock`|`uint32`|The block number to query the threshold stake for. If set to the maximum uint32 value, it retrieves the latest threshold stake.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The threshold stake in basis points for the reference block.|


### _validateThresholdStake

Validates that the cumulative stake of signed messages meets or exceeds the required threshold.


```solidity
function _validateThresholdStake(uint256 _signedWeight, uint32 _referenceBlock) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_signedWeight`|`uint256`|The cumulative weight of the signers that have signed the message.|
|`_referenceBlock`|`uint32`|The block number to verify the stake threshold for|


