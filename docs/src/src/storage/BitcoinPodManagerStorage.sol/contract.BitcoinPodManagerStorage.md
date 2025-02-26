# BitcoinPodManagerStorage
[Git Source](https://github.com/motif-project/motif-core-contracts/blob/2d5ca1db3b104b68bfb25c8e4e92709909e5d1c7/src/storage/BitcoinPodManagerStorage.sol)

Storage contract for BitcoinPodManager

*Contains all state variables used by BitcoinPodManager*


## State Variables
### _totalPods
Total number of pods created


```solidity
uint256 internal _totalPods;
```


### _totalTVL
Total Value Locked in all pods (in satoshis)


```solidity
uint256 internal _totalTVL;
```


### _motifServiceManager
Address of the Motif Service manager contract


```solidity
address internal _motifServiceManager;
```


### _appRegistry
Address of the App Registry contract


```solidity
address internal _appRegistry;
```


### _motifStakeRegistry
Address of the Motif Stake Registry contract


```solidity
address internal _motifStakeRegistry;
```


### _userToPod
Mapping of user address to their pod address


```solidity
mapping(address => address) internal _userToPod;
```


### _podToApp
Mapping of pod address to the app address it is delegated to


```solidity
mapping(address => address) internal _podToApp;
```


### _podToBitcoinDepositRequest
Mapping of pod address to the Bitcoin deposit request


```solidity
mapping(address => IBitcoinPodManager.BitcoinDepositRequest) internal _podToBitcoinDepositRequest;
```


### _podToWithdrawalAddress
Mapping of pod address to the withdrawal address


```solidity
mapping(address => string) internal _podToWithdrawalAddress;
```


### __gap
*Gap for future storage variables*


```solidity
uint256[50] private __gap;
```


## Functions
### _setUserPod

*Internal setters*


```solidity
function _setUserPod(address user, address pod) internal;
```

### _setPodApp


```solidity
function _setPodApp(address pod, address app) internal;
```

