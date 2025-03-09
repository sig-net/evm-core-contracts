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
  parseEther,
  encodeFunctionData,
  parseAbi,
  createWalletClient,
} from "viem";
import { hardhat } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import { secp256k1 } from "@noble/curves/secp256k1";

describe("EVMTxBuilder Comparison with Viem", function () {
  const TEST_PRIVATE_KEY =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
  const testAccount = privateKeyToAccount(TEST_PRIVATE_KEY as `0x${string}`);
  const RECIPIENT = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";

  const publicClient = createPublicClient({
    chain: hardhat,
    transport: http(),
  });

  const walletClient = createWalletClient({
    account: testAccount,
    chain: hardhat,
    transport: http(),
  });

  const ERC20_ABI = [
    "function mint(address to, uint256 amount) returns (bool)",
    "function balanceOf(address owner) view returns (uint256)",
    "function transfer(address to, uint256 amount) returns (bool)",
  ];

  const NFT_ABI = [
    "function mint(address to, uint256 tokenId)",
    "function ownerOf(uint256 tokenId) view returns (address)",
    "function transferFrom(address from, address to, uint256 tokenId)",
  ];

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

  async function deployTokenFixture() {
    await hre.run("compile");

    const artifactPath = require.resolve(
      "../artifacts/contracts/test/TestERC20.sol/TestERC20.json"
    );
    const artifact = require(artifactPath);

    const deployHash = await walletClient.deployContract({
      abi: artifact.abi,
      bytecode: artifact.bytecode as `0x${string}`,
      account: testAccount.address,
      gas: 5000000n,
      args: [],
    });

    const erc20Receipt = await publicClient.waitForTransactionReceipt({
      hash: deployHash,
      timeout: 5000,
    });

    const nftArtifactPath = require.resolve(
      "../artifacts/contracts/test/TestERC721.sol/TestERC721.json"
    );
    const nftArtifact = require(nftArtifactPath);

    const nftDeployHash = await walletClient.deployContract({
      abi: nftArtifact.abi,
      bytecode: nftArtifact.bytecode as `0x${string}`,
      account: testAccount.address,
      gas: 5000000n,
      args: ["TestNFT", "TNFT"],
    });

    const nftReceipt = await publicClient.waitForTransactionReceipt({
      hash: nftDeployHash,
      timeout: 5000,
    });

    return {
      erc20Address: erc20Receipt.contractAddress as `0x${string}`,
      nftAddress: nftReceipt.contractAddress as `0x${string}`,
    };
  }

  async function buildAndSignTransaction(
    helperContract: any,
    toAddress: `0x${string}`,
    inputData: Hex,
    value = 0n,
    gasLimit = 100000n
  ) {
    const chainId = 31337n;
    const nonce = await publicClient.getTransactionCount({
      address: testAccount.address,
    });
    const maxFeePerGas = 20000000000n;
    const maxPriorityFeePerGas = 1000000000n;

    const viemTx: TransactionSerializable = {
      chainId: Number(chainId),
      to: toAddress,
      value: value,
      nonce,
      gas: gasLimit,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      data: inputData,
      type: "eip1559",
    };

    const txParams = {
      chainId: Number(chainId),
      nonce: Number(nonce),
      to: toAddress,
      hasTo: true,
      value: value,
      input: inputData,
      gasLimit: gasLimit,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
    };

    const serializedViemTx = serializeTransaction(viemTx);
    const serializedEVMTx = await helperContract.read.createUnsignedTransaction(
      [txParams]
    );

    expect(serializedEVMTx).to.equal(
      serializedViemTx,
      "Serialized transactions should match"
    );

    const viemTxHash = keccak256(serializedViemTx);
    const evmTxHash = (await helperContract.read.getHashToSign([
      serializedEVMTx,
    ])) as `0x${string}`;

    expect(evmTxHash).to.equal(viemTxHash, "Transaction hashes should match");

    const privateKeyBytes = hexToBytes(TEST_PRIVATE_KEY as `0x${string}`);
    const messageHashBytes = hexToBytes(evmTxHash);

    const signature = secp256k1.sign(messageHashBytes, privateKeyBytes);

    const r = `0x${signature.r.toString(16).padStart(64, "0")}` as Hex;
    const s = `0x${signature.s.toString(16).padStart(64, "0")}` as Hex;
    const v = signature.recovery;

    const evmSignature = { v, r, s };

    const signedEVMTx = (await helperContract.read.createSignedTransaction([
      txParams,
      evmSignature,
    ])) as Hex;

    return { signedEVMTx, txParams };
  }

  async function executeAndVerifyTransaction(
    signedEVMTx: Hex,
    description: string
  ) {
    const txHash = await publicClient.sendRawTransaction({
      serializedTransaction: signedEVMTx,
    });

    const receipt = await publicClient.waitForTransactionReceipt({
      hash: txHash,
      timeout: 5000,
    });

    expect(receipt.status).to.equal(
      "success",
      `${description} should be successful`
    );

    return receipt;
  }

  describe("Direct Library Usage", function () {
    it("Should compare transaction building between EVMTxBuilder and viem", async function () {
      const { helperContract } = await loadFixture(deployLibraryFixture);

      const recipient = RECIPIENT;
      const value = 1000000000000000n;
      const input = "0x" as Hex;

      const { signedEVMTx } = await buildAndSignTransaction(
        helperContract,
        recipient,
        input,
        value,
        21000n
      );

      await executeAndVerifyTransaction(signedEVMTx, "ETH transfer");
    });
  });

  describe("ERC20 Contract Interaction", function () {
    it("Should build and execute ERC20 transfer transaction", async function () {
      const { helperContract } = await loadFixture(deployLibraryFixture);
      const { erc20Address } = await loadFixture(deployTokenFixture);

      await walletClient.writeContract({
        address: erc20Address,
        abi: parseAbi(ERC20_ABI),
        functionName: "mint",
        args: [testAccount.address, parseEther("100")],
      });

      const transferAmount = parseEther("10");
      const transferData = encodeFunctionData({
        abi: parseAbi(ERC20_ABI),
        functionName: "transfer",
        args: [RECIPIENT, transferAmount],
      });

      const { signedEVMTx } = await buildAndSignTransaction(
        helperContract,
        erc20Address,
        transferData
      );

      const receipt = await executeAndVerifyTransaction(
        signedEVMTx,
        "ERC20 transfer"
      );

      expect(receipt.blockNumber).to.not.be.undefined;

      const balance = await publicClient.readContract({
        address: erc20Address,
        abi: parseAbi(ERC20_ABI),
        functionName: "balanceOf",
        args: [testAccount.address],
      });

      expect(balance).to.equal(parseEther("90"), "ERC20 balance should be 90");

      const recipientBalance = await publicClient.readContract({
        address: erc20Address,
        abi: parseAbi(ERC20_ABI),
        functionName: "balanceOf",
        args: [RECIPIENT],
      });

      expect(recipientBalance).to.equal(
        parseEther("10"),
        "ERC20 balance should be 10"
      );
    });
  });

  describe("NFT Contract Interaction", function () {
    it("Should build and execute NFT transfer transaction", async function () {
      const { helperContract } = await loadFixture(deployLibraryFixture);
      const { nftAddress } = await loadFixture(deployTokenFixture);

      const mintTxHash = await walletClient.writeContract({
        address: nftAddress as `0x${string}`,
        abi: parseAbi(NFT_ABI),
        functionName: "mint",
        args: [testAccount.address, 2n],
      });

      await publicClient.waitForTransactionReceipt({
        hash: mintTxHash,
      });

      const transferData = encodeFunctionData({
        abi: parseAbi(NFT_ABI),
        functionName: "transferFrom",
        args: [testAccount.address, RECIPIENT, 2n],
      });

      const { signedEVMTx } = await buildAndSignTransaction(
        helperContract,
        nftAddress as `0x${string}`,
        transferData
      );

      await executeAndVerifyTransaction(signedEVMTx, "NFT transfer");

      const ownerAfter = await publicClient.readContract({
        address: nftAddress as `0x${string}`,
        abi: parseAbi(NFT_ABI),
        functionName: "ownerOf",
        args: [2n],
      });

      expect(ownerAfter).to.equal(
        RECIPIENT,
        "NFT should be owned by the recipient after transfer"
      );
    });
  });
});
