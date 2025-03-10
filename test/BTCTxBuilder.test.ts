import { expect } from "chai";
import hre from "hardhat";

import * as bitcoin from "bitcoinjs-lib";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

import { secp256k1 } from "@noble/curves/secp256k1";

const Client = require("bitcoin-core");

type BitcoinRPC = {
  command(method: string, ...params: any[]): Promise<any>;
  getBlockchainInfo(): Promise<any>;
  getNewAddress(): Promise<string>;
  validateAddress(address: string): Promise<any>;
  generateToAddress(blocks: number, address: string): Promise<string[]>;
  listUnspent(
    minConf: number,
    maxConf: number,
    addresses: string[]
  ): Promise<any[]>;
  getTxOut(txid: string, n: number): Promise<any>;
  decodeRawTransaction(hexstring: string): Promise<any>;
  getMemPoolEntry(txid: string): Promise<any>;
  getTransaction(txid: string): Promise<any>;
  signRawTransactionWithWallet(hexstring: string): Promise<any>;
  sendRawTransaction(hexstring: string): Promise<string>;
};

interface BTCInput {
  txid: `0x${string}`;
  vout: number;
  scriptSig: `0x${string}`;
  sequence: number;
  witnessData: `0x${string}`;
  scriptType: number;
}

interface BTCOutput {
  value: bigint;
  scriptPubKey: `0x${string}`;
}

interface BTCTransaction {
  version: number;
  inputs: BTCInput[];
  outputs: BTCOutput[];
  locktime: number;
  hasWitness: boolean;
}

const BTC_RPC_USER = "admin1";
const BTC_RPC_PASS = "123";
const BTC_RPC_URL = "http://localhost:19001";

const bitcoinClient = new Client({
  host: BTC_RPC_URL,
  username: BTC_RPC_USER,
  password: BTC_RPC_PASS,
  timeout: 30000,
}) as BitcoinRPC;

async function callBitcoinRPC(method: string, params: any[] = []) {
  try {
    const result = await bitcoinClient.command(method, ...params);

    return result;
  } catch (error: unknown) {
    console.error("Bitcoin RPC error type:", typeof error);

    if (error instanceof Error) {
      console.error("Bitcoin RPC error:", error.message);
      console.error("Error stack:", error.stack);
      throw new Error(`Bitcoin RPC call failed: ${error.message}`);
    } else {
      console.error("Unexpected error:", String(error));
      throw new Error(`Bitcoin RPC call failed: ${String(error)}`);
    }
  }
}

function reverseTxid(txid: string): string {
  return Buffer.from(txid, "hex").reverse().toString("hex");
}

function btcToSatoshis(btc: number): bigint {
  return BigInt(Math.floor(btc * 100000000));
}

function signMessage(
  message: Uint8Array,
  privateKey: Uint8Array
): { signature: Uint8Array; recoveryId: number } {
  const signature = secp256k1.sign(message, privateKey);

  return {
    signature: signature.toCompactRawBytes(),
    recoveryId: signature.recovery,
  };
}

function signWithPrivateKey(
  txHash: `0x${string}`,
  privateKey: Uint8Array
): `0x${string}` {
  const messageHash = Buffer.from(txHash.substring(2), "hex");

  const { signature } = signMessage(messageHash, privateKey);

  const derSignature = bitcoin.script.signature.encode(
    Buffer.from(signature),
    0x01
  );

  return `0x${Buffer.from(derSignature).toString("hex")}`;
}

async function signRawTransaction(hexString: string): Promise<string> {
  const txHex = hexString.startsWith("0x") ? hexString.substring(2) : hexString;

  try {
    const signResult = await callBitcoinRPC("signrawtransactionwithwallet", [
      txHex,
    ]);

    if (!signResult.complete) {
      throw new Error(
        "Failed to sign transaction: " + JSON.stringify(signResult.errors)
      );
    }

    return signResult.hex;
  } catch (error) {
    try {
      const signResult = await callBitcoinRPC("signrawtransaction", [txHex]);

      if (!signResult.complete) {
        throw new Error(
          "Failed to sign transaction: " + JSON.stringify(signResult.errors)
        );
      }

      return signResult.hex;
    } catch (fallbackError) {
      console.error("Both signing methods failed:", fallbackError);
      throw fallbackError;
    }
  }
}

