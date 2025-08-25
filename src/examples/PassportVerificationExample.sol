// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../libraries/BitcoinUtils.sol";

/**
 * @title PassportVerificationExample
 * @notice Demonstrates how passport verification works in the Motif system
 * @dev This contract shows the key verification patterns used throughout the system
 */
contract PassportVerificationExample {
    using BitcoinUtils for bytes;

    // Track used signatures for replay protection
    mapping(bytes32 => bool) public usedSignatures;
    
    // Events for verification results
    event PSBTVerified(bool isValid, string reason);
    event SignatureVerified(address signer, bool isValid);
    event AddressVerified(string btcAddress, bool isValid);

    /**
     * @notice Demonstrates PSBT verification process
     * @param psbtBytes The PSBT data to verify
     * @param expectedAddress The expected withdrawal address
     * @param expectedAmount The expected withdrawal amount
     * @return isValid True if PSBT is valid
     */
    function verifyPSBTExample(
        bytes calldata psbtBytes,
        string memory expectedAddress,
        uint256 expectedAmount
    ) external returns (bool isValid) {
        
        // Step 1: Basic validation
        if (psbtBytes.length == 0) {
            emit PSBTVerified(false, "Empty PSBT");
            return false;
        }
        
        if (bytes(expectedAddress).length == 0) {
            emit PSBTVerified(false, "Empty address");
            return false;
        }
        
        if (expectedAmount == 0) {
            emit PSBTVerified(false, "Zero amount");
            return false;
        }

        try BitcoinUtils.extractVoutFromPSBT(psbtBytes) returns (BitcoinUtils.Output[] memory outputs) {
            // Step 2: Validate outputs
            if (outputs.length == 0) {
                emit PSBTVerified(false, "No outputs found");
                return false;
            }
            
            if (outputs.length > 10) {
                emit PSBTVerified(false, "Too many outputs");
                return false;
            }

            // Step 3: Find matching output
            for (uint256 i = 0; i < outputs.length; i++) {
                string memory outputAddress = BitcoinUtils.convertScriptPubKeyToBech32Address(outputs[i].scriptPubKey);
                
                if (
                    BitcoinUtils.areEqualStrings(bytes(outputAddress), bytes(expectedAddress)) &&
                    outputs[i].value == expectedAmount
                ) {
                    emit PSBTVerified(true, "Valid PSBT found");
                    return true;
                }
            }
            
            emit PSBTVerified(false, "No matching output");
            return false;
            
        } catch {
            emit PSBTVerified(false, "PSBT parsing failed");
            return false;
        }
    }

    /**
     * @notice Demonstrates signature verification process
     * @param message The message that was signed
     * @param signature The signature to verify
     * @param expectedSigner The expected signer address
     * @return isValid True if signature is valid
     */
    function verifySignatureExample(
        bytes memory message,
        bytes memory signature,
        address expectedSigner
    ) external returns (bool isValid) {
        
        // Step 1: Check signature length
        if (signature.length != 65) {
            emit SignatureVerified(address(0), false);
            return false;
        }
        
        // Step 2: Check for replay attacks
        bytes32 sigHash = keccak256(abi.encodePacked(signature));
        if (usedSignatures[sigHash]) {
            emit SignatureVerified(address(0), false);
            return false;
        }
        
        // Step 3: Recover signer
        bytes32 messageHash = keccak256(message);
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        
        // Extract signature components
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        
        // Recover signer address
        address recoveredSigner = ecrecover(ethSignedMessageHash, v, r, s);
        
        // Step 4: Validate signer
        isValid = (recoveredSigner == expectedSigner && recoveredSigner != address(0));
        
        if (isValid) {
            usedSignatures[sigHash] = true;
        }
        
        emit SignatureVerified(recoveredSigner, isValid);
        return isValid;
    }

    /**
     * @notice Demonstrates Bitcoin address verification
     * @param scriptPubKey The script public key
     * @param expectedAddress The expected Bech32 address
     * @return isValid True if address matches
     */
    function verifyAddressExample(
        bytes calldata scriptPubKey,
        string memory expectedAddress
    ) external pure returns (bool isValid) {
        
        // Convert scriptPubKey to Bech32 address
        string memory computedAddress = BitcoinUtils.convertScriptPubKeyToBech32Address(scriptPubKey);
        
        // Compare addresses
        return BitcoinUtils.areEqualStrings(bytes(computedAddress), bytes(expectedAddress));
    }

    /**
     * @notice Demonstrates script verification for witness programs
     * @param script The Bitcoin script
     * @param witnessProgram The expected witness program hash
     * @return isValid True if script matches witness program
     */
    function verifyScriptExample(
        bytes calldata script,
        bytes32 witnessProgram
    ) external pure returns (bool isValid) {
        
        return BitcoinUtils.verifyScriptForAddress(script, witnessProgram);
    }

    /**
     * @notice Get the hash that would be used for signature verification
     * @param pod The pod address
     * @param amount The transaction amount
     * @param txData The transaction data
     * @param withdrawAddress The withdrawal address
     * @return messageHash The hash that should be signed
     */
    function getSignatureHash(
        address pod,
        uint256 amount,
        bytes memory txData,
        string memory withdrawAddress
    ) external pure returns (bytes32 messageHash) {
        
        return keccak256(abi.encodePacked(pod, amount, txData, withdrawAddress));
    }

    /**
     * @notice Check if a signature has been used (replay protection)
     * @param signature The signature to check
     * @return isUsed True if signature has been used
     */
    function isSignatureUsed(bytes memory signature) external view returns (bool isUsed) {
        bytes32 sigHash = keccak256(abi.encodePacked(signature));
        return usedSignatures[sigHash];
    }
}