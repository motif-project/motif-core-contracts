# IMotifServiceManager
[Git Source](https://github.com/motif-project/motif-core-contracts/blob/2d5ca1db3b104b68bfb25c8e4e92709909e5d1c7/src/interfaces/IMotifServiceManager.sol)

**Inherits:**
IServiceManager

Interface for managing Motif operations

*THIS CONTRACT IS NOT AUDITED.*

*Extends IServiceManager from EigenLayer middleware
This interface defines the core functionality for:
- Managing Bitcoin deposits and withdrawals through pods
- Handling operator signatures and transaction verification
- Integrating with EigenLayer's staking and delegation system
Key operations:
- Deposit confirmation by operators
- Two-phase Bitcoin withdrawals (PSBT + complete transaction)
- Signature verification for security
The contract works in conjunction with:
- BitcoinPodManager: For pod state management
- BitcoinPod: Individual Bitcoin custody pods
- EigenLayer: For staking and operator management*


## Functions
### setBitcoinPodManager

Set the BitcoinPodManager contract address


```solidity
function setBitcoinPodManager(address bitcoinPodManager) external;
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

*Verifies operator signature over deposit details*

*Updates pod state via BitcoinPodManager when deposit is confirmed*

*Emits BitcoinDepositConfirmed event via BitcoinPodManager*


```solidity
function confirmDeposit(address pod, bytes calldata signature) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|Address of the Bitcoin pod receiving the deposit|
|`signature`|`bytes`|Operator's signature over the deposit confirmation message|


### withdrawBitcoinPSBT

Aids in processing a Bitcoin withdrawal by storing signed PSBT transaction created by the operator

*Only callable by the operator assigned to the pod*

*Verifies pod has pending withdrawal request*

*Validates operator signature over withdrawal details*

*Stores PSBT in pod state and emits BitcoinWithdrawalTransactionSigned event*


```solidity
function withdrawBitcoinPSBT(address pod, uint256 amount, bytes calldata psbtTransaction, bytes calldata signature)
    external;
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

*Verifies operator controls pod before processing*

*Retrieves withdrawal address from pod state for verification*


```solidity
function withdrawBitcoinCompleteTx(address pod, uint256 amount, bytes calldata completeTx, bytes calldata signature)
    external;
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

*Verifies operator signature matches transaction details*

*Updates pod state via BitcoinPodManager when withdrawal is confirmed*

*Emits BitcoinWithdrawalConfirmed event via BitcoinPodManager*


```solidity
function confirmWithdrawal(address pod, bytes calldata transaction, bytes calldata signature) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|Address of the Bitcoin pod processing the withdrawal|
|`transaction`|`bytes`|Complete Bitcoin transaction data|
|`signature`|`bytes`|Operator's signature over the transaction data|


## Events
### BitcoinWithdrawalTransactionSigned
Emitted when a Bitcoin withdrawal transaction is signed by an operator


```solidity
event BitcoinWithdrawalTransactionSigned(address indexed pod, address indexed operator, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pod`|`address`|Address of the Bitcoin pod processing the withdrawal|
|`operator`|`address`|Address of the operator signing the transaction|
|`amount`|`uint256`|Amount of Bitcoin being withdrawn|

## Errors
### UnauthorizedPodOperator
*Thrown when caller is not the authorized operator for a pod*


```solidity
error UnauthorizedPodOperator(address caller, address pod);
```

### InvalidOperatorSignature
*Thrown when a signature verification fails*


```solidity
error InvalidOperatorSignature(address operator);
```

### InvalidKeyLength
*Thrown when a key length is invalid*


```solidity
error InvalidKeyLength(uint256 length);
```

### InvalidOperatorBTCKey
*Thrown when a operator BTC key is invalid*


```solidity
error InvalidOperatorBTCKey(bytes operatorKey, bytes operatorBtcPubKey);
```

### NoWithdrawalRequestToConfirm
*Thrown when there is no withdrawal request to confirm*


```solidity
error NoWithdrawalRequestToConfirm(address pod);
```

### NoWithdrawalRequestToProcess
*Thrown when there is no withdrawal request to process*


```solidity
error NoWithdrawalRequestToProcess(address pod);
```

### WithdrawalRequestAlreadyExists
*Thrown when a withdrawal request already exists*


```solidity
error WithdrawalRequestAlreadyExists(address pod);
```

### NoDepositRequestToConfirm
*Thrown when there is no deposit request to confirm*


```solidity
error NoDepositRequestToConfirm(address pod);
```

### InvalidPSBTOutputs
*Thrown when PSBT outputs are invalid*


```solidity
error InvalidPSBTOutputs();
```

### ZeroBitcoinPodManagerAddress
*Thrown when the BitcoinPodManager address is zero*


```solidity
error ZeroBitcoinPodManagerAddress();
```

### InvalidSignatureLength
*Thrown when the signature length is invalid*


```solidity
error InvalidSignatureLength(uint256 length);
```

### EmptyWithdrawAddress
*Thrown when the withdraw address is empty*


```solidity
error EmptyWithdrawAddress();
```

### ZeroWithdrawAmount
*Thrown when the withdraw amount is zero*


```solidity
error ZeroWithdrawAmount();
```

### TooManyPSBTOutputs
*Thrown when there are too many PSBT outputs*


```solidity
error TooManyPSBTOutputs(uint256 length);
```

### NoPSBTOutputs
*Thrown when there are no PSBT outputs*


```solidity
error NoPSBTOutputs();
```

### EmptyPSBTTransaction
*Thrown when the PSBT transaction is empty*


```solidity
error EmptyPSBTTransaction();
```

### InvalidPSBTTransaction
*Thrown when the PSBT transaction is too long or too short*


```solidity
error InvalidPSBTTransaction(uint256 length);
```

### InvalidTransaction
*Thrown when the BTC transaction is invalid*


```solidity
error InvalidTransaction(uint256 length);
```

