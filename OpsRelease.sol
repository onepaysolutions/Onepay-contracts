// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../manage/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStarNFT {
    function getTokenInfo(uint256 tokenId) external view returns (
        uint8 status,
        uint8 starLevel,
        uint40 activationTimestamp,
        uint64 totalOPSBought,
        uint64 totalOPSRewarded,
        uint64 totalOPSAirdropped
    );
    function ownerOf(uint256 tokenId) external view returns (address);
    function updateStatus(uint256 tokenId, uint8 newStatus) external;
    function burn(uint256 tokenId) external;
}

interface IOPSToken {
    function burn(address from, uint256 amount) external;
    function transfer(address to, uint256 amount) external returns (bool);
}

/**
 * @title OpsRelease
 * @notice Handles OPS token release and burn mechanisms
 */
contract OpsRelease is AccessControl, ReentrancyGuard {
    // Constants
    uint8 constant STATUS_PENDING = 1;
    uint8 constant STATUS_RELEASING = 2;
    uint8 constant STATUS_ACTIVE = 3;
    uint8 constant STATUS_INACTIVE = 4;
    uint8 constant STATUS_COMPLETED = 5;

    uint256 constant MIN_BURN_PERCENTAGE = 15;  // 15%
    uint256 constant MAX_BURN_PERCENTAGE = 85;  // 85%

    // Core contracts
    IStarNFT public starNFT;
    IOPSToken public opsToken;
    IERC20 public usdcToken;

    // Release info
    struct ReleaseInfo {
        uint256 totalAmount;
        bool isReleasing;
        bool isCompleted;
    }

    // Tracking
    mapping(uint256 => ReleaseInfo) public tokenReleases;

    // Events
    event ReleaseStarted(uint256 indexed tokenId, uint256 totalAmount);
    event TokensBurned(
        uint256 indexed tokenId,
        uint256 burnedAmount,
        uint256 releasedAmount,
        uint256 usdcAmount
    );
    event StarNFTBurned(uint256 indexed tokenId, address indexed owner);

    constructor(
        address initialOwner,
        address _starNFT,
        address _opsToken,
        address _usdcToken
    ) AccessControl(initialOwner) {
        starNFT = IStarNFT(_starNFT);
        opsToken = IOPSToken(_opsToken);
        usdcToken = IERC20(_usdcToken);
    }

    /**
     * @notice Start release process for a Star NFT
     * @param tokenId Token ID to start release for
     * @param amount Amount of OPS to release
     */
    function startRelease(
        uint256 tokenId,
        uint256 amount
    ) external onlyOperator nonReentrant {
        require(!tokenReleases[tokenId].isReleasing, "Already releasing");
        
        (uint8 status,,,,,,) = starNFT.getTokenInfo(tokenId);
        require(status == STATUS_RELEASING, "Not in releasing state");

        tokenReleases[tokenId] = ReleaseInfo({
            totalAmount: amount,
            isReleasing: true,
            isCompleted: false
        });

        emit ReleaseStarted(tokenId, amount);
    }

    /**
     * @notice Burn tokens and release USDC
     * @param tokenId Token ID to burn
     * @param burnPercentage Percentage of tokens to burn (15-85%)
     */
    function burnAndRelease(
        uint256 tokenId,
        uint256 burnPercentage
    ) external nonReentrant {
        ReleaseInfo storage info = tokenReleases[tokenId];
        require(info.isReleasing, "Not releasing");
        require(!info.isCompleted, "Already completed");
        require(starNFT.ownerOf(tokenId) == msg.sender, "Not token owner");
        require(
            burnPercentage >= MIN_BURN_PERCENTAGE && 
            burnPercentage <= MAX_BURN_PERCENTAGE,
            "Invalid burn percentage"
        );

        uint256 burnAmount = (info.totalAmount * burnPercentage) / 100;
        uint256 releaseAmount = info.totalAmount - burnAmount;

        // Calculate USDC amount based on current OPS price
        uint256 usdcAmount = calculateUSDCAmount(burnAmount);

        // Burn OPS tokens
        opsToken.burn(msg.sender, burnAmount);

        // Transfer remaining OPS and USDC
        require(
            opsToken.transfer(msg.sender, releaseAmount),
            "OPS transfer failed"
        );
        require(
            usdcToken.transfer(msg.sender, usdcAmount),
            "USDC transfer failed"
        );

        // Burn Star NFT and update status
        starNFT.burn(tokenId);
        info.isCompleted = true;
        starNFT.updateStatus(tokenId, STATUS_COMPLETED);

        emit TokensBurned(tokenId, burnAmount, releaseAmount, usdcAmount);
        emit StarNFTBurned(tokenId, msg.sender);
    }

    /**
     * @notice Calculate USDC amount for burned OPS
     * @param burnAmount Amount of OPS being burned
     */
    function calculateUSDCAmount(
        uint256 burnAmount
    ) internal view returns (uint256) {
        // Implementation depends on current OPS price
        // This is a placeholder
        uint256 currentPrice = 1e6; // $0.30
        return (burnAmount * currentPrice) / 1e18;
    }

    /**
     * @notice Get release information for a token
     * @param tokenId Token ID to query
     */
    function getReleaseInfo(
        uint256 tokenId
    ) external view returns (
        uint256 totalAmount,
        bool isReleasing,
        bool isCompleted
    ) {
        ReleaseInfo storage info = tokenReleases[tokenId];
        return (
            info.totalAmount,
            info.isReleasing,
            info.isCompleted
        );
    }
} 