// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/**
 * @title CosmosTxBuilder
 * @dev Library for building Cosmos SDK transactions in Solidity
 */
library CosmosTxBuilder {
    // Structs
    struct Address {
        bytes value; // Cosmos addresses are typically bech32 strings, stored as bytes
    }

    struct Coin {
        string denom; // e.g., "uatom"
        uint128 amount;
    }

    struct Signature {
        bytes pubKey; // Public key bytes (e.g., 33 bytes for compressed secp256k1)
        bytes signature; // Signature bytes (e.g., 64 bytes for secp256k1)
    }

    struct MsgSend {
        Address fromAddress;
        Address toAddress;
        Coin[] amount;
    }

    struct CosmosTx {
        uint64 chainId; // Cosmos chain ID (e.g., "cosmoshub-4" as a numeric ID)
        uint64 accountNumber;
        uint64 sequence;
        Coin[] fee; // Fee amount
        MsgSend[] messages; // Array of messages (e.g., MsgSend)
        string memo; // Optional memo
        uint64 timeoutHeight; // Block height until which tx is valid
    }

    /**
     * @dev Builds transaction data for signing (akin to SignDoc)
     * @param tx The Cosmos transaction to build
     * @return The encoded transaction data for signing
     */
    function buildForSigning(CosmosTx memory tx) public pure returns (bytes memory) {
        bytes memory encodedFields = encodeFields(tx);
        return encodedFields; // Simplified: no Protobuf, just concatenated fields
    }

    /**
     * @dev Builds transaction data with signature (akin to TxRaw)
     * @param tx The Cosmos transaction to build
     * @param signature The signature to include
     * @return The encoded transaction data with signature
     */
    function buildWithSignature(CosmosTx memory tx, Signature memory signature) public pure returns (bytes memory) {
        bytes memory encodedFields = encodeFields(tx);
        bytes memory encodedSignature = encodeSignature(signature);
        return bytes.concat(encodedFields, encodedSignature);
    }

    /**
     * @dev Encodes transaction fields
     * @param tx The transaction to encode
     * @return The encoded transaction fields
     */
    function encodeFields(CosmosTx memory tx) internal pure returns (bytes memory) {
        bytes memory result;
        result = bytes.concat(
            encodeUint64(tx.chainId),
            encodeUint64(tx.accountNumber),
            encodeUint64(tx.sequence),
            encodeCoins(tx.fee),
            encodeMessages(tx.messages),
            encodeString(tx.memo),
            encodeUint64(tx.timeoutHeight)
        );
        return result;
    }

    /**
     * @dev Encodes transaction messages (e.g., MsgSend)
     * @param messages The array of MsgSend messages
     * @return The encoded messages
     */
    function encodeMessages(MsgSend[] memory messages) internal pure returns (bytes memory) {
        bytes memory result;
        for (uint i = 0; i < messages.length; i++) {
            result = bytes.concat(
                result,
                encodeAddress(messages[i].fromAddress),
                encodeAddress(messages[i].toAddress),
                encodeCoins(messages[i].amount)
            );
        }
        return encodeList(result);
    }

    /**
     * @dev Encodes a signature
     * @param sig The signature to encode
     * @return The encoded signature
     */
    function encodeSignature(Signature memory sig) internal pure returns (bytes memory) {
        return bytes.concat(encodeBytes(sig.pubKey), encodeBytes(sig.signature));
    }

    /**
     * @dev Parses a Cosmos address from a string (e.g., "cosmos1...") into bytes
     * @param addrStr The address string
     * @return The parsed address
     */
    function parseCosmosAddress(string memory addrStr) public pure returns (Address memory) {
        return Address(bytes(addrStr)); // Simplified: assumes input is valid
    }

    /**
     * @dev Parses a uint64 from a string (decimal or hex with 0x prefix)
     * @param value The string value
     * @return The parsed uint64
     */
    function parseUint64(string memory value) public pure returns (uint64) {
        bytes memory valueBytes = bytes(value);
        if (valueBytes.length >= 2 && valueBytes[0] == "0" && (valueBytes[1] == "x" || valueBytes[1] == "X")) {
            return parseHexUint64(value, 2);
        } else {
            return parseDecimalUint64(value);
        }
    }

    // Encoding Helpers
    function encodeUint64(uint64 value) internal pure returns (bytes memory) {
        if (value == 0) return hex"80"; // RLP-like empty
        bytes memory b = new bytes(8);
        for (uint i = 0; i < 8; i++) {
            b[7 - i] = bytes1(uint8(value >> (i * 8)));
        }
        return trimLeadingZeros(b);
    }

    function encodeAddress(Address memory addr) internal pure returns (bytes memory) {
        return encodeBytes(addr.value);
    }

    function encodeCoins(Coin[] memory coins) internal pure returns (bytes memory) {
        bytes memory result;
        for (uint i = 0; i < coins.length; i++) {
            result = bytes.concat(
                result,
                encodeString(coins[i].denom),
                encodeUint128(coins[i].amount)
            );
        }
        return encodeList(result);
    }

    function encodeString(string memory value) internal pure returns (bytes memory) {
        return encodeBytes(bytes(value));
    }

    function encodeBytes(bytes memory value) internal pure returns (bytes memory) {
        if (value.length == 0) return hex"80";
        bytes memory lengthPrefix = encodeLength(value.length, 0x80);
        return bytes.concat(lengthPrefix, value);
    }

    function encodeList(bytes memory value) internal pure returns (bytes memory) {
        if (value.length == 0) return hex"c0";
        bytes memory lengthPrefix = encodeLength(value.length, 0xc0);
        return bytes.concat(lengthPrefix, value);
    }

    function encodeUint128(uint128 value) internal pure returns (bytes memory) {
        if (value == 0) return hex"80";
        bytes memory b = new bytes(16);
        for (uint i = 0; i < 16; i++) {
            b[15 - i] = bytes1(uint8(value >> (i * 8)));
        }
        return trimLeadingZeros(b);
    }

    function encodeLength(uint length, uint offset) internal pure returns (bytes memory) {
        if (length < 56) {
            return abi.encodePacked(bytes1(uint8(offset + length)));
        } else {
            bytes memory lenBytes = uintToBytes(length);
            return bytes.concat(bytes1(uint8(offset + 55 + lenBytes.length)), lenBytes);
        }
    }

    function trimLeadingZeros(bytes memory b) internal pure returns (bytes memory) {
        uint start;
        for (start = 0; start < b.length && b[start] == 0; start++) {}
        if (start == b.length) return hex"00";
        bytes memory result = new bytes(b.length - start);
        for (uint i = 0; i < result.length; i++) {
            result[i] = b[start + i];
        }
        return result;
    }

    function uintToBytes(uint value) internal pure returns (bytes memory) {
        if (value == 0) return new bytes(0);
        uint temp = value;
        uint len = 0;
        while (temp > 0) {
            len++;
            temp >>= 8;
        }
        bytes memory result = new bytes(len);
        temp = value;
        for (uint i = 0; i < len; i++) {
            result[len - 1 - i] = bytes1(uint8(temp & 0xFF));
            temp >>= 8;
        }
        return result;
    }

    // Parsing Helpers
    function parseDecimalUint64(string memory value) internal pure returns (uint64) {
        bytes memory valueBytes = bytes(value);
        uint64 result = 0;
        for (uint i = 0; i < valueBytes.length; i++) {
            require(valueBytes[i] >= "0" && valueBytes[i] <= "9", "Invalid decimal char");
            result = result * 10 + uint64(uint8(valueBytes[i]) - uint8(bytes1("0")));
        }
        return result;
    }

    function parseHexUint64(string memory value, uint startIdx) internal pure returns (uint64) {
        bytes memory valueBytes = bytes(value);
        uint64 result = 0;
        for (uint i = startIdx; i < valueBytes.length; i++) {
            result = result * 16 + uint64(hexCharToNibble(valueBytes[i]));
        }
        return result;
    }

    function hexCharToNibble(bytes1 c) internal pure returns (uint8) {
        if (c >= "0" && c <= "9") return uint8(c) - uint8(bytes1("0"));
        if (c >= "a" && c <= "f") return uint8(c) - uint8(bytes1("a")) + 10;
        if (c >= "A" && c <= "F") return uint8(c) - uint8(bytes1("A")) + 10;
        revert("Invalid hex char");
    }
}