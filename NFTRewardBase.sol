// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface INFTBase {
    function getTokenInfo(uint256 tokenId) external view returns (
        bool isClaimed,
        address referrer,
        bool isReferralRewardClaimed
    );
    function ownerOf(uint256 tokenId) external view returns (address);
    function balanceOf(address owner) external view returns (uint256);
}

interface IOPEToken {
    function mint(address to, uint256 amount) external;
}

/**
 * @title NFTRewardBase
 * @notice Base contract for NFT reward distribution
 */
abstract contract NFTRewardBase is ContractMetadata, PermissionsEnumerable, ReentrancyGuard {
    // Core state variables
    INFTBase public nftContract;
    IOPEToken public opeToken;

    // Constants
    uint256 public immutable MINING_REWARD;
    uint256 public immutable REFERRAL_REWARD;

    // Role definitions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Tracking
    mapping(uint256 => bool) public processedMiningRewards;
    mapping(uint256 => bool) public processedReferralRewards;

    // Events
    event MiningRewardDistributed(
        address indexed user,
        uint256 indexed tokenId,
        uint256 amount
    );
    event ReferralRewardDistributed(
        address indexed referrer,
        uint256 indexed tokenId,
        uint256 amount
    );
    event ReferralRewardExpired(
        uint256 indexed tokenId,
        address indexed referrer,
        uint256 amount
    );

    constructor(
        address _nftContract,
        address _opeToken,
        uint256 _miningReward,
        uint256 _referralReward
    ) {
        nftContract = INFTBase(_nftContract);
        opeToken = IOPEToken(_opeToken);
        MINING_REWARD = _miningReward;
        REFERRAL_REWARD = _referralReward;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(OPERATOR_ROLE, msg.sender);
    }

    /**
     * @notice Process mining reward for a token
     * @param tokenId Token ID to process reward for
     */
    function processMiningReward(
        uint256 tokenId
    ) external onlyRole(OPERATOR_ROLE) returns (uint256) {
        require(!processedMiningRewards[tokenId], "Mining reward already processed");
        
        address owner = nftContract.ownerOf(tokenId);
        processedMiningRewards[tokenId] = true;

        opeToken.mint(owner, MINING_REWARD);
        emit MiningRewardDistributed(owner, tokenId, MINING_REWARD);
        
        return MINING_REWARD;
    }

    /**
     * @notice Process referral reward for a token
     * @param tokenId Token ID to process reward for
     */
    function processReferralReward(
        uint256 tokenId
    ) external onlyRole(OPERATOR_ROLE) returns (uint256) {
        require(!processedReferralRewards[tokenId], "Referral reward already processed");
        
        (,address referrer,bool claimed) = nftContract.getTokenInfo(tokenId);
        require(referrer != address(0), "No referrer");

        if (isReferralRewardExpired(tokenId)) {
            processedReferralRewards[tokenId] = true;
            emit ReferralRewardExpired(tokenId, referrer, REFERRAL_REWARD);
            return 0;
        }

        if (canClaimReferralReward(tokenId)) {
            processedReferralRewards[tokenId] = true;
            opeToken.mint(referrer, REFERRAL_REWARD);
            emit ReferralRewardDistributed(referrer, tokenId, REFERRAL_REWARD);
            return REFERRAL_REWARD;
        }

        return 0;
    }

    /**
     * @notice Check if referral reward can be claimed
     * @param tokenId Token ID to check
     */
    function canClaimReferralReward(
        uint256 tokenId
    ) public view virtual returns (bool);

    /**
     * @notice Check if referral reward has expired
     * @param tokenId Token ID to check
     */
    function isReferralRewardExpired(
        uint256 tokenId
    ) public view virtual returns (bool);

    function _canSetContractURI() internal view virtual override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
} 