import { expect } from "chai";
import hre from "hardhat";

import * as bitcoin from "bitcoinjs-lib";
import { ECPairFactory } from "ecpair";
import * as tinysecp from "tiny-secp256k1";

const ECPair = ECPairFactory(tinysecp);

const Client = require("bitcoin-core");

const BTC_RPC_URL = "http://localhost:19001";
const BTC_RPC_USER = "admin1";
const BTC_RPC_PASS = "123";

const PRIVATE_KEY = Buffer.from(
  "0000000000000000000000000000000000000000000000000000000000000001",
  "hex"
);

const TEST_KEY_PAIR = ECPair.fromPrivateKey(PRIVATE_KEY);
const PUBLIC_KEY = Buffer.from(TEST_KEY_PAIR.publicKey);

const p2wpkh = bitcoin.payments.p2wpkh({
  pubkey: PUBLIC_KEY,
  network: bitcoin.networks.regtest,
});

const TEST_ADDRESS = p2wpkh.address as string;

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

  sign(hash: Buffer): Buffer {
    return Buffer.from(this._keyPair.sign(hash));
  }

  createP2WPKH(network = bitcoin.networks.regtest): bitcoin.payments.Payment {
    return bitcoin.payments.p2wpkh({
      pubkey: this.publicKey,
      network,
    });
  }
}

type BitcoinRPC = {
  command(method: string, ...params: any[]): Promise<any>;
  getBlockchainInfo(): Promise<any>;
  getNewAddress(): Promise<string>;
  validateAddress(address: string): Promise<any>;
  generateToAddress(blocks: number, address: string): Promise<string[]>;
  listUnspent(
    minConf: number,
    maxConf: number,
    addresses?: string[]
  ): Promise<any[]>;
  getTxOut(txid: string, n: number): Promise<any>;
  decodeRawTransaction(hexstring: string): Promise<any>;
  getMemPoolEntry(txid: string): Promise<any>;
  getTransaction(txid: string): Promise<any>;
  importPrivKey(privkey: string, label: string, rescan: boolean): Promise<void>;
  sendRawTransaction(hexstring: string): Promise<string>;
  sendToAddress(
    address: string,
    amount: number,
    comment?: string
  ): Promise<string>;
  createRawTransaction(inputs: any[], outputs: any): Promise<string>;
  getAddressInfo(address: string): Promise<any>;
  getRawTransaction(txid: string, verbose?: boolean): Promise<any>;
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
    if (error instanceof Error) {
      throw new Error(`Bitcoin RPC call failed: ${error.message}`);
    } else {
      throw new Error(`Bitcoin RPC call failed: ${String(error)}`);
    }
  }
}

async function signRawTransaction(
  hexString: string,
  utxoAmount: number
): Promise<string> {
  const txHex = hexString.startsWith("0x") ? hexString.substring(2) : hexString;

  try {
    const txBuffer = Buffer.from(txHex, "hex");
    const tx = bitcoin.Transaction.fromBuffer(txBuffer);
    const input = 0;
    const prevOutScript = p2wpkh.output as Buffer;
    const inputValue = Math.floor(utxoAmount * 100000000);

    const hashForSignature = tx.hashForWitnessV0(
      input,
      prevOutScript,
      inputValue,
      bitcoin.Transaction.SIGHASH_ALL
    );

    const signature = TEST_KEY_PAIR.sign(hashForSignature);
    const derSignature = bitcoin.script.signature.encode(
      Buffer.from(signature),
      bitcoin.Transaction.SIGHASH_ALL
    );

    tx.setWitness(input, [derSignature, PUBLIC_KEY]);

    return tx.toHex();
  } catch (error) {
    throw error;
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
