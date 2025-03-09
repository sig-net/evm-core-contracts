// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TestERC721
 * @dev A simple ERC721 token for testing
 */
contract TestERC721 is ERC721, Ownable {
    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {}

    /**
     * @dev Mint a new token to a specified address
     * @param to The address to mint the token to
     * @param tokenId The token ID to mint
     */
    function mint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }
    
    /**
     * @dev Override ownerOf to ensure it's explicitly marked as public
     * @param tokenId The token ID to query
     * @return The address of the owner of the token
     */
    function ownerOf(uint256 tokenId) public view override returns (address) {
        return super.ownerOf(tokenId);
    }
    
    /**
     * @dev Override transferFrom to ensure it's explicitly marked as public
     * @param from The current owner of the token
     * @param to The address to receive the token
     * @param tokenId The token ID being transferred
     */
    function transferFrom(address from, address to, uint256 tokenId) public override {
        super.transferFrom(from, to, tokenId);
    }
} 