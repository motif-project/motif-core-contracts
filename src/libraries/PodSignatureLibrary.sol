// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title PodSignatureLibrary
 * @notice Pure library for EIP-712 signature verification in Bitcoin pods
 * @dev Handles signature verification for curator operations with replay protection
 */
library PodSignatureLibrary {
    // EIP-712 Type Hashes
    bytes32 internal constant TRANSFER_TO_STRATEGY_TYPEHASH = 
        keccak256("TransferToStrategy(address owner,address strategy,uint256 amount,uint256 nonce,uint256 deadline)");

    bytes32 internal constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    // Custom errors for gas efficiency
    error InvalidSignature();
    error SignatureExpired();
    error ZeroAmount();
    error InvalidDeadline();

    /**
     * @notice Calculate domain separator for EIP-712
     * @param contractAddress Address of the contract using signatures
     * @param contractName Name of the contract for domain separation
     * @return domainSeparator The calculated domain separator
     */
    function calculateDomainSeparator(
        address contractAddress,
        string memory contractName
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(contractName)),
                block.chainid,
                contractAddress
            )
        );
    }

    /**
     * @notice Verify transfer to strategy signature
     * @param domainSeparator The domain separator for this contract
     * @param owner Address of the token owner (must match signature)
     * @param strategy Address of the strategy receiving tokens
     * @param amount Amount of tokens to transfer
     * @param nonce Current nonce for the owner (for replay protection)
     * @param deadline Signature expiry timestamp
     * @param v Recovery byte of the signature
     * @param r First 32 bytes of the signature
     * @param s Second 32 bytes of the signature
     * @return signer The recovered signer address
     */
    function verifyTransferSignature(
        bytes32 domainSeparator,
        address owner,
        address strategy,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (address signer) {
        // Validate inputs
        if (deadline < block.timestamp) revert SignatureExpired();
        if (amount == 0) revert ZeroAmount();
        
        // Build the signature hash
        bytes32 structHash = keccak256(
            abi.encode(
                TRANSFER_TO_STRATEGY_TYPEHASH,
                owner,
                strategy,
                amount,
                nonce,
                deadline
            )
        );
        
        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        
        // Recover signer
        signer = ecrecover(hash, v, r, s);
        
        // Validate signature
        if (signer != owner || signer == address(0)) {
            revert InvalidSignature();
        }
        
        return signer;
    }

    /**
     * @notice Verify and execute signature validation with nonce increment
     * @param domainSeparator The domain separator for this contract  
     * @param nonces Storage reference to nonces mapping
     * @param owner Address of the token owner
     * @param strategy Address of the strategy receiving tokens
     * @param amount Amount of tokens to transfer
     * @param deadline Signature expiry timestamp
     * @param v Recovery byte of the signature
     * @param r First 32 bytes of the signature
     * @param s Second 32 bytes of the signature
     * @return success True if signature is valid
     */
    function verifyAndIncrementNonce(
        bytes32 domainSeparator,
        mapping(address => uint256) storage nonces,
        address owner,
        address strategy,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal returns (bool success) {
        // Get current nonce and increment for replay protection
        uint256 currentNonce = nonces[owner]++;
        
        // Verify signature with current nonce
        address signer = verifyTransferSignature(
            domainSeparator,
            owner,
            strategy,
            amount,
            currentNonce,
            deadline,
            v,
            r,
            s
        );
        
        // Return success (will revert if signature invalid)
        return signer == owner;
    }

    /**
     * @notice Get the current nonce for an address
     * @param nonces Storage reference to nonces mapping
     * @param owner Address to get nonce for
     * @return currentNonce The current nonce value
     */
    function getCurrentNonce(
        mapping(address => uint256) storage nonces,
        address owner
    ) internal view returns (uint256 currentNonce) {
        return nonces[owner];
    }

    /**
     * @notice Generate EIP-712 typed data hash for off-chain signing
     * @param domainSeparator The domain separator for this contract
     * @param owner Address of the token owner
     * @param strategy Address of the strategy receiving tokens
     * @param amount Amount of tokens to transfer
     * @param nonce Current nonce for the owner
     * @param deadline Signature expiry timestamp
     * @return typedDataHash The hash to be signed off-chain
     */
    function getTypedDataHash(
        bytes32 domainSeparator,
        address owner,
        address strategy,
        uint256 amount,
        uint256 nonce,
        uint256 deadline
    ) internal pure returns (bytes32 typedDataHash) {
        bytes32 structHash = keccak256(
            abi.encode(
                TRANSFER_TO_STRATEGY_TYPEHASH,
                owner,
                strategy,
                amount,
                nonce,
                deadline
            )
        );
        
        return keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
    }
}