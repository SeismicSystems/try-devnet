pragma solidity ^0.8.20;

contract HashCheck {
    function getHash() public pure returns (bytes4) {
        return bytes4(keccak256("ERC721InvalidReceiver(address)"));
    }
}
