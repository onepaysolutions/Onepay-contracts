// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../manage/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IReferralSystem {
    function getUserRank(address user, string memory zone) external view returns (uint256);
}

/**
 * @title RankingRewardManager
 * @notice Handles ranking rewards for different zones
 */
contract RankingRewardManager is AccessControl, ReentrancyGuard {
    // Core contracts
    IReferralSystem public referralSystem;
    
    // Ranking reward percentages (in basis points)
    uint256[] public RANK_REWARDS = [
        500,  // Rank 1: 5%
        1000, // Rank 2: 10%
        1500, // Rank 3: 15%
        2000, // Rank 4: 20%
        2500, // Rank 5: 25%
        3000  // Rank 6: 30%
    ];

    // Events
    event RankingRewardProcessed(
        address indexed user,
        string zone,
        uint256 rank,
        uint256 amount,
        uint256 reward
    );

    constructor(
        address initialOwner,
        address _referralSystem
    ) AccessControl(initialOwner) {
        referralSystem = IReferralSystem(_referralSystem);
    }

    /**
     * @notice Process ranking reward
     * @param user User address
     * @param amount Base amount for reward calculation
     * @param zone Zone identifier
     */
    function processReward(
        address user,
        uint256 amount,
        string memory zone
    ) external onlyOperator returns (uint256) {
        uint256 rank = referralSystem.getUserRank(user, zone);
        if(rank == 0 || rank > 6) return 0;
        
        uint256 reward = (amount * RANK_REWARDS[rank - 1]) / 10000;
        if(reward > 0) {
            emit RankingRewardProcessed(user, zone, rank, amount, reward);
        }
        
        return reward;
    }

    /**
     * @notice Calculate potential ranking reward
     * @param user User address
     * @param amount Base amount for calculation
     * @param zone Zone identifier
     */
    function calculateReward(
        address user,
        uint256 amount,
        string memory zone
    ) external view returns (uint256) {
        uint256 rank = referralSystem.getUserRank(user, zone);
        if(rank == 0 || rank > 6) return 0;
        
        return (amount * RANK_REWARDS[rank - 1]) / 10000;
    }

    /**
     * @notice Update rank reward percentages
     * @param rank Rank to update (1-6)
     * @param rewardBps New reward in basis points
     */
    function updateRankReward(
        uint256 rank,
        uint256 rewardBps
    ) external onlyOwner {
        require(rank > 0 && rank <= 6, "Invalid rank");
        require(rewardBps <= 10000, "Invalid reward percentage");
        RANK_REWARDS[rank - 1] = rewardBps;
    }

    /**
     * @notice Set referral system contract
     * @param _referralSystem New referral system address
     */
    function setReferralSystem(address _referralSystem) external onlyOwner {
        require(_referralSystem != address(0), "Invalid address");
        referralSystem = IReferralSystem(_referralSystem);
    }
} 