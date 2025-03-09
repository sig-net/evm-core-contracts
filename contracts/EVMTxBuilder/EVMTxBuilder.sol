pragma solidity ^0.8.28;

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
    function buildForSigning(
        EVMTransaction memory tx
    ) public pure returns (bytes memory) {
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

        bytes memory encodedFieldsWithSignature = encodeFieldsWithSignature(
            tx,
            signature
        );

        return bytes.concat(result, encodedFieldsWithSignature);
    }

    /**
     * @dev Encodes transaction fields for RLP
     * @param tx The transaction to encode
     * @return The RLP encoded transaction fields
     */
    function encodeFields(
        EVMTransaction memory tx
    ) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](9);

        elements[0] = rlpEncodeUint(tx.chainId);
        elements[1] = rlpEncodeUint(tx.nonce);
        elements[2] = rlpEncodeUint(tx.maxPriorityFeePerGas);
        elements[3] = rlpEncodeUint(tx.maxFeePerGas);
        elements[4] = rlpEncodeUint(tx.gasLimit);

        if (tx.hasTo) {
            elements[5] = rlpEncodeAddress(tx.to);
        } else {
            elements[5] = rlpEncodeEmptyBytes();
        }

        elements[6] = rlpEncodeUint(tx.value);
        elements[7] = rlpEncodeBytes(tx.input);
        elements[8] = rlpEncodeAccessList(tx.accessList);

        return rlpEncodeList(elements);
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

        elements[0] = rlpEncodeUint(tx.chainId);
        elements[1] = rlpEncodeUint(tx.nonce);
        elements[2] = rlpEncodeUint(tx.maxPriorityFeePerGas);
        elements[3] = rlpEncodeUint(tx.maxFeePerGas);
        elements[4] = rlpEncodeUint(tx.gasLimit);

        if (tx.hasTo) {
            elements[5] = rlpEncodeAddress(tx.to);
        } else {
            elements[5] = rlpEncodeEmptyBytes();
        }

        elements[6] = rlpEncodeUint(tx.value);
        elements[7] = rlpEncodeBytes(tx.input);
        elements[8] = rlpEncodeAccessList(tx.accessList);
        elements[9] = rlpEncodeUint(signature.v);
        elements[10] = rlpEncodeBytes32(signature.r);
        elements[11] = rlpEncodeBytes32(signature.s);

        return rlpEncodeList(elements);
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
     * @dev Encodes a uint value for RLP
     * @param value The value to encode
     * @return The RLP encoded value
     */
    function rlpEncodeUint(uint value) internal pure returns (bytes memory) {
        if (value == 0) {
            bytes memory result = new bytes(1);
            result[0] = 0x80;
            return result;
        } else if (value < 128) {
            bytes memory result = new bytes(1);
            result[0] = bytes1(uint8(value));
            return result;
        } else {
            bytes memory encoded = uintToBytes(value);
            return rlpEncodeBytes(encoded);
        }
    }

    /**
     * @dev Encodes an address for RLP
     * @param addr The address to encode
     * @return The RLP encoded address
     */
    function rlpEncodeAddress(
        address addr
    ) internal pure returns (bytes memory) {
        bytes memory addrBytes = new bytes(20);

        uint160 addrValue = uint160(addr);

        for (uint i = 0; i < 20; i++) {
            addrBytes[i] = bytes1(uint8(addrValue >> (8 * (19 - i))));
        }

        return rlpEncodeBytes(addrBytes);
    }

    /**
     * @dev Encodes bytes for RLP
     * @param value The bytes to encode
     * @return The RLP encoded bytes
     */
    function rlpEncodeBytes(
        bytes memory value
    ) internal pure returns (bytes memory) {
        if (value.length == 1 && uint8(value[0]) < 128) {
            return value;
        } else if (value.length < 56) {
            bytes memory result = new bytes(value.length + 1);
            result[0] = bytes1(uint8(128 + value.length));
            for (uint i = 0; i < value.length; i++) {
                result[i + 1] = value[i];
            }
            return result;
        } else {
            bytes memory lengthBytes = uintToBytes(value.length);
            bytes memory result = new bytes(
                value.length + lengthBytes.length + 1
            );
            result[0] = bytes1(uint8(183 + lengthBytes.length));
            for (uint i = 0; i < lengthBytes.length; i++) {
                result[i + 1] = lengthBytes[i];
            }
            for (uint i = 0; i < value.length; i++) {
                result[i + lengthBytes.length + 1] = value[i];
            }
            return result;
        }
    }

    /**
     * @dev Encodes bytes32 for RLP
     * @param value The bytes32 to encode
     * @return The RLP encoded bytes32
     */
    function rlpEncodeBytes32(
        bytes32 value
    ) internal pure returns (bytes memory) {
        bytes memory valueBytes = new bytes(32);
        assembly {
            mstore(add(valueBytes, 32), value)
        }
        return rlpEncodeBytes(valueBytes);
    }

    /**
     * @dev Encodes empty bytes for RLP
     * @return The RLP encoded empty bytes
     */
    function rlpEncodeEmptyBytes() internal pure returns (bytes memory) {
        bytes memory result = new bytes(1);
        result[0] = 0x80;
        return result;
    }

    /**
     * @dev Encodes a list for RLP
     * @param elements The list elements to encode
     * @return The RLP encoded list
     */
    function rlpEncodeList(
        bytes[] memory elements
    ) internal pure returns (bytes memory) {
        uint totalLength = 0;
        for (uint i = 0; i < elements.length; i++) {
            totalLength += elements[i].length;
        }

        if (totalLength < 56) {
            bytes memory result = new bytes(totalLength + 1);
            result[0] = bytes1(uint8(192 + totalLength));
            uint position = 1;
            for (uint i = 0; i < elements.length; i++) {
                for (uint j = 0; j < elements[i].length; j++) {
                    result[position] = elements[i][j];
                    position++;
                }
            }
            return result;
        } else {
            bytes memory lengthBytes = uintToBytes(totalLength);
            bytes memory result = new bytes(
                totalLength + lengthBytes.length + 1
            );
            result[0] = bytes1(uint8(247 + lengthBytes.length));
            for (uint i = 0; i < lengthBytes.length; i++) {
                result[i + 1] = lengthBytes[i];
            }
            uint position = lengthBytes.length + 1;
            for (uint i = 0; i < elements.length; i++) {
                for (uint j = 0; j < elements[i].length; j++) {
                    result[position] = elements[i][j];
                    position++;
                }
            }
            return result;
        }
    }

    /**
     * @dev Encodes an access list for RLP
     * @param accessList The access list to encode
     * @return The RLP encoded access list
     */
    function rlpEncodeAccessList(
        AccessListEntry[] memory accessList
    ) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](accessList.length);

        for (uint i = 0; i < accessList.length; i++) {
            bytes[] memory entryElements = new bytes[](2);
            entryElements[0] = rlpEncodeAddress(accessList[i].addr);

            bytes[] memory storageKeyElements = new bytes[](
                accessList[i].storageKeys.length
            );
            for (uint j = 0; j < accessList[i].storageKeys.length; j++) {
                storageKeyElements[j] = rlpEncodeBytes32(
                    accessList[i].storageKeys[j]
                );
            }
            entryElements[1] = rlpEncodeList(storageKeyElements);

            elements[i] = rlpEncodeList(entryElements);
        }

        return rlpEncodeList(elements);
    }

    /**
     * @dev Converts a uint to bytes
     * @param value The uint value to convert
     * @return The bytes representation
     */
    function uintToBytes(uint value) internal pure returns (bytes memory) {
        if (value == 0) {
            return new bytes(0);
        }

        uint tempValue = value;
        uint length = 0;
        while (tempValue > 0) {
            length++;
            tempValue >>= 8;
        }

        bytes memory result = new bytes(length);
        tempValue = value;
        for (uint i = 0; i < length; i++) {
            result[length - i - 1] = bytes1(uint8(tempValue & 0xFF));
            tempValue >>= 8;
        }

        return result;
    }
}
