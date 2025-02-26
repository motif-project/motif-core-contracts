# IAppRegistry
[Git Source](https://github.com/motif-project/motif-core-contracts/blob/2d5ca1db3b104b68bfb25c8e4e92709909e5d1c7/src/interfaces/IAppRegistry.sol)

Interface for managing application registrations in the BitDSM protocol

*Implements app registration, deregistration and status tracking functionality
The IAppRegistry interface provides the following key functionality:
- App registration with signature verification
- App deregistration by owner
- Registration status checks
- Salt cancellation for security
- Metadata URI updates*


## Functions
### registerApp

Registers a new app with signature verification

*Requirements:
- `app` must not be zero address, reverts with `ZeroAddress`
- `app` must not be already registered, reverts with `AppAlreadyRegistered`
- `signature` must be valid EIP-712 signature, reverts with `InvalidSignature`
- `salt` must not be previously used, reverts with `SaltAlreadyUsed`
- `expiry` must be at least MIN_EXPIRY_DURATION from current time, reverts with `InvalidExpiryTime`
- `expiry` must not be in the past, reverts with `SignatureExpired`*


```solidity
function registerApp(address app, bytes memory signature, bytes32 salt, uint256 expiry) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`app`|`address`|The address of the app to register|
|`signature`|`bytes`|The EIP-712 signature proving ownership|
|`salt`|`bytes32`|Unique value to prevent replay attacks|
|`expiry`|`uint256`|Timestamp when signature expires|


### deregisterApp

Deregisters an app from the registry

*Requirements:
- Caller must be contract owner, reverts with `UnauthorizedCaller`
- `app` must be registered, reverts with `AppNotRegistered`*


```solidity
function deregisterApp(address app) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`app`|`address`|The address of the app to deregister|


### isAppRegistered

Checks if an app is registered

*Requirements:
- `app` must not be zero address, reverts with `ZeroAddress`*


```solidity
function isAppRegistered(address app) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`app`|`address`|The address of the app to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if registered, false otherwise|


### cancelSalt

Cancels a salt to prevent its future use

*Requirements:
- Salt must not be already cancelled, reverts with `SaltAlreadyUsed`
- Caller must be the app that would use this salt, reverts with `UnauthorizedCaller`*


```solidity
function cancelSalt(bytes32 salt) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`salt`|`bytes32`|The salt to cancel|


### updateAppMetadataURI

Updates the metadata URI for an app

*Requirements:
- Caller must be a registered app, reverts with `AppNotRegistered`
- URI length must not exceed MAX_METADATA_URI_LENGTH, reverts with `InvalidMetadataURILength`
- URI must not be empty, reverts with `InvalidMetadataURILength`*


```solidity
function updateAppMetadataURI(string calldata metadataURI) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`metadataURI`|`string`|The new metadata URI|


### calculateAppRegistrationDigestHash

Calculates the EIP-712 digest hash for app registration

*Requirements:
- All parameters must not be zero values, reverts with `ZeroAddress`*


```solidity
function calculateAppRegistrationDigestHash(address app, address appRegistry, bytes32 salt, uint256 expiry)
    external
    view
    returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`app`|`address`|The address of the app|
|`appRegistry`|`address`|The address of this registry contract|
|`salt`|`bytes32`|The salt value|
|`expiry`|`uint256`|The expiration timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|bytes32 The calculated EIP-712 digest hash|


### isSaltCancelled

Checks if a salt has been cancelled

*Requirements:
- `app` must be registered, reverts with `AppNotRegistered`*


```solidity
function isSaltCancelled(address app, bytes32 salt) external view returns (bool);
```

### getVersion

Gets the interface version


```solidity
function getVersion() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|string The semantic version string|


### getTotalAppsRegistered

Gets the total number of apps registered


```solidity
function getTotalAppsRegistered() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The total number of apps registered|


## Events
### AppRegistrationStatusUpdated
Emitted when registration status changes


```solidity
event AppRegistrationStatusUpdated(address indexed app, AppRegistrationStatus status);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`app`|`address`|The address of the app|
|`status`|`AppRegistrationStatus`|The new registration status|

### AppMetadataURIUpdated
Emitted when metadata URI is updated


```solidity
event AppMetadataURIUpdated(address indexed app, string metadataURI);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`app`|`address`|The address of the app|
|`metadataURI`|`string`|The new metadata URI|

### SaltCancelled
Emitted when a salt is cancelled


```solidity
event SaltCancelled(address indexed app, bytes32 indexed salt);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`app`|`address`|The address of the app|
|`salt`|`bytes32`|The salt value|

## Errors
### ZeroAddress

```solidity
error ZeroAddress();
```

### InvalidSignature

```solidity
error InvalidSignature();
```

### SignatureExpired

```solidity
error SignatureExpired();
```

### SignatureNotYetValid

```solidity
error SignatureNotYetValid();
```

### SaltAlreadySpent

```solidity
error SaltAlreadySpent();
```

### AppAlreadyRegistered

```solidity
error AppAlreadyRegistered();
```

### AppNotRegistered

```solidity
error AppNotRegistered();
```

### InvalidMetadataURILength

```solidity
error InvalidMetadataURILength();
```

### UnauthorizedCaller

```solidity
error UnauthorizedCaller();
```

### InvalidExpiryTime

```solidity
error InvalidExpiryTime();
```

## Enums
### AppRegistrationStatus

```solidity
enum AppRegistrationStatus {
    UNREGISTERED,
    REGISTERED
}
```

