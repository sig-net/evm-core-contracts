# EVM Core Contracts

A collection of libraries for building blockchain transactions in various formats, starting with EVM transactions.

## Overview

The project provides libraries for building and working with different types of blockchain transactions:

- **EVMTxBuilder**: A Solidity library for building Ethereum transactions, providing:
  - Construction of EIP-1559 (type 2) transactions
  - RLP encoding for transaction data
  - Parsing of addresses and numeric values
  - Support for access lists

## Project Structure

This project follows standard Hardhat practices for Solidity library development:

```
/
├── contracts/               # Smart contracts
│   ├── EVMTxBuilder/        # EVM transaction builder library
│   │   └── EVMTxBuilder.sol # Main library file
│   └── test/                # Test contracts
│       └── TestEVMTxBuilder.sol # Helper contract for testing the library
│
├── test/                    # Test files
│   └── EVMTxBuilder.test.ts # Unit tests for the library
│
└── ignition/                # Hardhat Ignition deployment modules
    └── modules/
        └── EVMTxBuilder.ts  # Deployment configuration
```

## Getting Started

### Prerequisites

- Node.js (version 18 or later)
- pnpm (recommended) or npm

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd evm-core-contracts

# Install dependencies
pnpm install
```

### Compilation

```bash
npx hardhat compile
```

## Testing

The project includes comprehensive tests that verify the functionality of the EVMTxBuilder library:

```bash
npx hardhat test
```

Our tests follow best practices for Solidity library testing:

1. They use a helper contract (`TestEVMTxBuilder.sol`) to access library functions
2. They employ test fixtures for efficient setup and teardown
3. They provide complete coverage for all key functionality:
   - Transaction building (transfers and contract deployments)
   - Address parsing
   - Numeric value parsing

## Deployment

You can deploy the library using Hardhat Ignition:

```bash
npx hardhat ignition deploy ./ignition/modules/EVMTxBuilder.ts
```

For different networks, specify the network flag:

```bash
npx hardhat ignition deploy ./ignition/modules/EVMTxBuilder.ts --network <network-name>
```

## License

UNLICENSED # evm-core-contracts
