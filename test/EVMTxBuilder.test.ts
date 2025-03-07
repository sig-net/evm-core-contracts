import { expect } from "chai";
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import {
  createPublicClient,
  http,
  keccak256,
  serializeTransaction,
  TransactionSerializable,
  Hex,
  recoverAddress,
} from "viem";
import { hardhat } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import { secp256k1 } from "@noble/curves/secp256k1";
import { hexToBytes } from "viem";

describe("EVMTxBuilder Comparison with Viem", function () {
  const TEST_PRIVATE_KEY =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
  const testAccount = privateKeyToAccount(TEST_PRIVATE_KEY);

  const publicClient = createPublicClient({
    chain: hardhat,
    transport: http(),
  });

  beforeEach(async () => {
    await publicClient.request({
      method: "hardhat_setBalance" as any,
      params: [testAccount.address, "0x56BC75E2D63100000"],
    });
  });

  async function deployLibraryFixture() {
    const evmTxBuilder = await hre.viem.deployContract(
      "contracts/EVMTxBuilder/EVMTxBuilder.sol:EVMTxBuilder"
    );
    return { evmTxBuilder };
  }

  describe("Direct Library Usage", function () {
    it("Should compare transaction building between EVMTxBuilder and viem", async function () {
      const { evmTxBuilder } = await loadFixture(deployLibraryFixture);

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

      const nonce = await publicClient.getTransactionCount({
        address: testAccount.address,
      });

      const baseTx = {
        chainId: 31337,
        to: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
        value: BigInt("1000000000000000"),
        nonce,
        gas: BigInt("21000"),
        maxFeePerGas: BigInt("20000000000"),
        maxPriorityFeePerGas: BigInt("1000000000"),
        data: "0x",
        type: "eip1559",
      };

      const serializedEVMTx = await helperContract.read.createTransaction([
        baseTx.chainId.toString(),
        baseTx.nonce.toString(),
        baseTx.to,
        true,
        baseTx.value.toString(),
        baseTx.data,
        baseTx.gas.toString(),
        baseTx.maxFeePerGas.toString(),
        baseTx.maxPriorityFeePerGas.toString(),
      ]);

      const serializedViemTx = serializeTransaction(
        baseTx as TransactionSerializable
      );

      expect(serializedEVMTx).to.equal(serializedViemTx);

      const evmTxHash = (await helperContract.read.getHashToSign([
        serializedEVMTx,
      ])) as Hex;

      const viemTxHash = keccak256(serializedViemTx);

      expect(evmTxHash).to.equal(viemTxHash);

      const privateKeyBytes = hexToBytes(TEST_PRIVATE_KEY);
      const messageHashBytes = hexToBytes(evmTxHash);

      const signature = secp256k1.sign(messageHashBytes, privateKeyBytes);

      const r = `0x${signature.r.toString(16).padStart(64, "0")}` as Hex;
      const s = `0x${signature.s.toString(16).padStart(64, "0")}` as Hex;
      const v = signature.recovery;
      const yParity = v === 0 ? "0" : "1";

      const recoveredAddress = await recoverAddress({
        hash: evmTxHash,
        signature: {
          r,
          s,
          v: BigInt(v),
        },
      });

      expect(recoveredAddress.toLowerCase()).to.equal(
        testAccount.address.toLowerCase()
      );

      const signedEVMTx = (await helperContract.read.createSignedTransaction([
        baseTx.chainId.toString(),
        baseTx.nonce.toString(),
        baseTx.to,
        true,
        baseTx.value.toString(),
        baseTx.data,
        baseTx.gas.toString(),
        baseTx.maxFeePerGas.toString(),
        baseTx.maxPriorityFeePerGas.toString(),
        yParity,
        r,
        s,
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
