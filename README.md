# MOTIF : The first in-kind Bitcoin staking DTP on Ethereum

![Motif Cover](./assets/og_image.png)

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
| ProxyAdmin                         | [0xd8DE7ffD0F33e1149B8B902e41a17bb818c9f128](https://holesky.etherscan.io/address/0xd8DE7ffD0F33e1149B8B902e41a17bb818c9f128) |
| MotifStakeRegistry                 | [0x83210B83d55fbCA44099972C358Bf8a4493352B1](https://holesky.etherscan.io/address/0x83210B83d55fbCA44099972C358Bf8a4493352B1) |
| MotifStakeRegistryImplementation   | [0xfb3637ca52db2997c73a3a9babf04277de1f2881](https://holesky.etherscan.io/address/0xfb3637ca52db2997c73a3a9babf04277de1f2881) |
| MotifServiceManager                | [0xbf49e34a432EAaC181c7AA65b98A20d04353dadD](https://holesky.etherscan.io/address/0xbf49e34a432EAaC181c7AA65b98A20d04353dadD) |
| MotifServiceManagerImplementation  | [0x21bcce172f6a5714f63f34aa63a1742b9ab37a19](https://holesky.etherscan.io/address/0x21bcce172f6a5714f63f34aa63a1742b9ab37a19) |
| AppRegistry                        | [0xe4FAb06cb45dE808894906146456c9f4D66Fad58](https://holesky.etherscan.io/address/0xe4FAb06cb45dE808894906146456c9f4D66Fad58) |
| AppRegistryImplementation          | [0x78bf598b76c21c9095dfe2bed9d47e411720dac7](https://holesky.etherscan.io/address/0x78bf598b76c21c9095dfe2bed9d47e411720dac7) |
| BitcoinPodManager                  | [0x033253C94884fdeB529857a66D06047384164525](https://holesky.etherscan.io/address/0x033253C94884fdeB529857a66D06047384164525) |
| BitcoinPodManagerImplementation    | [0xbb296d05c6df861e2d8a4b6d8a34af175b6a40e9](https://holesky.etherscan.io/address/0xbb296d05c6df861e2d8a4b6d8a34af175b6a40e9) |

Please see [Current Testnet Deployment](https://github.com/Layr-Labs/eigenlayer-contracts?tab=readme-ov-file#current-testnet-deployment) for additional deployed addresses of core EigenLayer contracts.

## Access Deployment Files

Contract deployment files including the abi's can be found at the following address.

```
DEPLOYMENT_FILES_DIR=contracts/script/output/${CHAINID}
```
