// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./MembershipNFT.sol";

error NotCreator(address user);
error AlreadyCreator(address user);
error PostNotFound(address creator, uint256 postId);

/*
* @title Frontseat
* @notice Built for HackFS'22 
*/
contract Frontseat is Ownable {

    using Counters for Counters.Counter;

    event ProfileUpdated (
        address user,
        string newProfile
    );

    event MembershipLaunched (
        address user,
        address nftCollection,
        string contentUri,
        uint256 supply,
        uint256 price
    );

    event PostAdded (
        address creator,
        uint256 postId,
        string contentUri
    );

    event PostEdited (
        address creator,
        uint256 postId,
        string contentUri
    );

    event PostDeleted (
        address creator,
        uint256 postId
    );

    event EarningsWithdrawn (
        address withdrawalAddress,
        uint256 amount
    );

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

    mapping (address => Profile) private profileRegistry;
    mapping (address => CreatorProfile) private creatorRegistry;
    mapping (address => mapping(uint256 => Post)) private postRegistry;

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

    /////////////////////
    // Main Functions //
    /////////////////////

    /*
     * @notice Method to update profile details
     * @param contentUri Link to where new profile data is stored
     */
    function updateProfile(string calldata _contentUri) external {
        address _user = msg.sender;
        profileRegistry[_user].personalDetailUri = _contentUri;
        emit ProfileUpdated(_user, _contentUri);
    }

    /*
     * @notice Method to launch membership NFT and become a creator
     * @param name 
     * @param symbol 
     * @param nftUri 
     * @param collectionUri Link to collection details (for Opensea)
     * @param supply Max supply of membership NFT
     * @param price Sale price of each item
     * @param royalty Royalty to creator in bps (basis points)
     */
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

    /*
     * @notice Method to add a post
     * @param contentUri Link to where post data is stored
     */
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

    /*
     * @notice Method to update a post
     * @param contentUri Link to where updated post data is stored
     */
    function editPost(uint256 _postId, string calldata _contentUri) 
        external 
        isCreator(msg.sender)
        postExists(msg.sender, _postId)
    {
        postRegistry[msg.sender][_postId].contentUri = _contentUri;
        emit PostEdited(msg.sender, _postId, _contentUri);
    }

    /*
     * @notice Method to delete a post
     * @param postId Post ID of creator to be removed
     */
    function deletePost(uint256 _postId) 
        external 
        isCreator(msg.sender)
        postExists(msg.sender, _postId)
    {
        delete (postRegistry[msg.sender][_postId]);
        emit PostDeleted(msg.sender, _postId);
    }

    /*
     * @notice Method to change withdrawal account of Frontseat's earnings
     * @param newAddress New address for withdrawal
     */
    function changeWithdrawalAccount(address _newAddress) external onlyOwner {
        withdrawalAccount = _newAddress;
    }

    /*
     * @notice Method to withdraw earnings
     * @param amount Amount to be withdrawn
     */
    function withdrawEarnings(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance, "Insufficient balance");
        (bool success, ) = payable(withdrawalAccount).call{value: _amount}("");
        require(success, "Transfer failed");
        emit EarningsWithdrawn(withdrawalAccount, _amount);
    }

    //////////////////////
    // Getter Functions //
    //////////////////////

    function getProfile(address _user) 
        external 
        view 
        returns (Profile memory) {
        return profileRegistry[_user];
    }

    function getCreatorProfile(address _creator) 
        external 
        view 
        isCreator(_creator)
        returns (CreatorProfile memory) 
    {
        return creatorRegistry[_creator];
    }

    function getPost(address _creator, uint256 _postId) 
        external 
        view
        postExists(_creator, _postId) 
        returns (Post memory) 
    {
        return postRegistry[_creator][_postId];
    }

    function getBalance() external view returns (uint) {
        return address(this).balance;
    }

    receive() external payable {}
    fallback() external payable {}
}