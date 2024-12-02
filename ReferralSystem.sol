// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";

interface IUserNFT {
    function getUserInfo(address user) external view returns (
        address referrer,
        string memory userId,
        string memory zone,
        uint256 mintTime,
        bool isActive,
        uint256 nftType
    );
}

contract ReferralSystem is ContractMetadata, PermissionsEnumerable {
    // Constants
    uint256 public constant MAX_LEVEL = 20;

    // Ranking thresholds
    uint256 public constant RANK1_THRESHOLD = 10000e18; // 10k OPS
    uint256 public constant RANK2_THRESHOLD = 50000e18; // 50k OPS

    struct UserInfo {
        address referrer;          
        uint256 level;            
        uint256 totalOPS;         
        mapping(string => uint256) zoneOPS;  
        mapping(string => uint256) zoneTeamOPS;  
        uint256 rank;             // User's current rank (1-6)
        mapping(string => uint256) zoneRank; // Rank in each zone
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    IUserNFT public userNFT;
    
    mapping(address => UserInfo) public users;
    mapping(address => address[]) public uplines;

    // Events
    event ReferralAdded(
        address indexed referrer,
        address indexed referee,
        string zone,
        uint256 level
    );
    event OPSRecorded(
        address indexed user,
        uint256 amount,
        string zone,
        bool isPersonal
    );
    event TeamOPSUpdated(
        address indexed user,
        string zone,
        uint256 newAmount
    );
    event RankUpdated(
        address indexed user,
        string zone,
        uint256 oldRank,
        uint256 newRank
    );

    constructor(address _userNFT) {
        userNFT = IUserNFT(_userNFT);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    function addReferral(address referrer, address referee) external onlyRole(ADMIN_ROLE) {
        require(referrer != address(0), "Invalid referrer");
        require(referee != address(0), "Invalid referee");
        require(referrer != referee, "Cannot refer self");

        (,, string memory zone,,,) = userNFT.getUserInfo(referee);
        
        UserInfo storage referrerInfo = users[referrer];
        users[referee].referrer = referrer;
        users[referee].level = referrerInfo.level + 1;

        // Update upline path
        address[] memory referrerUpline = uplines[referrer];
        address[] memory newUpline = new address[](referrerUpline.length + 1);
        for(uint i = 0; i < referrerUpline.length; i++) {
            newUpline[i] = referrerUpline[i];
        }
        newUpline[referrerUpline.length] = referrer;
        uplines[referee] = newUpline;

        emit ReferralAdded(referrer, referee, zone, users[referee].level);
    }

    function recordOPS(address user, uint256 amount) external onlyRole(ADMIN_ROLE) {
        (,, string memory zone,,,) = userNFT.getUserInfo(user);
        
        users[user].totalOPS += amount;
        users[user].zoneOPS[zone] += amount;
        
        // Update team performance and check ranks
        address[] memory userUplines = uplines[user];
        for(uint i = 0; i < userUplines.length; i++) {
            address upline = userUplines[i];
            users[upline].zoneTeamOPS[zone] += amount;
            
            // Check and update rank if needed
            updateRank(upline, zone);
            
            emit TeamOPSUpdated(upline, zone, users[upline].zoneTeamOPS[zone]);
        }

        // Check user's own rank
        updateRank(user, zone);

        emit OPSRecorded(user, amount, zone, true);
    }

    function updateRank(address user, string memory zone) internal {
        UserInfo storage info = users[user];
        uint256 zoneOPS = info.zoneOPS[zone];
        uint256 oldRank = info.zoneRank[zone];
        uint256 newRank;

        if (zoneOPS >= RANK2_THRESHOLD) {
            newRank = 2;
            // Check for higher ranks based on team structure
            if (checkRank3Requirements(user, zone)) {
                newRank = 3;
                if (checkRank4Requirements(user, zone)) {
                    newRank = 4;
                    if (checkRank5Requirements(user, zone)) {
                        newRank = 5;
                        if (checkRank6Requirements(user, zone)) {
                            newRank = 6;
                        }
                    }
                }
            }
        } else if (zoneOPS >= RANK1_THRESHOLD) {
            newRank = 1;
        }

        if (newRank != oldRank) {
            info.zoneRank[zone] = newRank;
            emit RankUpdated(user, zone, oldRank, newRank);
        }
    }

    // Rank requirement check functions
    function checkRank3Requirements(address user, string memory zone) internal view returns (bool) {
        uint256 rank2DirectCount = 0;
        address[] memory userUplines = uplines[user];
        
        for(uint i = 0; i < userUplines.length; i++) {
            if(users[userUplines[i]].zoneRank[zone] >= 2) {
                rank2DirectCount++;
                if(rank2DirectCount >= 2) return true;
            }
        }
        
        return false;
    }

    function checkRank4Requirements(address user, string memory zone) internal view returns (bool) {
        if(!checkRank3Requirements(user, zone)) return false;
        
        uint256 rank3DirectCount = 0;
        address[] memory userUplines = uplines[user];
        
        for(uint i = 0; i < userUplines.length; i++) {
            if(users[userUplines[i]].zoneRank[zone] >= 3) {
                rank3DirectCount++;
                if(rank3DirectCount >= 3) return true;
            }
        }
        
        return false;
    }

    function checkRank5Requirements(address user, string memory zone) internal view returns (bool) {
        // Implement rank 5 requirements
        return true; // Placeholder
    }

    function checkRank6Requirements(address user, string memory zone) internal view returns (bool) {
        // Implement rank 6 requirements
        return true; // Placeholder
    }

    // View functions
    function getUserLevel(address user) external view returns (uint256) {
        return users[user].level;
    }

    function getUserRank(address user, string memory zone) external view returns (uint256) {
        return users[user].zoneRank[zone];
    }

    function getUplines(address user) external view returns (address[] memory) {
        return uplines[user];
    }

    function _canSetContractURI() internal view virtual override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
} 