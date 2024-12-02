// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/base/ERC1155Base.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
import "@thirdweb-dev/contracts/extension/Permissions.sol";
import "@thirdweb-dev/contracts/extension/DropSinglePhase1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title StarNFT
 * @notice NFT contract for recording Star Contract status with claim conditions
 */
contract StarNFT is ERC1155Base, ContractMetadata, Permissions, DropSinglePhase1155, ReentrancyGuard {
    // Use uint8 for gas optimization
    uint8 constant STATUS_PENDING = 1;    // < USD CONTRACT VALUE
    uint8 constant STATUS_RELEASING = 2;  // > USD CONTRACT VALUE  
    uint8 constant STATUS_ACTIVE = 3;     // Airdrop List
    uint8 constant STATUS_INACTIVE = 4;   // USD CONTRACT VALUE = 0
    uint8 constant STATUS_COMPLETED = 5;  // Burned Star NFT

    // Pack data into single storage slot
    struct TokenInfo {
        uint8 status;                 // 8 bits
        uint8 starLevel;              // 8 bits
        uint40 activationTimestamp;   // 40 bits
        uint200 values;               // 200 bits (3 * uint64 for OPS amounts)
    }

    // Roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Main storage
    mapping(uint256 => TokenInfo) private tokenInfo;

    // Events
    event TokenMinted(address indexed to, uint256 indexed tokenId, uint8 starLevel);
    event StatusUpdated(uint256 indexed tokenId, uint8 oldStatus, uint8 newStatus);
    event ValueRecorded(uint256 indexed tokenId, uint256 values);

    constructor(
        string memory _name,
        string memory _symbol,
        address _royaltyRecipient,
        uint128 _royaltyBps
    ) ERC1155Base(_name, _symbol, _royaltyRecipient, _royaltyBps) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(OPERATOR_ROLE, msg.sender);
    }

    /**
     * @notice Mint new Star NFT
     * @param to Recipient address
     * @param starLevel Star level (1-4)
     * @param amount Amount to mint
     */
    function mint(
        address to,
        uint8 starLevel,
        uint256 amount
    ) external returns (uint256) {
        require(hasRole(MINTER_ROLE, msg.sender), "Not authorized to mint");
        require(starLevel >= 1 && starLevel <= 4, "Invalid star level");
        
        uint256 tokenId = (uint256(starLevel) << 248) | uint256(nextTokenIdToMint());
        _mint(to, tokenId, amount, "");
        
        tokenInfo[tokenId].status = STATUS_PENDING;
        tokenInfo[tokenId].starLevel = starLevel;
        
        emit TokenMinted(to, tokenId, starLevel);
        return tokenId;
    }

    /**
     * @notice Claim Star NFT with conditions
     * @param receiver Recipient address
     * @param tokenId Token ID to claim
     * @param quantity Amount to claim
     * @param currency Currency for payment
     * @param pricePerToken Price per token
     * @param allowlistProof Allowlist proof
     * @param data Additional data
     */
    function claim(
        address receiver,
        uint256 tokenId,
        uint256 quantity,
        address currency,
        uint256 pricePerToken,
        AllowlistProof calldata allowlistProof,
        bytes memory data
    ) external payable override {
        require(tokenId > 0 && tokenId <= 4, "Invalid token ID");
        
        // Verify and update claim conditions
        _processClaimConditions(
            tokenId,
            quantity,
            currency,
            pricePerToken,
            allowlistProof
        );

        // Mint tokens
        _mint(receiver, tokenId, quantity, data);
        
        // Initialize token info
        tokenInfo[tokenId].status = STATUS_PENDING;
        tokenInfo[tokenId].starLevel = uint8(tokenId);
        
        emit TokenMinted(receiver, tokenId, uint8(tokenId));
    }

    /**
     * @notice Burn tokens
     * @param account Account to burn from
     * @param id Token ID to burn
     * @param value Amount to burn
     */
    function burn(
        address account,
        uint256 id,
        uint256 value
    ) external {
        require(
            account == msg.sender || isApprovedForAll(account, msg.sender),
            "Not approved"
        );
        _burn(account, id, value);
    }

    /**
     * @notice Get token information
     * @param tokenId Token ID
     */
    function getTokenInfo(uint256 tokenId) external view returns (
        uint8 status,
        uint8 starLevel,
        uint40 activationTimestamp,
        uint64 totalOPSBought,
        uint64 totalOPSRewarded,
        uint64 totalOPSAirdropped
    ) {
        TokenInfo memory info = tokenInfo[tokenId];
        return (
            info.status,
            info.starLevel,
            info.activationTimestamp,
            uint64(info.values),
            uint64(info.values >> 64),
            uint64(info.values >> 128)
        );
    }

    /**
     * @notice Update token status
     * @param tokenId Token ID
     * @param newStatus New status code
     */
    function updateStatus(
        uint256 tokenId,
        uint8 newStatus
    ) external {
        require(hasRole(OPERATOR_ROLE, msg.sender), "Not authorized");
        require(_exists(tokenId), "Token does not exist");
        TokenInfo storage info = tokenInfo[tokenId];
        uint8 oldStatus = info.status;
        info.status = newStatus;
        
        if(newStatus == STATUS_ACTIVE) {
            info.activationTimestamp = uint40(block.timestamp);
        }
        
        emit StatusUpdated(tokenId, oldStatus, newStatus);
    }

    /**
     * @notice Record OPS values
     * @param tokenId Token ID
     * @param bought Amount bought
     * @param rewarded Amount rewarded
     * @param airdropped Amount airdropped
     */
    function recordValues(
        uint256 tokenId,
        uint64 bought,
        uint64 rewarded,
        uint64 airdropped
    ) external {
        require(hasRole(OPERATOR_ROLE, msg.sender), "Not authorized");
        require(_exists(tokenId), "Token does not exist");
        uint256 values = bought | (uint256(rewarded) << 64) | (uint256(airdropped) << 128);
        tokenInfo[tokenId].values = uint200(values);
        emit ValueRecorded(tokenId, values);
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return totalSupply(tokenId) > 0;
    }

    function _canSetContractURI() internal view virtual override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155Base, Permissions) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
} 