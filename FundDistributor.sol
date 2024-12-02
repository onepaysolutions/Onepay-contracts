// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title FundDistributor
 * @notice Handles the distribution of funds according to Star NFT levels
 */
contract FundDistributor is AccessControl, ReentrancyGuard {
    // Star level fund distribution ratios
    struct StarRatio {
        uint256 presaleShare;   // Presale funds share
        uint256 referralShare;  // Referral funds share
        uint256 buybackShare;   // Buyback funds share
    }

    // Core addresses
    address public presalePool;    // Pool for presale funds
    address public referralPool;   // Pool for referral rewards
    address public buybackPool;    // Pool for OPE buyback

    // Star level configurations
    mapping(uint256 => StarRatio) public starRatios;

    // Events
    event FundsDistributed(
        uint256 indexed starLevel,
        address indexed token,
        uint256 presaleAmount,
        uint256 referralAmount,
        uint256 buybackAmount
    );
    event PoolsUpdated(
        address presalePool,
        address referralPool,
        address buybackPool
    );

    constructor(
        address initialOwner,
        address _presalePool,
        address _referralPool,
        address _buybackPool
    ) AccessControl(initialOwner) {
        presalePool = _presalePool;
        referralPool = _referralPool;
        buybackPool = _buybackPool;

        // Initialize Star ratios
        starRatios[1] = StarRatio({
            presaleShare: 5000,  // 50%
            referralShare: 4500, // 45%
            buybackShare: 500    // 5%
        });

        starRatios[2] = StarRatio({
            presaleShare: 5500,  // 55%
            referralShare: 4000, // 40%
            buybackShare: 500    // 5%
        });

        starRatios[3] = StarRatio({
            presaleShare: 6000,  // 60%
            referralShare: 3500, // 35%
            buybackShare: 500    // 5%
        });

        starRatios[4] = StarRatio({
            presaleShare: 6500,  // 65%
            referralShare: 3000, // 30%
            buybackShare: 500    // 5%
        });
    }

    /**
     * @notice Distribute funds according to Star level ratios
     * @param starLevel Star level (1-4)
     * @param token Token address to distribute
     * @param amount Total amount to distribute
     */
    function distributeStarFunds(
        uint256 starLevel,
        address token,
        uint256 amount
    ) external onlyOperator nonReentrant {
        require(starLevel >= 1 && starLevel <= 4, "Invalid star level");
        require(amount > 0, "Amount must be greater than 0");

        StarRatio memory ratio = starRatios[starLevel];
        IERC20 tokenContract = IERC20(token);

        // Calculate amounts
        uint256 presaleAmount = (amount * ratio.presaleShare) / 10000;
        uint256 referralAmount = (amount * ratio.referralShare) / 10000;
        uint256 buybackAmount = (amount * ratio.buybackShare) / 10000;

        // Transfer funds
        require(
            tokenContract.transfer(presalePool, presaleAmount),
            "Presale transfer failed"
        );
        require(
            tokenContract.transfer(referralPool, referralAmount),
            "Referral transfer failed"
        );
        require(
            tokenContract.transfer(buybackPool, buybackAmount),
            "Buyback transfer failed"
        );

        emit FundsDistributed(
            starLevel,
            token,
            presaleAmount,
            referralAmount,
            buybackAmount
        );
    }

    /**
     * @notice Update pool addresses
     * @param _presalePool New presale pool address
     * @param _referralPool New referral pool address
     * @param _buybackPool New buyback pool address
     */
    function updatePools(
        address _presalePool,
        address _referralPool,
        address _buybackPool
    ) external onlyOwner {
        if(_presalePool != address(0)) presalePool = _presalePool;
        if(_referralPool != address(0)) referralPool = _referralPool;
        if(_buybackPool != address(0)) buybackPool = _buybackPool;

        emit PoolsUpdated(presalePool, referralPool, buybackPool);
    }

    /**
     * @notice Update Star level ratios
     * @param starLevel Star level to update
     * @param presaleShare New presale share
     * @param referralShare New referral share
     * @param buybackShare New buyback share
     */
    function updateStarRatio(
        uint256 starLevel,
        uint256 presaleShare,
        uint256 referralShare,
        uint256 buybackShare
    ) external onlyOwner {
        require(starLevel >= 1 && starLevel <= 4, "Invalid star level");
        require(
            presaleShare + referralShare + buybackShare == 10000,
            "Invalid shares total"
        );

        starRatios[starLevel] = StarRatio({
            presaleShare: presaleShare,
            referralShare: referralShare,
            buybackShare: buybackShare
        });
    }

    /**
     * @notice Emergency withdrawal
     * @param token Token address
     * @param amount Amount to withdraw
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