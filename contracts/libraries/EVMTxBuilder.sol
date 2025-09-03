pragma solidity ^0.8.28;
import {Lib_RLPWriter as RLPWriter} from "@eth-optimism/contracts/libraries/rlp/Lib_RLPWriter.sol";

/**
 * @title EVMTxBuilder
 * @dev Minimal library for building EIP-1559 EVM transactions
 */
library EVMTxBuilder {
    uint8 constant EIP_1559_TYPE = 2;

    struct AccessListEntry {
        address addr;
        bytes32[] storageKeys;
    }

    struct Signature {
        uint64 v;
        bytes32 r;
        bytes32 s;
    }

    struct EVMTransaction {
        uint64 chainId;
        uint64 nonce;
        address to;
        bool hasTo;
        uint128 value;
        bytes input;
        uint128 gasLimit;
        uint128 maxFeePerGas;
        uint128 maxPriorityFeePerGas;
        AccessListEntry[] accessList;
    }

    /**
     * @dev Builds transaction data for signing
     * @param tx The transaction to build
     * @return The RLP encoded transaction data
     */
    function buildForSigning(EVMTransaction memory tx) public pure returns (bytes memory) {
        bytes memory result = new bytes(1);
        result[0] = bytes1(EIP_1559_TYPE);

        bytes memory encodedFields = encodeFields(tx);

        return bytes.concat(result, encodedFields);
    }

    /**
     * @dev Builds transaction data with signature
     * @param tx The transaction to build
     * @param signature The signature to include
     * @return The RLP encoded transaction data with signature
     */
    function buildWithSignature(
        EVMTransaction memory tx,
        Signature memory signature
    ) public pure returns (bytes memory) {
        bytes memory result = new bytes(1);
        result[0] = bytes1(EIP_1559_TYPE);

        bytes memory encodedFieldsWithSignature = encodeFieldsWithSignature(tx, signature);

        return bytes.concat(result, encodedFieldsWithSignature);
    }

    /**
     * @dev Encodes transaction fields for RLP
     * @param tx The transaction to encode
     * @return The RLP encoded transaction fields
     */
    function encodeFields(EVMTransaction memory tx) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](9);

        elements[0] = RLPWriter.writeUint(uint(tx.chainId));
        elements[1] = RLPWriter.writeUint(uint(tx.nonce));
        elements[2] = RLPWriter.writeUint(uint(tx.maxPriorityFeePerGas));
        elements[3] = RLPWriter.writeUint(uint(tx.maxFeePerGas));
        elements[4] = RLPWriter.writeUint(uint(tx.gasLimit));

        if (tx.hasTo) {
            elements[5] = RLPWriter.writeAddress(tx.to);
        } else {
            elements[5] = RLPWriter.writeBytes("");
        }

        elements[6] = RLPWriter.writeUint(uint(tx.value));
        elements[7] = RLPWriter.writeBytes(tx.input);
        elements[8] = _writeAccessList(tx.accessList);

        return RLPWriter.writeList(elements);
    }

    /**
     * @dev Encodes transaction fields with signature for RLP
     * @param tx The transaction to encode
     * @param signature The signature to include
     * @return The RLP encoded transaction fields with signature
     */
    function encodeFieldsWithSignature(
        EVMTransaction memory tx,
        Signature memory signature
    ) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](12);

        elements[0] = RLPWriter.writeUint(uint(tx.chainId));
        elements[1] = RLPWriter.writeUint(uint(tx.nonce));
        elements[2] = RLPWriter.writeUint(uint(tx.maxPriorityFeePerGas));
        elements[3] = RLPWriter.writeUint(uint(tx.maxFeePerGas));
        elements[4] = RLPWriter.writeUint(uint(tx.gasLimit));

        if (tx.hasTo) {
            elements[5] = RLPWriter.writeAddress(tx.to);
        } else {
            elements[5] = RLPWriter.writeBytes("");
        }

        elements[6] = RLPWriter.writeUint(uint(tx.value));
        elements[7] = RLPWriter.writeBytes(tx.input);
        elements[8] = _writeAccessList(tx.accessList);
        elements[9] = RLPWriter.writeUint(uint(signature.v));
        elements[10] = RLPWriter.writeBytes(abi.encodePacked(signature.r));
        elements[11] = RLPWriter.writeBytes(abi.encodePacked(signature.s));

        return RLPWriter.writeList(elements);
    }

    /**
     * @dev Get the hash of a transaction for signing
     * @param txBytes The RLP encoded transaction
     * @return The keccak256 hash that should be signed
     */
    function getHashToSign(bytes memory txBytes) public pure returns (bytes32) {
        return keccak256(txBytes);
    }

    /**
     * @dev Encodes an access list for RLP
     * @param accessList The access list entries
     * @return The RLP-encoded access list
     */
    function _writeAccessList(
        AccessListEntry[] memory accessList
    ) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](accessList.length);
        for (uint i = 0; i < accessList.length; i++) {
            bytes[] memory entry = new bytes[](2);
            entry[0] = RLPWriter.writeAddress(accessList[i].addr);

            bytes[] memory keys = new bytes[](accessList[i].storageKeys.length);
            for (uint j = 0; j < accessList[i].storageKeys.length; j++) {
                keys[j] = RLPWriter.writeBytes(abi.encodePacked(accessList[i].storageKeys[j]));
            }
            entry[1] = RLPWriter.writeList(keys);
            elements[i] = RLPWriter.writeList(entry);
        }
        return RLPWriter.writeList(elements);
    }
}
