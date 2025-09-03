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

  interface AccessListEntry {
    addr: Address;
    storageKeys: `0x${string}`[];
  }

  interface EvmTx {
    chainId: bigint;
    nonce: bigint;
    to: Address;
    hasTo: boolean;
    value: bigint;
    input: Hex;
    gasLimit: bigint;
    maxFeePerGas: bigint;
    maxPriorityFeePerGas: bigint;
    accessList: AccessListEntry[];
  }

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

  interface Signature {
    v: number;
    r: `0x${string}`;
    s: `0x${string}`;
  }

  type EVMTxBuilderLibraryContract =
    ContractReturnType<"contracts/libraries/EVMTxBuilder.sol:EVMTxBuilder">;
  type TestEVMTxBuilderContract =
    ContractReturnType<"contracts/utils/TestEVMTxBuilder.sol:TestEVMTxBuilder">;

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

  function toEvmTx(input: SharedTxInput): EvmTx {
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

  async function processContractTx(
    input: SharedTxInput,
    libraryContract: EVMTxBuilderLibraryContract,
    helperContract: TestEVMTxBuilderContract,
  ) {
    const evmTx = toEvmTx(input);
    const serializedContract = await helperContract.read.createUnsignedTransaction([evmTx]);
    const hashContract = await libraryContract.read.getHashToSign([serializedContract]);
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
    const signedContract = await helperContract.read.createSignedTransaction([evmTx, signature]);
    return { serializedContract, hashContract, signedContract, params: evmTx };
  }

  async function deployContracts() {
    const evmTxBuilder = await viem.deployContract(
      "contracts/libraries/EVMTxBuilder.sol:EVMTxBuilder",
    );

    const helperContract = await viem.deployContract(
      "contracts/utils/TestEVMTxBuilder.sol:TestEVMTxBuilder",
      [],
      {
        libraries: {
          "project/contracts/libraries/EVMTxBuilder.sol:EVMTxBuilder": evmTxBuilder.address,
        },
      },
    );

    const erc20 = await viem.deployContract("contracts/mocks/TestERC20.sol:TestERC20");

    const nft = await viem.deployContract("contracts/mocks/TestERC721.sol:TestERC721", [
      "TestNFT",
      "TNFT",
    ]);

    return {
      evmTxBuilder,
      helperContract,
      erc20Address: erc20.address,
      nftAddress: nft.address,
    };
  }

  async function buildAndSignTransaction(
    evmTxBuilder: EVMTxBuilderLibraryContract,
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
      evmTxBuilder,
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
      const { helperContract, evmTxBuilder } = await deployContracts();

      const recipient = RECIPIENT;
      const value = 12382091830192n;
      const input = "0x" as Hex;

      const recipientBalanceBefore = await publicClient.getBalance({
        address: recipient,
      });

      const signedEVMTx = await buildAndSignTransaction(
        evmTxBuilder,
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

    void it("Should build and execute ERC20 transfer transaction", async function () {
      const { helperContract, erc20Address, evmTxBuilder } = await deployContracts();

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

      const signedEVMTx = await buildAndSignTransaction(
        evmTxBuilder,
        helperContract,
        erc20Address,
        transferData,
      );

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

    void it("Should build and execute NFT transfer transaction", async function () {
      const { helperContract, nftAddress, evmTxBuilder } = await deployContracts();

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

      const signedEVMTx = await buildAndSignTransaction(
        evmTxBuilder,
        helperContract,
        nftAddress,
        transferData,
      );

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
