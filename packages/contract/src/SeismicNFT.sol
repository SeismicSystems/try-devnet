// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// This is a standard ERC721 token deployed on Seismic.
// Seismic operates as an EVM-compatible chain where standard OpenZeppelin contracts work.
contract SeismicNFT is ERC721, Ownable {
    suint256 private _nextTokenId;

    constructor() ERC721("Seismic NFT", "SNFT") Ownable(msg.sender) {
        _nextTokenId = suint256(1); // Mulai dari 1 dan harus dicasting ke suint256
    }

    function mint(address to) public onlyOwner {
        suint256 tokenId = _nextTokenId;
        _nextTokenId = _nextTokenId + suint256(1); // Increment manual suint256
        _safeMint(to, uint256(tokenId)); // OpenZeppelin ERC721 memerlukan uint256 standar, kita decrypt kembali saat assign ke parameter internal
    }
}
