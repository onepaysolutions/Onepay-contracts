// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title OPE Token
 * @notice Implementation of the One Pay Equity token with reflection mechanism
 */
contract OpeToken is ERC20, Ownable, ReentrancyGuard {
    // Constants
    uint256 public constant TOTAL_SUPPLY = 3_000_000 * 10**18;  // 3,000,000 OPE
    uint256 public constant TAX_FEE = 10;                       // 10% tax fee
    uint256 public constant MIN_HOLDING_FOR_REFLECTION = 1000 * 10**18; // 1000 OPE minimum

    // State variables
    uint256 private _totalFees;
    uint256 private _reflectionTotal;
    uint256 private constant MAX = type(uint256).max;

    // Mappings
    mapping(address => uint256) private _reflectionBalances;
    mapping(address => uint256) private _tokenBalances;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcludedFromReflection;

    // Events
    event ReflectionDistributed(uint256 amount);
    event ExcludedFromFee(address indexed account, bool isExcluded);
    event ExcludedFromReflection(address indexed account, bool isExcluded);
    event ReflectionClaimed(address indexed account, uint256 amount);

    constructor(address initialOwner) ERC20("One Pay Equity", "OPE") Ownable(initialOwner) {
        _reflectionTotal = (MAX - (MAX % TOTAL_SUPPLY));
        _reflectionBalances[initialOwner] = _reflectionTotal;
        _isExcludedFromFee[initialOwner] = true;
        _isExcludedFromReflection[initialOwner] = true;

        emit Transfer(address(0), initialOwner, TOTAL_SUPPLY);
    }

    /**
     * @notice Get total fees collected
     */
    function totalFees() external view returns (uint256) {
        return _totalFees;
    }

    /**
     * @notice Get reflection balance of account
     */
    function reflectionBalance(address account) external view returns (uint256) {
        return _reflectionBalances[account];
    }

    /**
     * @notice Check if account is excluded from fee
     */
    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcludedFromFee[account];
    }

    /**
     * @notice Check if account is excluded from reflection
     */
    function isExcludedFromReflection(address account) external view returns (bool) {
        return _isExcludedFromReflection[account];
    }

    /**
     * @notice Get token balance of account
     */
    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcludedFromReflection[account]) return _tokenBalances[account];
        return tokenFromReflection(_reflectionBalances[account]);
    }

    /**
     * @notice Transfer tokens with reflection mechanism
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        require(sender != address(0), "Transfer from zero address");
        require(recipient != address(0), "Transfer to zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        uint256 fee = 0;
        if (!_isExcludedFromFee[sender]) {
            fee = (amount * TAX_FEE) / 100;
            _reflectFee(fee);
            amount -= fee;
        }

        uint256 rate = _getRate();
        uint256 reflectionAmount = amount * rate;
        uint256 reflectionFee = fee * rate;

        _reflectionBalances[sender] -= (reflectionAmount + reflectionFee);
        _reflectionBalances[recipient] += reflectionAmount;

        if (_isExcludedFromReflection[sender]) {
            _tokenBalances[sender] -= (amount + fee);
        }
        if (_isExcludedFromReflection[recipient]) {
            _tokenBalances[recipient] += amount;
        }

        emit Transfer(sender, recipient, amount);
        if (fee > 0) {
            emit Transfer(sender, address(this), fee);
        }
    }

    /**
     * @notice Claim reflection rewards
     */
    function claimReflection() external nonReentrant {
        require(balanceOf(msg.sender) >= MIN_HOLDING_FOR_REFLECTION, "Insufficient balance for reflection");
        uint256 reflection = reflectionOf(msg.sender);
        require(reflection > 0, "No reflection to claim");

        _reflectionBalances[msg.sender] += reflection;
        emit ReflectionClaimed(msg.sender, reflection);
    }

    /**
     * @notice Calculate reflection amount for account
     */
    function reflectionOf(address account) public view returns (uint256) {
        if (balanceOf(account) < MIN_HOLDING_FOR_REFLECTION) return 0;
        uint256 totalSupplyMinusFees = TOTAL_SUPPLY - _totalFees;
        if (totalSupplyMinusFees == 0) return 0;
        return (balanceOf(account) * _totalFees) / totalSupplyMinusFees;
    }

    // Internal functions
    function _reflectFee(uint256 fee) private {
        _reflectionTotal -= fee * _getRate();
        _totalFees += fee;
        emit ReflectionDistributed(fee);
    }

    function _getRate() private view returns (uint256) {
        return _reflectionTotal / TOTAL_SUPPLY;
    }

    function tokenFromReflection(uint256 reflectionAmount) private view returns (uint256) {
        require(reflectionAmount <= _reflectionTotal, "Amount must be less than total reflections");
        return reflectionAmount / _getRate();
    }

    // Admin functions
    function excludeFromFee(address account, bool excluded) external onlyOwner {
        _isExcludedFromFee[account] = excluded;
        emit ExcludedFromFee(account, excluded);
    }

    function excludeFromReflection(address account, bool excluded) external onlyOwner {
        _isExcludedFromReflection[account] = excluded;
        emit ExcludedFromReflection(account, excluded);
    }
}

