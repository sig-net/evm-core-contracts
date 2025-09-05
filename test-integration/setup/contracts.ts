import { network } from "hardhat";
import "@nomicfoundation/hardhat-toolbox-viem";
import type { Address } from "viem";
import type { ContractReturnType } from "@nomicfoundation/hardhat-viem/types";

type TestEVMTxBuilderContract =
  ContractReturnType<"contracts/utils/TestEVMTxBuilder.sol:TestEVMTxBuilder">;

export interface IntegrationContracts {
  signerAddress: Address;
  tokenAddress: Address;
}

export const SEPOLIA_CONTRACTS: IntegrationContracts = {
  signerAddress: "0x83458E8Bf8206131Fe5c05127007FA164c0948A2",
  tokenAddress: "0xbe72E441BF55620febc26715db68d3494213D8Cb",
};

export async function getContracts() {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const chainId = await publicClient.getChainId();

  if (chainId !== 11155111) {
    throw new Error("Integration tests must run on Sepolia network");
  }

  return SEPOLIA_CONTRACTS;
}

export async function deployOrGetTestContract(
  signerAddress: Address,
): Promise<TestEVMTxBuilderContract> {
  const { viem } = await network.connect();

  const testContractAddress = process.env.TEST_CONTRACT_ADDRESS as Address | undefined;

  if (testContractAddress) {
    return await viem.getContractAt(
      "contracts/utils/TestEVMTxBuilder.sol:TestEVMTxBuilder",
      testContractAddress,
    );
  }

  const testContract = await viem.deployContract(
    "contracts/utils/TestEVMTxBuilder.sol:TestEVMTxBuilder",
    [signerAddress],
  );

  console.log("✅ TestEVMTxBuilder deployed to:", testContract.address);

  return testContract;
}
