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
    bytes constant CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l";
   
  
    // Events
    event ScriptProcessed(bytes32 indexed witnessProgram);

    /// @notice Calculates witness program from script
    /// @param script The input script
    /// @return witnessProgram The calculated witness program
    function getWitnessProgram(bytes calldata script) 
        public
        pure
        returns (bytes32 witnessProgram)
    {
        if (script.length < MIN_SCRIPT_LENGTH) {
            revert InvalidScriptLength(script.length);
        }
        if (script.length > MAX_SCRIPT_LENGTH) {
            revert ScriptTooLong(script.length);
        }

        witnessProgram = sha256(script);
    }
    
    /// @notice Converts a script to a P2WSH scriptPubKey format
    /// @dev Creates a Pay-to-Witness-Script-Hash (P2WSH) scriptPubKey from a given script
    /// @param script The script to convert
    /// @return The P2WSH scriptPubKey in format: OP_0 <32-byte-hash>
    function getScriptPubKey(bytes calldata script) public pure returns (bytes memory) {
        bytes32 witnessProgram = getWitnessProgram(script);
        
        // P2WSH scriptPubKey: OP_0 <32-byte-hash>
        return abi.encodePacked(
            WITNESS_VERSION_0,  // witness version (0x00)
            PUSH_32_BYTES,     // push 32 bytes (0x20)
            witnessProgram
        );
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
    function _convertBits(bytes calldata data, uint8 fromBits, uint8 toBits, bool pad) 
        internal pure returns (bytes memory) {
        uint256 acc = 0;  // Accumulator for bits
        uint256 bits = 0; // Number of bits in accumulator
        bytes memory ret = new bytes(64); // Inefficient:: Max possible size buffer
        // Should calculate exact size needed: (data.length * fromBits + toBits - 1) / toBits
        uint256 length = 0; // Current length of output
        
        // Process each input byte
        for (uint256 i = 0; i < data.length; i++) {
            acc = (acc << fromBits) | uint8(data[i]);
            bits += fromBits;
            
            // Extract complete groups of toBits
            while (bits >= toBits) {
                bits -= toBits;
                ret[length] = bytes1(uint8((acc >> bits) & ((1 << toBits) - 1)));
                length++;
            }
        }
        
        // Handle remaining bits if padding is requested
        if (pad && bits > 0) {
            ret[length] = bytes1(uint8((acc << (toBits - bits)) & ((1 << toBits) - 1)));
            length++;
        }
        
        // Create final result array trimmed to actual length
        bytes memory result = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = ret[i];
        }
        return result;
    }
    
    /// @notice Creates a checksum for Bech32 address
    /// @dev Implements the checksum calculation for Bech32 addresses
    /// @param hrp The human-readable part of the Bech32 address
    /// @param data The data part of the Bech32 address
    /// @return A bytes array containing the checksum
    function _createChecksum(bytes memory hrp, bytes memory data) 
        internal pure returns (bytes memory) {
        uint256[] memory values = new uint256[](hrp.length + data.length + 7);
        uint256 i = 0;
        
        // Expand HRP
        for (; i < hrp.length; i++) {
            values[i] = uint8(hrp[i]) >> 5;
        }
        values[i++] = 0;
        for (uint256 j = 0; j < hrp.length; j++) {
            values[i++] = uint8(hrp[j]) & 31;
        }
        
        // Add data
        for (uint256 j = 0; j < data.length; j++) {
            values[i++] = uint8(data[j]);
        }
        
        // Add checksum template
        values[i++] = 0;
        values[i++] = 0;
        values[i++] = 0;
        values[i++] = 0;
        values[i++] = 0;
        values[i++] = 0;
        
        // Calculate checksum
        uint256 polymod = 1;
        for (i = 0; i < values.length; i++) {
            uint256 b = polymod >> 25;
            polymod = ((polymod & 0x1ffffff) << 5) ^ values[i];
            for (uint256 j = 0; j < 5; j++) {
                if (((b >> j) & 1) == 1) {
                    polymod ^= uint256(0x3b6a57b2) << (j * 5);
                }
            }
        }
        polymod ^= 1;
        
        // Convert checksum to 5-bit array
        bytes memory checksum = new bytes(6);
        for (i = 0; i < 6; i++) {
            checksum[5 - i] = bytes1(uint8((polymod >> (5 * i)) & 31));
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
        require(scriptPubKey.length > 2, "Invalid scriptPubKey length");
        require(scriptPubKey[0] == 0x00, "Invalid witness version");
        
        // HRP for mainnet
        bytes memory hrp = "tb";
        
        // Convert scriptPubKey to 5-bit data
        bytes memory converted = _convertBits(scriptPubKey, 8, 5, true);
        
        // Get checksum
        bytes memory checksum = _createChecksum(hrp, converted);
        
        // Combine all parts
        bytes memory combined = new bytes(converted.length + checksum.length);
        for (uint256 i = 0; i < converted.length; i++) {
            combined[i] = converted[i];
        }
        for (uint256 i = 0; i < checksum.length; i++) {
            combined[converted.length + i] = checksum[i];
        }
        
        // Create final string
        bytes memory result = new bytes(hrp.length + 1 + combined.length);
        for (uint256 i = 0; i < hrp.length; i++) {
            result[i] = hrp[i];
        }
        result[hrp.length] = "1";
        
        // Encode data using charset
        for (uint256 i = 0; i < combined.length; i++) {
            result[hrp.length + 1 + i] = CHARSET[uint8(combined[i])];
        }
        
        return string(result);
    }

    /// @notice Extracts two public keys from a Bitcoin script
    /// @dev Assumes the script contains two 33-byte compressed public keys in sequence
    /// @param scriptBytes The raw Bitcoin script bytes containing the public keys
    /// @return pubKey1 The first 33-byte compressed public key
    /// @return pubKey2 The second 33-byte compressed public key
    function extractPublicKeys(bytes calldata scriptBytes) public pure returns (bytes memory pubKey1, bytes memory pubKey2) {
        require(scriptBytes.length >= 66, "Script is too short to contain two public keys");
    // Add more specific validation
    //if (scriptBytes.length < 66) revert InvalidScriptLength(scriptBytes.length);
    //if (scriptBytes[0] != 0x21) revert InvalidPublicKeyFormat(); // Check for compressed pubkey marker
        pubKey1 = new bytes(33);
        pubKey2 = new bytes(33);

        for(uint256 i = 0; i < 33; i++) {
            pubKey1[i] = scriptBytes[i + 1];
            pubKey2[i] = scriptBytes[i + 34];
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

            outputs[i] = Output({
                value: value,
                scriptPubKey: script
            });
        }

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
        if (pos + 32 > data.length) {
            revert UnexpectedEndOfData();
        }
        pos += 32; // Skip txid

        if (pos + 4 > data.length) {
            revert UnexpectedEndOfData();
        }
        pos += 4; // Skip vout index

        // Skip script
        if (pos >= data.length) {
            revert UnexpectedEndOfData();
        }
        (uint64 scriptSize, uint256 bytesRead) = _readCompactSize(data, pos);
        pos += bytesRead + uint256(scriptSize);

        if (pos + 4 > data.length) {
            revert UnexpectedEndOfData();
        }
        pos += 4; // Skip sequence

        return pos;
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
        for (uint256 i = 0; i < length; i++) {
            result[i] = data[start + i];
        }
        return result;
    }

    /// @notice Returns the version number of this library
    /// @dev Used for tracking library versions and compatibility
    /// @return A string representing the semantic version number (e.g. "1.0.0")
    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}