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
import { secp256k1 } from "@noble/curves/secp256k1.js";
import { privateKeyToAccount } from "viem/accounts";

describe("EVMTxBuilder Comparison with Viem", async function () {
  const TEST_PRIVATE_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
  const RECIPIENT = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";

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
      erc20Address: erc20.address as `0x${string}`,
      nftAddress: nft.address as `0x${string}`,
    };
  }

  async function buildAndSignTransaction(
    evmTxBuilder: any,
    helperContract: any,
    toAddress: `0x${string}`,
    inputData: Hex,
    value = 0n,
    gasLimit = DEFAULT_GAS_LIMIT,
  ) {
    const chainId = await publicClient.getChainId();
    const nonce = await publicClient.getTransactionCount({ address: walletClient.account.address });

    const viemTx: TransactionSerializable = {
      chainId,
      to: toAddress,
      value,
      nonce,
      gas: gasLimit,
      maxFeePerGas: DEFAULT_MAX_FEE_PER_GAS,
      maxPriorityFeePerGas: DEFAULT_MAX_PRIORITY_FEE_PER_GAS,
      data: inputData,
      type: "eip1559",
    };

    const txParams = {
      chainId,
      nonce: Number(nonce),
      to: toAddress,
      hasTo: true,
      value,
      input: inputData,
      gasLimit,
      maxFeePerGas: DEFAULT_MAX_FEE_PER_GAS,
      maxPriorityFeePerGas: DEFAULT_MAX_PRIORITY_FEE_PER_GAS,
    };

    const serializedViemTx = serializeTransaction(viemTx);
    const serializedEVMTx = await helperContract.read.createUnsignedTransaction([txParams]);

    assert.equal(serializedEVMTx, serializedViemTx, "Serialized transactions should match");

    const viemTxHash = keccak256(serializedViemTx);
    const evmTxHash = (await evmTxBuilder.read.getHashToSign([serializedEVMTx])) as `0x${string}`;

    assert.equal(evmTxHash, viemTxHash, "Transaction hashes should match");

    const privateKeyBytes = hexToBytes(TEST_PRIVATE_KEY as `0x${string}`);
    const messageHashBytes = hexToBytes(evmTxHash);

    const sigBytes = secp256k1.sign(messageHashBytes, privateKeyBytes, {
      prehash: false,
      format: "recovered",
    });
    const sig = secp256k1.Signature.fromBytes(sigBytes, "recovered");
    const r = `0x${sig.r.toString(16).padStart(64, "0")}` as Hex;
    const s = `0x${sig.s.toString(16).padStart(64, "0")}` as Hex;
    const v = sig.recovery as number;

    const evmSignature = { v, r, s };

    const signedEVMTx = (await helperContract.read.createSignedTransaction([
      txParams,
      evmSignature,
    ])) as Hex;

    const localAccount = privateKeyToAccount(TEST_PRIVATE_KEY as `0x${string}`);
    const signedViemTx = await localAccount.signTransaction(viemTx);
    assert.equal(signedEVMTx, signedViemTx, "Signed transactions should match");

    return { signedEVMTx, txParams, signedViemTx };
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

  describe("Direct Library Usage", function () {
    it("Should compare transaction building between EVMTxBuilder and viem", async function () {
      const { helperContract, evmTxBuilder } = await deployContracts();

      const recipient = RECIPIENT;
      const value = 12382091830192n;
      const input = "0x" as Hex;

      const recipientBalanceBefore = await publicClient.getBalance({
        address: recipient,
      });

      const { signedEVMTx } = await buildAndSignTransaction(
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

    it("Should build and execute ERC20 transfer transaction", async function () {
      const { helperContract, erc20Address, evmTxBuilder } = await deployContracts();

      await walletClient.writeContract({
        address: erc20Address,
        abi: ERC20_ABI,
        functionName: "mint",
        args: [walletClient.account.address, parseEther("100")],
      });

      const transferAmount = parseEther("10");
      const transferData = encodeFunctionData({
        abi: ERC20_ABI,
        functionName: "transfer",
        args: [RECIPIENT, transferAmount],
      });

      const { signedEVMTx } = await buildAndSignTransaction(
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

    it("Should build and execute NFT transfer transaction", async function () {
      const { helperContract, nftAddress, evmTxBuilder } = await deployContracts();

      const mintTxHash = await walletClient.writeContract({
        address: nftAddress as `0x${string}`,
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

      const { signedEVMTx } = await buildAndSignTransaction(
        evmTxBuilder,
        helperContract,
        nftAddress as `0x${string}`,
        transferData,
      );

      await executeAndVerifyTransaction(signedEVMTx, "NFT transfer");

      const ownerAfter = await publicClient.readContract({
        address: nftAddress as `0x${string}`,
        abi: NFT_ABI,
        functionName: "ownerOf",
        args: [2n],
      });

      assert.equal(ownerAfter, RECIPIENT, "NFT should be owned by the recipient after transfer");
    });
  });
});
