// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/base/ERC721Base.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";

interface IOPCToken {
    function mint(address to, uint256 amount) external;
}

contract AngelNFT is ERC721Base, PermissionsEnumerable {
    IERC20 public usdcToken;
    IOPCToken public opcToken;
    uint256 public constant CLAIM_PRICE = 1000e6; // 1000 USDC
    uint256 public constant MINING_REWARD = 1000e18; // 1000 OPE
    uint256 public constant REFERRAL_REWARD = 1000e18; // 1000 OPE

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    mapping(uint256 => bool) public claimed;
    mapping(uint256 => address) public referrers;
    mapping(uint256 => bool) public referralRewardClaimed;

    event AngelMinted(
        address indexed owner,
        uint256 indexed tokenId,
        address indexed referrer
    );
    event RewardClaimed(uint256 indexed tokenId, uint256 amount);
    event ReferralRewardClaimed(
        uint256 indexed tokenId,
        address indexed referrer,
        uint256 amount
    );

    constructor(
        string memory _name,
        string memory _symbol,
        address _royaltyRecipient,
        uint128 _royaltyBps,
        address _usdcToken,
        address _opcToken
    ) ERC721Base(_name, _symbol, _royaltyRecipient, _royaltyBps) {
        usdcToken = IERC20(_usdcToken);
        opcToken = IOPCToken(_opcToken);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(OPERATOR_ROLE, msg.sender);
    }

    function mint(address referrer) external {
        require(
            usdcToken.transferFrom(msg.sender, address(this), CLAIM_PRICE),
            "USDC transfer failed"
        );

        uint256 tokenId = nextTokenIdToMint();

        _safeMint(msg.sender, tokenId);
        claimed[tokenId] = true;

        if (referrer != address(0) && referrer != msg.sender) {
            referrers[tokenId] = referrer;
            opcToken.mint(referrer, REFERRAL_REWARD);
            referralRewardClaimed[tokenId] = true;
            emit ReferralRewardClaimed(tokenId, referrer, REFERRAL_REWARD);
        }

        opcToken.mint(msg.sender, MINING_REWARD);

        emit AngelMinted(msg.sender, tokenId, referrer);
        emit RewardClaimed(tokenId, MINING_REWARD);
    }

    function claimReferralReward(uint256 tokenId) external {
        require(!referralRewardClaimed[tokenId], "Already claimed");
        address referrer = referrers[tokenId];
        require(referrer == msg.sender, "Not referrer");
        require(balanceOf(referrer) > 0, "Must own Angel NFT");

        referralRewardClaimed[tokenId] = true;
        opcToken.mint(referrer, REFERRAL_REWARD);

        emit ReferralRewardClaimed(tokenId, referrer, REFERRAL_REWARD);
    }

    function getTokenInfo(
        uint256 tokenId
    ) external view returns (
        bool isClaimed,
        address referrer,
        bool isReferralRewardClaimed
    ) {
        require(_exists(tokenId), "Token does not exist");
        return (
            claimed[tokenId],
            referrers[tokenId],
            referralRewardClaimed[tokenId]
        );
    }

    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) {
        require(
            IERC20(token).transfer(msg.sender, amount),
            "Transfer failed"
        );
    }

    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721Base, PermissionsEnumerable)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
