# BitcoinPodManager
[Git Source](https://github.com/motif-project/motif-core-contracts/blob/2d5ca1db3b104b68bfb25c8e4e92709909e5d1c7/src/core/BitcoinPodManager.sol)

**Inherits:**
[BitcoinPodManagerStorage](/src/storage/BitcoinPodManagerStorage.sol/contract.BitcoinPodManagerStorage.md), Initializable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, [IBitcoinPodManager](/src/interfaces/IBitcoinPodManager.sol/interface.IBitcoinPodManager.md)

Manages Bitcoin custody pods for Clients in the MOTIF protocol

*Handles pod creation, deposits, withdrawals and pod state management
The BitcoinPodManager contract provides the following key functionality:
- Pod creation and management
- Bitcoin deposit and withdrawal request handling for each pod
- Integration with Motif Service Manager for operator actions
- Pod delegation to apps
Key components:
- BitcoinPod: Individual custody pods that hold Bitcoin
- MotifServiceManager: Manages operator tasks and verification
- AppRegistry: Verifies and delegates to/from registered applications
Security features:
- Reentrancy protection on state-modifying functions
- Access control via modifiers
- Circuit breaker (pause) functionality
- Pod ownership verification
- App verification through App Registry
State Management:
- Tracks user to pod mappings
- Tracks pod to app mappings
- Tracks deposit requests per pod
- Tracks withdrawal addresses per pod
Key flows:
1. Pod Creation
- User requests for pod creation with a selected operator
- User and operator needs to create a Bitcoin Multisig address beforehand
- Manager verifies operator and creates new BitcoinPod contract
- Transfers ownership of Pod to the user
2. Deposits
- User initiates deposit verification request
- Operator verifies the bitcoin deposit on Bitcoin Network
- Manager updates pod balance
3. Withdrawals
- User initiates withdrawal request
- Operator signs withdrawal transaction
- Manager facilitates withdrawal completion*


## Functions
### onlyMotifServiceManager


```solidity
modifier onlyMotifServiceManager();
```

### onlyPodOwner


```solidity
modifier onlyPodOwner(address pod);
```

### initialize

Initialization function to set the App Registry, Motif Stake Registry, and Motif Service Manager


```solidity
function initialize(address appRegistry_, address motifStakeRegistry_, address motifServiceManager_)
    public
    initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`appRegistry_`|`address`|Address of the App Registry contract|
|`motifStakeRegistry_`|`address`|Address of the Motif Stake Registry contract|
|`motifServiceManager_`|`address`|Address of the Motif Service Manager contract|


### getUserPod


```solidity
function getUserPod(address user) external view override returns (address);
```

### getPodApp


```solidity
function getPodApp(address pod) external view override returns (address);
```

### getTotalTVL


```solidity
function getTotalTVL() external view override returns (uint256);
```

### getMotifServiceManager


```solidity
function getMotifServiceManager() external view override returns (address);
```

### getAppRegistry


```solidity
function getAppRegistry() external view override returns (address);
```

### getMotifStakeRegistry


```solidity
function getMotifStakeRegistry() external view override returns (address);
```

### getBitcoinDepositRequest


```solidity
function getBitcoinDepositRequest(address pod) external view override returns (BitcoinDepositRequest memory);
```

### getBitcoinWithdrawalAddress


```solidity
function getBitcoinWithdrawalAddress(address pod) external view override returns (string memory);
```

### getTotalPods


```solidity
function getTotalPods() external view override returns (uint256);
```

### hasPendingBitcoinDepositRequest


```solidity
function hasPendingBitcoinDepositRequest(address pod) external view override returns (bool);
```

### createPod

Creates a new pod

*Creates a new Bitcoin pod with the specified operator and Bitcoin address*

*Owner can only creata a single pod against its Ethereum address*

*Retrieves operator's Bitcoin public key from registry*

*Creates new BitcoinPod contract and stores mapping*

*Emits PodCreated event*


```solidity
function createPod(address operator, string calldata btcAddress, bytes calldata script)
    external
    whenNotPaused
    nonReentrant
    returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operator`|`address`|The address of the operator creating the pod|
|`btcAddress`|`string`|The Bitcoin address for the pod|
|`script`|`bytes`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address The address of the created pod|


### delegatePod

Delegates a pod to an app

*Checks:
- Caller must be the pod owner
- App contract must be registered in AppRegistry
- Pod must not already be delegated*

*Updates pod-to-app mapping and emits PodDelegated event*


```solidity
function delegatePod(address pod, address appContract) external whenNotPaused nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|The address of the pod to be delegated|
|`appContract`|`address`|The address of the app to delegate the pod to|


### undelegatePod

Undelegates a pod

*Checks:
- Caller must be the pod owner
- Pod must be delegated to an app*

*Updates pod-to-app mapping and emits PodUndelegated event*


```solidity
function undelegatePod(address pod) external whenNotPaused nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|The address of the pod to be undelegated|


### _mintBitcoin

Internal function to set Bitcoin tokens to a pod

*This function performs the following:
- Validates that the pod is not delegated to any app
- Emits a BitcoinMinted event*

*Security considerations:
- Only callable internally by other functions
- Pod must not be delegated to prevent unauthorized minting
- Tokens are minted to the pod owner*


```solidity
function _mintBitcoin(address pod, uint256 amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|The address of the pod to add tokens to|
|`amount`|`uint256`|The amount of tokens to set|


### _burnBitcoin

Internal function to clear Bitcoin tokens from a pod

*This function performs the following:
- Validates that the pod is not delegated to any app
- Emits a BitcoinBurned event*


```solidity
function _burnBitcoin(address pod, uint256 amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|The address of the pod to remove tokens from|
|`amount`|`uint256`|The amount of tokens to remove|


### lockPod

Locks a pod

*Checks:
- Pod must be delegated to an app
- Caller must be the delegated app*

*Locks the pod*


```solidity
function lockPod(address pod) external whenNotPaused nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|The address of the pod to be locked|


### unlockPod

Unlocks a pod

*Checks:
- Pod must be delegated to an app
- Caller must be the delegated app*

*Unlocks the pod*


```solidity
function unlockPod(address pod) external whenNotPaused nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|The address of the pod to be unlocked|


### verifyBitcoinDepositRequest

Client request to verify the deposit

*Checks:
- Caller must be the pod owner
- No pending deposit request*

*Updates pod-to-bitcoin deposit request mapping and emits VerifyBitcoinDepositRequest event*


```solidity
function verifyBitcoinDepositRequest(address pod, bytes32 transactionId, uint256 amount)
    external
    whenNotPaused
    nonReentrant
    onlyPodOwner(pod);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|The address of the pod|
|`transactionId`|`bytes32`|The Bitcoin transaction ID|
|`amount`|`uint256`|The amount deposited|


### confirmBitcoinDeposit

Confirms the deposit on Bitcoin Network

*Checks:
- Caller must be Motif Service Manager
- Transaction ID must match pending deposit request*

*Updates pod state:
- Adds Bitcoin token value to pod
- Clears pending deposit request*

*Emits BitcoinDepositConfirmed event*


```solidity
function confirmBitcoinDeposit(address pod, bytes32 transactionId, uint256 amount)
    external
    whenNotPaused
    nonReentrant
    onlyMotifServiceManager;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|The address of the pod|
|`transactionId`|`bytes32`|The Bitcoin transaction ID|
|`amount`|`uint256`|The amount deposited|


### withdrawBitcoinPSBTRequest

Initiates a Bitcoin withdrawal request using PSBT (Partially Signed Bitcoin Transaction) from pod owner

*This function starts the PSBT withdrawal flow where:
1. Pod owner initiates a withdrawal request
2. Operator creates and signs PSBT in response to the request
3. Operator sends the PSBT to the Service Manager
4. Service manager verifies and stores PSBT in pod
5. Pod owner can retrieve and complete PSBT*

*Checks:
- Caller must be the pod owner
- No pending withdrawal request exists
- Pod must be unlocked
- Pod must not be delegated to any app
- Withdrawal address must be valid*

*Updates pod-to-withdrawal address mapping and emits BitcoinWithdrawalPSBTRequest event*

*The operator will create and sign PSBT in response to this request*


```solidity
function withdrawBitcoinPSBTRequest(address pod, string memory withdrawAddress)
    external
    whenNotPaused
    nonReentrant
    onlyPodOwner(pod);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|The address of the pod where the withdrawal is requested|
|`withdrawAddress`|`string`|The Bitcoin address where funds should be withdrawn to|


### withdrawBitcoinCompleteTxRequest

Initiates a Bitcoin withdrawal request from the pod owner

*This function starts the complete transaction withdrawal flow where:
1. Pod owner creates and signs a Bitcoin transaction
2. Pod owner initiates withdrawal with the pre-signed transaction
3. Operator completes signing the transaction
4. Service manager verifies and stores completed transaction in pod
5. Pod owner can retrieve and broadcast transaction*

*Checks:
- Caller must be the pod owner
- No pending withdrawal request exists
- Pod must be unlocked
- Pod must not be delegated to any app
- Withdrawal address must be valid
- Pre-signed transaction must be provided*

*Updates pod-to-withdrawal address mapping and emits BitcoinWithdrawalCompleteTxRequest event*

*The operator will complete signing the transaction in response to this request*


```solidity
function withdrawBitcoinCompleteTxRequest(
    address pod,
    bytes memory preSignedWithdrawTransaction,
    string memory withdrawAddress
) external whenNotPaused nonReentrant onlyPodOwner(pod);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|The address of the pod where the withdrawal is requested|
|`preSignedWithdrawTransaction`|`bytes`|The pre-signed Bitcoin transaction sent from the pod owner|
|`withdrawAddress`|`string`|The Bitcoin address where funds should be withdrawn to|


### withdrawBitcoinAsTokens

Withdraws Bitcoin as tokens from a pod

*This function handles the clearing of Bitcoin token value from a pod by:
1. Verifying there is an active withdrawal request
3. Unsetting the pod's entire Bitcoin balance
4. Emitting withdrawal event
5. Cleaning up withdrawal request state*

*Can only be called by the Motif Service Manager*

*Checks:
- Pod must have an active withdrawal request*


```solidity
function withdrawBitcoinAsTokens(address pod) external whenNotPaused nonReentrant onlyMotifServiceManager;
```

### setSignedBitcoinWithdrawTransactionPod

Sets the signed Bitcoin withdrawal transaction in the pod

*Checks:
- Caller must be Motif Service Manager*

*Updates pod state:
- Stores the signed Bitcoin withdrawal transaction*


```solidity
function setSignedBitcoinWithdrawTransactionPod(address pod, bytes memory signedBitcoinWithdrawTransaction)
    external
    whenNotPaused
    onlyMotifServiceManager;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|The address of the pod|
|`signedBitcoinWithdrawTransaction`|`bytes`|The signed Bitcoin PSBT or raw transaction|


### cancelWithdrawalRequest


```solidity
function cancelWithdrawalRequest(address pod) external whenNotPaused onlyPodOwner(pod);
```

### _verifyBTCAddress

Verify if a BTC address is correct for a given scriptPubKey


```solidity
function _verifyBTCAddress(string calldata btcAddress, bytes calldata script, bytes memory operatorBtcPubKey)
    internal
    pure
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`btcAddress`|`string`|The bech32 BTC address to verify|
|`script`|`bytes`|The scriptPubKey to verify against|
|`operatorBtcPubKey`|`bytes`|The operator's BTC public key|


### pause

Pauses all contract functions

*Only callable by contract owner*


```solidity
function pause() external onlyOwner;
```

### unpause

Unpauses all contract functions

*Only callable by contract owner*


```solidity
function unpause() external onlyOwner;
```

