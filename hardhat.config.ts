import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.28",
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 1, // Use a low value for more aggressive optimization
        details: {
          yul: true,
          yulDetails: {
            stackAllocation: true // Enables stack allocation optimization
          }
        }
      }
    }
  },
  // Networks configuration (placeholder for project expansion)
  networks: {
    hardhat: {
      // Default network
    },
    // Add additional networks as needed
  },
  
  // Path configurations
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  }
};

export default config;
