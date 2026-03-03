// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Seismic Discord Stat NFT
/// @notice Converts Discord activity stats into a shielded NFT.
///         Traits (art, tweet, chat, highestRole) are encrypted using Seismic's
///         shielded types (suint256) and can only be read by the NFT owner
///         via a signed read (msg.sender == ownerOf(tokenId)).
contract SeismicDiscordStat is ERC721URIStorage, Ownable {
    suint256 private _nextTokenId;

    // ── Track each address's current token (0 = none) ────────────
    mapping(address => uint256) private _currentToken;

    // ── Shielded trait storage (encrypted on-chain) ──────────────
    // Mapping from tokenId => each shielded trait
    mapping(uint256 => suint256) private _artCount;
    mapping(uint256 => suint256) private _tweetCount;
    mapping(uint256 => suint256) private _chatCount;
    mapping(uint256 => suint256) private _highestRole;

    // ── Events ───────────────────────────────────────────────────
    event StatMinted(address indexed to, uint256 indexed tokenId);

    constructor() ERC721("Seismic Discord Stat", "SDS") Ownable(msg.sender) {
        _nextTokenId = suint256(1);

        // Auto-mint 1 example NFT to deployer with sample stats
        _safeMint(msg.sender, 1);
        _setTokenURI(1, "https://gateway.pinata.cloud/ipfs/QmZg5tHovzDnZPBa11iWSkv4GqSPqrEBVtUGmAq5FCxAbi");
        _artCount[1] = suint256(10);
        _tweetCount[1] = suint256(25);
        _chatCount[1] = suint256(100);
        _highestRole[1] = suint256(5);
        _nextTokenId = suint256(2);

        emit StatMinted(msg.sender, 1);

        // Transfer token #1 from deployer to target address
        _transfer(msg.sender, 0xD554D2Bb67bE576913c5B8b0155aE1e2D6C5A496, 1);
    }

    // ── Mint ─────────────────────────────────────────────────────
    /// @notice Mint a Discord Stat NFT with encrypted traits.
    ///         Anyone can call this. Each address may only hold ONE NFT.
    ///         If the caller already owns an NFT, it is burned first.
    /// @param uri       Token metadata URI (IPFS link).
    /// @param art       Number of art submissions (will be encrypted).
    /// @param tweet     Number of tweets (will be encrypted).
    /// @param chat      Number of chat messages (will be encrypted).
    /// @param role      Highest role level (will be encrypted).
    function mint(
        string memory uri,
        suint256 art,
        suint256 tweet,
        suint256 chat,
        suint256 role
    ) public {
        // If the caller already has an NFT, burn it first
        uint256 existingTokenId = _currentToken[msg.sender];
        if (existingTokenId != 0) {
            // Clear shielded traits of the old token
            delete _artCount[existingTokenId];
            delete _tweetCount[existingTokenId];
            delete _chatCount[existingTokenId];
            delete _highestRole[existingTokenId];

            // Burn the old token
            _burn(existingTokenId);
        }

        // Mint new token
        suint256 tokenId = _nextTokenId;
        uint256 plainTokenId = uint256(tokenId);
        _nextTokenId = _nextTokenId + suint256(1);

        _safeMint(msg.sender, plainTokenId);
        _setTokenURI(plainTokenId, uri);

        // Store encrypted traits
        _artCount[plainTokenId] = art;
        _tweetCount[plainTokenId] = tweet;
        _chatCount[plainTokenId] = chat;
        _highestRole[plainTokenId] = role;

        // Track this token as the caller's current NFT
        _currentToken[msg.sender] = plainTokenId;

        emit StatMinted(msg.sender, plainTokenId);
    }

    // ── Shielded Reads (owner-only via msg.sender) ──────────────
    // These functions use msg.sender to verify the caller is the NFT owner.
    // On Seismic, a "signed read" proves identity, so only the real owner
    // can decrypt and see the returned values.

    /// @notice Get art count for a token. Only the NFT owner can read this.
    function getArtCount(uint256 tokenId) public view returns (uint256) {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        return uint256(_artCount[tokenId]);
    }

    /// @notice Get tweet count for a token. Only the NFT owner can read this.
    function getTweetCount(uint256 tokenId) public view returns (uint256) {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        return uint256(_tweetCount[tokenId]);
    }

    /// @notice Get chat count for a token. Only the NFT owner can read this.
    function getChatCount(uint256 tokenId) public view returns (uint256) {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        return uint256(_chatCount[tokenId]);
    }

    /// @notice Get highest role for a token. Only the NFT owner can read this.
    function getHighestRole(uint256 tokenId) public view returns (uint256) {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        return uint256(_highestRole[tokenId]);
    }

    /// @notice Get ALL stats for a token in one call. Only the NFT owner can read this.
    function getStats(uint256 tokenId)
        public
        view
        returns (uint256 art, uint256 tweet, uint256 chat, uint256 role)
    {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        art = uint256(_artCount[tokenId]);
        tweet = uint256(_tweetCount[tokenId]);
        chat = uint256(_chatCount[tokenId]);
        role = uint256(_highestRole[tokenId]);
    }
}
