// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Oracle.sol";

contract MEVDetection is Ownable {
    Oracle public oracle;
    uint256 public n; // Number of blocks to consider
    uint256 public sigma; // Sigma multiplier
    uint256 public currentBlockId;
    mapping(uint256 => uint256[]) public blockPriorityFees;
    mapping(address => bool) public isProbabilisticMEV;

    event PriorityFeeRecorded(uint256 blockId, uint256 priorityFee);
    event ProbabilisticMEVDetected(address indexed sender, uint256 priorityFee);

    constructor(address _oracle, uint256 _n, uint256 _sigma) {
        oracle = Oracle(_oracle);
        n = _n;
        sigma = _sigma;
        currentBlockId = block.number;
    }

    // Function to record a priority fee
    function recordPriorityFee(uint256 priorityFee) external {
        // Update the current block ID if a new block has started
        if (block.number != currentBlockId) {
            currentBlockId = block.number;
            // Reset the priority fees for the new block
            blockPriorityFees[currentBlockId] = new uint256[](0);
        }

        blockPriorityFees[currentBlockId].push(priorityFee);
        emit PriorityFeeRecorded(currentBlockId, priorityFee);

        // Check if the transaction is a probabilistic MEV transaction
        if (isProbabilisticMEVTransaction(priorityFee)) {
            isProbabilisticMEV[msg.sender] = true;
            emit ProbabilisticMEVDetected(msg.sender, priorityFee);
        }
    }

    // Function to check if a transaction is a probabilistic MEV transaction
    function isProbabilisticMEVTransaction(uint256 priorityFee) internal view returns (bool) {
        uint256[] memory previousFees = getPreviousPriorityFees();
        if (previousFees.length == 0) {
            return false;
        }

        (uint256 mean, uint256 stdDev) = calculateMeanAndStdDev(previousFees);
        uint256 threshold = mean + sigma * stdDev;

        uint256 priorityFeeVolatility = calculateVolatility(previousFees);
        uint256 token0Volatility = calculateToken0Volatility();

        return priorityFee > threshold && priorityFeeVolatility > token0Volatility;
    }

    // Function to get priority fees from the previous n blocks
    function getPreviousPriorityFees() internal view returns (uint256[] memory) {
        uint256[] memory previousFees;
        uint256 count = 0;

        for (uint256 i = 1; i <= n; i++) {
            if (blockPriorityFees[currentBlockId - i].length > 0) {
                uint256[] memory fees = blockPriorityFees[currentBlockId - i];
                for (uint256 j = 0; j < fees.length; j++) {
                    previousFees[count] = fees[j];
                    count++;
                }
            }
        }

        return previousFees;
    }

    // Function to calculate the mean and standard deviation of an array of values
    function calculateMeanAndStdDev(uint256[] memory values) internal pure returns (uint256, uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < values.length; i++) {
            sum += values[i];
        }
        uint256 mean = sum / values.length;

        uint256 varianceSum = 0;
        for (uint256 i = 0; i < values.length; i++) {
            varianceSum += (values[i] - mean) ** 2;
        }
        uint256 variance = varianceSum / values.length;
        uint256 stdDev = sqrt(variance);

        return (mean, stdDev);
    }

    // Function to calculate the volatility of an array of values
    function calculateVolatility(uint256[] memory values) internal pure returns (uint256) {
        (uint256 mean, uint256 stdDev) = calculateMeanAndStdDev(values);
        return stdDev;
    }

    // Function to calculate the volatility of token0 returns using the oracle
    function calculateToken0Volatility() internal view returns (uint256) {
        // Implement your logic to calculate the volatility of token0 returns using the oracle
        // Placeholder implementation
        int latestPrice = oracle.getLatestPrice();
        return uint256(latestPrice) % 100; // Mock implementation
    }

    // Function to calculate the square root of a value
    function sqrt(uint256 x) internal pure returns (uint256) {
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}
