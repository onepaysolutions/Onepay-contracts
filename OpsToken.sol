// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IStarNFT {
    function getTokenInfo(uint256 tokenId) external view returns (
        uint8 status,
        uint8 starLevel,
        uint40 activationTimestamp,
        uint64 totalOPSBought,
        uint64 totalOPSRewarded,
        uint64 totalOPSAirdropped
    );
    function ownerOf(uint256 tokenId) external view returns (address);
}

/**
 * @title OpsToken
 * @notice Implementation of the OPS token with minting and burning mechanisms
 */
contract OpsToken is ERC20, Ownable, ReentrancyGuard {
    // Core contracts
    IStarNFT public starNFT;
    address public presaleContract;
    address public airdropContract;
    address public releaseContract;

    // Authorized operators
    mapping(address => bool) public operators;

    // Events
    event OperatorUpdated(address indexed operator, bool status);
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);

    constructor(
        address initialOwner,
        address _starNFT
    ) ERC20("OPS Token", "OPS") Ownable(initialOwner) {
        starNFT = IStarNFT(_starNFT);
        operators[msg.sender] = true;
    }

    modifier onlyOperator() {
        require(operators[msg.sender], "Not operator");
        _;
    }

    /**
     * @notice Set operator status
     * @param operator Operator address
     * @param status New operator status
     */
    function setOperator(address operator, bool status) external onlyOwner {
        operators[operator] = status;
        emit OperatorUpdated(operator, status);
    }

    /**
     * @notice Set contract addresses
     * @param _presale Presale contract address
     * @param _airdrop Airdrop contract address
     * @param _release Release contract address
     */
    function setContracts(
        address _presale,
        address _airdrop,
        address _release
    ) external onlyOwner {
        if(_presale != address(0)) presaleContract = _presale;
        if(_airdrop != address(0)) airdropContract = _airdrop;
        if(_release != address(0)) releaseContract = _release;
    }

    /**
     * @notice Mint new tokens
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyOperator {
        require(
            msg.sender == presaleContract ||
            msg.sender == airdropContract ||
            msg.sender == releaseContract,
            "Not authorized"
        );
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /**
     * @notice Burn tokens
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burn(address from, uint256 amount) external onlyOperator {
        require(msg.sender == releaseContract, "Only release contract");
        _burn(from, amount);
        emit TokensBurned(from, amount);
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