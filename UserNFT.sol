// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/base/ERC721Base.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";

/**
 * @title UserNFT Contract
 * @notice Handles user authentication, addresses and status tracking
 */
contract UserNFT is ERC721Base, PermissionsEnumerable {
    // Role definitions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // User status enum
    enum UserStatus {
        Inactive,
        Active,
        Suspended
    }

    // User information structure
    struct UserInfo {
        string userId;          // Unique user identifier
        address referrer;       // Referrer address
        string referralUrl;     // User's referral URL
        string zone;           // User's zone (Left/Middle/Right)
        uint256 mintTime;      // When the NFT was minted
        UserStatus status;     // User's current status
        address smartWallet;   // User's smart wallet address
    }

    // Mappings
    mapping(uint256 => UserInfo) public userInfo;
    mapping(string => bool) public usedUserIds;
    mapping(address => uint256) public userTokenIds;
    mapping(string => address) public referralUrlToUser;

    // Events
    event UserRegistered(
        address indexed user,
        uint256 indexed tokenId,
        string userId,
        string referralUrl
    );
    event SmartWalletCreated(
        address indexed user,
        address indexed smartWallet,
        uint256 indexed tokenId
    );
    event UserStatusChanged(
        uint256 indexed tokenId,
        UserStatus oldStatus,
        UserStatus newStatus
    );
    event ZoneAssigned(
        uint256 indexed tokenId,
        string zone
    );

    constructor(
        string memory _name,
        string memory _symbol,
        address _royaltyRecipient,
        uint128 _royaltyBps
    ) ERC721Base(_name, _symbol, _royaltyRecipient, _royaltyBps) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(OPERATOR_ROLE, msg.sender);
    }

    /**
     * @notice Registers a new user and mints their NFT
     * @param userId Unique identifier for the user
     * @param referrer Address of the referrer
     * @param zone User's zone (Left/Middle/Right)
     */
    function registerUser(
        string memory userId,
        address referrer,
        string memory zone
    ) external {
        require(!usedUserIds[userId], "UserID already exists");
        require(userTokenIds[msg.sender] == 0, "User already registered");
        require(
            keccak256(bytes(zone)) == keccak256(bytes("Left")) ||
            keccak256(bytes(zone)) == keccak256(bytes("Middle")) ||
            keccak256(bytes(zone)) == keccak256(bytes("Right")),
            "Invalid zone"
        );

        uint256 tokenId = nextTokenIdToMint();
        _safeMint(msg.sender, tokenId);

        // Generate referral URL (implementation depends on your URL structure)
        string memory referralUrl = generateReferralUrl(userId);

        // Create and store user info
        userInfo[tokenId] = UserInfo({
            userId: userId,
            referrer: referrer,
            referralUrl: referralUrl,
            zone: zone,
            mintTime: block.timestamp,
            status: UserStatus.Active,
            smartWallet: address(0)
        });

        userTokenIds[msg.sender] = tokenId;
        usedUserIds[userId] = true;
        referralUrlToUser[referralUrl] = msg.sender;

        emit UserRegistered(msg.sender, tokenId, userId, referralUrl);
    }

    /**
     * @notice Records the user's smart wallet address
     * @param user User address
     * @param smartWallet Smart wallet address
     */
    function setSmartWallet(
        address user,
        address smartWallet
    ) external onlyRole(OPERATOR_ROLE) {
        uint256 tokenId = userTokenIds[user];
        require(tokenId != 0, "User not registered");
        require(userInfo[tokenId].smartWallet == address(0), "Smart wallet already set");

        userInfo[tokenId].smartWallet = smartWallet;
        emit SmartWalletCreated(user, smartWallet, tokenId);
    }

    /**
     * @notice Updates user status
     * @param tokenId Token ID of the user
     * @param newStatus New status to set
     */
    function updateUserStatus(
        uint256 tokenId,
        UserStatus newStatus
    ) external onlyRole(OPERATOR_ROLE) {
        require(_exists(tokenId), "Token does not exist");
        
        UserStatus oldStatus = userInfo[tokenId].status;
        userInfo[tokenId].status = newStatus;
        
        emit UserStatusChanged(tokenId, oldStatus, newStatus);
    }

    /**
     * @notice Gets user information
     * @param user User address
     */
    function getUserInfo(
        address user
    ) external view returns (
        address referrer,
        string memory userId,
        string memory zone,
        uint256 mintTime,
        bool isActive,
        uint256 tokenId
    ) {
        tokenId = userTokenIds[user];
        require(tokenId != 0, "User not registered");
        
        UserInfo storage info = userInfo[tokenId];
        return (
            info.referrer,
            info.userId,
            info.zone,
            info.mintTime,
            info.status == UserStatus.Active,
            tokenId
        );
    }

    /**
     * @notice Generates a referral URL for a user
     * @param userId User's ID
     * @return Referral URL string
     */
    function generateReferralUrl(
        string memory userId
    ) internal pure returns (string memory) {
        return string(abi.encodePacked("https://onepay.com/ref/", userId));
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721Base, PermissionsEnumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