describe("BTCTxBuilder Integration Tests", function () {
  before(async function () {
    try {
      await callBitcoinRPC("getblockchaininfo");
    } catch (error: unknown) {
      console.warn(
        "Bitcoin testnet not available or not responsive. Skipping integration tests."
      );
      console.warn(
        "Error details:",
        error instanceof Error ? error.message : String(error)
      );
      console.warn(
        "Make sure the container is running with: docker run -d -p 19001:19001 -p 19011:19011 freewil/bitcoin-testnet-box"
      );
      this.skip();
    }
  });

  async function deployContracts() {
    const btcTxBuilder = await hre.viem.deployContract(
      "contracts/BTCTxBuilder/BTCTxBuilder.sol:BTCTxBuilder"
    );

    const helperContract = await hre.viem.deployContract(
      "contracts/test/TestBTCTxBuilder.sol:TestBTCTxBuilder",
      [],
      {
        libraries: {
          "contracts/BTCTxBuilder/BTCTxBuilder.sol:BTCTxBuilder":
            btcTxBuilder.address,
        },
      }
    );

    return { btcTxBuilder, helperContract };
  }

  async function sendRawTransaction(hexString: string): Promise<string> {
    const txHex = hexString.startsWith("0x")
      ? hexString.substring(2)
      : hexString;

    return await callBitcoinRPC("sendrawtransaction", [txHex]);
  }

  async function verifyTransaction(txid: string): Promise<boolean> {
    try {
      await callBitcoinRPC("getmempoolentry", [txid]);
      return true;
    } catch (error) {
      try {
        const txInfo = await callBitcoinRPC("gettransaction", [txid]);

        return true;
      } catch (getError) {
        console.error("Transaction not found:", getError);
        return false;
      }
    }
  }

  describe("Integration Tests", function () {
    it("should create, sign, and broadcast a real transaction on testnet", async function () {
      const { helperContract } = await loadFixture(deployContracts);

      try {
        const senderAddress = await callBitcoinRPC("getnewaddress");

        await callBitcoinRPC("generatetoaddress", [101, senderAddress]);

        const unspentOutputs = await callBitcoinRPC("listunspent", [
          1,
          9999999,
          [senderAddress],
        ]);

        if (unspentOutputs.length === 0) {
          throw new Error("No unspent outputs available");
        }

        const utxo = unspentOutputs[0];

        const recipientAddress = await callBitcoinRPC("getnewaddress");

        const recipientAddressInfo = await callBitcoinRPC("validateaddress", [
          recipientAddress,
        ]);
        const recipientScriptPubKey =
          `0x${recipientAddressInfo.scriptPubKey}` as `0x${string}`;

        const senderAddressInfo = await callBitcoinRPC("validateaddress", [
          senderAddress,
        ]);
        const senderScriptPubKey =
          `0x${senderAddressInfo.scriptPubKey}` as `0x${string}`;

        const utxoScriptPubKey = await callBitcoinRPC("gettxout", [
          utxo.txid,
          utxo.vout,
        ]);
        if (
          !utxoScriptPubKey ||
          !utxoScriptPubKey.scriptPubKey ||
          !utxoScriptPubKey.scriptPubKey.hex
        ) {
          throw new Error("Failed to get UTXO scriptPubKey");
        }

        const scriptCode =
          `0x${utxoScriptPubKey.scriptPubKey.hex}` as `0x${string}`;

        const txParams: BTCTransaction = {
          version: 2,
          inputs: [
            {
              txid: `0x${reverseTxid(utxo.txid)}` as `0x${string}`,
              vout: utxo.vout,
              scriptSig: "0x" as `0x${string}`,
              sequence: 0xffffffff,
              witnessData: "0x" as `0x${string}`,
              scriptType: 1,
            },
          ],
          outputs: [
            {
              value: btcToSatoshis(Math.min(0.5, utxo.amount * 0.5)),
              scriptPubKey: recipientScriptPubKey,
            },
            {
              value: btcToSatoshis(Math.max(0.01, utxo.amount - 0.51)),
              scriptPubKey: senderScriptPubKey,
            },
          ],
          locktime: 0,
          hasWitness: false,
        };

        const unsignedTx = await helperContract.read.createUnsignedTransaction([
          txParams,
        ]);

        const decodedTx = await callBitcoinRPC("decoderawtransaction", [
          unsignedTx.substring(2),
        ]);

        expect(decodedTx).to.have.property("txid");
        expect(decodedTx.version).to.equal(txParams.version);
        expect(decodedTx.locktime).to.equal(txParams.locktime);
        expect(decodedTx.vin.length).to.equal(txParams.inputs.length);
        expect(decodedTx.vout.length).to.equal(txParams.outputs.length);

        const satoshisValue = BigInt(Math.floor(utxo.amount * 100000000));

        const hashToSign = await helperContract.read.getHashToSign([
          txParams,
          BigInt(0),
          scriptCode,
          satoshisValue,
          1,
        ]);

        const signedTxHex = await signRawTransaction(unsignedTx);

        const txid = await sendRawTransaction(signedTxHex);

        const isVerified = await verifyTransaction(txid);
        expect(isVerified).to.be.true;

        await callBitcoinRPC("generatetoaddress", [1, senderAddress]);

        const confirmedTx = await callBitcoinRPC("gettransaction", [txid]);

        expect(confirmedTx.confirmations).to.be.at.least(1);
      } catch (error) {
        console.error("Test failed:", error);
        throw error;
      }
    });
  });
});
