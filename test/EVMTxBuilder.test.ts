import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { network } from "hardhat";
import "@nomicfoundation/hardhat-toolbox-viem";
import {
  hexToBytes,
  keccak256,
  serializeTransaction,
  TransactionSerializable,
  Hex,
  parseEther,
  encodeFunctionData,
  parseAbi,
} from "viem";
import type { Address } from "viem";
import { secp256k1 } from "@noble/curves/secp256k1.js";
import { privateKeyToAccount } from "viem/accounts";
import { ContractReturnType } from "@nomicfoundation/hardhat-viem/types";

void describe("EVMTxBuilder Comparison with Viem", async function () {
  const TEST_PRIVATE_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
  const RECIPIENT: Address = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";

  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const [walletClient] = await viem.getWalletClients();

  const DEFAULT_GAS_LIMIT = 100000n;
  const DEFAULT_MAX_FEE_PER_GAS = 20_000_000_000n;
  const DEFAULT_MAX_PRIORITY_FEE_PER_GAS = 1_000_000_000n;

  const ERC20_ABI = parseAbi([
    "function mint(address to, uint256 amount) returns (bool)",
    "function balanceOf(address owner) view returns (uint256)",
    "function transfer(address to, uint256 amount) returns (bool)",
  ]);

  const NFT_ABI = parseAbi([
    "function mint(address to, uint256 tokenId)",
    "function ownerOf(uint256 tokenId) view returns (address)",
    "function transferFrom(address from, address to, uint256 tokenId)",
  ]);

  interface SharedTxInput {
    chainId: number;
    to: Address;
    value: bigint;
    nonce: number;
    gasLimit: bigint;
    maxFeePerGas: bigint;
    maxPriorityFeePerGas: bigint;
    data: Hex;
  }

  type TestEVMTxBuilderContract =
    ContractReturnType<"contracts/utils/TestEVMTxBuilder.sol:TestEVMTxBuilder">;

  type EvmTx = Parameters<TestEVMTxBuilderContract["read"]["createUnsignedTransaction"]>[0][0];
  type Signature = Parameters<TestEVMTxBuilderContract["read"]["createSignedTransaction"]>[0][1];

  async function buildSharedTxInput(
    to: Address,
    data: Hex,
    value: bigint,
    gasLimit: bigint,
  ): Promise<SharedTxInput> {
    const chainId = await publicClient.getChainId();
    const nonce = await publicClient.getTransactionCount({ address: walletClient.account.address });
    return {
      chainId,
      to,
      value,
      nonce: Number(nonce),
      gasLimit,
      maxFeePerGas: DEFAULT_MAX_FEE_PER_GAS,
      maxPriorityFeePerGas: DEFAULT_MAX_PRIORITY_FEE_PER_GAS,
      data,
    };
  }

  function toViemTransaction(input: SharedTxInput): TransactionSerializable {
    return {
      chainId: input.chainId,
      to: input.to,
      value: input.value,
      nonce: input.nonce,
      gas: input.gasLimit,
      maxFeePerGas: input.maxFeePerGas,
      maxPriorityFeePerGas: input.maxPriorityFeePerGas,
      data: input.data,
      type: "eip1559",
    };
  }

  function toContractEvmTx(input: SharedTxInput): EvmTx {
    return {
      chainId: BigInt(input.chainId),
      nonce: BigInt(input.nonce),
      to: input.to,
      hasTo: true,
      value: input.value,
      input: input.data,
      gasLimit: input.gasLimit,
      maxFeePerGas: input.maxFeePerGas,
      maxPriorityFeePerGas: input.maxPriorityFeePerGas,
      accessList: [],
    };
  }

  async function processViemTx(input: SharedTxInput) {
    const viemTx = toViemTransaction(input);
    const serializedViem = serializeTransaction(viemTx);
    const hashViem = keccak256(serializedViem);
    const signedViem = await privateKeyToAccount(TEST_PRIVATE_KEY as Hex).signTransaction(viemTx);
    return { serializedViem, hashViem, signedViem };
  }

  async function processContractTx(input: SharedTxInput, helperContract: TestEVMTxBuilderContract) {
    const contractEvmTx = toContractEvmTx(input);

    const hashContract: Hex = await helperContract.read.serializeAndHashEvmTx([contractEvmTx]);
    const serializedContract: Hex = await helperContract.read.createUnsignedTransaction([
      contractEvmTx,
    ]);
    const signature: Signature = (function () {
      const pk = hexToBytes(TEST_PRIVATE_KEY as Hex);
      const msg = hexToBytes(hashContract);
      const bytes = secp256k1.sign(msg, pk, { prehash: false, format: "recovered" });
      const sig = secp256k1.Signature.fromBytes(bytes, "recovered");
      const r: `0x${string}` = `0x${sig.r.toString(16).padStart(64, "0")}`;
      const s: `0x${string}` = `0x${sig.s.toString(16).padStart(64, "0")}`;
      return {
        v: Number(sig.recovery ?? 0),
        r,
        s,
      };
    })();
    const signedContract: Hex = await helperContract.read.createSignedTransaction([
      contractEvmTx,
      signature,
    ]);
    return { serializedContract, hashContract, signedContract };
  }

  async function deployContracts() {
    const helperContract = await viem.deployContract(
      "contracts/utils/TestEVMTxBuilder.sol:TestEVMTxBuilder",
      [],
    );

    const erc20 = await viem.deployContract("contracts/mocks/TestERC20.sol:TestERC20");

    const nft = await viem.deployContract("contracts/mocks/TestERC721.sol:TestERC721", [
      "TestNFT",
      "TNFT",
    ]);

    return {
      helperContract,
      erc20Address: erc20.address,
      nftAddress: nft.address,
    };
  }

  async function buildAndSignTransaction(
    helperContract: TestEVMTxBuilderContract,
    toAddress: Address,
    inputData: Hex,
    value = 0n,
    gasLimit = DEFAULT_GAS_LIMIT,
  ) {
    const shared = await buildSharedTxInput(toAddress, inputData, value, gasLimit);
    const { serializedViem, hashViem, signedViem } = await processViemTx(shared);
    const { serializedContract, hashContract, signedContract } = await processContractTx(
      shared,
      helperContract,
    );

    assert.equal(serializedContract, serializedViem, "Serialized transactions should match");
    assert.equal(hashContract, hashViem, "Transaction hashes should match");
    assert.equal(signedContract, signedViem, "Signed transactions should match");

    return signedContract;
  }

  async function executeAndVerifyTransaction(signedEVMTx: Hex, description: string) {
    const txHash = await publicClient.sendRawTransaction({
      serializedTransaction: signedEVMTx,
    });

    const receipt = await publicClient.waitForTransactionReceipt({
      hash: txHash,
    });

    assert.equal(receipt.status, "success", `${description} should be successful`);

    return receipt;
  }

  void describe("Direct Library Usage", function () {
    void it("Should compare transaction building between EVMTxBuilder and viem", async function () {
      const { helperContract } = await deployContracts();

      const recipient = RECIPIENT;
      const value = 12382091830192n;
      const input = "0x" as Hex;

      const recipientBalanceBefore = await publicClient.getBalance({
        address: recipient,
      });

      const signedEVMTx = await buildAndSignTransaction(
        helperContract,
        recipient,
        input,
        value,
        21000n,
      );

      await executeAndVerifyTransaction(signedEVMTx, "ETH transfer");

      const recipientBalanceAfter = await publicClient.getBalance({
        address: recipient,
      });

      assert.equal(
        recipientBalanceAfter - recipientBalanceBefore,
        value,
        "Recipient should have received the ETH",
      );
    });

    void it("Should build and execute ERC20 transfer transaction, abi encode on contract", async function () {
      const { helperContract, erc20Address } = await deployContracts();

      await walletClient.writeContract({
        address: erc20Address,
        abi: ERC20_ABI,
        functionName: "mint",
        args: [walletClient.account.address, parseEther("100")],
      });

      const transferAmount = parseEther("10");

      // Encode the input data using contract
      // const transferData = encodeFunctionData({
      //   abi: ERC20_ABI,
      //   functionName: "transfer",
      //   args: [RECIPIENT, transferAmount],
      // });
      const transferData = await helperContract.read.encodeErc20TransferInput([
        RECIPIENT,
        transferAmount,
      ]);

      const signedEVMTx = await buildAndSignTransaction(helperContract, erc20Address, transferData);

      const receipt = await executeAndVerifyTransaction(signedEVMTx, "ERC20 transfer");

      assert.ok(receipt.blockNumber !== undefined);

      const balance = await publicClient.readContract({
        address: erc20Address,
        abi: ERC20_ABI,
        functionName: "balanceOf",
        args: [walletClient.account.address],
      });

      assert.equal(balance, parseEther("90"), "ERC20 balance should be 90");

      const recipientBalance = await publicClient.readContract({
        address: erc20Address,
        abi: ERC20_ABI,
        functionName: "balanceOf",
        args: [RECIPIENT],
      });

      assert.equal(recipientBalance, parseEther("10"), "ERC20 balance should be 10");
    });

    void it("Should build and execute NFT transfer transaction, abi encode with viem", async function () {
      const { helperContract, nftAddress } = await deployContracts();

      const mintTxHash = await walletClient.writeContract({
        address: nftAddress,
        abi: NFT_ABI,
        functionName: "mint",
        args: [walletClient.account.address, 2n],
      });

      await publicClient.waitForTransactionReceipt({
        hash: mintTxHash,
      });

      const transferData = encodeFunctionData({
        abi: NFT_ABI,
        functionName: "transferFrom",
        args: [walletClient.account.address, RECIPIENT, 2n],
      });

      const signedEVMTx = await buildAndSignTransaction(helperContract, nftAddress, transferData);

      await executeAndVerifyTransaction(signedEVMTx, "NFT transfer");

      const ownerAfter = await publicClient.readContract({
        address: nftAddress,
        abi: NFT_ABI,
        functionName: "ownerOf",
        args: [2n],
      });

      assert.equal(ownerAfter, RECIPIENT, "NFT should be owned by the recipient after transfer");
    });
  });
});
