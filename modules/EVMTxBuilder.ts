import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * EVMTxBuilderModule - Ignition module for deploying the EVMTxBuilder library
 *
 * This module deploys:
 * 1. The EVMTxBuilder library for generating EVM transactions
 */
const EVMTxBuilderModule = buildModule("EVMTxBuilderModule", (m) => {
  // Deploy the EVMTxBuilder library
  const evmTxBuilder = m.contract(
    "contracts/EVMTxBuilder/EVMTxBuilder.sol:EVMTxBuilder"
  );

  // Return all deployed contract instances
  return { evmTxBuilder };
});

export default EVMTxBuilderModule;
