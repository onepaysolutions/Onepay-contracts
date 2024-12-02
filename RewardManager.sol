// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../manage/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IOPSToken {
    function mint(address to, uint256 amount) external;
}

/**
 * @title RewardManager
 * @notice Main contract for managing all reward systems
 */
contract RewardManager is AccessControl, ReentrancyGuard {
    // Core contracts
    IOPSToken public opsToken;

    // Reward managers
    address public levelRewardManager;    // 20级推荐奖励
    address public sharingRewardManager;  // Star NFT分享奖励
    address public rankingRewardManager;  // 排名奖励

    // Events
    event RewardProcessed(
        address indexed user,
        string rewardType,
        uint256 amount,
        string zone
    );
    event ManagerUpdated(string indexed rewardType, address manager);

    constructor(
        address initialOwner,
        address _opsToken
    ) AccessControl(initialOwner) {
        opsToken = IOPSToken(_opsToken);
    }

    /**
     * @notice Process all rewards for a user
     * @param user User address
     * @param amount Base amount for reward calculation
     * @param zone Zone identifier
     */
    function processRewards(
        address user,
        uint256 amount,
        string memory zone
    ) external onlyOperator nonReentrant returns (uint256) {
        uint256 totalReward = 0;

        // Process level rewards
        if(levelRewardManager != address(0)) {
            uint256 levelReward = IRewardManager(levelRewardManager).processReward(user, amount);
            if(levelReward > 0) {
                totalReward += levelReward;
                emit RewardProcessed(user, "LEVEL", levelReward, zone);
            }
        }
        
        // Process sharing rewards
        if(sharingRewardManager != address(0)) {
            uint256 sharingReward = IRewardManager(sharingRewardManager).processReward(user, amount);
            if(sharingReward > 0) {
                totalReward += sharingReward;
                emit RewardProcessed(user, "SHARING", sharingReward, zone);
            }
        }
        
        // Process ranking rewards
        if(rankingRewardManager != address(0)) {
            uint256 rankingReward = IRewardManager(rankingRewardManager).processReward(user, amount, zone);
            if(rankingReward > 0) {
                totalReward += rankingReward;
                emit RewardProcessed(user, "RANKING", rankingReward, zone);
            }
        }

        // Mint rewards if any
        if(totalReward > 0) {
            opsToken.mint(user, totalReward);
        }

        return totalReward;
    }

    /**
     * @notice Calculate total potential reward
     * @param user User address
     * @param amount Base amount for calculation
     * @param zone Zone identifier
     */
    function calculateTotalReward(
        address user,
        uint256 amount,
        string memory zone
    ) external view returns (uint256) {
        uint256 total = 0;

        if(levelRewardManager != address(0)) {
            total += IRewardManager(levelRewardManager).calculateReward(user, amount);
        }
        
        if(sharingRewardManager != address(0)) {
            total += IRewardManager(sharingRewardManager).calculateReward(user, amount);
        }
        
        if(rankingRewardManager != address(0)) {
            total += IRewardManager(rankingRewardManager).calculateReward(user, amount, zone);
        }

        return total;
    }

    /**
     * @notice Set reward manager addresses
     * @param _levelManager Level reward manager address
     * @param _sharingManager Sharing reward manager address
     * @param _rankingManager Ranking reward manager address
     */
    function setManagers(
        address _levelManager,
        address _sharingManager,
        address _rankingManager
    ) external onlyOwner {
        if(_levelManager != address(0)) {
            levelRewardManager = _levelManager;
            emit ManagerUpdated("LEVEL", _levelManager);
        }
        if(_sharingManager != address(0)) {
            sharingRewardManager = _sharingManager;
            emit ManagerUpdated("SHARING", _sharingManager);
        }
        if(_rankingManager != address(0)) {
            rankingRewardManager = _rankingManager;
            emit ManagerUpdated("RANKING", _rankingManager);
        }
    }
}

interface IRewardManager {
    function processReward(
        address user,
        uint256 amount,
        string memory zone
    ) external returns (uint256);

    function processReward(
        address user,
        uint256 amount
    ) external returns (uint256);

    function calculateReward(
        address user,
        uint256 amount,
        string memory zone
    ) external view returns (uint256);

    function calculateReward(
        address user,
        uint256 amount
    ) external view returns (uint256);
} 