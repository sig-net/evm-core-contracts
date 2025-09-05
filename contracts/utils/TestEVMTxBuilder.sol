// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "../libraries/EVMTxBuilder.sol";
import {IChainSignatures} from "../interfaces/IChainSignatures.sol";

/**
 * @title TestEVMTxBuilder
 * @dev A minimal helper contract for testing the EVMTxBuilder library
 */
contract TestEVMTxBuilder {
    using EVMTxBuilder for *;

    IChainSignatures public immutable signer;

    constructor(address _signer) {
        signer = IChainSignatures(_signer);
    }

    /**
     * @dev Create an unsigned transaction
     * @param evmTx The transaction fields
     * @return The RLP encoded unsigned transaction
     */
    function buildUnsignedEip1559Tx(
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
    function buildSignedEip1559Tx(
        EVMTxBuilder.EVMTransaction memory evmTx,
        EVMTxBuilder.Signature memory signature
    ) public pure returns (bytes memory) {
        if (evmTx.accessList.length == 0) {
            evmTx.accessList = new EVMTxBuilder.AccessListEntry[](0);
        }
        return EVMTxBuilder.serializeEvmTxSigned(evmTx, signature);
    }

    /**
     * @dev Serialize and hash an unsigned EIP-1559 transaction.
     * @param evmTx The transaction fields
     * @return digest Keccak256 hash of the serialized tx
     */
    function computeUnsignedEip1559TxHash(
        EVMTxBuilder.EVMTransaction memory evmTx
    ) public pure returns (bytes32 digest) {
        if (evmTx.accessList.length == 0) {
            evmTx.accessList = new EVMTxBuilder.AccessListEntry[](0);
        }
        bytes memory serialized = EVMTxBuilder.serializeEvmTxUnsigned(evmTx);
        digest = EVMTxBuilder.hashEvmTx(serialized);
    }

    /**
     * @dev Build an ERC20 transfer transaction, compute its digest and request a signature from a signer contract.
     * @param token Address of the ERC20 token contract
     * @param recipient Recipient address for the token transfer
     * @param amount Amount of tokens to transfer
     * @param chainId EVM chain id
     * @param nonce Sender nonce
     * @param gasLimit Gas limit for the transaction
     * @param maxFeePerGas Max fee per gas (EIP-1559)
     * @param maxPriorityFeePerGas Priority fee per gas (EIP-1559)
     * @param keyVersion Key version to use in the signer
     * @param path Derivation path
     * @param algo Signing algorithm identifier
     * @param dest Response destination descriptor
     * @param params Additional parameters
     */
    function requestSignatureForErc20Transfer(
        address token,
        address recipient,
        uint256 amount,
        uint256 chainId,
        uint256 nonce,
        uint256 gasLimit,
        uint256 maxFeePerGas,
        uint256 maxPriorityFeePerGas,
        uint32 keyVersion,
        string memory path,
        string memory algo,
        string memory dest,
        string memory params
    ) external payable {
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", recipient, amount);

        EVMTxBuilder.EVMTransaction memory txFields = EVMTxBuilder.EVMTransaction({
            chainId: chainId,
            nonce: nonce,
            to: token,
            hasTo: true,
            value: 0,
            input: data,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
            accessList: new EVMTxBuilder.AccessListEntry[](0)
        });

        bytes memory serialized = EVMTxBuilder.serializeEvmTxUnsigned(txFields);
        bytes32 digest = EVMTxBuilder.hashEvmTx(serialized);

        signer.sign{value: msg.value}(
            IChainSignatures.SignRequest({
                payload: digest,
                path: path,
                keyVersion: keyVersion,
                algo: algo,
                dest: dest,
                params: params
            })
        );
    }
}
