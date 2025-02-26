# IBitcoinPod
[Git Source](https://github.com/motif-project/motif-core-contracts/blob/2d5ca1db3b104b68bfb25c8e4e92709909e5d1c7/src/interfaces/IBitcoinPod.sol)

Interface for individual Bitcoin pods that handle Bitcoin deposits and withdrawals

*This interface defines the core functionality for Bitcoin pods including:
- Balance tracking
- Withdrawal transaction handling
- Pod locking/unlocking mechanisms
- Pod owner management*


## Functions
### setPodState

Sets the state of the pod

*This function is used to set the state of the pod*

*Only callable by pod manager*

*State transition rules:
- Active -> Inactive: Always allowed
- Inactive -> Active: Only if pod meets activation requirements (e.g., BitcoinWithdrawal request is cancelled)*


```solidity
function setPodState(PodState _newState) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newState`|`PodState`|The new state of the pod|


### getBitcoinAddress

Returns the Bitcoin address of the pod

*This is the address where Bitcoin deposits are received on the Bitcoin Chain*


```solidity
function getBitcoinAddress() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|string The Bitcoin address as a string|


### getOperatorBtcPubKey

Returns the Bitcoin public key of the operator associated with this pod

*This operator key is used to generate the multisig Bitcoin address*


```solidity
function getOperatorBtcPubKey() external view returns (bytes memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|bytes The Bitcoin public key as a byte array|


### getOperator

Returns the Ethereum address of the operator associated with this pod

*This is the address of the operator who can perform sensitive actions*


```solidity
function getOperator() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address The operator's Ethereum address|


### getBitcoinBalance

Returns the current Bitcoin balance tracked in the pod

*This balance is updated through minting and burning actions*


```solidity
function getBitcoinBalance() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The current Bitcoin balance|


### getSignedBitcoinWithdrawTransaction

Returns the signed Bitcoin withdrawal transaction stored in the pod

*This transaction is used in the process of withdrawing Bitcoin from the pod*

*The transaction can either be a partially signed PSBT created by the operator or a completely signed raw transaction depending on the withdrawal path taken by the client*


```solidity
function getSignedBitcoinWithdrawTransaction() external view returns (bytes memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|bytes The signed Bitcoin transaction as a byte array|


### setSignedBitcoinWithdrawTransaction

Sets the signed Bitcoin withdrawal psbt or raw transaction in the pod

*This transaction is used by the client to create and broadcast the final signed transaction on the Bitcoin Network*


```solidity
function setSignedBitcoinWithdrawTransaction(bytes memory _signedBitcoinWithdrawTransaction) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_signedBitcoinWithdrawTransaction`|`bytes`|The signed Bitcoin transaction as a byte array|


### getPodState

Returns the current state of the pod

*This is used to check if the pod is active or inactive*


```solidity
function getPodState() external view returns (PodState);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`PodState`|PodState The current state of the pod|


### lock

Locks the pod to prevent further withdrawals

*This is a security measure to prevent unauthorized withdrawals*

*The pod can only be locked by the BitcoinPodManager*


```solidity
function lock() external;
```

### unlock

Unlocks the pod to allow withdrawals

*This is used when the pod is ready to be used again*

*The pod can only be unlocked by the BitcoinPodManager*


```solidity
function unlock() external;
```

### isLocked

Checks if the pod is currently locked

*This is used to ensure the pod is not locked before performing actions*


```solidity
function isLocked() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if the pod is locked, false otherwise|


### mint

Adds Bitcoin value to the pod

*This is used to set the Bitcoin balance in the pod*

*Only callable by pod manager*

*Must be called with reentrancy protection*


```solidity
function mint(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of Bitcoin tokens to mint (must be > 0)|


### burn

Removes Bitcoin token value from the pod

*This is used to clear the Bitcoin balance in the pod*

*Only callable by pod manager*

*Must be called with reentrancy protection*


```solidity
function burn(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of Bitcoin tokens to burn (must be > 0 and <= current balance)|


## Events
### PodInitialized
Event emitted when the pod is initialized

*This event is emitted when the pod is initialized*


```solidity
event PodInitialized(address indexed pod, address indexed owner, address indexed operator);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|The address of the pod|
|`owner`|`address`|The owner of the pod|
|`operator`|`address`|The operator of the pod|

### PodLocked
Event emitted when the pod is locked

*This event is emitted when the pod is locked*


```solidity
event PodLocked(address indexed pod);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|The address of the pod|

### PodUnlocked
Event emitted when the pod is unlocked

*This event is emitted when the pod is unlocked*


```solidity
event PodUnlocked(address indexed pod);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|The address of the pod|

### MintPodValue
Event emitted when the pod value is minted

*This event is emitted when the pod value is minted*


```solidity
event MintPodValue(address indexed pod, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|The address of the pod|
|`amount`|`uint256`|The amount of pod value minted|

### BurnPodValue
Event emitted when the pod value is burned

*This event is emitted when the pod value is burned*


```solidity
event BurnPodValue(address indexed pod, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|The address of the pod|
|`amount`|`uint256`|The amount of pod value burned|

### PodStateChanged
Event emitted when the pod state is changed

*This event is emitted when the pod state is changed*


```solidity
event PodStateChanged(PodState previousState, PodState newState);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`previousState`|`PodState`|The previous state of the pod|
|`newState`|`PodState`|The new state of the pod|

### WithdrawTransactionSet
Event emitted when the signed Bitcoin withdrawal transaction is set

*This event is emitted when the signed Bitcoin withdrawal transaction is set*


```solidity
event WithdrawTransactionSet(bytes signedTransaction);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signedTransaction`|`bytes`|The signed Bitcoin withdrawal transaction as a byte array|

## Enums
### PodState
Enum to represent the state of the pod

*Inactive: The pod is not active and cannot be used for deposits or withdrawals*

*Active: The pod is active and can be used for deposits and withdrawals*


```solidity
enum PodState {
    Inactive,
    Active
}
```

