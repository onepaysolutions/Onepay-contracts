// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./StarNFT.sol";

interface IOPSPresale {
    function buyPresaleOPS(address buyer, uint256 usdAmount) external;
}

interface IFundDistributor {
    function distributeStarFunds(uint256 starLevel, address token, uint256 amount) external;
}

/**
 * @title StarContract
 * @notice Handles Star NFT claiming and fund distribution
 * @dev This contract manages the business logic for Star NFT contracts
 */
contract StarContract is Ownable, ReentrancyGuard {
    // Core contracts
    StarNFT public starNFT;
    IERC20 public usdcToken;
    IERC20 public usdtToken;
    IOPSPresale public opsPresale;
    IFundDistributor public fundDistributor;

    // Contract values for each Star level
    struct ContractValue {
        uint256 usdValue;      // Total USD value required for contract
        uint256 presaleAmount; // Amount of OPS to be purchased in presale
    }

    // Star contract values mapping
    mapping(uint256 => ContractValue) public contractValues;

    // Events
    event ContractClaimed(
        uint256 indexed tokenId,
        address indexed user,
        uint256 starLevel,
        uint256 usdAmount,
        uint256 opsAmount
    );

    constructor(
        address _starNFT,
        address _usdcToken,
        address _usdtToken,
        address _opsPresale,
        address _fundDistributor
    ) {
        starNFT = StarNFT(_starNFT);
        usdcToken = IERC20(_usdcToken);
        usdtToken = IERC20(_usdtToken);
        opsPresale = IOPSPresale(_opsPresale);
        fundDistributor = IFundDistributor(_fundDistributor);

        // Initialize contract values for each Star level
        contractValues[1] = ContractValue({
            usdValue: 1250e6,  // Star 1: 1,250 USD
            presaleAmount: 250e6  // 250 USD worth of OPS
        });
        contractValues[2] = ContractValue({
            usdValue: 3300e6,  // Star 2: 3,300 USD
            presaleAmount: 550e6  // 550 USD worth of OPS
        });
        contractValues[3] = ContractValue({
            usdValue: 12600e6, // Star 3: 12,600 USD
            presaleAmount: 1800e6 // 1,800 USD worth of OPS
        });
        contractValues[4] = ContractValue({
            usdValue: 35600e6, // Star 4: 35,600 USD
            presaleAmount: 4450e6 // 4,450 USD worth of OPS
        });
    }

    /**
     * @notice Claim a Star contract by paying required USD value
     * @param tokenId The ID of the Star NFT to claim
     * @param useUSDC True to use USDC, false to use USDT
     * @dev This function handles payment, fund distribution, and OPS presale purchase
     */
    function claimContract(
        uint256 tokenId,
        bool useUSDC
    ) external nonReentrant {
        require(starNFT.ownerOf(tokenId) == msg.sender, "Not token owner");
        
        uint256 starLevel = starNFT.getStarLevel(tokenId);
        require(starLevel >= 1 && starLevel <= 4, "Invalid star level");

        (
            StarNFT.StarStatus status,
            ,
            ,
            ,
            ,
            
        ) = starNFT.getTokenInfo(tokenId);
        require(status == StarNFT.StarStatus.Pending, "Invalid status");

        ContractValue memory value = contractValues[starLevel];
        
        // Handle payment in USDC or USDT
        IERC20 token = useUSDC ? usdcToken : usdtToken;
        require(
            token.transferFrom(msg.sender, address(this), value.usdValue),
            "Transfer failed"
        );

        // Distribute funds according to Star level ratios
        fundDistributor.distributeStarFunds(starLevel, address(token), value.usdValue);

        // Purchase OPS tokens in presale
        opsPresale.buyPresaleOPS(msg.sender, value.presaleAmount);

        // Update NFT status to Active
        starNFT.updateStatus(tokenId, StarNFT.StarStatus.Active);

        emit ContractClaimed(
            tokenId,
            msg.sender,
            starLevel,
            value.usdValue,
            value.presaleAmount
        );
    }

    /**
     * @notice Get contract value details for a Star level
     * @param starLevel The Star level (1-4)
     * @return usdValue Required USD value for the contract
     * @return presaleAmount Amount of OPS to be purchased in presale
     */
    function getContractValue(
        uint256 starLevel
    ) external view returns (
        uint256 usdValue,
        uint256 presaleAmount
    ) {
        ContractValue memory value = contractValues[starLevel];
        return (value.usdValue, value.presaleAmount);
    }

    /**
     * @notice Emergency withdrawal of tokens
     * @param token Address of token to withdraw
     * @param amount Amount to withdraw
     * @dev Only callable by owner in emergency situations
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