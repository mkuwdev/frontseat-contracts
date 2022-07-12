// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MembershipNFT is ERC721, Ownable {

    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private supply;

    string public tokenUri;
    uint256 public maxSupply;
    uint256 public price;
    uint256 public royalty;

    mapping (address => bool) private minted;
    
    // maybe add our address which has access?
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _tokenURI,
        address _creator,
        uint256 _supply,
        uint256 _price,
        uint256 _royalty
    ) ERC721 (_name, _symbol) {
        tokenUri = _tokenURI;
        transferOwnership(_creator);
        maxSupply = _supply;
        price = _price;
        royalty = _royalty;
    }

    modifier mintCompliance(address _minter) {
        require(!minted[_minter]);
        require(supply.current() + 1 <= maxSupply, "Max supply exceeded!");
        _;
    }

    function mint() public payable mintCompliance(msg.sender) {
        // make pausing??
        require(msg.value >= price, "Insufficient funds!");
        supply.increment();
        minted[msg.sender] = true;
        _safeMint(msg.sender, supply.current());
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return tokenUri;
    }
    
    
}