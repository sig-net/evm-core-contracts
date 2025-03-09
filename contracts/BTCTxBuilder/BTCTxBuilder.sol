// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/**
 * @title BTCTxBuilder
 * @dev Library for building Bitcoin transactions, with support for SegWit (P2WPKH, P2WSH)
 */
library BTCTxBuilder {
    // Transaction version
    uint8 constant DEFAULT_VERSION = 2;
    
    // SegWit marker and flag
    uint8 constant SEGWIT_MARKER = 0x00;
    uint8 constant SEGWIT_FLAG = 0x01;
    
    // Input sequence values
    uint32 constant SEQUENCE_FINAL = 0xffffffff;
    
    // Script types
    uint8 constant P2PKH = 1;
    uint8 constant P2SH = 2;
    uint8 constant P2WPKH = 3;
    uint8 constant P2WSH = 4;
    
    struct TxInput {
        bytes32 txid;        // Transaction ID (little-endian)
        uint32 vout;         // Output index
        bytes scriptSig;     // Script signature (empty for SegWit inputs before signing)
        uint32 sequence;     // Sequence number
        bytes witnessData;   // Witness data (for SegWit only)
        uint8 scriptType;    // Type of script (P2PKH, P2SH, P2WPKH, P2WSH)
    }
    
    struct TxOutput {
        uint64 value;        // Output value in satoshis
        bytes scriptPubKey;  // Output script
    }
    
    struct BTCTransaction {
        uint32 version;      // Transaction version
        TxInput[] inputs;    // Transaction inputs
        TxOutput[] outputs;  // Transaction outputs
        uint32 locktime;     // Transaction locktime
        bool hasWitness;     // Whether the transaction has witness data
    }
    
    struct Signature {
        bytes r;             // R component of signature
        bytes s;             // S component of signature
        uint8 hashType;      // Signature hash type (SIGHASH_ALL, etc.)
    }
    
    /**
     * @dev Builds an unsigned Bitcoin transaction
     * @param tx The transaction to build
     * @return The serialized transaction bytes
     */
    function buildUnsignedTransaction(BTCTransaction memory tx) public pure returns (bytes memory) {
        bytes memory result;
        
        // Add version
        result = bytes.concat(result, uint32ToLittleEndian(tx.version));
        
        // Add SegWit marker and flag if needed
        if (tx.hasWitness) {
            result = bytes.concat(result, bytes1(SEGWIT_MARKER), bytes1(SEGWIT_FLAG));
        }
        
        // Add input count
        result = bytes.concat(result, encodeVarInt(tx.inputs.length));
        
        // Add inputs
        for (uint i = 0; i < tx.inputs.length; i++) {
            result = bytes.concat(
                result,
                bytes32ToLittleEndian(tx.inputs[i].txid),
                uint32ToLittleEndian(tx.inputs[i].vout),
                encodeVarInt(tx.inputs[i].scriptSig.length),
                tx.inputs[i].scriptSig,
                uint32ToLittleEndian(tx.inputs[i].sequence)
            );
        }
        
        // Add output count
        result = bytes.concat(result, encodeVarInt(tx.outputs.length));
        
        // Add outputs
        for (uint i = 0; i < tx.outputs.length; i++) {
            result = bytes.concat(
                result,
                uint64ToLittleEndian(tx.outputs[i].value),
                encodeVarInt(tx.outputs[i].scriptPubKey.length),
                tx.outputs[i].scriptPubKey
            );
        }
        
        // Add witness data if needed
        if (tx.hasWitness) {
            for (uint i = 0; i < tx.inputs.length; i++) {
                if (tx.inputs[i].witnessData.length > 0) {
                    result = bytes.concat(result, tx.inputs[i].witnessData);
                } else {
                    // Empty witness
                    result = bytes.concat(result, bytes1(0x00));
                }
            }
        }
        
        // Add locktime
        result = bytes.concat(result, uint32ToLittleEndian(tx.locktime));
        
        return result;
    }
    
    /**
     * @dev Builds a signed Bitcoin transaction
     * @param tx The transaction to build
     * @param signatures Array of signatures for each input
     * @param pubKeys Array of public keys for each input
     * @return The serialized transaction bytes
     */
    function buildSignedTransaction(
        BTCTransaction memory tx, 
        Signature[] memory signatures, 
        bytes[] memory pubKeys
    ) public pure returns (bytes memory) {
        require(signatures.length == tx.inputs.length, "Signature count mismatch");
        require(pubKeys.length == tx.inputs.length, "Public key count mismatch");
        
        // Create a copy of the transaction to modify
        BTCTransaction memory signedTx = tx;
        
        // Apply signatures to inputs
        for (uint i = 0; i < tx.inputs.length; i++) {
            if (tx.inputs[i].scriptType == P2PKH) {
                // P2PKH signature script: <sig> <pubkey>
                signedTx.inputs[i].scriptSig = createP2PKHScriptSig(signatures[i], pubKeys[i]);
            } 
            else if (tx.inputs[i].scriptType == P2WPKH || tx.inputs[i].scriptType == P2WSH) {
                // For SegWit, scriptSig is empty and witness data contains the signature and pubkey
                signedTx.inputs[i].scriptSig = new bytes(0);
                signedTx.inputs[i].witnessData = createWitnessData(signatures[i], pubKeys[i], tx.inputs[i].scriptType);
                signedTx.hasWitness = true;
            }
            // Add other script types as needed
        }
        
        return buildUnsignedTransaction(signedTx);
    }
    
    /**
     * @dev Creates a P2PKH script signature
     * @param signature The signature
     * @param pubKey The public key
     * @return The script signature bytes
     */
    function createP2PKHScriptSig(Signature memory signature, bytes memory pubKey) internal pure returns (bytes memory) {
        // Signature with hash type
        bytes memory sigWithHashType = bytes.concat(signature.r, signature.s, bytes1(signature.hashType));
        
        // Create script: <sig_size> <sig> <pubkey_size> <pubkey>
        return bytes.concat(
            bytes1(uint8(sigWithHashType.length)),
            sigWithHashType,
            bytes1(uint8(pubKey.length)),
            pubKey
        );
    }
    
    /**
     * @dev Creates witness data for SegWit transactions
     * @param signature The signature
     * @param pubKey The public key
     * @param scriptType The script type (P2WPKH or P2WSH)
     * @return The witness data bytes
     */
    function createWitnessData(Signature memory signature, bytes memory pubKey, uint8 scriptType) internal pure returns (bytes memory) {
        bytes memory sigWithHashType = bytes.concat(signature.r, signature.s, bytes1(signature.hashType));
        
        if (scriptType == P2WPKH) {
            // P2WPKH witness: <item_count> <sig_size> <sig> <pubkey_size> <pubkey>
            return bytes.concat(
                bytes1(0x02), // 2 items
                bytes1(uint8(sigWithHashType.length)),
                sigWithHashType,
                bytes1(uint8(pubKey.length)),
                pubKey
            );
        } else if (scriptType == P2WSH) {
            // P2WSH witness structure depends on the specific redeem script
            // This is a simplified version
            return bytes.concat(
                bytes1(0x02), // 2 items
                bytes1(uint8(sigWithHashType.length)),
                sigWithHashType,
                bytes1(uint8(pubKey.length)),
                pubKey
            );
        }
        
        return new bytes(0);
    }
    
    /**
     * @dev Computes the transaction hash for signing
     * @param tx The transaction
     * @param inputIndex The index of the input being signed
     * @param scriptCode The script code for the input
     * @param value The value of the input (for SegWit only)
     * @param hashType The signature hash type
     * @return The transaction hash
     */
    function getHashToSign(
        BTCTransaction memory tx,
        uint inputIndex,
        bytes memory scriptCode,
        uint64 value,
        uint8 hashType
    ) public pure returns (bytes32) {
        require(inputIndex < tx.inputs.length, "Input index out of bounds");
        
        // For SegWit inputs, use BIP143 signature hash algorithm
        if (tx.inputs[inputIndex].scriptType == P2WPKH || tx.inputs[inputIndex].scriptType == P2WSH) {
            return hashForWitnessV0(tx, inputIndex, scriptCode, value, hashType);
        } else {
            // Legacy signature hash algorithm
            return hashForLegacy(tx, inputIndex, scriptCode, hashType);
        }
    }
    
    /**
     * @dev Computes the transaction hash for signing legacy inputs
     * @param tx The transaction
     * @param inputIndex The index of the input being signed
     * @param scriptCode The script code for the input
     * @param hashType The signature hash type
     * @return The transaction hash
     */
    function hashForLegacy(
        BTCTransaction memory tx,
        uint inputIndex,
        bytes memory scriptCode,
        uint8 hashType
    ) internal pure returns (bytes32) {
        // This is a simplified implementation
        // In a real implementation, you would need to handle different SIGHASH types
        
        // Create a copy of the transaction
        BTCTransaction memory txCopy = tx;
        
        // Clear all input scripts
        for (uint i = 0; i < txCopy.inputs.length; i++) {
            txCopy.inputs[i].scriptSig = new bytes(0);
        }
        
        // Set the script for the current input
        txCopy.inputs[inputIndex].scriptSig = scriptCode;
        
        // Serialize the transaction
        bytes memory serialized = buildUnsignedTransaction(txCopy);
        
        // Add hash type
        serialized = bytes.concat(serialized, bytes1(hashType));
        
        // Double SHA256
        return sha256(abi.encodePacked(sha256(serialized)));
    }
    
    /**
     * @dev Computes the transaction hash for signing SegWit inputs (BIP143)
     * @param tx The transaction
     * @param inputIndex The index of the input being signed
     * @param scriptCode The script code for the input
     * @param value The value of the input
     * @param hashType The signature hash type
     * @return The transaction hash
     */
    function hashForWitnessV0(
        BTCTransaction memory tx,
        uint inputIndex,
        bytes memory scriptCode,
        uint64 value,
        uint8 hashType
    ) internal pure returns (bytes32) {
        // This is a simplified implementation of BIP143
        // In a real implementation, you would need to handle different SIGHASH types
        
        bytes memory hashPrevouts = new bytes(0);
        bytes memory hashSequence = new bytes(0);
        bytes memory hashOutputs = new bytes(0);
        
        // Calculate hashPrevouts
        bytes memory prevouts = new bytes(0);
        for (uint i = 0; i < tx.inputs.length; i++) {
            prevouts = bytes.concat(
                prevouts,
                bytes32ToLittleEndian(tx.inputs[i].txid),
                uint32ToLittleEndian(tx.inputs[i].vout)
            );
        }
        hashPrevouts = abi.encodePacked(sha256(abi.encodePacked(sha256(prevouts))));
        
        // Calculate hashSequence
        bytes memory sequences = new bytes(0);
        for (uint i = 0; i < tx.inputs.length; i++) {
            sequences = bytes.concat(sequences, uint32ToLittleEndian(tx.inputs[i].sequence));
        }
        hashSequence = abi.encodePacked(sha256(abi.encodePacked(sha256(sequences))));
        
        // Calculate hashOutputs
        bytes memory outputs = new bytes(0);
        for (uint i = 0; i < tx.outputs.length; i++) {
            outputs = bytes.concat(
                outputs,
                uint64ToLittleEndian(tx.outputs[i].value),
                encodeVarInt(tx.outputs[i].scriptPubKey.length),
                tx.outputs[i].scriptPubKey
            );
        }
        hashOutputs = abi.encodePacked(sha256(abi.encodePacked(sha256(outputs))));
        
        // Build the signature hash preimage
        bytes memory preimage = bytes.concat(
            uint32ToLittleEndian(tx.version),
            hashPrevouts,
            hashSequence,
            bytes32ToLittleEndian(tx.inputs[inputIndex].txid),
            uint32ToLittleEndian(tx.inputs[inputIndex].vout),
            encodeVarInt(scriptCode.length),
            scriptCode,
            uint64ToLittleEndian(value),
            uint32ToLittleEndian(tx.inputs[inputIndex].sequence),
            hashOutputs,
            uint32ToLittleEndian(tx.locktime),
            bytes1(hashType)
        );
        
        // Double SHA256
        return sha256(abi.encodePacked(sha256(preimage)));
    }
    
    // ================ UTILITY FUNCTIONS ================
    
    /**
     * @dev Converts a uint32 to little-endian bytes
     * @param value The uint32 value
     * @return The little-endian bytes
     */
    function uint32ToLittleEndian(uint32 value) internal pure returns (bytes memory) {
        bytes memory result = new bytes(4);
        result[0] = bytes1(uint8(value));
        result[1] = bytes1(uint8(value >> 8));
        result[2] = bytes1(uint8(value >> 16));
        result[3] = bytes1(uint8(value >> 24));
        return result;
    }
    
    /**
     * @dev Converts a uint64 to little-endian bytes
     * @param value The uint64 value
     * @return The little-endian bytes
     */
    function uint64ToLittleEndian(uint64 value) internal pure returns (bytes memory) {
        bytes memory result = new bytes(8);
        result[0] = bytes1(uint8(value));
        result[1] = bytes1(uint8(value >> 8));
        result[2] = bytes1(uint8(value >> 16));
        result[3] = bytes1(uint8(value >> 24));
        result[4] = bytes1(uint8(value >> 32));
        result[5] = bytes1(uint8(value >> 40));
        result[6] = bytes1(uint8(value >> 48));
        result[7] = bytes1(uint8(value >> 56));
        return result;
    }
    
    /**
     * @dev Converts a bytes32 to little-endian bytes
     * @param value The bytes32 value
     * @return The little-endian bytes
     */
    function bytes32ToLittleEndian(bytes32 value) internal pure returns (bytes memory) {
        bytes memory result = new bytes(32);
        bytes32 reversed = 0;
        
        // Reverse the bytes
        for (uint i = 0; i < 32; i++) {
            reversed |= bytes32(uint256(uint8(value[i])) << (8 * (31 - i)));
        }
        
        assembly {
            mstore(add(result, 32), reversed)
        }
        
        return result;
    }
    
    /**
     * @dev Encodes a variable integer (VarInt)
     * @param value The integer value
     * @return The encoded VarInt
     */
    function encodeVarInt(uint value) internal pure returns (bytes memory) {
        if (value < 0xfd) {
            return bytes.concat(bytes1(uint8(value)));
        } else if (value <= 0xffff) {
            return bytes.concat(bytes1(0xfd), bytes1(uint8(value)), bytes1(uint8(value >> 8)));
        } else if (value <= 0xffffffff) {
            return bytes.concat(
                bytes1(0xfe),
                bytes1(uint8(value)),
                bytes1(uint8(value >> 8)),
                bytes1(uint8(value >> 16)),
                bytes1(uint8(value >> 24))
            );
        } else {
            return bytes.concat(
                bytes1(0xff),
                bytes1(uint8(value)),
                bytes1(uint8(value >> 8)),
                bytes1(uint8(value >> 16)),
                bytes1(uint8(value >> 24)),
                bytes1(uint8(value >> 32)),
                bytes1(uint8(value >> 40)),
                bytes1(uint8(value >> 48)),
                bytes1(uint8(value >> 56))
            );
        }
    }
}
