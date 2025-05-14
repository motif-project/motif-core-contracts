// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "./reBTC.sol";

/**
 * @title reBTCPermit - ERC2612 Permit Extension for reBTC
 * @notice Adds permit functionality to reBTC token
 * @dev This contract extends reBTC with ERC2612 permit functionality
 */
contract reBTCPermit is Initializable, reBTC {
    using ECDSAUpgradeable for bytes32;

    // ================ Constants ================

    /// @notice EIP-712 typehash for permit
    bytes32 public constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    /// @notice Threshold for large permit notification
    uint256 public constant LARGE_PERMIT_THRESHOLD = 1000 * 10**8; // 1,000 BTC

    // ================ Storage ================

    /// @notice Nonces for permit signatures
    mapping(address => uint256) private _nonces;

    /// @notice Domain separator for EIP-712
    bytes32 private _domainSeparator;

    // ================ Events ================

    /// @notice Emitted when permit is used
    event PermitUsed(
        address indexed owner,
        address indexed spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    );

    /// @notice Emitted when a permit is attempted but fails
    event PermitFailed(
        address indexed owner,
        address indexed spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline,
        string reason
    );

    /// @notice Emitted when a permit is used with a high value
    event LargePermit(
        address indexed owner,
        address indexed spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    );

    // ================ Initializer ================

    /**
     * @notice Initializes the permit functionality
     * @param admin Address that will have admin role
     */
    function initializePermit(address admin) public initializer {
        super.initialize(admin);

        // Initialize domain separator
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        _domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Motif Bitcoin")),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    // ================ External Functions ================

    /**
     * @notice Sets allowance using a signed permit
     * @param owner Token owner's address
     * @param spender Spender's address
     * @param value Amount of tokens to approve
     * @param deadline Expiration time of the permit
     * @param v Part of the signature
     * @param r Part of the signature
     * @param s Part of the signature
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        try this.permitInternal(owner, spender, value, deadline, v, r, s) {
            // Success case is handled in permitInternal
        } catch Error(string memory reason) {
            emit PermitFailed(owner, spender, value, _nonces[owner], deadline, reason);
            revert(reason);
        } catch {
            emit PermitFailed(owner, spender, value, _nonces[owner], deadline, "Unknown error");
            revert("Permit failed");
        }
    }

    /**
     * @notice Internal permit function with enhanced logging
     */
    function permitInternal(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "Permit expired");
        require(owner != address(0), "Invalid owner");
        require(spender != address(0), "Invalid spender");

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                _useNonce(owner),
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = hash.recover(v, r, s);
        require(signer == owner, "Invalid signature");

        _approve(owner, spender, value);

        // Log large permits
        if (value >= LARGE_PERMIT_THRESHOLD) {
            emit LargePermit(owner, spender, value, _nonces[owner] - 1, deadline);
        }

        emit PermitUsed(owner, spender, value, _nonces[owner] - 1, deadline);
    }

    /**
     * @notice Returns the current nonce for an address
     * @param owner Address to get nonce for
     * @return Current nonce
     */
    function nonces(address owner) external view returns (uint256) {
        return _nonces[owner];
    }

    /**
     * @notice Returns the domain separator used in the encoding of the signature
     * @return Domain separator
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparator;
    }

    // ================ Internal Functions ================

    /**
     * @notice Returns the domain separator for EIP-712
     * @return Domain separator
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        return _domainSeparator;
    }

    /**
     * @notice Hashes a typed data structure according to EIP-712
     * @param structHash Hash of the typed data structure
     * @return Hash of the typed data
     */
    function _hashTypedDataV4(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparatorV4(), structHash));
    }

    /**
     * @notice Uses a nonce and returns the current value
     * @param owner Address to use nonce for
     * @return Current nonce
     */
    function _useNonce(address owner) internal returns (uint256) {
        uint256 current = _nonces[owner];
        _nonces[owner] = current + 1;
        return current;
    }
} 