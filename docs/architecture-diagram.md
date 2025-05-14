# Motif Core Contracts Architecture

This document provides a visual representation of the Motif Core Contracts architecture and its component relationships.

## System Architecture Diagram

```mermaid
graph TB
    %% Core Contracts
    subgraph Core["Core Contracts"]
        direction TB
        EBP[EnhancedBitcoinPod]
        BPM[BitcoinPodManager]
        MSM[MotifServiceManager]
        MSR[MotifStakeRegistry]
        AR[AppRegistry]
        BP[BitcoinPod]
    end

    %% Token Contracts
    subgraph Token["Token Contracts"]
        direction TB
        MB[MotifBitcoin]
        WMB[WMotifBTC]
        MBC[MotifBTC]
    end

    %% Module Contracts
    subgraph Modules["Module Contracts"]
        direction TB
        RM[RoleManager]
        TH[TokenHub]
        FM[FeeManager]
    end

    %% Interface Contracts
    subgraph Interfaces["Interface Contracts"]
        direction TB
        IBP[IBitcoinPod]
        IBPM[IBitcoinPodManager]
        ITH[ITokenHub]
        IMSR[IMotifStakeRegistry]
        IMSM[IMotifServiceManager]
        IAR[IAppRegistry]
    end

    %% Core Relationships
    EBP -->|implements| IBP
    BPM -->|implements| IBPM
    MSM -->|implements| IMSM
    MSR -->|implements| IMSR
    AR -->|implements| IAR

    %% Token Relationships
    MB -->|wraps| MBC
    WMB -->|wraps| MB

    %% Module Relationships
    EBP -->|uses| FM
    EBP -->|uses| RM
    TH -->|uses| RM
    TH -->|uses| FM

    %% Core to Module Relationships
    EBP -->|interacts with| TH
    BPM -->|manages| EBP
    BPM -->|uses| MSR
    BPM -->|uses| AR

    %% Token Hub Integration
    TH -->|mints/burns| MB
    EBP -->|delegates to| TH

    %% Service Management
    MSM -->|manages| AR
    MSM -->|uses| MSR

    %% Role Management
    EBP -->|inherits| RM
    BPM -->|inherits| RM
    MSM -->|inherits| RM
    AR -->|inherits| RM

    %% Styling
    classDef core fill:#f9f,stroke:#333,stroke-width:2px;
    classDef token fill:#bbf,stroke:#333,stroke-width:2px;
    classDef module fill:#bfb,stroke:#333,stroke-width:2px;
    classDef interface fill:#fbb,stroke:#333,stroke-width:2px;

    class EBP,BPM,MSM,MSR,AR,BP core;
    class MB,WMB,MBC token;
    class RM,TH,FM module;
    class IBP,IBPM,ITH,IMSR,IMSM,IAR interface;
```

## Component Descriptions

### Core Contracts
- **EnhancedBitcoinPod**: Main contract for Bitcoin custody and token management
- **BitcoinPodManager**: Manages multiple Bitcoin pods
- **MotifServiceManager**: Handles service management and registration
- **MotifStakeRegistry**: Manages staking functionality
- **AppRegistry**: Handles application registration and management
- **BitcoinPod**: Base contract for Bitcoin pod functionality

### Token Contracts
- **MotifBitcoin**: Main token contract
- **WMotifBTC**: Wrapped version of MotifBitcoin
- **MotifBTC**: Base token implementation

### Module Contracts
- **RoleManager**: Handles role-based access control
- **TokenHub**: Manages token minting and burning
- **FeeManager**: Handles fee calculations and distribution

### Interface Contracts
- Define the contract interfaces for all major components
- Ensure consistent interaction patterns

## Key Relationships

1. **EnhancedBitcoinPod**
   - Implements IBitcoinPod interface
   - Uses FeeManager for fee handling
   - Uses RoleManager for access control
   - Interacts with TokenHub for token operations

2. **BitcoinPodManager**
   - Manages multiple EnhancedBitcoinPod instances
   - Uses MotifStakeRegistry for staking functionality
   - Uses AppRegistry for application management

3. **TokenHub**
   - Handles token minting and burning operations
   - Uses both RoleManager and FeeManager
   - Interacts with the MotifBitcoin token contract

4. **Token System**
   - MotifBitcoin is the main token
   - WMotifBTC provides wrapped functionality
   - Both are managed through the TokenHub

## System Features

The architecture provides a robust system for:
- Bitcoin custody and management
- Token minting and burning
- Role-based access control
- Fee management
- Service and application management
- Staking functionality

The system is designed to be modular, with clear separation of concerns and well-defined interfaces between components. 