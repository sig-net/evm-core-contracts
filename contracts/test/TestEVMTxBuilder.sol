// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "../EVMTxBuilder/EVMTxBuilder.sol";

/**
 * @title TestEVMTxBuilder
 * @dev Helper contract for testing the EVMTxBuilder library functions
 */
contract TestEVMTxBuilder {
    using EVMTxBuilder for *;

    /**
     * @dev Parameter struct to avoid stack too deep errors
     */
    struct TxParams {
        string chainId;
        string nonce;
        string to;
        bool hasTo;
        string value;
        bytes input;
        string gasLimit;
        string maxFeePerGas;
        string maxPriorityFeePerGas;
    }

    /**
     * @dev Create a simple transaction for testing
     * @param params The transaction parameters
     * @return The RLP encoded transaction data (without signature)
     */
    function createTransaction(TxParams memory params) public pure returns (bytes memory) {
        EVMTxBuilder.EVMTransaction memory tx;
        
        tx.chainId = EVMTxBuilder.parseUint64(params.chainId);
        tx.nonce = EVMTxBuilder.parseUint64(params.nonce);
        if (params.hasTo) {
            tx.to = EVMTxBuilder.parseEthAddress(params.to);
        }
        tx.hasTo = params.hasTo;
        tx.value = EVMTxBuilder.parseUint128(params.value);
        tx.input = params.input;
        tx.gasLimit = EVMTxBuilder.parseUint128(params.gasLimit);
        tx.maxFeePerGas = EVMTxBuilder.parseUint128(params.maxFeePerGas);
        tx.maxPriorityFeePerGas = EVMTxBuilder.parseUint128(params.maxPriorityFeePerGas);
        
        // Empty access list
        tx.accessList = new EVMTxBuilder.AccessListEntry[](0);
        
        return EVMTxBuilder.buildForSigning(tx);
    }

    /**
     * @dev Compatibility function to keep existing test code working
     */
    function createTransaction(
        string memory chainId,
        string memory nonce,
        string memory to,
        bool hasTo,
        string memory value,
        bytes memory input,
        string memory gasLimit,
        string memory maxFeePerGas,
        string memory maxPriorityFeePerGas
    ) public pure returns (bytes memory) {
        TxParams memory params = TxParams({
            chainId: chainId,
            nonce: nonce,
            to: to,
            hasTo: hasTo,
            value: value,
            input: input,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas
        });
        
        return createTransaction(params);
    }

    /**
     * @dev Access list params struct
     */
    struct AccessListParams {
        string[] accessListAddrs;
        bytes32[][] accessListStorageKeys;
    }

    /**
     * @dev Create a transaction with custom access list
     */
    function createTransactionWithAccessList(
        TxParams memory txParams,
        AccessListParams memory accessListParams
    ) public pure returns (bytes memory) {
        EVMTxBuilder.EVMTransaction memory tx;
        
        // Set basic transaction parameters
        tx.chainId = EVMTxBuilder.parseUint64(txParams.chainId);
        tx.nonce = EVMTxBuilder.parseUint64(txParams.nonce);
        if (txParams.hasTo) {
            tx.to = EVMTxBuilder.parseEthAddress(txParams.to);
        }
        tx.hasTo = txParams.hasTo;
        tx.value = EVMTxBuilder.parseUint128(txParams.value);
        tx.input = txParams.input;
        tx.gasLimit = EVMTxBuilder.parseUint128(txParams.gasLimit);
        tx.maxFeePerGas = EVMTxBuilder.parseUint128(txParams.maxFeePerGas);
        tx.maxPriorityFeePerGas = EVMTxBuilder.parseUint128(txParams.maxPriorityFeePerGas);
        
        // Build access list
        require(accessListParams.accessListAddrs.length == accessListParams.accessListStorageKeys.length, 
                "Access list arrays must have same length");
        
        tx.accessList = new EVMTxBuilder.AccessListEntry[](accessListParams.accessListAddrs.length);
        
        for (uint i = 0; i < accessListParams.accessListAddrs.length; i++) {
            tx.accessList[i].addr = EVMTxBuilder.parseEthAddress(accessListParams.accessListAddrs[i]);
            tx.accessList[i].storageKeys = accessListParams.accessListStorageKeys[i];
        }
        
        return EVMTxBuilder.buildForSigning(tx);
    }

    /**
     * @dev Compatibility function for createTransactionWithAccessList
     */
    function createTransactionWithAccessList(
        string memory chainId,
        string memory nonce,
        string memory to,
        bool hasTo,
        string memory value,
        bytes memory input,
        string memory gasLimit,
        string memory maxFeePerGas,
        string memory maxPriorityFeePerGas,
        string[] memory accessListAddrs,
        bytes32[][] memory accessListStorageKeys
    ) public pure returns (bytes memory) {
        TxParams memory txParams = TxParams({
            chainId: chainId,
            nonce: nonce,
            to: to,
            hasTo: hasTo,
            value: value,
            input: input,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas
        });
        
        AccessListParams memory accessListParams = AccessListParams({
            accessListAddrs: accessListAddrs,
            accessListStorageKeys: accessListStorageKeys
        });
        
        return createTransactionWithAccessList(txParams, accessListParams);
    }

    /**
     * @dev Helper to create ERC20 transfer transaction
     */
    function createERC20TransferTx(
        string memory chainId,
        string memory nonce,
        string memory tokenContract,
        string memory to,
        string memory amount,
        string memory gasLimit,
        string memory maxFeePerGas,
        string memory maxPriorityFeePerGas
    ) public pure returns (bytes memory) {
        // Create the ERC20 transfer function call
        // Function selector for transfer(address,uint256): 0xa9059cbb
        bytes memory transferCalldata = abi.encodeWithSelector(
            bytes4(0xa9059cbb),
            EVMTxBuilder.parseEthAddress(to).value,
            EVMTxBuilder.parseUint128(amount)
        );
        
        return createTransaction(
            chainId,
            nonce,
            tokenContract,
            true,
            "0", // No ETH value
            transferCalldata,
            gasLimit,
            maxFeePerGas,
            maxPriorityFeePerGas
        );
    }

    /**
     * @dev Helper to create NFT transfer transaction (ERC-721)
     */
    function createNFTTransferTx(
        string memory chainId,
        string memory nonce,
        string memory nftContract,
        string memory from,
        string memory to,
        string memory tokenId,
        string memory gasLimit,
        string memory maxFeePerGas,
        string memory maxPriorityFeePerGas
    ) public pure returns (bytes memory) {
        // Function selector for transferFrom(address,address,uint256): 0x23b872dd
        bytes memory transferCalldata = abi.encodeWithSelector(
            bytes4(0x23b872dd),
            EVMTxBuilder.parseEthAddress(from).value,
            EVMTxBuilder.parseEthAddress(to).value,
            EVMTxBuilder.parseUint128(tokenId)
        );
        
        return createTransaction(
            chainId,
            nonce,
            nftContract,
            true,
            "0", // No ETH value
            transferCalldata,
            gasLimit,
            maxFeePerGas,
            maxPriorityFeePerGas
        );
    }

    /**
     * @dev Test the parseEthAddress function
     * @param addrStr The address string to parse
     * @return The parsed address bytes
     */
    function testParseEthAddress(string memory addrStr) public pure returns (bytes20) {
        EVMTxBuilder.Address memory addr = EVMTxBuilder.parseEthAddress(addrStr);
        return addr.value;
    }

    /**
     * @dev Test the parseUint64 function
     * @param value The string value to parse
     * @return The parsed uint64
     */
    function testParseUint64(string memory value) public pure returns (uint64) {
        return EVMTxBuilder.parseUint64(value);
    }

    /**
     * @dev Test the parseUint128 function
     * @param value The string value to parse
     * @return The parsed uint128
     */
    function testParseUint128(string memory value) public pure returns (uint128) {
        return EVMTxBuilder.parseUint128(value);
    }

    /**
     * @dev Add signature to a transaction for testing
     * @param chainId The chain ID of the transaction
     * @param nonce The nonce of the transaction
     * @param to The destination address (can be empty for contract creation)
     * @param hasTo Whether the transaction has a destination address
     * @param value The amount of ETH to send
     * @param input The transaction input data
     * @param gasLimit The gas limit for the transaction
     * @param maxFeePerGas The maximum fee per gas
     * @param maxPriorityFeePerGas The maximum priority fee per gas
     * @param v The recovery id of the signature
     * @param r The r value of the signature
     * @param s The s value of the signature
     * @return The RLP encoded transaction data (with signature)
     */
    function createSignedTransaction(
        string memory chainId,
        string memory nonce,
        string memory to,
        bool hasTo,
        string memory value,
        bytes memory input,
        string memory gasLimit,
        string memory maxFeePerGas,
        string memory maxPriorityFeePerGas,
        string memory v,
        bytes32 r,
        bytes32 s
    ) public pure returns (bytes memory) {
        EVMTxBuilder.EVMTransaction memory tx;
        
        tx.chainId = EVMTxBuilder.parseUint64(chainId);
        tx.nonce = EVMTxBuilder.parseUint64(nonce);
        if (hasTo) {
            tx.to = EVMTxBuilder.parseEthAddress(to);
        }
        tx.hasTo = hasTo;
        tx.value = EVMTxBuilder.parseUint128(value);
        tx.input = input;
        tx.gasLimit = EVMTxBuilder.parseUint128(gasLimit);
        tx.maxFeePerGas = EVMTxBuilder.parseUint128(maxFeePerGas);
        tx.maxPriorityFeePerGas = EVMTxBuilder.parseUint128(maxPriorityFeePerGas);
        
        // Empty access list
        tx.accessList = new EVMTxBuilder.AccessListEntry[](0);
        
        // Create signature
        EVMTxBuilder.Signature memory signature;
        signature.v = EVMTxBuilder.parseUint64(v);
        signature.r = r;
        signature.s = s;
        
        return EVMTxBuilder.buildWithSignature(tx, signature);
    }

    /**
     * @dev Get transaction hash for signing
     * @param txBytes The RLP encoded transaction data
     * @return The keccak256 hash of the transaction
     */
    function getHashToSign(bytes memory txBytes) public pure returns (bytes32) {
        return keccak256(txBytes);
    }
} 