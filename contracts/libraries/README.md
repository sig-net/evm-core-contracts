# EVMTxBuilder (EIP-1559 transaction builder)

EVMTxBuilder is a lightweight Solidity library for building EIP-1559 (type-2) transaction payloads entirely on-chain using Optimism's RLP writer. It does not perform signing; you obtain the hash and sign off-chain.

## Features

- Build unsigned EIP-1559 transaction bytes (type-prefixed RLP)
- Build signed bytes from fields and compact signature
- Compute the hash to sign for an unsigned payload
- Access list support (EIP-2930/EIP-1559)

## Installation

- Added as part of this repository. It depends on `@eth-optimism/contracts` for `Lib_RLPWriter`.

```bash
pnpm add -D @eth-optimism/contracts
```

## Library

File: `contracts/libraries/EVMTxBuilder.sol`

Exports:

- `struct EVMTransaction` — full transaction fields (EIP-1559)
- `struct Signature { uint8 v; bytes32 r; bytes32 s; }` — compact y-parity signature
- `function serializeEvmTxUnsigned(EVMTransaction)` — unsigned bytes
- `function serializeEvmTxWithSignature(EVMTransaction, Signature)` — signed bytes
- `function hashEvmTx(bytes)` — digest for off-chain signing

## Usage example (via helper contract)

See `contracts/utils/TestEVMTxBuilder.sol` and `test/EVMTxBuilder.test.ts` for an end-to-end example that:

- Builds an unsigned payload from fields
- Computes the hash with `getHashToSign`
- Signs off-chain (Viem + Noble secp256k1)
- Creates the signed bytes on-chain, then broadcasts via Viem

### Minimal flow

1. Construct `EVMTransaction` fields (all numeric as `uint256`).
2. Call `buildForSigning(tx)` and then `getHashToSign(bytes)`.
3. Sign the digest off-chain. Derive compact signature `(v in {0,1}, r, s)`.
4. Call `buildWithSignature(tx, signature)` to produce final bytes.
5. Submit bytes with your client (e.g., `publicClient.sendRawTransaction`).

### Contract creation vs. calls

- Set `hasTo=false` for contract creation (encodes empty to field).
- Set `hasTo=true` and `to=<address>` for contract calls.

### Access list

Pass an array of `{ addr, storageKeys[] }`. If empty, it is encoded as an empty list.

## Notes & limitations

- Only EIP-1559 transactions are supported.
- Signing must be performed off-chain.
- This library encodes; it does not validate fields or simulate execution.

## Development

- Tests: `pnpm hardhat test`
- Lint: `pnpm lint`
- Typecheck: `pnpm typecheck`
