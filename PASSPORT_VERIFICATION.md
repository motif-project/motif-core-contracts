# Passport Verification in Motif Core Contracts

## Overview

The Motif Core Contracts implement a comprehensive verification system that acts as a "passport" for validating Bitcoin transactions and operator actions. While there's no single "passport" entity, the system uses multiple layers of verification to ensure security and authenticity.

## Key Verification Components

### 1. PSBT (Partially Signed Bitcoin Transaction) Verification

**Location:** `src/core/MotifServiceManager.sol` - `_verifyPSBTOutputs()`

**Purpose:** Validates that Bitcoin transactions are properly formatted and contain expected outputs.

**Verification Process:**
```solidity
function _verifyPSBTOutputs(bytes calldata psbtBytes, string memory withdrawAddress, uint256 withdrawAmount)
    internal pure returns (bool)
```

**Steps:**
1. **Format Validation:**
   - Verifies PSBT magic bytes: `0x70736274ff`
   - Checks PSBT version (must be 0x01)
   - Validates global unsigned transaction structure

2. **Output Extraction:**
   - Uses `BitcoinUtils.extractVoutFromPSBT()` to parse outputs
   - Extracts value amounts and scriptPubKey data
   - Converts scriptPubKey to witness programs (20 or 32 bytes)

3. **Address/Amount Validation:**
   - Converts scriptPubKey to Bech32 address
   - Compares against expected withdrawal address
   - Verifies exact amount matches

4. **Security Limits:**
   - Maximum 10 outputs allowed (`MAX_PSBT_OUTPUTS`)
   - Rejects empty or oversized PSBTs

### 2. Digital Signature Verification

**Location:** Multiple functions in `MotifServiceManager.sol`

**Purpose:** Authenticates operator actions using ECDSA signatures.

**Verification Functions:**
- `confirmDeposit()` - Confirms Bitcoin deposits
- `withdrawBitcoinPSBT()` - Authorizes PSBT withdrawals  
- `withdrawBitcoinCompleteTx()` - Authorizes complete transaction withdrawals
- `confirmWithdrawal()` - Confirms withdrawal completion

**Verification Process:**
```solidity
// Standard signature verification pattern
bytes32 messageHash = keccak256(abi.encodePacked(pod, amount, transaction, withdrawAddress));
bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);
address signer = ECDSA.recover(ethSignedMessageHash, signature);

if (signer != msg.sender) {
    revert InvalidOperatorSignature(signer);
}
```

**Security Features:**
- **Replay Protection:** `_usedSignatures` mapping prevents signature reuse
- **Message Integrity:** Hash includes all relevant transaction data
- **Operator Authorization:** Only authorized pod operators can sign

### 3. Bitcoin Address Verification

**Location:** `src/core/BitcoinPodManager.sol` - `_verifyBTCAddress()`

**Purpose:** Validates Bitcoin addresses against scripts and operator public keys.

**Verification Process:**
1. **Script Parsing:** Extracts public keys from Bitcoin scripts
2. **Key Validation:** Verifies operator's BTC public key is included
3. **Address Generation:** Computes expected address from script
4. **Comparison:** Validates provided address matches computed address

### 4. Script Hash Verification

**Location:** `src/libraries/BitcoinUtils.sol` - `verifyScriptForAddress()`

**Purpose:** Verifies Bitcoin scripts match expected witness programs.

**Implementation:**
```solidity
function verifyScriptForAddress(bytes calldata script, bytes32 witnessProgram) 
    public pure returns (bool) 
{
    return sha256(script) == witnessProgram;
}
```

## Verification Flow Examples

### Bitcoin Deposit Verification
```
1. Operator receives deposit confirmation request
2. System checks for pending deposit request
3. Signature verification:
   - Message: keccak256(pod + operator + amount + txId + true)
   - Verify signature matches calling operator
4. Mark signature as used
5. Confirm deposit in BitcoinPodManager
```

### Bitcoin Withdrawal Verification
```
1. Client creates withdrawal request
2. Operator submits PSBT for withdrawal
3. PSBT verification:
   - Validate PSBT format and structure
   - Extract outputs and verify addresses/amounts
4. Signature verification:
   - Message: keccak256(pod + amount + psbtBytes + withdrawAddress)
   - Verify operator signature
5. Store signed PSBT in pod
6. Emit withdrawal event
```

## Security Mechanisms

### Anti-Replay Protection
- **Used Signatures Tracking:** `mapping(bytes32 => bool) _usedSignatures`
- **Signature Hashing:** `keccak256(abi.encodePacked(signature))`
- **One-Time Use:** Each signature can only be used once

### Access Control
- **Pod Operator Authorization:** `onlyPodOperator(pod)` modifier
- **Operator Validation:** `IBitcoinPod(pod).getOperator() != msg.sender`
- **Owner Controls:** Various `onlyOwner` functions

### Input Validation
- **Size Limits:** PSBTs and transactions limited to 10KB
- **Format Validation:** Magic bytes and version checks
- **Address Validation:** Bech32 format and witness program validation

## Error Handling

The system includes comprehensive error handling:

```solidity
// PSBT-related errors
error InvalidPSBTMagic();
error UnsupportedPSBTVersion(uint8 version);
error InvalidPSBTOutputs();
error NoPSBTOutputs();
error TooManyPSBTOutputs(uint256 count);

// Signature-related errors  
error InvalidSignatureLength(uint256 length);
error InvalidOperatorSignature(address signer);

// Transaction-related errors
error InvalidTransaction(uint256 length);
error NoWithdrawalRequestToProcess(address pod);
```

## Integration Points

### BitcoinUtils Library
- **PSBT Parsing:** `extractVoutFromPSBT()`
- **Address Conversion:** `convertScriptPubKeyToBech32Address()`
- **Script Validation:** `verifyScriptForAddress()`
- **Public Key Extraction:** `extractPublicKeys()`

### EigenLayer Integration
- **Service Management:** Extends `ECDSAServiceManagerBase`
- **Stake Registry:** Integrates with `IMotifStakeRegistry`
- **Operator Management:** Uses EigenLayer's operator framework

## Summary

The "passport verification" in Motif Core Contracts is implemented through a multi-layered security system that validates:

1. **Transaction Authenticity** - via PSBT verification
2. **Operator Authorization** - via ECDSA signature verification  
3. **Address Validity** - via Bitcoin address and script verification
4. **Message Integrity** - via cryptographic hashing and signature validation

This comprehensive approach ensures that all Bitcoin operations are properly authenticated and authorized before execution.