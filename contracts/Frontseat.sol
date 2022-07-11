// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// PLACE ERRORS HERE
error NotCreator(address user);
error PostNotFound(address creator, uint256 postId);
error NoReceivable();

contract Frontseat is ReentrancyGuard {

    using Counters for Counters.Counter;

    // EVENTS
    event ProfileUpdated (
        address indexed user,
        string indexed newProfile
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
        address indexed creator,
        address indexed withdrawalAddress,
        uint256 indexed amount
    );

    // STRUCTS
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

    // Mappings
    mapping (address => Profile) profileRegistry;
    mapping (address => CreatorProfile) creatorRegistry;
    mapping (address => uint256) earnings;
    mapping (address => address) withdrawalAccount;
    mapping (address => mapping(uint256 => Post)) postRegistry;

    // Modifiers
    modifier isCreator(address _user) {
        CreatorProfile memory profile = creatorRegistry[_user];
        if (profile.membershipNft == address(0)) {
            revert NotCreator(_user);
        }
        _;
    }

    modifier postExists(address _creator, uint256 _postId) {
        Post memory post = postRegistry[_creator][_postId];
        if (post.id > 0) {
            revert PostNotFound(_creator, _postId);
        }
        _;
    }

    // Functions
    function updateProfile(string calldata _contentUri) external {
        address _user = msg.sender;
        profileRegistry[_user].personalDetailUri = _contentUri;
        emit ProfileUpdated(_user, _contentUri);
    }

    // TODO: Launch membership nft collection and change status to creator
    // ///////////////////////////////TO DO///////////////////////////////

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

    function withdrawEarnings() external nonReentrant {
        address _user = msg.sender;
        uint256 _receivable = earnings[msg.sender];
        if (_receivable <= 0) {
            revert NoReceivable();
        }
        earnings[_user] = 0;
        if (withdrawalAccount[_user] == address(0)) {
            withdrawalAccount[_user] = _user;
        }
        (bool success, ) = payable(withdrawalAccount[_user]).call{value: _receivable}("");
        require(success, "Transfer failed");
        emit EarningsWithdrawn(_user, withdrawalAccount[_user], _receivable);
    }

    // TODO: GETTER FUNCTIONS
    // ///////////////////////////////TO DO///////////////////////////////
}