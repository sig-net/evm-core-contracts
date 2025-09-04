// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "../libraries/EVMTxBuilder.sol";

/**
 * @title TestEVMTxBuilder
 * @dev A minimal helper contract for testing the EVMTxBuilder library
 */
contract TestEVMTxBuilder {
    using EVMTxBuilder for *;

    /**
     * @dev Encodes ERC20 transfer input data on-chain
     * @param to Recipient address
     * @param amount Transfer amount
     * @return The ABI-encoded calldata for ERC20.transfer(address,uint256)
     */
    function encodeErc20TransferInput(
        address to,
        uint256 amount
    ) public pure returns (bytes memory) {
        return abi.encodeWithSignature("transfer(address,uint256)", to, amount);
    }

    /**
     * @dev Create an unsigned transaction
     * @param evmTx The transaction fields
     * @return The RLP encoded unsigned transaction
     */
    function createUnsignedTransaction(
        EVMTxBuilder.EVMTransaction memory evmTx
    ) public pure returns (bytes memory) {
        // Ensure access list defaults to empty when not provided
        if (evmTx.accessList.length == 0) {
            evmTx.accessList = new EVMTxBuilder.AccessListEntry[](0);
        }
        return EVMTxBuilder.serializeEvmTxUnsigned(evmTx);
    }

    /**
     * @dev Create a signed transaction
     * @param evmTx The transaction fields
     * @param signature The signature components
     * @return The RLP encoded signed transaction
     */
    function createSignedTransaction(
        EVMTxBuilder.EVMTransaction memory evmTx,
        EVMTxBuilder.Signature memory signature
    ) public pure returns (bytes memory) {
        if (evmTx.accessList.length == 0) {
            evmTx.accessList = new EVMTxBuilder.AccessListEntry[](0);
        }
        return EVMTxBuilder.serializeEvmTxWithSignature(evmTx, signature);
    }

    /**
     * @dev Serialize and hash an unsigned EIP-1559 transaction.
     * @param evmTx The transaction fields
     * @return digest Keccak256 hash of the serialized tx
     */
    function serializeAndHashEvmTx(
        EVMTxBuilder.EVMTransaction memory evmTx
    ) public pure returns (bytes32 digest) {
        if (evmTx.accessList.length == 0) {
            evmTx.accessList = new EVMTxBuilder.AccessListEntry[](0);
        }
        bytes memory serialized = EVMTxBuilder.serializeEvmTxUnsigned(evmTx);
        digest = EVMTxBuilder.hashEvmTx(serialized);
    }
}
