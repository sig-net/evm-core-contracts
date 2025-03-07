// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/**
 * @title EVMTxBuilder
 * @dev Library for building EVM transactions
 */
library EVMTxBuilder {
    // Constants
    uint8 constant EIP_1559_TYPE = 2;

    // Structs
    struct Address {
        bytes20 value;
    }

    struct Signature {
        uint64 v;
        bytes32 r;
        bytes32 s;
    }

    struct AccessListEntry {
        Address addr;
        bytes32[] storageKeys;
    }

    struct EVMTransaction {
        uint64 chainId;
        uint64 nonce;
        Address to;
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
    function buildWithSignature(EVMTransaction memory tx, Signature memory signature) public pure returns (bytes memory) {
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
        
        elements[0] = rlpEncodeUint64(tx.chainId);
        elements[1] = rlpEncodeUint64(tx.nonce);
        elements[2] = rlpEncodeUint128(tx.maxPriorityFeePerGas);
        elements[3] = rlpEncodeUint128(tx.maxFeePerGas);
        elements[4] = rlpEncodeUint128(tx.gasLimit);
        
        // Handle 'to' address
        if (tx.hasTo) {
            elements[5] = rlpEncodeAddress(tx.to);
        } else {
            elements[5] = rlpEncodeEmptyBytes();
        }
        
        elements[6] = rlpEncodeUint128(tx.value);
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
    function encodeFieldsWithSignature(EVMTransaction memory tx, Signature memory signature) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](12);
        
        elements[0] = rlpEncodeUint64(tx.chainId);
        elements[1] = rlpEncodeUint64(tx.nonce);
        elements[2] = rlpEncodeUint128(tx.maxPriorityFeePerGas);
        elements[3] = rlpEncodeUint128(tx.maxFeePerGas);
        elements[4] = rlpEncodeUint128(tx.gasLimit);
        
        // Handle 'to' address
        if (tx.hasTo) {
            elements[5] = rlpEncodeAddress(tx.to);
        } else {
            elements[5] = rlpEncodeEmptyBytes();
        }
        
        elements[6] = rlpEncodeUint128(tx.value);
        elements[7] = rlpEncodeBytes(tx.input);
        elements[8] = rlpEncodeAccessList(tx.accessList);
        elements[9] = rlpEncodeUint64(signature.v);
        elements[10] = rlpEncodeBytes32(signature.r);
        elements[11] = rlpEncodeBytes32(signature.s);
        
        return rlpEncodeList(elements);
    }

    /**
     * @dev Parses an Ethereum address from a string
     * @param addrStr The address string (with or without 0x prefix)
     * @return The parsed address
     */
    function parseEthAddress(string memory addrStr) public pure returns (Address memory) {
        bytes memory addrBytes = bytes(addrStr);
        bytes memory result = new bytes(20);
        
        // Remove 0x prefix if present
        uint256 startIdx = 0;
        if (addrBytes.length >= 2 && addrBytes[0] == bytes1('0') && (addrBytes[1] == bytes1('x') || addrBytes[1] == bytes1('X'))) {
            startIdx = 2;
        }
        
        // Convert hex string to bytes
        for (uint256 i = 0; i < 20; i++) {
            uint8 highNibble = hexCharToNibble(addrBytes[startIdx + i * 2]);
            uint8 lowNibble = hexCharToNibble(addrBytes[startIdx + i * 2 + 1]);
            result[i] = bytes1(highNibble * 16 + lowNibble);
        }
        
        return Address(bytes20(result));
    }

    /**
     * @dev Converts a hex character to its nibble value
     * @param c The hex character
     * @return The nibble value
     */
    function hexCharToNibble(bytes1 c) internal pure returns (uint8) {
        if (c >= bytes1('0') && c <= bytes1('9')) {
            return uint8(c) - uint8(bytes1('0'));
        }
        if (c >= bytes1('a') && c <= bytes1('f')) {
            return uint8(c) - uint8(bytes1('a')) + 10;
        }
        if (c >= bytes1('A') && c <= bytes1('F')) {
            return uint8(c) - uint8(bytes1('A')) + 10;
        }
        revert("Invalid hex character");
    }

    /**
     * @dev Parses a uint64 from a string
     * @param value The string value (decimal or hex with 0x prefix)
     * @return The parsed uint64
     */
    function parseUint64(string memory value) public pure returns (uint64) {
        bytes memory valueBytes = bytes(value);
        
        // Check for 0x prefix
        if (valueBytes.length >= 2 && valueBytes[0] == bytes1('0') && (valueBytes[1] == bytes1('x') || valueBytes[1] == bytes1('X'))) {
            return parseHexUint64(value, 2);
        } else {
            return parseDecimalUint64(value);
        }
    }

    /**
     * @dev Parses a uint128 from a string
     * @param value The string value (decimal or hex with 0x prefix)
     * @return The parsed uint128
     */
    function parseUint128(string memory value) public pure returns (uint128) {
        bytes memory valueBytes = bytes(value);
        
        // Check for 0x prefix
        if (valueBytes.length >= 2 && valueBytes[0] == bytes1('0') && (valueBytes[1] == bytes1('x') || valueBytes[1] == bytes1('X'))) {
            return parseHexUint128(value, 2);
        } else {
            return parseDecimalUint128(value);
        }
    }

    /**
     * @dev Parses a decimal uint64 from a string
     * @param value The string value
     * @return The parsed uint64
     */
    function parseDecimalUint64(string memory value) internal pure returns (uint64) {
        bytes memory valueBytes = bytes(value);
        uint64 result = 0;
        
        for (uint256 i = 0; i < valueBytes.length; i++) {
            require(valueBytes[i] >= bytes1('0') && valueBytes[i] <= bytes1('9'), "Invalid decimal character");
            result = result * 10 + uint64(uint8(valueBytes[i]) - uint8(bytes1('0')));
        }
        
        return result;
    }

    /**
     * @dev Parses a hex uint64 from a string
     * @param value The string value
     * @param startIndex The start index (after 0x prefix)
     * @return The parsed uint64
     */
    function parseHexUint64(string memory value, uint256 startIndex) internal pure returns (uint64) {
        bytes memory valueBytes = bytes(value);
        uint64 result = 0;
        
        for (uint256 i = startIndex; i < valueBytes.length; i++) {
            result = result * 16 + uint64(hexCharToNibble(valueBytes[i]));
        }
        
        return result;
    }

    /**
     * @dev Parses a decimal uint128 from a string
     * @param value The string value
     * @return The parsed uint128
     */
    function parseDecimalUint128(string memory value) internal pure returns (uint128) {
        bytes memory valueBytes = bytes(value);
        uint128 result = 0;
        
        for (uint256 i = 0; i < valueBytes.length; i++) {
            require(valueBytes[i] >= bytes1('0') && valueBytes[i] <= bytes1('9'), "Invalid decimal character");
            result = result * 10 + uint128(uint8(valueBytes[i]) - uint8(bytes1('0')));
        }
        
        return result;
    }

    /**
     * @dev Parses a hex uint128 from a string
     * @param value The string value
     * @param startIndex The start index (after 0x prefix)
     * @return The parsed uint128
     */
    function parseHexUint128(string memory value, uint256 startIndex) internal pure returns (uint128) {
        bytes memory valueBytes = bytes(value);
        uint128 result = 0;
        
        for (uint256 i = startIndex; i < valueBytes.length; i++) {
            result = result * 16 + uint128(hexCharToNibble(valueBytes[i]));
        }
        
        return result;
    }

    // RLP encoding functions
    function rlpEncodeUint64(uint64 value) internal pure returns (bytes memory) {
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

    function rlpEncodeUint128(uint128 value) internal pure returns (bytes memory) {
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

    function rlpEncodeAddress(Address memory addr) internal pure returns (bytes memory) {
        bytes memory addrBytes = new bytes(20);
        for (uint i = 0; i < 20; i++) {
            addrBytes[i] = addr.value[i];
        }
        return rlpEncodeBytes(addrBytes);
    }

    function rlpEncodeBytes(bytes memory value) internal pure returns (bytes memory) {
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
            bytes memory result = new bytes(value.length + lengthBytes.length + 1);
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

    function rlpEncodeBytes32(bytes32 value) internal pure returns (bytes memory) {
        bytes memory valueBytes = new bytes(32);
        for (uint i = 0; i < 32; i++) {
            valueBytes[i] = value[i];
        }
        return rlpEncodeBytes(valueBytes);
    }

    function rlpEncodeEmptyBytes() internal pure returns (bytes memory) {
        bytes memory result = new bytes(1);
        result[0] = 0x80;
        return result;
    }

    function rlpEncodeList(bytes[] memory elements) internal pure returns (bytes memory) {
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
            bytes memory result = new bytes(totalLength + lengthBytes.length + 1);
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
    function rlpEncodeAccessList(AccessListEntry[] memory accessList) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](accessList.length);
        
        for (uint i = 0; i < accessList.length; i++) {
            bytes[] memory entryElements = new bytes[](2);
            entryElements[0] = rlpEncodeAddress(accessList[i].addr);
            
            bytes[] memory storageKeyElements = new bytes[](accessList[i].storageKeys.length);
            for (uint j = 0; j < accessList[i].storageKeys.length; j++) {
                storageKeyElements[j] = rlpEncodeBytes32(accessList[i].storageKeys[j]);
            }
            entryElements[1] = rlpEncodeList(storageKeyElements);
            
            elements[i] = rlpEncodeList(entryElements);
        }
        
        return rlpEncodeList(elements);
    }

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
