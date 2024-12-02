// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../manage/AccessControl.sol";

/**
 * @title PresalePriceControl
 * @notice Controls OPS token price across multiple cycles with different rules
 */
contract PresalePriceControl is AccessControl {
    // Cycle configuration
    struct CycleConfig {
        uint256 startPrice;      // Starting price for the cycle (e.g., 0.30 USD)
        uint256 stepSize;        // Amount of OPS for each price increase (e.g., 100,000 OPS)
        uint256 priceIncrement;  // Price increase per step (e.g., 0.01 USD)
        uint256 maxSteps;        // Maximum number of price increases
        uint256 cycleSupply;     // Total OPS supply for this cycle
    }

    // State variables
    uint256 public currentCycle;
    uint256 public currentStep;
    uint256 public soldInStep;
    mapping(uint256 => CycleConfig) public cycleConfigs;
    mapping(uint256 => uint256) public cycleSold;

    // Events
    event PriceIncreased(uint256 indexed cycle, uint256 newPrice);
    event CycleCompleted(uint256 indexed cycle);
    event CycleConfigUpdated(uint256 indexed cycle, CycleConfig config);

    constructor(address initialOwner) AccessControl(initialOwner) {
        // Initialize first 5 cycles
        cycleConfigs[1] = CycleConfig({
            startPrice: 0.30e18,     // 0.30 USD
            stepSize: 100000e18,     // 100,000 OPS
            priceIncrement: 0.01e18, // 0.01 USD
            maxSteps: 20,            // 20 steps max
            cycleSupply: 2000000e18  // 2M OPS
        });

        cycleConfigs[2] = CycleConfig({
            startPrice: 0.32e18,     // 0.32 USD
            stepSize: 100000e18,     // 100,000 OPS
            priceIncrement: 0.01e18, // 0.01 USD
            maxSteps: 20,
            cycleSupply: 2000000e18
        });

        cycleConfigs[3] = CycleConfig({
            startPrice: 0.34e18,     // 0.34 USD
            stepSize: 100000e18,
            priceIncrement: 0.01e18,
            maxSteps: 20,
            cycleSupply: 2000000e18
        });

        cycleConfigs[4] = CycleConfig({
            startPrice: 0.36e18,     // 0.36 USD
            stepSize: 100000e18,
            priceIncrement: 0.01e18,
            maxSteps: 20,
            cycleSupply: 2000000e18
        });

        cycleConfigs[5] = CycleConfig({
            startPrice: 0.38e18,     // 0.38 USD
            stepSize: 150000e18,     // Changed to 150,000 OPS
            priceIncrement: 0.01e18,
            maxSteps: 20,
            cycleSupply: 3000000e18  // Changed to 3M OPS
        });

        currentCycle = 1;
    }

    /**
     * @notice Get current price
     * @return Current OPS price
     */
    function getCurrentPrice() external view returns (uint256) {
        CycleConfig memory config = cycleConfigs[currentCycle];
        return config.startPrice + (currentStep * config.priceIncrement);
    }

    /**
     * @notice Get next cycle's starting price
     * @return Next cycle's starting price
     */
    function getNextCycleStartPrice() external view returns (uint256) {
        return cycleConfigs[currentCycle + 1].startPrice;
    }

    /**
     * @notice Update sold amount and adjust price if needed
     * @param amount Amount of OPS sold
     */
    function updateSold(uint256 amount) external onlyOperator {
        CycleConfig memory config = cycleConfigs[currentCycle];
        
        cycleSold[currentCycle] += amount;
        soldInStep += amount;

        // Check if should increase price
        if(soldInStep >= config.stepSize) {
            soldInStep = 0;
            if(currentStep < config.maxSteps) {
                currentStep++;
                emit PriceIncreased(currentCycle, getCurrentPrice());
            }
        }

        // Check if cycle is completed
        if(cycleSold[currentCycle] >= config.cycleSupply) {
            completeCycle();
        }
    }

    /**
     * @notice Complete current cycle and move to next
     */
    function completeCycle() internal {
        emit CycleCompleted(currentCycle);
        currentCycle++;
        currentStep = 0;
        soldInStep = 0;
    }

    /**
     * @notice Add or update cycle configuration
     * @param cycle Cycle number
     * @param config New cycle configuration
     */
    function setCycleConfig(
        uint256 cycle,
        CycleConfig memory config
    ) external onlyOwner {
        cycleConfigs[cycle] = config;
        emit CycleConfigUpdated(cycle, config);
    }

    /**
     * @notice Get cycle information
     * @param cycle Cycle number
     */
    function getCycleInfo(uint256 cycle) external view returns (
        uint256 startPrice,
        uint256 stepSize,
        uint256 priceIncrement,
        uint256 maxSteps,
        uint256 cycleSupply,
        uint256 totalSold
    ) {
        CycleConfig memory config = cycleConfigs[cycle];
        return (
            config.startPrice,
            config.stepSize,
            config.priceIncrement,
            config.maxSteps,
            config.cycleSupply,
            cycleSold[cycle]
        );
    }
}