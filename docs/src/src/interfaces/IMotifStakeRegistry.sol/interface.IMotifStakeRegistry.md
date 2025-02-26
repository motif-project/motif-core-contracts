# IMotifStakeRegistry
[Git Source](https://github.com/motif-project/motif-core-contracts/blob/2d5ca1db3b104b68bfb25c8e4e92709909e5d1c7/src/interfaces/IMotifStakeRegistry.sol)

Registry contract for Motif operators

*THIS CONTRACT IS NOT AUDITED.*

*Extends ECDSAStakeRegistry to handle Bitcoin-specific operator registration
This contract manages:
- Registration of operators with their Bitcoin public keys
- Integration with EigenLayer's delegation system
- Operator deregistration
Key features:
- Secure storage of operator Bitcoin public keys
- Validation of Bitcoin public key format
- Integration with EigenLayer staking
The contract works in conjunction with:
- MotifServiceManager: For operator task management
- BitcoinPodManager: For pod operations
- EigenLayer: For staking and delegation*


## Functions
### registerOperatorWithSignature

Registers a new operator using a provided signature and signing key

*caller must be the operator itself*

*Only interface for registering an operator with Motif AVS*


```solidity
function registerOperatorWithSignature(
    ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature,
    address _signingKey,
    bytes calldata btcPublicKey
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operatorSignature`|`ISignatureUtils.SignatureWithSaltAndExpiry`|Contains the operator's ECDSA signature, salt, and expiry|
|`_signingKey`|`address`|The signing key to add to the operator's history|
|`btcPublicKey`|`bytes`|The Bitcoin public key to register for the operator|


### deregisterOperator

Deregisters an operator and removes their Bitcoin public key

*Only interface for deregistering an operator with Motif AVS*


```solidity
function deregisterOperator() external;
```

### isOperatorBtcKeyRegistered

Checks if an operator has a registered Bitcoin public key


```solidity
function isOperatorBtcKeyRegistered(address operator) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operator`|`address`|Address of the operator to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the operator has a registered Bitcoin public key, false otherwise|


### getOperatorBtcPublicKey

Retrieves the Bitcoin public key for a registered operator


```solidity
function getOperatorBtcPublicKey(address operator) external view returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operator`|`address`|Address of the operator to retrieve the key for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The Bitcoin public key associated with the operator|


## Events
### OperatorBtcKeyRegistered
Emitted when an operator registers their Bitcoin public key


```solidity
event OperatorBtcKeyRegistered(address indexed operator, bytes btcPublicKey);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operator`|`address`|Address of the operator registering their key|
|`btcPublicKey`|`bytes`|The Bitcoin public key being registered|

### OperatorBtckeyDeregistered
Emitted when an operator deregisters and removes their Bitcoin public key


```solidity
event OperatorBtckeyDeregistered(address indexed operator);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operator`|`address`|Address of the operator deregistering|

