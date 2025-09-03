// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "../libraries/BTCTxBuilder.sol";

/**
 * @title TestBTCTxBuilder
 * @dev A minimal helper contract for testing the BTCTxBuilder library
 */
contract TestBTCTxBuilder {
    using BTCTxBuilder for *;

    /**
     * @dev A structured representation of a transaction input
     */
    struct TxInputParams {
        bytes32 txid;
        uint32 vout;
        bytes scriptSig;
        uint32 sequence;
        bytes witnessData;
        uint8 scriptType;
    }

    /**
     * @dev A structured representation of a transaction output
     */
    struct TxOutputParams {
        uint64 value;
        bytes scriptPubKey;
    }

    /**
     * @dev A structured representation of a transaction
     */
    struct TransactionParams {
        uint32 version;
        TxInputParams[] inputs;
        TxOutputParams[] outputs;
        uint32 locktime;
        bool hasWitness;
    }

    /**
     * @dev A structured representation of a signature
     */
    struct SignatureParams {
        bytes r;
        bytes s;
        uint8 hashType;
    }

    /**
     * @dev Create an unsigned transaction
     * @param txParams The transaction parameters
     * @return The serialized unsigned transaction
     */
    function createUnsignedTransaction(
        TransactionParams memory txParams
    ) public pure returns (bytes memory) {
        BTCTxBuilder.BTCTransaction memory tx = _buildBtcTransaction(txParams);
        return BTCTxBuilder.buildUnsignedTransaction(tx);
    }

    /**
     * @dev Create a signed transaction
     * @param txParams The transaction parameters
     * @param signatures The signatures for each input
     * @param pubKeys The public keys for each input
     * @return The serialized signed transaction
     */
    function createSignedTransaction(
        TransactionParams memory txParams,
        SignatureParams[] memory signatures,
        bytes[] memory pubKeys
    ) public pure returns (bytes memory) {
        BTCTxBuilder.BTCTransaction memory tx = _buildBtcTransaction(txParams);

        BTCTxBuilder.Signature[]
            memory btcSignatures = new BTCTxBuilder.Signature[](
                signatures.length
            );
        for (uint i = 0; i < signatures.length; i++) {
            btcSignatures[i] = BTCTxBuilder.Signature({
                r: signatures[i].r,
                s: signatures[i].s,
                hashType: signatures[i].hashType
            });
        }

        return BTCTxBuilder.buildSignedTransaction(tx, btcSignatures, pubKeys);
    }

    /**
     * @dev Get the hash of a transaction for signing
     * @param txParams The transaction parameters
     * @param inputIndex The index of the input being signed
     * @param scriptCode The script code for the input
     * @param value The value of the input (for SegWit only)
     * @param hashType The signature hash type
     * @return The hash that should be signed
     */
    function getHashToSign(
        TransactionParams memory txParams,
        uint inputIndex,
        bytes memory scriptCode,
        uint64 value,
        uint8 hashType
    ) public pure returns (bytes32) {
        BTCTxBuilder.BTCTransaction memory tx = _buildBtcTransaction(txParams);
        return
            BTCTxBuilder.getHashToSign(
                tx,
                inputIndex,
                scriptCode,
                value,
                hashType
            );
    }

    /**
     * @dev Get all hashes of a transaction for signing all inputs
     * @param txParams The transaction parameters
     * @param scriptCodes The script codes for each input
     * @param values The values of each input (for SegWit only)
     * @param hashType The signature hash type
     * @return The hashes that should be signed for each input
     */
    function getAllHashesToSign(
        TransactionParams memory txParams,
        bytes[] memory scriptCodes,
        uint64[] memory values,
        uint8 hashType
    ) public pure returns (bytes32[] memory) {
        BTCTxBuilder.BTCTransaction memory tx = _buildBtcTransaction(txParams);
        return
            BTCTxBuilder.getAllHashesToSign(tx, scriptCodes, values, hashType);
    }

    /**
     * @dev Builds a BTC transaction from transaction parameters
     */
    function _buildBtcTransaction(
        TransactionParams memory txParams
    ) internal pure returns (BTCTxBuilder.BTCTransaction memory) {
        BTCTxBuilder.BTCTransaction memory tx;

        tx.version = txParams.version;
        tx.locktime = txParams.locktime;
        tx.hasWitness = txParams.hasWitness;

        tx.inputs = new BTCTxBuilder.TxInput[](txParams.inputs.length);
        for (uint i = 0; i < txParams.inputs.length; i++) {
            tx.inputs[i] = BTCTxBuilder.TxInput({
                txid: txParams.inputs[i].txid,
                vout: txParams.inputs[i].vout,
                scriptSig: txParams.inputs[i].scriptSig,
                sequence: txParams.inputs[i].sequence,
                witnessData: txParams.inputs[i].witnessData,
                scriptType: txParams.inputs[i].scriptType
            });
        }

        tx.outputs = new BTCTxBuilder.TxOutput[](txParams.outputs.length);
        for (uint i = 0; i < txParams.outputs.length; i++) {
            tx.outputs[i] = BTCTxBuilder.TxOutput({
                value: txParams.outputs[i].value,
                scriptPubKey: txParams.outputs[i].scriptPubKey
            });
        }

        return tx;
    }
}
