/**
 * BTCTxBuilder Integration Tests
 *
 * These tests demonstrate the functionality of the BTCTxBuilder contract for Bitcoin transaction handling.
 *
 * Test 1: "should create, sign and broadcast a transaction using local signing only"
 * - Uses bitcoinjs-lib to create, sign, and broadcast a Bitcoin transaction
 * - Serves as a baseline to verify that the Bitcoin RPC connection is working
 *
 * Test 2: "should create, sign and broadcast a transaction using BTCTxBuilder contract"
 * - Uses the BTCTxBuilder contract to generate an unsigned transaction
 * - Uses the BTCTxBuilder contract to generate the hash for signing
 * - Verifies that the hash is correct by creating a valid signature with it
 * - Uses bitcoinjs-lib to sign and broadcast the transaction
 *
 * Test 3: "should build, sign, and broadcast a transaction using the contract with external signing"
 * - Uses the BTCTxBuilder contract to generate an unsigned transaction
 * - Uses the BTCTxBuilder contract to generate all hashes for signing
 * - Signs the hashes externally
 * - Uses the BTCTxBuilder contract to build the signed transaction
 * - Broadcasts the transaction
 *
 * Current Implementation Status:
 * - The BTCTxBuilder contract can correctly build unsigned Bitcoin transactions
 * - The BTCTxBuilder contract can correctly generate the hash for signing
 * - The BTCTxBuilder contract has DER signature encoding, but there are still issues with the signature format
 * - Future work: Fix the signature format issues to enable full transaction signing with the contract
 */

import { expect } from "chai";
import hre from "hardhat";

import * as bitcoin from "bitcoinjs-lib";
import { ECPairFactory } from "ecpair";
import * as tinysecp from "tiny-secp256k1";
import { secp256k1 } from "@noble/curves/secp256k1";

const ECPair = ECPairFactory(tinysecp);

import Client from "bitcoin-core";

const BTC_RPC_URL = "http://localhost:19001";
const BTC_RPC_USER = "admin1";
const BTC_RPC_PASS = "123";

class BitcoinKeyPair {
  private _keyPair: ReturnType<typeof ECPair.makeRandom>;

  constructor(network = bitcoin.networks.regtest) {
    this._keyPair = ECPair.makeRandom({ network });
  }

  get wif(): string {
    return this._keyPair.toWIF();
  }

  get publicKey(): Buffer {
    return Buffer.from(this._keyPair.publicKey);
  }

  get privateKey(): Buffer | undefined {
    return this._keyPair.privateKey
      ? Buffer.from(this._keyPair.privateKey)
      : undefined;
  }

  sign(hash: Buffer): Buffer {
    if (!this.privateKey) {
      throw new Error("Cannot sign without private key");
    }

    // Use noble/curves secp256k1 for signing
    const signature = secp256k1.sign(hash, this.privateKey);
    return Buffer.from(signature.toCompactRawBytes());
  }

  createP2WPKH(network = bitcoin.networks.regtest): bitcoin.payments.Payment {
    return bitcoin.payments.p2wpkh({
      pubkey: this.publicKey,
      network,
    });
  }
}

const bitcoinClient = new Client({
  host: BTC_RPC_URL,
  username: BTC_RPC_USER,
  password: BTC_RPC_PASS,
  timeout: 30000,
});

async function callBitcoinRPC(method: string, params: any[] = []) {
  try {
    const result = await bitcoinClient.command(method, ...params);
    return result;
  } catch (error: unknown) {
    throw new Error(`Bitcoin RPC call failed: ${String(error)}`);
  }
}

async function sendRawTransaction(hexString: string): Promise<string> {
  const txHex = hexString.startsWith("0x") ? hexString.substring(2) : hexString;
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
      return false;
    }
  }
}

describe("BTCTxBuilder Integration Tests", function () {
  before(async function () {
    try {
      await callBitcoinRPC("getblockchaininfo");
    } catch (error: unknown) {
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

  describe("Integration Tests", function () {
    it("should create, sign and broadcast a transaction using local signing only", async function () {
      try {
        const keyPair = new BitcoinKeyPair();
        const p2wpkh = keyPair.createP2WPKH();
        const testAddress = p2wpkh.address as string;
        const receivingAddress = await callBitcoinRPC("getnewaddress");
        const fundingAmount = 0.1;
        const fundingTxid = await callBitcoinRPC("sendtoaddress", [
          testAddress,
          fundingAmount,
          "Fund test address",
        ]);

        await callBitcoinRPC("generatetoaddress", [
          1,
          await callBitcoinRPC("getnewaddress"),
        ]);

        const txDetails = await callBitcoinRPC("gettransaction", [fundingTxid]);
        const decodedTx = await callBitcoinRPC("decoderawtransaction", [
          txDetails.hex,
        ]);

        let utxoVout = -1;
        let utxoValue = 0;

        for (const detail of txDetails.details) {
          if (detail.address === testAddress && detail.category === "send") {
            utxoVout = detail.vout;
            utxoValue = Math.abs(detail.amount);
            break;
          }
        }

        if (utxoVout === -1) {
          for (let i = 0; i < decodedTx.vout.length; i++) {
            const output = decodedTx.vout[i];
            if (output.scriptPubKey.address === testAddress) {
              utxoVout = i;
              utxoValue = output.value;
              break;
            }
          }
        }

        if (utxoVout === -1) {
          throw new Error(
            "Could not find UTXO for our address in the funding transaction"
          );
        }

        const sendAmount = 0.01;
        const fee = 0.0001;
        const changeAmount = utxoValue - sendAmount - fee;
        const sendAmountSats = Math.floor(sendAmount * 100000000);
        const changeAmountSats = Math.floor(changeAmount * 100000000);

        const psbt = new bitcoin.Psbt({ network: bitcoin.networks.regtest });

        const witnessUtxo = {
          script: p2wpkh.output ? Buffer.from(p2wpkh.output) : Buffer.alloc(0),
          value: Math.floor(utxoValue * 100000000),
        };
        psbt.addInput({
          hash: fundingTxid,
          index: utxoVout,
          witnessUtxo,
        });

        psbt.addOutput({
          address: receivingAddress,
          value: sendAmountSats,
        });

        psbt.addOutput({
          address: testAddress,
          value: changeAmountSats,
        });

        psbt.signInput(0, {
          publicKey: keyPair.publicKey,
          sign: (hash) => keyPair.sign(hash),
        });

        psbt.finalizeAllInputs();

        const signedTx = psbt.extractTransaction();
        const signedTxHex = signedTx.toHex();
        const txid = await sendRawTransaction(signedTxHex);
        const isVerified = await verifyTransaction(txid);
        expect(isVerified).to.be.true;

        await callBitcoinRPC("generatetoaddress", [
          1,
          await callBitcoinRPC("getnewaddress"),
        ]);

        const confirmedTx = await callBitcoinRPC("gettransaction", [txid]);
        expect(confirmedTx.confirmations).to.be.at.least(1);
      } catch (error) {
        throw error;
      }
    });
  });
});
