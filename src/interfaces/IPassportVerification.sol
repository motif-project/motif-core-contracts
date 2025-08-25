// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @title IPassportVerification
 * @notice Interface defining the core verification methods used as "passport" verification
 * @dev This interface abstracts the key verification patterns in the Motif system
 */
interface IPassportVerification {
    
    /// @notice Emitted when PSBT verification is performed
    event PSBTVerificationResult(bytes32 indexed psbtHash, bool isValid, string reason);
    
    /// @notice Emitted when signature verification is performed  
    event SignatureVerificationResult(bytes32 indexed sigHash, address signer, bool isValid);
    
    /// @notice Emitted when address verification is performed
    event AddressVerificationResult(string indexed address, bool isValid);

    /**
     * @notice Verifies a PSBT (Partially Signed Bitcoin Transaction)
     * @param psbtBytes The PSBT data to verify
     * @param expectedAddress The expected withdrawal address
     * @param expectedAmount The expected withdrawal amount  
     * @return isValid True if PSBT is valid and contains expected outputs
     */
    function verifyPSBT(
        bytes calldata psbtBytes,
        string memory expectedAddress,
        uint256 expectedAmount
    ) external view returns (bool isValid);

    /**
     * @notice Verifies an ECDSA signature for operator authentication
     * @param messageHash The hash of the message that was signed
     * @param signature The signature to verify (65 bytes)
     * @param expectedSigner The expected signer address
     * @return isValid True if signature is valid and from expected signer
     */
    function verifySignature(
        bytes32 messageHash,
        bytes memory signature, 
        address expectedSigner
    ) external view returns (bool isValid);

    /**
     * @notice Verifies a Bitcoin address against a scriptPubKey
     * @param scriptPubKey The Bitcoin scriptPubKey 
     * @param expectedAddress The expected Bech32 address
     * @return isValid True if scriptPubKey corresponds to the address
     */
    function verifyBitcoinAddress(
        bytes calldata scriptPubKey,
        string memory expectedAddress
    ) external pure returns (bool isValid);

    /**
     * @notice Verifies a Bitcoin script matches a witness program
     * @param script The Bitcoin script
     * @param witnessProgram The expected witness program (32-byte hash)
     * @return isValid True if sha256(script) == witnessProgram
     */
    function verifyScript(
        bytes calldata script,
        bytes32 witnessProgram
    ) external pure returns (bool isValid);

    /**
     * @notice Checks if a signature has been used (replay protection)
     * @param signature The signature to check
     * @return isUsed True if signature has been used before
     */
    function isSignatureUsed(bytes memory signature) external view returns (bool isUsed);

    /**
     * @notice Generates the message hash for signature verification
     * @param pod The pod address
     * @param amount The transaction amount
     * @param transactionData The transaction data
     * @param withdrawAddress The withdrawal address
     * @return messageHash The hash that should be signed
     */
    function getMessageHash(
        address pod,
        uint256 amount,
        bytes memory transactionData,
        string memory withdrawAddress
    ) external pure returns (bytes32 messageHash);
}

/**
 * @title PassportVerificationErrors
 * @notice Custom errors for passport verification failures
 */
interface PassportVerificationErrors {
    
    /// @notice Thrown when PSBT format is invalid
    error InvalidPSBTFormat(string reason);
    
    /// @notice Thrown when signature verification fails
    error InvalidSignature(address expectedSigner, address actualSigner);
    
    /// @notice Thrown when signature has been used before
    error SignatureAlreadyUsed(bytes32 sigHash);
    
    /// @notice Thrown when Bitcoin address verification fails
    error InvalidBitcoinAddress(string expectedAddress, string actualAddress);
    
    /// @notice Thrown when script verification fails
    error InvalidScript(bytes32 expectedHash, bytes32 actualHash);
    
    /// @notice Thrown when input validation fails
    error InvalidInput(string parameter, string reason);
}

/**
 * @title PassportVerificationTypes
 * @notice Data types used in passport verification
 */
interface PassportVerificationTypes {
    
    /// @notice Represents a Bitcoin transaction output
    struct BitcoinOutput {
        uint64 value;           // Amount in satoshis
        bytes scriptPubKey;     // The script public key
        string address;         // The Bech32 address (computed)
    }
    
    /// @notice Represents signature verification data
    struct SignatureData {
        bytes32 messageHash;    // Hash of the signed message
        bytes signature;        // The signature (65 bytes)
        address signer;         // Recovered signer address
        bool isUsed;           // Whether signature has been used
        uint256 timestamp;     // When signature was verified
    }
    
    /// @notice Represents PSBT verification results
    struct PSBTVerificationResult {
        bool isValid;           // Whether PSBT is valid
        uint256 outputCount;    // Number of outputs found
        BitcoinOutput[] outputs; // All outputs in the PSBT
        string failureReason;   // Reason for failure (if any)
    }
    
    /// @notice Configuration for verification parameters
    struct VerificationConfig {
        uint256 maxPSBTSize;     // Maximum PSBT size in bytes
        uint256 maxOutputs;      // Maximum outputs per PSBT
        uint256 minAmount;       // Minimum transaction amount
        bool enableReplayProtection; // Whether to check for signature reuse
    }
}