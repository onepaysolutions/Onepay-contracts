// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../manage/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IReferralSystem {
    function getUserLevel(address user) external view returns (uint256);
    function getUplines(address user) external view returns (address[] memory);
}

/**
 * @title LevelRewardManager
 * @notice Handles 20-level referral rewards
 */
contract LevelRewardManager is AccessControl, ReentrancyGuard {
    // Core contracts
    IReferralSystem public referralSystem;
    
    // Level reward percentages (in basis points)
    uint256[] public LEVEL_REWARDS = [
        1000, // Level 1: 10%
        500,  // Level 2: 5%
        500,  // Level 3: 5%
        200,  // Level 4: 2%
        200,  // Level 5: 2%
        200,  // Level 6: 2%
        200,  // Level 7: 2%
        200,  // Level 8: 2%
        100,  // Level 9: 1%
        100,  // Level 10: 1%
        100,  // Level 11: 1%
        100,  // Level 12: 1%
        100,  // Level 13: 1%
        100,  // Level 14: 1%
        200,  // Level 15: 2%
        200,  // Level 16: 2%
        200,  // Level 17: 2%
        200,  // Level 18: 2%
        200,  // Level 19: 2%
        200   // Level 20: 2%
    ];

    // Events
    event LevelRewardProcessed(
        address indexed user,
        uint256 level,
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
     * @notice Process level reward
     * @param user User address
     * @param amount Base amount for reward calculation
     */
    function processReward(
        address user,
        uint256 amount
    ) external onlyOperator returns (uint256) {
        uint256 totalReward = 0;
        address[] memory uplines = referralSystem.getUplines(user);

        for(uint i = 0; i < uplines.length && i < 20; i++) {
            address upline = uplines[i];
            uint256 level = referralSystem.getUserLevel(upline);
            
            if(level > 0 && level <= 20) {
                uint256 reward = (amount * LEVEL_REWARDS[level - 1]) / 10000;
                if(reward > 0) {
                    totalReward += reward;
                    emit LevelRewardProcessed(upline, level, amount, reward);
                }
            }
        }

        return totalReward;
    }

    /**
     * @notice Calculate potential level reward
     * @param user User address
     * @param amount Base amount for calculation
     */
    function calculateReward(
        address user,
        uint256 amount
    ) external view returns (uint256) {
        uint256 totalReward = 0;
        address[] memory uplines = referralSystem.getUplines(user);

        for(uint i = 0; i < uplines.length && i < 20; i++) {
            address upline = uplines[i];
            uint256 level = referralSystem.getUserLevel(upline);
            
            if(level > 0 && level <= 20) {
                uint256 reward = (amount * LEVEL_REWARDS[level - 1]) / 10000;
                totalReward += reward;
            }
        }

        return totalReward;
    }

    /**
     * @notice Update level reward percentages
     * @param level Level to update (1-20)
     * @param rewardBps New reward in basis points
     */
    function updateLevelReward(
        uint256 level,
        uint256 rewardBps
    ) external onlyOwner {
        require(level > 0 && level <= 20, "Invalid level");
        require(rewardBps <= 10000, "Invalid reward percentage");
        LEVEL_REWARDS[level - 1] = rewardBps;
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