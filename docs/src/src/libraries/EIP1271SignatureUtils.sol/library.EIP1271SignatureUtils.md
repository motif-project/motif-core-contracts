# EIP1271SignatureUtils
[Git Source](https://github.com/motif-project/motif-core-contracts/blob/2d5ca1db3b104b68bfb25c8e4e92709909e5d1c7/src/libraries/EIP1271SignatureUtils.sol)

**Author:**
Layr Labs, Inc.

Terms of Service: https://docs.eigenlayer.xyz/overview/terms-of-service


## State Variables
### EIP1271_MAGICVALUE

```solidity
bytes4 internal constant EIP1271_MAGICVALUE = 0x1626ba7e;
```


## Functions
### checkSignature_EIP1271

Checks @param signature is a valid signature of @param digestHash from @param signer.
If the `signer` contains no code -- i.e. it is not (yet, at least) a contract address, then checks using standard ECDSA logic
Otherwise, passes on the signature to the signer to verify the signature and checks that it returns the `EIP1271_MAGICVALUE`.


```solidity
function checkSignature_EIP1271(address signer, bytes32 digestHash, bytes memory signature) internal view;
```

