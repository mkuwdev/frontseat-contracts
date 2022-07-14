// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./MembershipNFT.sol";

// Errors
error NotCreator(address user);
error AlreadyCreator(address user);
error PostNotFound(address creator, uint256 postId);

contract Frontseat is Ownable {

    using Counters for Counters.Counter;

    // Events
    event ProfileUpdated (
        address indexed user,
        string indexed newProfile
    );

    event MembershipLaunched (
        address indexed user,
        address indexed nftCollection,
        string indexed contentUri,
        uint256 supply,
        uint256 price
    );

    event PostAdded (
        address indexed creator,
        uint256 indexed postId,
        string indexed contentUri
    );

    event PostEdited (
        address indexed creator,
        uint256 indexed postId,
        string indexed contentUri
    );

    event PostDeleted (
        address indexed creator,
        uint256 indexed postId
    );

    event EarningsWithdrawn (
        address indexed withdrawalAddress,
        uint256 indexed amount
    );

    // Structs
    struct Profile {
        string personalDetailUri;
        bool isCreator;
    }

    struct CreatorProfile {
        address membershipNft;
        Counters.Counter postCount;
    }

    struct Post {
        uint256 id;
        string contentUri;
        uint256 uploadTime;
    }

    address public withdrawalAccount;

    // Mappings
    mapping (address => Profile) private profileRegistry;
    mapping (address => CreatorProfile) private creatorRegistry;
    mapping (address => mapping(uint256 => Post)) private postRegistry;

    // Modifiers
    modifier isCreator(address _user) {
        CreatorProfile memory profile = creatorRegistry[_user];
        if (profile.membershipNft == address(0)) {
            revert NotCreator(_user);
        }
        _;
    }

    modifier notCreator(address _user) {
        CreatorProfile memory profile = creatorRegistry[_user];
        if (profile.membershipNft != address(0)) {
            revert AlreadyCreator(_user);
        }
        _;
    }

    modifier postExists(address _creator, uint256 _postId) {
        Post memory post = postRegistry[_creator][_postId];
        if (post.id <= 0) {
            revert PostNotFound(_creator, _postId);
        }
        _;
    }

    constructor() {
        withdrawalAccount = msg.sender;
    } 

    // Functions
    function updateProfile(string calldata _contentUri) external {
        address _user = msg.sender;
        profileRegistry[_user].personalDetailUri = _contentUri;
        emit ProfileUpdated(_user, _contentUri);
    }

    function launchMembershipNft(
        string calldata _name,
        string calldata _symbol,
        string calldata _nftUri,
        string calldata _collectionUri,
        uint256 _supply,
        uint256 _price,
        uint96 _royalty
    )
        external
        notCreator(msg.sender)
    {
        address _user = msg.sender;
        MembershipNFT newCollection = new MembershipNFT(
            _name,
            _symbol,
            _nftUri,
            _user,
            address(this),
            _supply,
            _price
        );
        newCollection.initializeCollectionRoyalty(_collectionUri, _user, _royalty);
        profileRegistry[_user].isCreator = true;
        creatorRegistry[_user].membershipNft = address(newCollection);
        emit MembershipLaunched(_user, address(newCollection), _nftUri, _supply, _price);
    }

    function addPost(string calldata _contentUri) 
        external 
        isCreator(msg.sender) 
    {
        address _creator = msg.sender;
        creatorRegistry[_creator].postCount.increment();
        uint256 _postId = creatorRegistry[_creator].postCount.current();
        postRegistry[_creator][_postId] = Post({
            id: _postId,
            contentUri: _contentUri,
            uploadTime: block.timestamp
        });
        emit PostAdded(_creator, _postId, _contentUri);
    }

    function editPost(uint256 _postId, string calldata _contentUri) 
        external 
        isCreator(msg.sender)
        postExists(msg.sender, _postId)
    {
        postRegistry[msg.sender][_postId].contentUri = _contentUri;
        emit PostEdited(msg.sender, _postId, _contentUri);
    }

    function deletePost(uint256 _postId) 
        external 
        isCreator(msg.sender)
        postExists(msg.sender, _postId)
    {
        delete (postRegistry[msg.sender][_postId]);
        emit PostDeleted(msg.sender, _postId);
    }

    function changeWithdrawalAccount(address _newAddress) external onlyOwner {
        withdrawalAccount = _newAddress;
    }

    function withdrawEarnings(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        (bool success, ) = payable(withdrawalAccount).call{value: amount}("");
        require(success, "Transfer failed");
        emit EarningsWithdrawn(withdrawalAccount, amount);
    }

    function getProfile(address _user) external view returns (string memory) {
        return profileRegistry[_user].personalDetailUri;
    }

    function getMembershipNft(address _creator) 
        external 
        view 
        isCreator(msg.sender) 
        returns (address) 
    {
        return creatorRegistry[_creator].membershipNft;
    }

    function getPost(address _creator, uint256 _postId) 
        external 
        view
        postExists(_creator, _postId) 
        returns (string memory) 
    {
        return postRegistry[_creator][_postId].contentUri;
    }

    function getBalance() external view returns (uint) {
        return address(this).balance;
    }

    receive() external payable {}
    fallback() external payable {}
}