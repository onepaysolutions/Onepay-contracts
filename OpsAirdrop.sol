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
    function recordValues(
        uint256 tokenId,
        uint64 bought,
        uint64 rewarded,
        uint64 airdropped
    ) external;
}

interface IOPSToken {
    function mint(address to, uint256 amount) external;
}

interface IOPSRelease {
    function startRelease(uint256 tokenId, uint256 amount) external;
}

/**
 * @title OpsAirdrop
 * @notice Handles OPS token airdrop and status management
 */
contract OpsAirdrop is AccessControl, ReentrancyGuard {
    // Core contracts
    IStarNFT public starNFT;
    IOPSToken public opsToken;
    IOPSRelease public opsRelease;

    // Constants
    uint8 constant STATUS_PENDING = 1;
    uint8 constant STATUS_RELEASING = 2;
    uint8 constant STATUS_ACTIVE = 3;
    uint8 constant STATUS_INACTIVE = 4;
    uint8 constant STATUS_COMPLETED = 5;

    // Tracking
    mapping(uint256 => bool) public isAirdropProcessed;

    // Events
    event AirdropProcessed(
        uint256 indexed tokenId,
        address indexed recipient,
        uint256 amount
    );
    event StatusUpdated(
        uint256 indexed tokenId,
        uint8 newStatus
    );

    constructor(
        address initialOwner,
        address _starNFT,
        address _opsToken,
        address _opsRelease
    ) AccessControl(initialOwner) {
        starNFT = IStarNFT(_starNFT);
        opsToken = IOPSToken(_opsToken);
        opsRelease = IOPSRelease(_opsRelease);
    }

    /**
     * @notice Process airdrop for a Star NFT
     * @param tokenId Token ID to process airdrop for
     * @param amount Amount of OPS to airdrop
     */
    function processAirdrop(
        uint256 tokenId,
        uint256 amount
    ) external onlyOperator nonReentrant {
        require(!isAirdropProcessed[tokenId], "Airdrop already processed");
        
        (
            uint8 status,
            uint8 starLevel,
            ,
            uint64 totalOPSBought,
            uint64 totalOPSRewarded,
            uint64 totalOPSAirdropped
        ) = starNFT.getTokenInfo(tokenId);

        require(status == STATUS_ACTIVE, "Token not active");

        address owner = starNFT.ownerOf(tokenId);
        isAirdropProcessed[tokenId] = true;

        // Check if total value exceeds cap
        uint256 totalValue = calculateTotalValue(
            totalOPSBought,
            totalOPSRewarded,
            totalOPSAirdropped + amount
        );

        // Update Star NFT values
        starNFT.recordValues(
            tokenId,
            totalOPSBought,
            totalOPSRewarded,
            uint64(totalOPSAirdropped + amount)
        );

        // Mint OPS tokens
        opsToken.mint(address(this), amount);

        // Check if should move to releasing state
        if(shouldStartRelease(starLevel, totalValue)) {
            starNFT.updateStatus(tokenId, STATUS_RELEASING);
            opsRelease.startRelease(tokenId, amount);
            emit StatusUpdated(tokenId, STATUS_RELEASING);
        } else {
            require(
                IERC20(address(opsToken)).transfer(owner, amount),
                "Transfer failed"
            );
        }

        emit AirdropProcessed(tokenId, owner, amount);
    }

    /**
     * @notice Calculate total value of OPS tokens
     * @param bought Amount bought
     * @param rewarded Amount rewarded
     * @param airdropped Amount airdropped
     */
    function calculateTotalValue(
        uint256 bought,
        uint256 rewarded,
        uint256 airdropped
    ) internal pure returns (uint256) {
        return bought + rewarded + airdropped;
    }

    /**
     * @notice Check if should start release process
     * @param starLevel Star level
     * @param totalValue Total OPS value
     */
    function shouldStartRelease(
        uint8 starLevel,
        uint256 totalValue
    ) internal pure returns (bool) {
        uint256 cap;
        if(starLevel == 1) cap = 1250e6;
        else if(starLevel == 2) cap = 3300e6;
        else if(starLevel == 3) cap = 12600e6;
        else if(starLevel == 4) cap = 35600e6;
        else return false;

        return totalValue > cap;
    }

    /**
     * @notice Set contract addresses
     * @param _starNFT Star NFT contract address
     * @param _opsToken OPS token contract address
     * @param _opsRelease OPS release contract address
     */
    function setContracts(
        address _starNFT,
        address _opsToken,
        address _opsRelease
    ) external onlyOwner {
        if(_starNFT != address(0)) starNFT = IStarNFT(_starNFT);
        if(_opsToken != address(0)) opsToken = IOPSToken(_opsToken);
        if(_opsRelease != address(0)) opsRelease = IOPSRelease(_opsRelease);
    }
} 