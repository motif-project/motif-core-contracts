// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/// @title Bitcoin Utilities Library
/// @notice Collection of utilities for Bitcoin operations
/// @dev Version 1.0.0
library BitcoinUtils {
 
    struct Output {
        uint64 value;
        bytes scriptPubKey;
    }
    
    // Custom errors
    error InvalidScriptLength(uint256 length);
    error ScriptTooLong(uint256 length);
    error UnauthorizedOperator(address caller);
    error InvalidPSBTMagic();
    error PSBTTooShort();
    error UnsupportedPSBTVersion(uint8 version);
    error ExpectedGlobalUnsignedTx();
    error UnexpectedEndOfData();

    // Constants
    uint256 private constant MAX_SCRIPT_LENGTH = 10000;
    uint256 private constant MIN_SCRIPT_LENGTH = 1;
    bytes1 private constant WITNESS_VERSION_0 = 0x00;
    bytes1 private constant PUSH_32_BYTES = 0x20;
   
  
    // Events
    event ScriptProcessed(bytes program);
    
    /// @notice Converts a script to a P2WSH scriptPubKey format
    /// @dev Creates a Pay-to-Witness-Script-Hash (P2WSH) scriptPubKey from a given script
    /// @param script The script to convert
    /// @return The P2WSH witnessProgram as scriptPubKey
    function getScriptPubKey(bytes calldata script) public pure returns (bytes32) {
        require(script.length <= 71 , "Script length exceeds 2 of 2 multisig P2WSH script");
        if (script.length < MIN_SCRIPT_LENGTH) {
            revert InvalidScriptLength(script.length);
        }
        if (script.length > MAX_SCRIPT_LENGTH) {
            revert ScriptTooLong(script.length);
        }
        return sha256(script);
    }
    
    /// @notice Verifies if a script matches an address's witness program
    /// @dev Computes the SHA256 hash of the script and compares it with the provided witness program
    /// @param script The Bitcoin script to verify
    /// @param witnessProgram The witness program (32-byte hash) to check against
    /// @return bool True if the script's hash matches the witness program, false otherwise
    function verifyScriptForAddress(
        bytes calldata script,
        bytes32 witnessProgram
    ) public pure returns (bool) {
        return sha256(script) == witnessProgram;
    }

    /// @notice Converts an array of bytes from one bit width to another
    /// @dev Used for converting between 8-bit and 5-bit representations in Bech32 encoding
    /// @param data The input byte array to convert
    /// @param fromBits The bit width of the input data (typically 8)
    /// @param toBits The desired output bit width (typically 5)
    /// @param pad Whether to pad any remaining bits in the final group
    /// @return A new byte array with the converted bit representation
    function _convertBits(bytes memory data, uint8 fromBits, uint8 toBits, bool pad) 
    internal pure returns (bytes memory) {
    
    require(fromBits > 0 && toBits > 0 && fromBits <= 8 && toBits <= 8, "Invalid bit size");
    
    // Calculate max length once
    uint256 maxLength = (data.length * fromBits + toBits - 1) / toBits;
    bytes memory ret = new bytes(maxLength);
    
    uint256 acc;
    uint256 bits;
    uint256 length;
    
    // Use assembly for bit manipulation
    assembly {
        let dataPtr := add(data, 32)
        let retPtr := add(ret, 32)
        let mask := sub(shl(toBits, 1), 1)  // (1 << toBits) - 1
        
        for { let i := 0 } lt(i, mload(data)) { i := add(i, 1) } {
            // Load next byte and shift into accumulator
            acc := or(shl(fromBits, acc), byte(0, mload(add(dataPtr, i))))
            bits := add(bits, fromBits)
            
            // Extract complete groups
            for {} gt(bits, toBits) {} {
                bits := sub(bits, toBits)
                mstore8(
                    add(retPtr, length), 
                    and(shr(bits, acc), mask)
                )
                length := add(length, 1)
            }
        }
        
        // Handle padding
        if and(pad, gt(bits, 0)) {
            mstore8(
                add(retPtr, length),
                and(shl(sub(toBits, bits), acc), mask)
            )
            length := add(length, 1)
        }
        
        // Update final length
        mstore(ret, length)
    }
    
    return ret;
}
    
    /// @notice Creates a checksum for Bech32 address
    /// @dev Implements the checksum calculation for Bech32 addresses
    /// @param hrp The human-readable part of the Bech32 address
    /// @param data The data part of the Bech32 address
    /// @return A bytes array containing the checksum
    function _createChecksum(bytes memory hrp, bytes memory data) 
        internal pure returns (bytes memory) {
        uint256[] memory values = new uint256[](hrp.length * 2 + 1 + data.length + 6);

        uint256 i = 0;

        for (; i < hrp.length; i++) {
            values[i] = uint8(hrp[i]) >> 5;
            values[i + hrp.length + 1] = uint8(hrp[i]) & 31;
        }
        values[hrp.length] = 0;
        i = i + hrp.length + 1;
        // Add data
        for (uint256 j = 0; j < data.length && i < values.length; j++) {
            values[i++] = uint8(data[j]);
        }
        
        // Add checksum template
        values[i++] = 0;
        values[i++] = 0;
        values[i++] = 0;
        values[i++] = 0;
        values[i++] = 0;
        values[i++] = 0;
        
        // Correct generator constants from BIP-0173
        uint256[5] memory GEN = [
            uint256(0x3b6a57b2),
            uint256(0x26508e6d),
            uint256(0x1ea119fa),
            uint256(0x3d4233dd),
            uint256(0x2a1462b3)
        ];
        // Calculate checksum
        uint256 polymod = 1;
        for (i = 0; i < values.length; i++) {
            uint256 b = polymod >> 25;
            polymod = ((polymod & 0x1ffffff) << 5) ^ values[i];
            //console.log("Polymod after XOR:", polymod);
            for (uint256 j = 0; j < 5; j++) {
                if (((b >> j) & 1) == 1) {
                     polymod ^= GEN[j];
                }
                else {
                    polymod ^= 0;
                }
            }
        }
        polymod ^= 1;
        
        // Convert checksum to 5-bit array
        bytes memory checksum = new bytes(6);
        assembly {
            let checksumPtr := add(checksum, 32)  // Point to checksum data (after length prefix)
            
            // Calculate all 6 bytes of the checksum
            for { let iter := 0 } lt(iter, 6) { iter := add(iter, 1) } {
                // Calculate shift amount: 5 * (5-i)
                let shift := mul(5, sub(5, iter))
                // Extract the byte: (polymod >> shift) & 31
                let value := and(shr(shift, polymod), 31)
                // Store the byte
                mstore8(add(checksumPtr, iter), value)
            }
        }
        return checksum;
    }
    
    /// @notice Converts a Bitcoin scriptPubKey to a Bech32 address
    /// @dev Implements the Bech32 address encoding specification (BIP-0173)
    /// @param scriptPubKey The Bitcoin scriptPubKey to convert, must be witness program
    /// @return The Bech32 encoded Bitcoin address as a string
    /// @custom:throws "Invalid scriptPubKey length" if scriptPubKey is too short
    /// @custom:throws "Invalid witness version" if first byte is not 0x00
    function convertScriptPubKeyToBech32Address(bytes calldata scriptPubKey) public pure returns (string memory) {
        require(scriptPubKey.length ==32 || scriptPubKey.length == 20 , "ScriptPubKey should be 32 or 22 bytes");
        
        // HRP for mainnet
        bytes memory hrp = "tb";
        
        bytes memory converted = _convertBits(scriptPubKey, 8, 5, true);
       
        bytes memory convertedWithPrefix = new bytes(converted.length + 1);  // 1 byte prefix + 32 bytes hash // 1 byte prefix + 32 bytes hash
        assembly {
            // Store 0x00 at first byte
            mstore8(add(convertedWithPrefix, 32), 0x00)
            
            // Copy converted bytes to convertedWithPrefix starting at position 1
            let srcPtr := add(converted, 32)
            let destPtr := add(convertedWithPrefix, 33)
            let len := mload(converted)
            for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                mstore8(add(destPtr, i), byte(0, mload(add(srcPtr, i))))
            }
        }
        // Get checksum
        bytes memory checksum = _createChecksum(hrp, convertedWithPrefix);
        
        // // Combine all parts
        bytes memory combined = new bytes(convertedWithPrefix.length + checksum.length);
        assembly {
            // Copy convertedWithPrefix
            let srcPtr1 := add(convertedWithPrefix, 32)
            let destPtr := add(combined, 32)
            let len1 := mload(convertedWithPrefix)
            for { let i := 0 } lt(i, len1) { i := add(i, 1) } {
                mstore8(add(destPtr, i), byte(0, mload(add(srcPtr1, i))))
            }
            
            // Copy checksum after convertedWithPrefix
            let srcPtr2 := add(checksum, 32)
            let destStart := add(destPtr, len1)
            let len2 := mload(checksum)
            for { let i := 0 } lt(i, len2) { i := add(i, 1) } {
                mstore8(add(destStart, i), byte(0, mload(add(srcPtr2, i))))
            }
        }
        // Create final string
        bytes memory result = new bytes(hrp.length + 1 + combined.length);
        bytes memory charset = "qpzry9x8gf2tvdw0s3jn54khce6mua7l";  // Define charset here
        assembly {
            // Copy hrp
            let destPtr := add(result, 32)
            let srcPtr := add(hrp, 32)
            let hrpLen := mload(hrp)
            for { let i := 0 } lt(i, hrpLen) { i := add(i, 1) } {
                mstore8(add(destPtr, i), byte(0, mload(add(srcPtr, i))))
            }
            
            // Add "1" separator
            mstore8(add(destPtr, hrpLen), 0x31)  // ASCII "1" is 0x31
            
            // Encode data using charset
            let combinedPtr := add(combined, 32)
            let charsetPtr := add(charset, 32)
            let combinedLen := mload(combined)
            let resultStart := add(destPtr, add(hrpLen, 1))
            for { let i := 0 } lt(i, combinedLen) { i := add(i, 1) } {
                let charIndex := byte(0, mload(add(combinedPtr, i)))
                let char := byte(0, mload(add(charsetPtr, charIndex)))
                mstore8(add(resultStart, i), char)
            }
        }
        
        return string(result);
    }

    /// @notice Extracts two public keys from a Bitcoin script
    /// @dev Assumes the script contains two 33-byte compressed public keys in sequence
    /// @param scriptBytes The raw Bitcoin script bytes containing the public keys
    /// @return pubKey1 The first 33-byte compressed public key
    /// @return pubKey2 The second 33-byte compressed public key
    function extractPublicKeys(bytes calldata scriptBytes) public pure returns (bytes memory pubKey1, bytes memory pubKey2) {
        require(scriptBytes.length <= 71 , "Script length exceeds 2 of 2 multisig P2WSH script");
        require(scriptBytes[scriptBytes.length-1] == bytes1(0xae), "Script is not a multisig");
        require(scriptBytes[scriptBytes.length-2] == bytes1(0x52), "m value for multisig is not 2");
        require(scriptBytes[0] == bytes1(0x52), "n value for multisig is not 2");
        require(scriptBytes.length >= 66, "Script is too short to contain two public keys");
        pubKey1 = new bytes(33);
        pubKey2 = new bytes(33);

       // for(uint256 i = 0; i < 33; i++) {
         //   pubKey1[i] = scriptBytes[i + 2]; // Start after OP_2 (0x52) and length byte (0x21)
           // pubKey2[i] = scriptBytes[i + 36]; // Start after first pubkey and second length byte (0x21)
       // }
       assembly {
        // Copy first public key
        let pubKey1Ptr := add(pubKey1, 32)  // Skip length prefix
        calldatacopy(
            pubKey1Ptr,                      // destination
            add(scriptBytes.offset, 2),      // source (skip OP_2)
            33                               // length
        )

        // Copy second public key
        let pubKey2Ptr := add(pubKey2, 32)  // Skip length prefix
        calldatacopy(
            pubKey2Ptr,                      // destination
            add(scriptBytes.offset, 36),     // source (skip first key)
            33                               // length
        )
    }
    }

    /// @notice Extracts outputs from a PSBT
    /// @dev Parses the PSBT to extract output details
    /// @param psbtBytes The PSBT byte array to parse
    /// @return An array of Output structs containing value and scriptPubKey
    function extractVoutFromPSBT(bytes calldata psbtBytes) public pure returns (Output[] memory) {
        uint256 pos = 5; // Skip magic bytes

        // Verify magic bytes
        if (psbtBytes.length < 5 || 
            psbtBytes[0] != 0x70 || 
            psbtBytes[1] != 0x73 || 
            psbtBytes[2] != 0x62 || 
            psbtBytes[3] != 0x74 || 
            psbtBytes[4] != 0xff) {
            revert InvalidPSBTMagic();
        }

        // Read PSBT version
        if (pos >= psbtBytes.length) {
            revert PSBTTooShort();
        }
        uint8 btcVersion = uint8(psbtBytes[pos]);
        pos++;

        if (btcVersion != 0x01) {
            revert UnsupportedPSBTVersion(btcVersion);
        }

        // Read global unsigned tx
        if (psbtBytes[pos] != 0x00) {
            revert ExpectedGlobalUnsignedTx();
        }
        pos++;

        // Read tx length
        pos++; // Skip tx length byte

        // Skip version (4 bytes)
        pos += 4;

        // Read input count
        (uint64 inputCount, uint256 bytesRead) = _readCompactSize(psbtBytes, pos);
        pos += bytesRead;

        // Skip inputs
        for (uint64 i = 0; i < inputCount; i++) {
            pos = _skipInput(psbtBytes, pos);
        }

        // Read output count
        (uint64 outputCount, uint256 bytesRead2) = _readCompactSize(psbtBytes, pos);
        pos += bytesRead2;

        // Create outputs array
        Output[] memory outputs = new Output[](outputCount);

        // Parse outputs
        for (uint64 i = 0; i < outputCount; i++) {
            if (pos + 8 > psbtBytes.length) {
                revert UnexpectedEndOfData();
            }

            // Read value (8 bytes)
            uint64 value = uint64(_readLittleEndianUint64(psbtBytes, pos));
            pos += 8;

            // Read scriptPubKey
            (uint64 scriptSize, uint256 scriptBytesRead) = _readCompactSize(psbtBytes, pos);
            pos += scriptBytesRead;

            if (pos + scriptSize > psbtBytes.length) {
                revert UnexpectedEndOfData();
            }

            // Extract scriptPubKey
            bytes memory script = _extractBytes(psbtBytes, pos, uint256(scriptSize));
            pos += uint256(scriptSize);

            bytes memory witnessprogram;
            if (script.length == 34) {
            witnessprogram = new bytes(32);
            for (uint256 j = 0; j < 32; j++) {
                witnessprogram[j] = script[script.length - 32 + j];
            }
            }else if(script.length == 22) {
                witnessprogram = new bytes(20);
                for (uint256 j = 0; j < 20; j++) {
                    witnessprogram[j] = script[script.length - 20 + j];
                }
            }else {
                revert InvalidScriptLength(script.length);
            }


            outputs[i] = Output({
                value: value,
                scriptPubKey: witnessprogram
            });
        }
      //  emit ScriptProcessed(psbtBytes);
        return outputs;
    }
    /// @notice Reads a compact size integer from a byte array
    /// @dev Compact size integers are variable length encodings used in Bitcoin
    /// @param data The byte array to read from
    /// @param pos The position to start reading from
    /// @return A tuple containing:
    ///         - The decoded compact size value as uint64
    ///         - The number of bytes read
    function _readCompactSize(bytes calldata data, uint256 pos) internal pure returns (uint64, uint256) {
        if (pos >= data.length) {
            return (0, 0);
        }

        uint8 first = uint8(data[pos]);
        if (first < 253) {
            return (uint64(first), 1);
        }

        if (first == 253) {
            if (pos + 3 > data.length) {
                return (0, 0);
            }
            return (uint64(_readLittleEndianUint16(data, pos + 1)), 3);
        }

        if (first == 254) {
            if (pos + 5 > data.length) {
                return (0, 0);
            }
            return (uint64(_readLittleEndianUint32(data, pos + 1)), 5);
        }

        if (pos + 9 > data.length) {
            return (0, 0);
        }
        return (uint64(_readLittleEndianUint64(data, pos + 1)), 9);
    }
    /// @notice Skips over an input in a Bitcoin transaction
    /// @dev Used when parsing transaction data to move past input fields
    /// @param data The transaction byte array
    /// @param pos The current position in the byte array
    /// @return The new position after skipping the input
    function _skipInput(bytes calldata data, uint256 pos) internal pure returns (uint256) {
        // Combine bounds checks
        uint256 len = data.length;
        if (pos + 40 > len) {  // 32 (txid) + 4 (vout) + 4 (minimum for next checks)
            revert UnexpectedEndOfData();
        }
        
        unchecked {
            pos += 36;  // Skip txid (32) and vout index (4)
            
            (uint64 scriptSize, uint256 bytesRead) = _readCompactSize(data, pos);
            pos += bytesRead + uint256(scriptSize);
            
            if (pos + 4 > len) {
                revert UnexpectedEndOfData();
            }
            return pos + 4;  // Skip sequence
        }
    }

    /// @notice Reads a 16-bit unsigned integer from a byte array in little-endian format
    /// @dev Combines two bytes into a uint16, with the first byte being least significant
    /// @param data The byte array to read from
    /// @param pos The position in the byte array to start reading
    /// @return The 16-bit unsigned integer in native endianness
    function _readLittleEndianUint16(bytes calldata data, uint256 pos) internal pure returns (uint16) {
        return uint16(uint8(data[pos])) | (uint16(uint8(data[pos + 1])) << 8);
    }

    /// @notice Reads a 32-bit unsigned integer from a byte array in little-endian format
    /// @dev Combines four bytes into a uint32, with the first byte being least significant
    /// @param data The byte array to read from
    /// @param pos The position in the byte array to start reading
    /// @return The 32-bit unsigned integer in native endianness
    function _readLittleEndianUint32(bytes calldata data, uint256 pos) internal pure returns (uint32) {
        return uint32(uint8(data[pos])) |
               (uint32(uint8(data[pos + 1])) << 8) |
               (uint32(uint8(data[pos + 2])) << 16) |
               (uint32(uint8(data[pos + 3])) << 24);
    }

    /// @notice Reads a 64-bit unsigned integer from a byte array in little-endian format
    /// @dev Combines eight bytes into a uint64, with the first byte being least significant
    /// @param data The byte array to read from
    /// @param pos The position in the byte array to start reading
    /// @return The 64-bit unsigned integer in native endianness
    function _readLittleEndianUint64(bytes calldata data, uint256 pos) internal pure returns (uint64) {
        unchecked {
            return uint64(uint8(data[pos])) |
                   (uint64(uint8(data[pos + 1])) << 8) |
                   (uint64(uint8(data[pos + 2])) << 16) |
                   (uint64(uint8(data[pos + 3])) << 24) |
                   (uint64(uint8(data[pos + 4])) << 32) |
                   (uint64(uint8(data[pos + 5])) << 40) |
                   (uint64(uint8(data[pos + 6])) << 48) |
                   (uint64(uint8(data[pos + 7])) << 56);
        }
    }
    /// @notice Extracts a slice of bytes from a byte array
    /// @dev Creates a new bytes array containing the extracted slice
    /// @param data The source byte array to extract from
    /// @param start The starting position in the source array
    /// @param length The number of bytes to extract
    /// @return A new bytes array containing the extracted slice
    function _extractBytes(bytes calldata data, uint256 start, uint256 length) internal pure returns (bytes memory) {
        bytes memory result = new bytes(length);
        assembly {
            // Copy from calldata to memory
            calldatacopy(
                add(result, 32),             // destination (skip length prefix)
                add(data.offset, start),     // source
                length                       // length
            )
        }
        return result;
    }
    function areEqualStrings(bytes memory a, bytes memory b) external pure returns (bool) {
        if (a.length != b.length) return false;
        return keccak256(a) == keccak256(b);
    }

    /// @notice Returns the version number of this library
    /// @dev Used for tracking library versions and compatibility
    /// @return A string representing the semantic version number (e.g. "1.0.0")
    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}