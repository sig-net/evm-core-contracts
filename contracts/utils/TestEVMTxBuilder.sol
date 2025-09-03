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
     * @dev A structured representation of a transaction
     */
    struct TransactionParams {
        uint64 chainId;
        uint64 nonce;
        address to;
        bool hasTo;
        uint128 value;
        bytes input;
        uint128 gasLimit;
        uint128 maxFeePerGas;
        uint128 maxPriorityFeePerGas;
    }

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
     * @dev A structured representation of a signature
     */
    struct Signature {
        uint64 v;
        bytes32 r;
        bytes32 s;
    }

    /**
     * @dev Create an unsigned transaction
     * @param txParams The transaction parameters
     * @return The RLP encoded unsigned transaction
     */
    function createUnsignedTransaction(
        TransactionParams memory txParams
    ) public pure returns (bytes memory) {
        EVMTxBuilder.EVMTransaction memory tx = _buildEvmTransaction(txParams);
        tx.accessList = new EVMTxBuilder.AccessListEntry[](0);

        return EVMTxBuilder.buildForSigning(tx);
    }

    /**
     * @dev Create a signed transaction
     * @param txParams The transaction parameters
     * @param signature The signature components
     * @return The RLP encoded signed transaction
     */
    function createSignedTransaction(
        TransactionParams memory txParams,
        Signature memory signature
    ) public pure returns (bytes memory) {
        EVMTxBuilder.EVMTransaction memory tx = _buildEvmTransaction(txParams);
        tx.accessList = new EVMTxBuilder.AccessListEntry[](0);

        EVMTxBuilder.Signature memory evmSignature = EVMTxBuilder.Signature({
            v: signature.v,
            r: signature.r,
            s: signature.s
        });

        return EVMTxBuilder.buildWithSignature(tx, evmSignature);
    }

    /**
     * @dev Builds an EVM transaction from transaction parameters
     */
    function _buildEvmTransaction(
        TransactionParams memory txParams
    ) internal pure returns (EVMTxBuilder.EVMTransaction memory) {
        EVMTxBuilder.EVMTransaction memory tx;

        tx.chainId = txParams.chainId;
        tx.nonce = txParams.nonce;
        tx.to = txParams.to;
        tx.hasTo = txParams.hasTo;
        tx.value = txParams.value;
        tx.input = txParams.input;
        tx.gasLimit = txParams.gasLimit;
        tx.maxFeePerGas = txParams.maxFeePerGas;
        tx.maxPriorityFeePerGas = txParams.maxPriorityFeePerGas;

        return tx;
    }
}
