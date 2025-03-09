# EVM Core Contracts

A collection of libraries for building blockchain transactions in various formats, including EVM transactions and Bitcoin transactions.

## Overview

The project provides libraries for building and working with different types of blockchain transactions:

- **EVMTxBuilder**: A Solidity library for building Ethereum transactions, providing:

  - Construction of EIP-1559 (type 2) transactions
  - RLP encoding for transaction data
  - Parsing of addresses and numeric values
  - Support for access lists

- **BTCTxBuilder**: A Solidity library for building Bitcoin transactions, providing:
  - Construction of legacy and SegWit transactions
  - Bitcoin-specific transaction serialization
  - Support for P2PKH, P2SH, and P2WPKH output types

## Project Structure

This project follows standard Hardhat practices for Solidity library development:

```
/
├── contracts/               # Smart contracts
│   ├── EVMTxBuilder/        # EVM transaction builder library
│   │   └── EVMTxBuilder.sol # Main library file
│   ├── BTCTxBuilder/        # Bitcoin transaction builder library
│   │   └── BTCTxBuilder.sol # Main library file
│   └── test/                # Test contracts
│       ├── TestEVMTxBuilder.sol # Helper contract for testing the EVM library
│       └── TestBTCTxBuilder.sol # Helper contract for testing the BTC library
│
├── test/                    # Test files
│   ├── EVMTxBuilder.test.ts        # Unit tests for the EVM library
│   └── BTCTxBuilder.integration.test.ts # Integration tests for the BTC library
│
├── scripts/                 # Utility scripts
│   ├── start-btc-testnet.sh # Script to start Bitcoin testnet container
│   ├── run-btc-tests.sh     # Script to run Bitcoin integration tests
│   └── stop-btc-testnet.sh  # Script to stop and clean up Bitcoin testnet container
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

The project includes comprehensive tests that verify the functionality of our libraries:

```bash
# Run all tests
npx hardhat test

# Run specific test files
npx hardhat test test/EVMTxBuilder.test.ts
npx hardhat test test/BTCTxBuilder.integration.test.ts
```

Our tests follow best practices for Solidity library testing:

1. They use helper contracts to access library functions
2. They employ test fixtures for efficient setup and teardown
3. They provide complete coverage for all key functionality

### Bitcoin Integration Testing

The BTCTxBuilder library includes integration tests that verify its functionality against a real Bitcoin testnet node. These tests require Docker to run a local Bitcoin testnet container.

#### Automated Setup and Testing

We provide scripts to automate the setup, testing, and cleanup:

```bash
# Start the Bitcoin testnet container and initialize it
./scripts/start-btc-testnet.sh

# Run the Bitcoin integration tests (this will start the testnet if not already running)
./scripts/run-btc-tests.sh

# Stop and clean up the Bitcoin testnet container
./scripts/stop-btc-testnet.sh
```

#### Manual Setup

If you prefer to manage the Bitcoin testnet container manually:

1. Start the container:

   ```bash
   docker run -d --name bitcoin-testnet-box -p 19001:19001 -p 19011:19011 freewil/bitcoin-testnet-box
   ```

2. Configure RPC access:

   ```bash
   docker exec bitcoin-testnet-box sh -c "echo 'rpcallowip=0.0.0.0/0' >> /bitcoin-testnet-box/1/bitcoin.conf"
   docker exec bitcoin-testnet-box sh -c "echo 'rpcbind=0.0.0.0' >> /bitcoin-testnet-box/1/bitcoin.conf"
   docker exec bitcoin-testnet-box sh -c "bitcoin-cli -regtest -datadir=/bitcoin-testnet-box/1 stop"
   docker exec bitcoin-testnet-box sh -c "bitcoind -regtest -datadir=/bitcoin-testnet-box/1 -daemon"
   ```

3. Create a wallet and generate initial blocks:
   ```bash
   docker exec bitcoin-testnet-box sh -c "bitcoin-cli -regtest -datadir=/bitcoin-testnet-box/1 -rpcuser=admin1 -rpcpassword=123 createwallet default"
   docker exec bitcoin-testnet-box sh -c "bitcoin-cli -regtest -datadir=/bitcoin-testnet-box/1 -rpcuser=admin1 -rpcpassword=123 loadwallet default"
   ADDRESS=$(docker exec bitcoin-testnet-box sh -c "bitcoin-cli -regtest -datadir=/bitcoin-testnet-box/1 -rpcuser=admin1 -rpcpassword=123 getnewaddress")
   docker exec bitcoin-testnet-box sh -c "bitcoin-cli -regtest -datadir=/bitcoin-testnet-box/1 -rpcuser=admin1 -rpcpassword=123 generatetoaddress 101 \"$ADDRESS\""
   ```

#### Bitcoin Testnet RPC Configuration

The integration tests connect to the Bitcoin testnet node with these default settings:

- RPC Endpoint: http://localhost:19001
- Username: admin1
- Password: 123

If you need to modify these settings, update the constants at the top of `test/BTCTxBuilder.integration.test.ts`.

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
