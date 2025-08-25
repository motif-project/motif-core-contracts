# Passport Verification Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                     MOTIF PASSPORT VERIFICATION SYSTEM               │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Bitcoin User  │    │    Operator     │    │ MotifService    │
│                 │    │                 │    │   Manager       │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          │ 1. Request Deposit   │                      │
          ├─────────────────────▶│                      │
          │                      │                      │
          │                      │ 2. Submit Deposit    │
          │                      │    Confirmation      │
          │                      ├─────────────────────▶│
          │                      │                      │
          │                      │                      │ ┌─────────────────┐
          │                      │                      │ │ SIGNATURE       │
          │                      │                      │ │ VERIFICATION    │
          │                      │                      │ │                 │
          │                      │                      │ │ 1. Check length │
          │                      │                      │ │ 2. Replay check │
          │                      │                      │ │ 3. ECDSA verify │
          │                      │                      │ │ 4. Operator auth│
          │                      │                      │ └─────────────────┘
          │                      │                      │
          │                      │ 3. Confirmation OK   │
          │                      │◀─────────────────────┤
          │                      │                      │
          │ 4. Deposit Confirmed │                      │
          │◀─────────────────────┤                      │
          │                      │                      │

══════════════════════════════════════════════════════════════════════════

          │ 5. Request Withdraw  │                      │
          ├─────────────────────▶│                      │
          │                      │                      │
          │                      │ 6. Submit PSBT      │
          │                      ├─────────────────────▶│
          │                      │                      │
          │                      │                      │ ┌─────────────────┐
          │                      │                      │ │ PSBT            │
          │                      │                      │ │ VERIFICATION    │
          │                      │                      │ │                 │
          │                      │                      │ │ 1. Magic bytes  │
          │                      │                      │ │ 2. Version      │
          │                      │                      │ │ 3. Parse outputs│
          │                      │                      │ │ 4. Address/amt  │
          │                      │                      │ │ 5. Output limits│
          │                      │                      │ └─────────────────┘
          │                      │                      │
          │                      │                      │ ┌─────────────────┐
          │                      │                      │ │ ADDRESS         │
          │                      │                      │ │ VERIFICATION    │
          │                      │                      │ │                 │
          │                      │                      │ │ 1. ScriptPubKey │
          │                      │                      │ │ 2. Bech32 conv  │
          │                      │                      │ │ 3. String match │
          │                      │                      │ └─────────────────┘
          │                      │                      │
          │                      │ 7. PSBT Verified    │
          │                      │◀─────────────────────┤
          │                      │                      │
          │ 8. Withdrawal Ready  │                      │
          │◀─────────────────────┤                      │

══════════════════════════════════════════════════════════════════════════

VERIFICATION COMPONENTS:

┌─────────────────────────────────────────────────────────────────────┐
│                      SIGNATURE VERIFICATION                         │
├─────────────────────────────────────────────────────────────────────┤
│ Input: message, signature, expectedSigner                          │
│                                                                     │
│ Steps:                                                              │
│ 1. Length Check: signature.length == 65                           │
│ 2. Replay Check: !usedSignatures[keccak256(signature)]            │
│ 3. Hash Message: keccak256(pod + amount + txData + address)       │
│ 4. Recover Signer: ECDSA.recover(ethSignedMessageHash, signature) │
│ 5. Verify: recoveredSigner == expectedSigner                      │
│ 6. Mark Used: usedSignatures[sigHash] = true                      │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                        PSBT VERIFICATION                            │
├─────────────────────────────────────────────────────────────────────┤
│ Input: psbtBytes, withdrawAddress, withdrawAmount                   │
│                                                                     │
│ Steps:                                                              │
│ 1. Magic Check: psbtBytes[0:5] == 0x70736274ff                    │
│ 2. Version Check: psbtBytes[5] == 0x01                            │
│ 3. Parse Structure: global tx + inputs + outputs                   │
│ 4. Extract Outputs: BitcoinUtils.extractVoutFromPSBT()            │
│ 5. Convert Address: convertScriptPubKeyToBech32Address()           │
│ 6. Match Validation: address == expected && amount == expected     │
│ 7. Limit Check: outputs.length <= 10                              │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                      ADDRESS VERIFICATION                           │
├─────────────────────────────────────────────────────────────────────┤
│ Input: scriptPubKey, expectedAddress                               │
│                                                                     │
│ Steps:                                                              │
│ 1. Witness Program: Extract 20/32 byte witness program            │
│ 2. Convert Bits: _convertBits(witnessProgram, 8, 5, true)         │
│ 3. Add Prefix: [0x00] + converted                                 │
│ 4. Checksum: _createChecksum(hrp, prefixedData)                    │
│ 5. Encode: hrp + "1" + charset[data] + charset[checksum]          │
│ 6. Compare: areEqualStrings(computed, expected)                    │
└─────────────────────────────────────────────────────────────────────┘

SECURITY FEATURES:
• Replay Protection: _usedSignatures mapping
• Access Control: onlyPodOperator modifier  
• Input Validation: Size limits and format checks
• Cryptographic Integrity: SHA256 and ECDSA verification
• Multi-layer Validation: PSBT + Signature + Address verification
```