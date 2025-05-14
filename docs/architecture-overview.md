# Motif Core Contracts - High Level Overview

This document provides a simplified high-level overview of the Motif Core Contracts architecture.

## System Overview Diagram

```mermaid
graph TB
    subgraph Core["Core System"]
        direction TB
        EBP[EnhancedBitcoinPod]
        BPM[BitcoinPodManager]
        TH[TokenHub]
    end

    subgraph Token["Token System"]
        direction TB
        MB[MotifBitcoin]
        WMB[WMotifBTC]
    end

    subgraph Management["Management System"]
        direction TB
        MSM[MotifServiceManager]
        MSR[MotifStakeRegistry]
        AR[AppRegistry]
    end

    %% Main Relationships
    BPM -->|manages| EBP
    EBP -->|delegates to| TH
    TH -->|mints/burns| MB
    WMB -->|wraps| MB
    
    %% Management Relationships
    BPM -->|uses| MSR
    BPM -->|uses| AR
    MSM -->|manages| AR

    %% Styling
    classDef core fill:#f9f,stroke:#333,stroke-width:2px;
    classDef token fill:#bbf,stroke:#333,stroke-width:2px;
    classDef management fill:#bfb,stroke:#333,stroke-width:2px;

    class EBP,BPM,TH core;
    class MB,WMB token;
    class MSM,MSR,AR management;
```

## System Components

### Core System
- **EnhancedBitcoinPod**: Main contract for Bitcoin custody
- **BitcoinPodManager**: Manages multiple Bitcoin pods
- **TokenHub**: Handles token operations

### Token System
- **MotifBitcoin**: Main token contract
- **WMotifBTC**: Wrapped version for DeFi compatibility

### Management System
- **MotifServiceManager**: Service management
- **MotifStakeRegistry**: Staking functionality
- **AppRegistry**: Application management

## Key Interactions
1. Bitcoin Pods are managed by the Pod Manager
2. Pods delegate token operations to the Token Hub
3. Token Hub handles minting and burning of MotifBitcoin
4. Management system handles services, staking, and applications 