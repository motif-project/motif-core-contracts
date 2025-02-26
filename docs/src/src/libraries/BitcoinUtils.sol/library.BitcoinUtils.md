# BitcoinUtils
[Git Source](https://github.com/motif-project/motif-core-contracts/blob/2d5ca1db3b104b68bfb25c8e4e92709909e5d1c7/src/libraries/BitcoinUtils.sol)

Collection of utilities for Bitcoin operations

*Version 1.0.0*


## State Variables
### MAX_SCRIPT_LENGTH

```solidity
uint256 private constant MAX_SCRIPT_LENGTH = 10000;
```


### MIN_SCRIPT_LENGTH

```solidity
uint256 private constant MIN_SCRIPT_LENGTH = 1;
```


### WITNESS_VERSION_0

```solidity
bytes1 private constant WITNESS_VERSION_0 = 0x00;
```


### PUSH_32_BYTES

```solidity
bytes1 private constant PUSH_32_BYTES = 0x20;
```


## Functions
### getScriptPubKey

Converts a script to a P2WSH scriptPubKey format

*Creates a Pay-to-Witness-Script-Hash (P2WSH) scriptPubKey from a given script*


```solidity
function getScriptPubKey(bytes calldata script) public pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`script`|`bytes`|The script to convert|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The P2WSH witnessProgram as scriptPubKey|


### verifyScriptForAddress

Verifies if a script matches an address's witness program

*Computes the SHA256 hash of the script and compares it with the provided witness program*


```solidity
function verifyScriptForAddress(bytes calldata script, bytes32 witnessProgram) public pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`script`|`bytes`|The Bitcoin script to verify|
|`witnessProgram`|`bytes32`|The witness program (32-byte hash) to check against|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if the script's hash matches the witness program, false otherwise|


### _convertBits

Converts an array of bytes from one bit width to another

*Used for converting between 8-bit and 5-bit representations in Bech32 encoding*


```solidity
function _convertBits(bytes memory data, uint8 fromBits, uint8 toBits, bool pad) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|The input byte array to convert|
|`fromBits`|`uint8`|The bit width of the input data (typically 8)|
|`toBits`|`uint8`|The desired output bit width (typically 5)|
|`pad`|`bool`|Whether to pad any remaining bits in the final group|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|A new byte array with the converted bit representation|


### _createChecksum

Creates a checksum for Bech32 address

*Implements the checksum calculation for Bech32 addresses*


```solidity
function _createChecksum(bytes memory hrp, bytes memory data) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hrp`|`bytes`|The human-readable part of the Bech32 address|
|`data`|`bytes`|The data part of the Bech32 address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|A bytes array containing the checksum|


### convertScriptPubKeyToBech32Address

Converts a Bitcoin scriptPubKey to a Bech32 address

*Implements the Bech32 address encoding specification (BIP-0173)*


```solidity
function convertScriptPubKeyToBech32Address(bytes calldata scriptPubKey) public pure returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`scriptPubKey`|`bytes`|The Bitcoin scriptPubKey to convert, must be witness program|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The Bech32 encoded Bitcoin address as a string|


### extractPublicKeys

Extracts two public keys from a Bitcoin script

*Assumes the script contains two 33-byte compressed public keys in sequence*


```solidity
function extractPublicKeys(bytes calldata scriptBytes)
    public
    pure
    returns (bytes memory pubKey1, bytes memory pubKey2);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`scriptBytes`|`bytes`|The raw Bitcoin script bytes containing the public keys|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pubKey1`|`bytes`|The first 33-byte compressed public key|
|`pubKey2`|`bytes`|The second 33-byte compressed public key|


### extractVoutFromPSBT

Extracts outputs from a PSBT

*Parses the PSBT to extract output details*


```solidity
function extractVoutFromPSBT(bytes calldata psbtBytes) public pure returns (Output[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`psbtBytes`|`bytes`|The PSBT byte array to parse|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Output[]`|An array of Output structs containing value and scriptPubKey|


### _readCompactSize

Reads a compact size integer from a byte array

*Compact size integers are variable length encodings used in Bitcoin*


```solidity
function _readCompactSize(bytes calldata data, uint256 pos) internal pure returns (uint64, uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|The byte array to read from|
|`pos`|`uint256`|The position to start reading from|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint64`|A tuple containing: - The decoded compact size value as uint64 - The number of bytes read|
|`<none>`|`uint256`||


### _skipInput

Skips over an input in a Bitcoin transaction

*Used when parsing transaction data to move past input fields*


```solidity
function _skipInput(bytes calldata data, uint256 pos) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|The transaction byte array|
|`pos`|`uint256`|The current position in the byte array|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The new position after skipping the input|


### _readLittleEndianUint16

Reads a 16-bit unsigned integer from a byte array in little-endian format

*Combines two bytes into a uint16, with the first byte being least significant*


```solidity
function _readLittleEndianUint16(bytes calldata data, uint256 pos) internal pure returns (uint16);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|The byte array to read from|
|`pos`|`uint256`|The position in the byte array to start reading|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint16`|The 16-bit unsigned integer in native endianness|


### _readLittleEndianUint32

Reads a 32-bit unsigned integer from a byte array in little-endian format

*Combines four bytes into a uint32, with the first byte being least significant*


```solidity
function _readLittleEndianUint32(bytes calldata data, uint256 pos) internal pure returns (uint32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|The byte array to read from|
|`pos`|`uint256`|The position in the byte array to start reading|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|The 32-bit unsigned integer in native endianness|


### _readLittleEndianUint64

Reads a 64-bit unsigned integer from a byte array in little-endian format

*Combines eight bytes into a uint64, with the first byte being least significant*


```solidity
function _readLittleEndianUint64(bytes calldata data, uint256 pos) internal pure returns (uint64);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|The byte array to read from|
|`pos`|`uint256`|The position in the byte array to start reading|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint64`|The 64-bit unsigned integer in native endianness|


### _extractBytes

Extracts a slice of bytes from a byte array

*Creates a new bytes array containing the extracted slice*


```solidity
function _extractBytes(bytes calldata data, uint256 start, uint256 length) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|The source byte array to extract from|
|`start`|`uint256`|The starting position in the source array|
|`length`|`uint256`|The number of bytes to extract|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|A new bytes array containing the extracted slice|


### areEqualStrings


```solidity
function areEqualStrings(bytes memory a, bytes memory b) external pure returns (bool);
```

### version

Returns the version number of this library

*Used for tracking library versions and compatibility*


```solidity
function version() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|A string representing the semantic version number (e.g. "1.0.0")|


## Errors
### InvalidScriptLength

```solidity
error InvalidScriptLength(uint256 length);
```

### ScriptTooLong

```solidity
error ScriptTooLong(uint256 length);
```

### UnauthorizedOperator

```solidity
error UnauthorizedOperator(address caller);
```

### InvalidPSBTMagic

```solidity
error InvalidPSBTMagic();
```

### PSBTTooShort

```solidity
error PSBTTooShort();
```

### UnsupportedPSBTVersion

```solidity
error UnsupportedPSBTVersion(uint8 version);
```

### ExpectedGlobalUnsignedTx

```solidity
error ExpectedGlobalUnsignedTx();
```

### UnexpectedEndOfData

```solidity
error UnexpectedEndOfData();
```

## Structs
### Output

```solidity
struct Output {
    uint64 value;
    bytes scriptPubKey;
}
```

