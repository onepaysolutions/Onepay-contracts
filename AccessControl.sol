// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract AccessControl is Ownable, Pausable {
    bytes32 public constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");

    mapping(address => bool) public operators;
    mapping(address => bool) public managers;
    
    event OperatorAdded(address operator);
    event OperatorRemoved(address operator);
    event ManagerAdded(address manager);
    event ManagerRemoved(address manager);

    modifier onlyOperator() {
        require(operators[msg.sender] || owner() == msg.sender, "Not operator");
        _;
    }

    modifier onlyManager() {
        require(managers[msg.sender] || owner() == msg.sender, "Not manager");
        _;
    }

    constructor(address initialOwner) Ownable(initialOwner) {
    }

    function addOperator(address operator) external onlyOwner {
        operators[operator] = true;
        emit OperatorAdded(operator);
    }

    function removeOperator(address operator) external onlyOwner {
        operators[operator] = false;
        emit OperatorRemoved(operator);
    }

    function addManager(address manager) external onlyOwner {
        managers[manager] = true;
        emit ManagerAdded(manager);
    }

    function removeManager(address manager) external onlyOwner {
        managers[manager] = false;
        emit ManagerRemoved(manager);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
} 