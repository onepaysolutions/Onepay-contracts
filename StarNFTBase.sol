// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IOPSPresale {
    function getCurrentPrice() external view returns (uint256);
}

contract StarNFTBase is ERC721Enumerable, Ownable, ReentrancyGuard {
    // Star NFT Status
    enum StarStatus {
        Pending,    // < USD CONTRACT VALUE
        Releasing,  // > USD CONTRACT VALUE  
        Active,     // Airdrop List
        Inactive,   // USD CONTRACT VALUE = 0
        Completed   // Burned Star NFT
    }

    // Star NFT Info
    struct TokenInfo {
        StarStatus status;
        uint256 activationTimestamp;
        uint256 usdValueCap;
        uint256 totalOPSBought;
        uint256 totalOPSRewarded;
        uint256 totalOPSAirdropped;
    }

    // Constants for each Star level
    struct StarConfig {
        uint256 contractValue;  // USD contract value
        uint256 presaleShare;   // Presale funds share
        uint256 referralShare;  // Referral funds share
        uint256 buybackShare;   // Buyback funds share
    }

    // Star level configurations
    mapping(uint256 => StarConfig) public starConfigs;

    // Token info mapping
    mapping(uint256 => TokenInfo) public tokenInfo;

    // Core contracts
    IERC20 public usdcToken;
    IERC20 public usdtToken;
    IOPSPresale public presaleContract;

    // Events
    event TokenMinted(address indexed to, uint256 indexed tokenId, uint256 starLevel);
    event StatusUpdated(uint256 indexed tokenId, StarStatus oldStatus, StarStatus newStatus);
    event ValueRecorded(
        uint256 indexed tokenId,
        uint256 totalOPSBought,
        uint256 totalOPSRewarded,
        uint256 totalOPSAirdropped
    );

    constructor(
        string memory name,
        string memory symbol,
        address _usdcToken,
        address _usdtToken,
        address _presaleContract
    ) ERC721(name, symbol) {
        usdcToken = IERC20(_usdcToken);
        usdtToken = IERC20(_usdtToken);
        presaleContract = IOPSPresale(_presaleContract);

        // Initialize Star configurations
        starConfigs[1] = StarConfig({
            contractValue: 1250e6,  // 1,250 USD
            presaleShare: 5000,     // 50%
            referralShare: 4500,    // 45%
            buybackShare: 500       // 5%
        });

        starConfigs[2] = StarConfig({
            contractValue: 3300e6,  // 3,300 USD
            presaleShare: 5500,     // 55%
            referralShare: 4000,    // 40%
            buybackShare: 500       // 5%
        });

        starConfigs[3] = StarConfig({
            contractValue: 12600e6, // 12,600 USD
            presaleShare: 6000,     // 60%
            referralShare: 3500,    // 35%
            buybackShare: 500       // 5%
        });

        starConfigs[4] = StarConfig({
            contractValue: 35600e6, // 35,600 USD
            presaleShare: 6500,     // 65%
            referralShare: 3000,    // 30%
            buybackShare: 500       // 5%
        });
    }

    /**
     * @notice Get Star level from token ID
     * @param tokenId Token ID
     */
    function getStarLevel(uint256 tokenId) public pure returns (uint256) {
        return tokenId >> 248;
    }

    /**
     * @notice Get token information
     * @param tokenId Token ID
     */
    function getTokenInfo(uint256 tokenId) external view returns (
        StarStatus status,
        uint256 activationTimestamp,
        uint256 usdValueCap,
        uint256 totalOPSBought,
        uint256 totalOPSRewarded,
        uint256 totalOPSAirdropped
    ) {
        TokenInfo storage info = tokenInfo[tokenId];
        return (
            info.status,
            info.activationTimestamp,
            info.usdValueCap,
            info.totalOPSBought,
            info.totalOPSRewarded,
            info.totalOPSAirdropped
        );
    }

    /**
     * @notice Update token status
     * @param tokenId Token ID
     * @param newStatus New status
     */
    function updateStatus(
        uint256 tokenId,
        StarStatus newStatus
    ) external onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        StarStatus oldStatus = tokenInfo[tokenId].status;
        tokenInfo[tokenId].status = newStatus;
        emit StatusUpdated(tokenId, oldStatus, newStatus);
    }

    /**
     * @notice Record token values
     * @param tokenId Token ID
     * @param bought OPS bought amount
     * @param rewarded OPS rewarded amount
     * @param airdropped OPS airdropped amount
     */
    function recordValues(
        uint256 tokenId,
        uint256 bought,
        uint256 rewarded,
        uint256 airdropped
    ) external onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        TokenInfo storage info = tokenInfo[tokenId];
        
        info.totalOPSBought = bought;
        info.totalOPSRewarded = rewarded;
        info.totalOPSAirdropped = airdropped;

        emit ValueRecorded(tokenId, bought, rewarded, airdropped);
    }

    /**
     * @notice Emergency withdrawal
     */
    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external onlyOwner {
        require(
            IERC20(token).transfer(owner(), amount),
            "Transfer failed"
        );
    }
} 