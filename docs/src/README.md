# MOTIF : The first in-kind Bitcoin staking DTP on Ethereum

![Motif Cover](../../assets/og_image.png)

**Motif is the first in-kind Bitcoin staking DTP issuance protocol on Ethereum.**


Motif is a decentralized protocol that redefines Bitcoin staking by separating custody from issuance. It empowers Bitcoin holders to solo stake through EigenLayer and access a permissionless staking index that connects them to top-tier digital communities — spanning security, lending, stablecoins, data storage, prediction markets, and AI wallets.

# Core Concepts

## Bitcoin Remap

Motif’s solo staking mechanism is powered by Bitcoin Remap, allowing operators to facilitate in-kind creation and redemption. This ensures that staking Delegated Tokenised Position (DTPs) remain fully backed by Bitcoin, while enabling operators to design risk-adjusted remaps tailored to their Bitcoin Liquidity Providers' (LPs) staking preferences.

## BitcoinPod (BOD)

At the heart of the Motif protocol lies the BitcoinPod (BOD), inspired by the EigenPod concept. A BOD is a non-custodial vault on the Bitcoin network, created using a P2WSH Bitcoin address. The primary objective of a BOD is to ensure that a smart contract can slash the BOD for predetermined conditions for the value already held in the BOD or set to be processed through it.

### Key Functions of BOD

- Validator Withdrawal Address: Acts as the withdrawal address for one or more PoS validators managed by the BOD owner.
- Pre-signed Unbonding Transactions: Verifies pre-signed unbonding transactions from the source chain.
- Blockchain Monitoring: Continuously monitors the Bitcoin blockchain to track the status of all BitcoinPods.
- Delegation: Provides a delegation mechanism to other smart contracts via the BOD manager.

A BOD can be either stateful or stateless:

- Stateful: Holds Bitcoin directly.
- Stateless: Acts as a withdrawal/unbonding address for a PoS validator on another chain.

Importantly, a BOD is not a bridge and does not mint any ERC-20 tokens. It simply delegates spending authority to a smart contract, unlocking new financial applications.

# Use Cases

By leveraging BitcoinPods, Motif unlocks a range of innovative financial applications, including:

- Liquid Staking Tokens (LSTs): PoS validators using Bitcoin to secure their chains can set the BOD as their withdrawal address, minting an LST on Ethereum.
- Lending/Borrowing: BODs can be locked as collateral to borrow stable assets on Ethereum.
- Stablecoins: BODs can act as Collateralized Debt Positions (CDPs) to mint stable assets.
- Insurance: BODs can serve as an insurance mechanism for BTC bridges on Ethereum.
- BTC Bridge: BODs can act as deposit addresses for minting wrapped versions of Bitcoin on Ethereum.

# Security

BitcoinPods are secured by restaked security available to the EigenLayer's AVS. Operator sets can issue BitcoinPods with predetermined independent tasks, secured either through insurance mechanisms built using BitDSM or Liquid Restaking Tokens (LRTs) on Ethereum.

Motif is pushing the boundaries of Bitcoin’s utility by combining EigenLayer’s restaking innovations with native Bitcoin security. This foundation unlocks a dynamic ecosystem of staking, lending, and financial primitives — all while keeping Bitcoin at the core.

# Frontend

Front end link: https://motif.finance/

You can find the [Motif examples here](https://github.com/Motif-Protocol/motif-examples).

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/DeployMotif.s.sol:DeployMotif --fork-url http://localhost:8545 --broadcast --private-key $PRIVATE_KEY
```

### To-Do

EigenLayer AVS deployment and operator registration.

```shell
$ forge --help
$ anvil --help
$ cast --help
``` 

## Deployment

```shell
$ forge script script/DeployMotif.s.sol:DeployMotif --fork-url http://localhost:8545 --broadcast --private-key $PRIVATE_KEY
```

## Existing Holesky Testnet Deployment

| Contract Name                      | Holesky Address                                                                                                               |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| ProxyAdmin                         | [0xc8a51779c4d6365dd5fc4779a6518fc1598d1654](https://holesky.etherscan.io/address/0xc8a51779c4d6365dd5fc4779a6518fc1598d1654) |
| MotifStakeRegistry                 | [0xba3c98e3d60871f92d1c8890a13207fe46534641](https://holesky.etherscan.io/address/0xba3c98e3d60871f92d1c8890a13207fe46534641) |
| MotifStakeRegistryImplementation   | [0x37e04ac839c85e472310ff592b83e3f15e9920ec](https://holesky.etherscan.io/address/0x37e04ac839c85e472310ff592b83e3f15e9920ec) |
| MotifServiceManager                | [0x7238717bcf57fa8dcfece86f827e05a1ad4bf6b1](https://holesky.etherscan.io/address/0x7238717bcf57fa8dcfece86f827e05a1ad4bf6b1) |
| MotifServiceManagerImplementation  | [0xfadca4a8774deaf364fa92d62054430ff76b3e97](https://holesky.etherscan.io/address/0xfadca4a8774deaf364fa92d62054430ff76b3e97) |
| AppRegistry                        | [0x91677dd787cd9056c5805cbb74e271fd83d88e61](https://holesky.etherscan.io/address/0x91677dd787cd9056c5805cbb74e271fd83d88e61) |
| AppRegistryImplementation          | [0x25dd3fc30f59f240cfccfd893340f9cb9e365d75](https://holesky.etherscan.io/address/0x25dd3fc30f59f240cfccfd893340f9cb9e365d75) |
| BitcoinPodManager                  | [0x96eae70bc21925dde05602c87c4483579205b1f6](https://holesky.etherscan.io/address/0x96eae70bc21925dde05602c87c4483579205b1f6) |
| BitcoinPodManagerImplementation    | [0x49741f924ef91b14184ebe38b952f3ddf09008be](https://holesky.etherscan.io/address/0x49741f924ef91b14184ebe38b952f3ddf09008be) |

Please see [Current Testnet Deployment](https://github.com/Layr-Labs/eigenlayer-contracts?tab=readme-ov-file#current-testnet-deployment) for additional deployed addresses of core EigenLayer contracts.

## Access Deployment Files

Contract deployment files including the abi's can be found at the following address.

```
DEPLOYMENT_FILES_DIR=contracts/script/output/${CHAINID}
```
