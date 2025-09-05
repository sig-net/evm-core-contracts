import assert from "node:assert/strict";
import { chainAdapters, contracts as chainSigContracts } from "signet.js";
import { describe, it, before } from "node:test";
import { network } from "hardhat";
import "@nomicfoundation/hardhat-toolbox-viem";
import { encodeFunctionData, Hex, parseUnits, type Address } from "viem";
import type { ContractReturnType } from "@nomicfoundation/hardhat-viem/types";
import { getContracts, deployOrGetTestContract } from "./setup/contracts.js";

type TestEVMTxBuilderContract =
  ContractReturnType<"contracts/utils/TestEVMTxBuilder.sol:TestEVMTxBuilder">;

const SEPOLIA_CHAIN_ID = 11155111n;
const DEFAULT_GAS_LIMIT = 100000n;
const SIGNATURE_DEPOSIT = parseUnits("0.001", 18); // 0.001 ETH for signature request

const KEY_VERSION = 0;
const DERIVATION_PATH = "ethereum,1";
const SIGNING_ALGORITHM = "ecdsa";
const RESPONSE_DESTINATION = "";
const ADDITIONAL_PARAMS = "";

// TODO: Work in progress
void describe.skip("ERC20 Transfer Signature Request - Sepolia Integration", async function () {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const [walletClient] = await viem.getWalletClients();

  let testContract: TestEVMTxBuilderContract;
  let contracts: Awaited<ReturnType<typeof getContracts>>;

  before(async () => {
    contracts = await getContracts();

    testContract = await deployOrGetTestContract(contracts.signerAddress);
  });

  void describe("requestSignatureForErc20Transfer", () => {
    void it("should successfully request signature for ERC20 transfer", async () => {
      const recipient: Address = "0x4174678c78fEaFd778c1ff319D5D326701449b25";
      const amount = parseUnits("1", 18);

      const contract = new chainSigContracts.evm.ChainSignatureContract({
        publicClient: publicClient,
        walletClient: walletClient,
        contractAddress: contracts.signerAddress,
      });

      const evmChain = new chainAdapters.evm.EVM({
        publicClient,
        contract,
      });

      const { address } = await evmChain.deriveAddressAndPublicKey(
        contracts.signerAddress,
        DERIVATION_PATH,
      );

      const [nonce, feeData] = await Promise.all([
        publicClient.getTransactionCount({
          address: walletClient.account.address,
        }),
        publicClient.estimateFeesPerGas(),
      ]);

      const txHash = await testContract.write.requestSignatureForErc20Transfer(
        [
          contracts.tokenAddress,
          recipient,
          amount,
          SEPOLIA_CHAIN_ID,
          BigInt(nonce),
          DEFAULT_GAS_LIMIT,
          feeData.maxFeePerGas ?? 20000000000n, // fallback to 20 gwei
          feeData.maxPriorityFeePerGas ?? 1000000000n, // fallback to 1 gwei
          KEY_VERSION,
          DERIVATION_PATH,
          SIGNING_ALGORITHM,
          RESPONSE_DESTINATION,
          ADDITIONAL_PARAMS,
        ] as const,
        {
          value: SIGNATURE_DEPOSIT, // Send ETH for signature payment
        },
      );

      // Define ERC20 transfer function ABI
      const erc20TransferAbi = [
        {
          inputs: [
            { name: "recipient", type: "address" },
            { name: "amount", type: "uint256" },
          ],
          name: "transfer",
          outputs: [{ name: "", type: "bool" }],
          stateMutability: "nonpayable",
          type: "function",
        },
      ] as const;

      const data = encodeFunctionData({
        abi: erc20TransferAbi,
        functionName: "transfer",
        args: [recipient, amount],
      });

      const { hashesToSign } = await evmChain.prepareTransactionForSigning({
        from: address as Hex,
        to: contracts.tokenAddress,
        nonce,
        value: 0n,
        data: data,
        gas: DEFAULT_GAS_LIMIT,
        maxFeePerGas: feeData.maxFeePerGas ?? 20000000000n, // fallback to 20 gwei
        maxPriorityFeePerGas: feeData.maxPriorityFeePerGas ?? 1000000000n, // fallback to 1 gwei
      });

      const requestId = contract.getRequestId(
        {
          payload: hashesToSign[0],
          path: DERIVATION_PATH,
          key_version: KEY_VERSION,
        },
        {
          algo: SIGNING_ALGORITHM,
          dest: RESPONSE_DESTINATION,
          params: ADDITIONAL_PARAMS,
        },
      );

      console.log("⏳ Request ID:", requestId);

      console.log("⏳ Transaction hash:", txHash);

      const receipt = await publicClient.waitForTransactionReceipt({ hash: txHash });

      assert.equal(receipt.status, "success", "Transaction should succeed");
    });
  });
});
