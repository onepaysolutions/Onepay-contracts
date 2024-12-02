// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../star/StarNFTBase.sol";

contract SharingRewardManager is Ownable {
    StarNFTBase public starNFT;
    
    struct StarReward {
        uint256 level1Reward; // 10%
        uint256 level2Reward; // 5%
        uint256 level3Reward; // 5%
    }
    
    mapping(uint256 => StarReward) public starRewards;

    event SharingRewardProcessed(
        address indexed user,
        uint256 starLevel,
        uint256 amount,
        uint256 reward
    );

    constructor(
        address _starNFT,
        address initialOwner
    ) Ownable(initialOwner) {
        starNFT = StarNFTBase(_starNFT);
        
        // Initialize star rewards
        starRewards[2] = StarReward(1000, 0, 0);     // Star 2
        starRewards[3] = StarReward(1000, 500, 0);   // Star 3
        starRewards[4] = StarReward(1000, 500, 500); // Star 4
    }

    function processReward(
        address user,
        uint256 amount
    ) external onlyOwner returns (uint256) {
        uint256 starLevel = starNFT.getStarLevel(user);
        if(starLevel < 2) return 0;
        
        StarReward storage reward = starRewards[starLevel];
        uint256 totalReward = (amount * (
            reward.level1Reward + 
            reward.level2Reward + 
            reward.level3Reward
        )) / 10000;

        emit SharingRewardProcessed(user, starLevel, amount, totalReward);
        
        return totalReward;
    }

    function calculateReward(
        address user,
        uint256 amount
    ) external view returns (uint256) {
        uint256 starLevel = starNFT.getStarLevel(user);
        if(starLevel < 2) return 0;
        
        StarReward storage reward = starRewards[starLevel];
        return (amount * (
            reward.level1Reward + 
            reward.level2Reward + 
            reward.level3Reward
        )) / 10000;
    }
} 