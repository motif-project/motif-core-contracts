# BitcoinPod
[Git Source](https://github.com/motif-project/motif-core-contracts/blob/2d5ca1db3b104b68bfb25c8e4e92709909e5d1c7/src/core/BitcoinPod.sol)

**Inherits:**
[IBitcoinPod](/src/interfaces/IBitcoinPod.sol/interface.IBitcoinPod.md), OwnableUpgradeable, ReentrancyGuardUpgradeable

A contract that represents a Bitcoin custody pod managed by an Client and an Operator

*This contract handles Bitcoin deposits and withdrawals through a designated operator,
tracks balances, and manages pod locking/unlocking functionality
Key features:
- Links a Bitcoin address to an Ethereum address
- Tracks Bitcoin balances in the pod
- Allows only authorized operator actions
- Supports locking mechanism for security
- Manages withdrawal transaction storage
Security considerations:
- Pod can be locked to prevent unauthorized withdrawals
- Manager contract has privileged access for administrative functions*

*Security assumptions:
- All state-modifying functions are only callable by the PodManager contract
- The PodManager is trusted and implements necessary security measures
- No direct external calls are made from these functions*


## State Variables
### operator

```solidity
address public operator;
```


### operatorBtcPubKey

```solidity
bytes public operatorBtcPubKey;
```


### bitcoinAddress

```solidity
string public bitcoinAddress;
```


### bitcoinBalance

```solidity
uint256 public bitcoinBalance;
```


### locked

```solidity
bool public locked;
```


### manager

```solidity
address public immutable manager;
```


### signedBitcoinWithdrawTransaction

```solidity
bytes public signedBitcoinWithdrawTransaction;
```


### podState

```solidity
PodState public podState;
```


### MAX_TX_SIZE

```solidity
uint256 private constant MAX_TX_SIZE = 1024 * 100;
```


## Functions
### onlyActive

Modifier to ensure the pod is active before execution


```solidity
modifier onlyActive();
```

### lockedPod

Modifier to ensure the pod is not locked before execution


```solidity
modifier lockedPod();
```

### onlyManager

Modifier to ensure only the manager contract can perform an action


```solidity
modifier onlyManager();
```

### constructor

Initializes the immutable manager address


```solidity
constructor(address _manager);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_manager`|`address`|Address of the BitcoinPodManager contract that manages this pod|


### initialize

Initializes a new Bitcoin pod with the specified parameters

*Sets initial state:
- Transfers ownership to _owner
- Sets operator and their BTC public key
- Sets the pod's Bitcoin address
- Initializes pod as unlocked and active*


```solidity
function initialize(address _owner, address _operator, bytes memory _operatorBtcPubKey, string memory _btcAddress)
    external
    initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|Address that will own this pod contract|
|`_operator`|`address`|Address of the designated operator who can perform sensitive actions|
|`_operatorBtcPubKey`|`bytes`|Bitcoin public key of the operator for multisig address generation|
|`_btcAddress`|`string`|Multisig Bitcoin address associated with this pod|


### getBitcoinAddress


```solidity
function getBitcoinAddress() external view returns (string memory);
```

### getOperatorBtcPubKey


```solidity
function getOperatorBtcPubKey() external view returns (bytes memory);
```

### getOperator


```solidity
function getOperator() external view returns (address);
```

### getBitcoinBalance


```solidity
function getBitcoinBalance() external view returns (uint256);
```

### getSignedBitcoinWithdrawTransaction


```solidity
function getSignedBitcoinWithdrawTransaction() external view returns (bytes memory);
```

### setSignedBitcoinWithdrawTransaction


```solidity
function setSignedBitcoinWithdrawTransaction(bytes memory _signedBitcoinWithdrawTransaction)
    external
    onlyManager
    nonReentrant;
```

### setPodState


```solidity
function setPodState(PodState _newState) external onlyManager nonReentrant;
```

### lock


```solidity
function lock() external onlyManager onlyActive lockedPod;
```

### unlock


```solidity
function unlock() external onlyManager;
```

### isLocked


```solidity
function isLocked() external view returns (bool);
```

### mint


```solidity
function mint(uint256 amount) external onlyManager onlyActive lockedPod nonReentrant;
```

### burn


```solidity
function burn(uint256 amount) external onlyManager lockedPod nonReentrant;
```

### getPodState


```solidity
function getPodState() external view returns (PodState);
```

### _isValidStateTransition


```solidity
function _isValidStateTransition(PodState _from, PodState _to) internal pure returns (bool);
```

