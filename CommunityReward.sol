// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NFTRewardBase.sol";

contract CommunityReward is NFTRewardBase {
    // Constants
    uint256 public constant CLAIM_WINDOW = 60 days;
    uint256 public constant MIN_HOLDING_PERIOD = 14 days;

    constructor(
        address _communityNFT,
        address _opeToken
    ) NFTRewardBase(
        _communityNFT,
        _opeToken,
        1000e18,   // 1000 OPE mining reward
        1000e18    // 1000 OPE referral reward
    ) {}

    function canClaimReferralReward(
        uint256 tokenId
    ) public view override returns (bool) {
        (,address referrer,) = nftContract.getTokenInfo(tokenId);
        if(referrer == address(0)) return false;

        // Referrer must hold at least one Community NFT
        return nftContract.balanceOf(referrer) > 0;
    }

    function isReferralRewardExpired(
        uint256 tokenId
    ) public view override returns (bool) {
        (,,bool claimed) = nftContract.getTokenInfo(tokenId);
        if(claimed) return true;

        // Check if within claim window
        address owner = nftContract.ownerOf(tokenId);
        uint256 holdingTime = block.timestamp - nftContract.mintTime(tokenId);
        
        return holdingTime > CLAIM_WINDOW || holdingTime < MIN_HOLDING_PERIOD;
    }
} 