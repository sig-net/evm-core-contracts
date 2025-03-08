import { expect } from "chai";
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import {
  createPublicClient,
  http,
  hexToBytes,
  keccak256,
  serializeTransaction,
  TransactionSerializable,
  Hex,
} from "viem";
import { hardhat } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import { secp256k1 } from "@noble/curves/secp256k1";

describe("EVMTxBuilder Comparison with Viem", function () {
  const TEST_PRIVATE_KEY =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
  const testAccount = privateKeyToAccount(TEST_PRIVATE_KEY as `0x${string}`);

  const publicClient = createPublicClient({
    chain: hardhat,
    transport: http(),
  });

  async function deployLibraryFixture() {
    const evmTxBuilder = await hre.viem.deployContract(
      "contracts/EVMTxBuilder/EVMTxBuilder.sol:EVMTxBuilder"
    );

    const helperContract = await hre.viem.deployContract(
      "./contracts/test/TestEVMTxBuilder.sol:TestEVMTxBuilder",
      [],
      {
        libraries: {
          "contracts/EVMTxBuilder/EVMTxBuilder.sol:EVMTxBuilder":
            evmTxBuilder.address,
        },
      }
    );

    return { evmTxBuilder, helperContract };
  }

  describe("Direct Library Usage", function () {
    it("Should compare transaction building between EVMTxBuilder and viem", async function () {
      const { helperContract } = await loadFixture(deployLibraryFixture);

      const chainId = 31337n;
      const nonce = await publicClient.getTransactionCount({
        address: testAccount.address,
      });

      const recipient = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
      const value = 1000000000000000n;
      const input = "0x" as Hex;
      const gasLimit = 21000n;
      const maxFeePerGas = 20000000000n;
      const maxPriorityFeePerGas = 1000000000n;

      const viemTx: TransactionSerializable = {
        chainId: Number(chainId),
        to: recipient,
        value: value,
        nonce,
        gas: gasLimit,
        maxFeePerGas: maxFeePerGas,
        maxPriorityFeePerGas: maxPriorityFeePerGas,
        data: input,
        type: "eip1559",
      };

      const txParams = {
        chainId: Number(chainId),
        nonce: Number(nonce),
        to: recipient as `0x${string}`,
        hasTo: true,
        value: value,
        input: input,
        gasLimit: gasLimit,
        maxFeePerGas: maxFeePerGas,
        maxPriorityFeePerGas: maxPriorityFeePerGas,
      };

      const serializedViemTx = serializeTransaction(viemTx);
      const serializedEVMTx =
        await helperContract.read.createUnsignedTransaction([txParams]);

      expect(serializedEVMTx).to.equal(serializedViemTx);

      const viemTxHash = keccak256(serializedViemTx);
      const evmTxHash = (await helperContract.read.getHashToSign([
        serializedEVMTx,
      ])) as `0x${string}`;

      expect(evmTxHash).to.equal(viemTxHash);

      const privateKeyBytes = hexToBytes(TEST_PRIVATE_KEY as `0x${string}`);
      const messageHashBytes = hexToBytes(evmTxHash);

      const signature = secp256k1.sign(messageHashBytes, privateKeyBytes);

      const r = `0x${signature.r.toString(16).padStart(64, "0")}` as Hex;
      const s = `0x${signature.s.toString(16).padStart(64, "0")}` as Hex;
      const v = signature.recovery;

      const evmSignature = {
        v,
        r,
        s,
      };

      const signedEVMTx = (await helperContract.read.createSignedTransaction([
        txParams,
        evmSignature,
      ])) as Hex;

      const txHash = await publicClient.sendRawTransaction({
        serializedTransaction: signedEVMTx,
      });

      const receipt = await publicClient.waitForTransactionReceipt({
        hash: txHash,
        timeout: 5000,
      });

      expect(receipt.status).to.equal("success");
    });
  });
});
