import assert from "node:assert/strict";
import { describe, it, before } from "node:test";
import { network } from "hardhat";
import "@nomicfoundation/hardhat-toolbox-viem";
import { parseUnits, type Address } from "viem";
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

void describe("ERC20 Transfer Signature Request - Sepolia Integration", async function () {
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

      console.log("⏳ Transaction hash:", txHash);

      const receipt = await publicClient.waitForTransactionReceipt({ hash: txHash });

      assert.equal(receipt.status, "success", "Transaction should succeed");
    });
  });
});
