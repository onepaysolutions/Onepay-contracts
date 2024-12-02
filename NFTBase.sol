// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/base/ERC721Base.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IOPEToken {
    function mint(address to, uint256 amount) external;
}

/**
 * @title NFTBase
 * @notice Base contract for Angel and Community NFTs
 */
abstract contract NFTBase is ERC721Base, PermissionsEnumerable, ReentrancyGuard {
    // Core state variables
    IERC20 public usdcToken;
    IOPEToken public opeToken;

    // Constants
    uint256 public immutable CLAIM_PRICE;
    uint256 public immutable MINING_REWARD;
    uint256 public immutable REFERRAL_REWARD;
    uint256 public immutable MAX_SUPPLY;

    // Tracking
    uint256 public totalMinted;
    mapping(uint256 => bool) public claimed;
    mapping(uint256 => address) public referrers;
    mapping(uint256 => bool) public referralRewardClaimed;

    // Events
    event NFTMinted(
        address indexed owner,
        uint256 indexed tokenId,
        address indexed referrer
    );
    event RewardClaimed(uint256 indexed tokenId, uint256 amount);
    event ReferralRewardClaimed(
        uint256 indexed tokenId,
        address indexed referrer,
        uint256 amount
    );

    constructor(
        string memory _name,
        string memory _symbol,
        address _royaltyRecipient,
        uint128 _royaltyBps,
        address _usdcToken,
        address _opeToken,
        uint256 _claimPrice,
        uint256 _miningReward,
        uint256 _referralReward,
        uint256 _maxSupply
    ) ERC721Base(_name, _symbol, _royaltyRecipient, _royaltyBps) {
        usdcToken = IERC20(_usdcToken);
        opeToken = IOPEToken(_opeToken);
        CLAIM_PRICE = _claimPrice;
        MINING_REWARD = _miningReward;
        REFERRAL_REWARD = _referralReward;
        MAX_SUPPLY = _maxSupply;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Mints a new NFT
     * @param referrer Address of the referrer (optional)
     */
    function mint(address referrer) external nonReentrant {
        require(totalMinted < MAX_SUPPLY, "Max supply reached");
        require(
            usdcToken.transferFrom(msg.sender, address(this), CLAIM_PRICE),
            "USDC transfer failed"
        );

        uint256 tokenId = nextTokenIdToMint();
        totalMinted++;
        
        _safeMint(msg.sender, tokenId);
        claimed[tokenId] = true;

        if (referrer != address(0)) {
            referrers[tokenId] = referrer;
        }

        opeToken.mint(msg.sender, MINING_REWARD);

        if (referrer != address(0) && balanceOf(referrer) > 0) {
            opeToken.mint(referrer, REFERRAL_REWARD);
            referralRewardClaimed[tokenId] = true;
            emit ReferralRewardClaimed(tokenId, referrer, REFERRAL_REWARD);
        }

        emit NFTMinted(msg.sender, tokenId, referrer);
        emit RewardClaimed(tokenId, MINING_REWARD);
    }

    /**
     * @notice Claims referral reward
     * @param tokenId Token ID to claim reward for
     */
    function claimReferralReward(uint256 tokenId) external nonReentrant {
        require(!referralRewardClaimed[tokenId], "Already claimed");
        address referrer = referrers[tokenId];
        require(referrer == msg.sender, "Not referrer");
        require(balanceOf(referrer) > 0, "Must own NFT");

        referralRewardClaimed[tokenId] = true;
        opeToken.mint(referrer, REFERRAL_REWARD);

        emit ReferralRewardClaimed(tokenId, referrer, REFERRAL_REWARD);
    }

    /**
     * @notice Gets token information
     * @param tokenId Token ID to query
     */
    function getTokenInfo(
        uint256 tokenId
    ) external view returns (
        bool isClaimed,
        address referrer,
        bool isReferralRewardClaimed
    ) {
        require(_exists(tokenId), "Token does not exist");
        return (
            claimed[tokenId],
            referrers[tokenId],
            referralRewardClaimed[tokenId]
        );
    }

    /**
     * @notice Emergency withdrawal of tokens
     * @param token Token address to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            IERC20(token).transfer(msg.sender, amount),
            "Transfer failed"
        );
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721Base, PermissionsEnumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
} 