// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ChainSignatures interface
 * @dev Minimal interface to interact with the ChainSignatures contract using its canonical types.
 */
interface IChainSignatures {
    struct SignRequest {
        bytes32 payload;
        string path;
        uint32 keyVersion;
        string algo;
        string dest;
        string params;
    }

    struct AffinePoint {
        uint256 x;
        uint256 y;
    }

    struct Signature {
        AffinePoint bigR;
        uint256 s;
        uint8 recoveryId;
    }

    struct Response {
        bytes32 requestId;
        Signature signature;
    }

    struct ErrorResponse {
        bytes32 requestId;
        string errorMessage;
    }

    function sign(SignRequest memory _request) external payable;
}
