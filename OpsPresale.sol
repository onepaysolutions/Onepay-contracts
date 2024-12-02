// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../manage/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStarNFT {
    function getTokenInfo(uint256 tokenId) external view returns (
        uint8 status,
        uint8 starLevel,
        uint40 activationTimestamp,
        uint64 totalOPSBought,
        uint64 totalOPSRewarded,
        uint64 totalOPSAirdropped
    );
    function recordValues(
        uint256 tokenId,
        uint64 bought,
        uint64 rewarded,
        uint64 airdropped
    ) external;
}

interface IOPSToken {
    function mint(address to, uint256 amount) external;
}

interface IPriceController {
    function getCurrentPrice() external view returns (uint256);
    function getNextPhasePrice() external view returns (uint256);
    function advancePhase() external returns (bool);
    function isPhaseCompleted() external view returns (bool);
}

/**
 * @title OpsPresale
 * @notice Handles OPS token presale with 20 phases
 */
contract OpsPresale is AccessControl, ReentrancyGuard {
    // Core contracts
    IStarNFT public starNFT;
    IOPSToken public opsToken;
    IPriceController public priceController;
    IERC20 public usdcToken;
    IERC20 public usdtToken;

    // Constants
    uint256 public constant TOTAL_PHASES = 20;
    uint256 public constant MIN_PURCHASE = 100e18;  // Minimum 100 OPS

    // State variables
    bool public isPresaleActive;
    uint256 public currentPhase;
    uint256 public totalSold;
    uint256 public phaseTarget = 1000000e18; // 1M OPS per phase

    // Tracking
    mapping(uint256 => uint256) public phaseSold;
    mapping(address => bool) public whitelisted;
    mapping(address => uint256) public userPurchases;

    // Events
    event PresaleStarted(uint256 timestamp);
    event PresalePaused(uint256 timestamp);
    event TokensPurchased(
        address indexed buyer,
        uint256 usdAmount,
        uint256 opsAmount,
        uint256 price,
        uint256 phase
    );
    event PhaseCompleted(
        uint256 indexed phase,
        uint256 totalSold,
        uint256 finalPrice
    );
    event WhitelistUpdated(address indexed user, bool status);

    constructor(
        address initialOwner,
        address _starNFT,
        address _opsToken,
        address _priceController,
        address _usdcToken,
        address _usdtToken
    ) AccessControl(initialOwner) {
        starNFT = IStarNFT(_starNFT);
        opsToken = IOPSToken(_opsToken);
        priceController = IPriceController(_priceController);
        usdcToken = IERC20(_usdcToken);
        usdtToken = IERC20(_usdtToken);
    }

    /**
     * @notice Purchase OPS tokens
     * @param amount Amount of OPS to purchase
     * @param useUSDC Whether to use USDC or USDT
     * @param tokenId Optional Star NFT token ID
     */
    function purchaseOPS(
        uint256 amount,
        bool useUSDC,
        uint256 tokenId
    ) external nonReentrant whenNotPaused {
        require(isPresaleActive, "Presale not active");
        require(amount >= MIN_PURCHASE, "Below minimum purchase");
        require(whitelisted[msg.sender], "Not whitelisted");

        uint256 currentPrice = priceController.getCurrentPrice();
        uint256 usdAmount = (amount * currentPrice) / 1e18;

        // Transfer payment
        IERC20 token = useUSDC ? usdcToken : usdtToken;
        require(
            token.transferFrom(msg.sender, address(this), usdAmount),
            "Transfer failed"
        );

        // Update state
        phaseSold[currentPhase] += amount;
        totalSold += amount;
        userPurchases[msg.sender] += amount;

        // Update Star NFT if provided
        if(tokenId != 0) {
            (
                uint8 status,
                ,
                ,
                uint64 totalOPSBought,
                uint64 totalOPSRewarded,
                uint64 totalOPSAirdropped
            ) = starNFT.getTokenInfo(tokenId);

            starNFT.recordValues(
                tokenId,
                uint64(totalOPSBought + amount),
                totalOPSRewarded,
                totalOPSAirdropped
            );
        }

        // Mint OPS tokens
        opsToken.mint(msg.sender, amount);

        // Check phase completion
        if(phaseSold[currentPhase] >= phaseTarget) {
            completePhase();
        }

        emit TokensPurchased(
            msg.sender,
            usdAmount,
            amount,
            currentPrice,
            currentPhase
        );
    }

    /**
     * @notice Complete current phase
     */
    function completePhase() internal {
        uint256 finalPrice = priceController.getCurrentPrice();
        emit PhaseCompleted(currentPhase, phaseSold[currentPhase], finalPrice);

        if(priceController.advancePhase()) {
            currentPhase++;
        }
    }

    // Admin functions
    function startPresale() external onlyManager {
        isPresaleActive = true;
        emit PresaleStarted(block.timestamp);
    }

    function pausePresale() external onlyManager {
        isPresaleActive = false;
        emit PresalePaused(block.timestamp);
    }

    function updateWhitelist(
        address user,
        bool status
    ) external onlyManager {
        whitelisted[user] = status;
        emit WhitelistUpdated(user, status);
    }

    function setPhaseTarget(uint256 newTarget) external onlyOwner {
        require(newTarget > 0, "Invalid target");
        phaseTarget = newTarget;
    }

    /**
     * @notice Get current phase information
     */
    function getCurrentPhaseInfo() external view returns (
        uint256 phaseIndex,
        uint256 currentPrice,
        uint256 nextPrice,
        uint256 sold,
        bool completed
    ) {
        return (
            currentPhase,
            priceController.getCurrentPrice(),
            priceController.getNextPhasePrice(),
            phaseSold[currentPhase],
            phaseSold[currentPhase] >= phaseTarget
        );
    }
}
