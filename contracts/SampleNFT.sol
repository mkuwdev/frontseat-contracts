// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract SampleNFT {
    string uri;
    uint256 supply;
    uint256 price;

    constructor(string memory _uri, uint256 _supply, uint256 _price) {
        uri = _uri;
        supply = _supply;
        price = _price;
    }
}