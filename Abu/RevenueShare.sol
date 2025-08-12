// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SocialMediaRevenue
 * @dev A smart contract that enables creators to earn revenue from content engagement
 * Users can tip creators for their posts, and creators can withdraw their earnings
 */
contract SocialMediaRevenue is ReentrancyGuard, Ownable {
    
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    struct Post {
        address creator;
        string contentHash; // IPFS hash or content identifier
        uint256 totalEarnings;
        uint256 engagementCount;
        uint256 timestamp;
        bool isActive;
    }
    
    struct Creator {
        uint256 totalEarnings;
        uint256 postCount;
        bool isRegistered;
    }
    
    // Mappings
    mapping(uint256 => Post) public posts;
    mapping(address => Creator) public creators;
    mapping(address => uint256[]) public creatorPosts; // Track posts by creator
    
    // State variables
    uint256 public nextPostId = 1;
    uint256 public platformFeePercentage = 5; // 5% platform fee
    uint256 public totalPlatformEarnings;
    
    // Events
    event PostCreated(uint256 indexed postId, address indexed creator, string contentHash);
    event ContentTipped(uint256 indexed postId, address indexed tipper, uint256 amount);
    event EarningsWithdrawn(address indexed creator, uint256 amount);
    event PlatformFeesWithdrawn(uint256 amount);
    
    /**
     * @dev Create a new post
     * @param _contentHash IPFS hash or identifier for the content
     */
    function createPost(string memory _contentHash) external {
        require(bytes(_contentHash).length > 0, "Content hash cannot be empty");
        
        // Register creator if first time
        if (!creators[msg.sender].isRegistered) {
            creators[msg.sender].isRegistered = true;
        }
        
        // Create new post
        posts[nextPostId] = Post({
            creator: msg.sender,
            contentHash: _contentHash,
            totalEarnings: 0,
            engagementCount: 0,
            timestamp: block.timestamp,
            isActive: true
        });
        
        // Update creator stats
        creators[msg.sender].postCount++;
        creatorPosts[msg.sender].push(nextPostId);
        
        emit PostCreated(nextPostId, msg.sender, _contentHash);
        nextPostId++;
    }
    
    /**
     * @dev Tip a creator for their content
     * @param _postId The ID of the post to tip
     */
    function tipContent(uint256 _postId) external payable nonReentrant {
        require(msg.value > 0, "Tip amount must be greater than 0");
        require(_postId < nextPostId && _postId > 0, "Invalid post ID");
        require(posts[_postId].isActive, "Post is not active");
        require(posts[_postId].creator != msg.sender, "Cannot tip your own content");
        
        Post storage post = posts[_postId];
        Creator storage creator = creators[post.creator];
        
        // Calculate platform fee
        uint256 platformFee = (msg.value * platformFeePercentage) / 100;
        uint256 creatorEarning = msg.value - platformFee;
        
        // Update post stats
        post.totalEarnings += creatorEarning;
        post.engagementCount++;
        
        // Update creator earnings
        creator.totalEarnings += creatorEarning;
        
        // Update platform earnings
        totalPlatformEarnings += platformFee;
        
        emit ContentTipped(_postId, msg.sender, msg.value);
    }
    
    /**
     * @dev Allow creators to withdraw their earnings
     */
    function withdrawEarnings() external nonReentrant {
        require(creators[msg.sender].isRegistered, "Creator not registered");
        require(creators[msg.sender].totalEarnings > 0, "No earnings to withdraw");
        
        uint256 amount = creators[msg.sender].totalEarnings;
        creators[msg.sender].totalEarnings = 0;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");
        
        emit EarningsWithdrawn(msg.sender, amount);
    }
    
    /**
     * @dev Get post details by ID
     * @param _postId The ID of the post
     * @return creator Address of the post creator
     * @return contentHash IPFS hash of the content
     * @return totalEarnings Total earnings from tips
     * @return engagementCount Number of tips received
     * @return timestamp When the post was created
     * @return isActive Whether the post is still active
     */
    function getPost(uint256 _postId) external view returns (
        address creator,
        string memory contentHash,
        uint256 totalEarnings,
        uint256 engagementCount,
        uint256 timestamp,
        bool isActive
    ) {
        require(_postId < nextPostId && _postId > 0, "Invalid post ID");
        Post memory post = posts[_postId];
        return (
            post.creator,
            post.contentHash,
            post.totalEarnings,
            post.engagementCount,
            post.timestamp,
            post.isActive
        );
    }
    
    /**
     * @dev Get creator's posts
     * @param _creator Address of the creator
     * @return postIds Array of post IDs belonging to the creator
     */
    function getCreatorPosts(address _creator) external view returns (uint256[] memory) {
        return creatorPosts[_creator];
    }
    
    /**
     * @dev Owner function to withdraw platform fees
     */
    function withdrawPlatformFees() external onlyOwner nonReentrant {
        require(totalPlatformEarnings > 0, "No platform fees to withdraw");
        
        uint256 amount = totalPlatformEarnings;
        totalPlatformEarnings = 0;
        
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Platform fee withdrawal failed");
        
        emit PlatformFeesWithdrawn(amount);
    }
}
