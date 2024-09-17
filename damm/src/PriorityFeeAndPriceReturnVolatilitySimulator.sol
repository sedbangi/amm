// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;


import {console} from "forge-std/console.sol";

contract PriorityFeeAndPriceReturnVolatilitySimulator {
    uint256 public historicalBlocks;
    uint256[] public priorityFees;
    uint256[] public prices;
    uint256[] public blockNumbers;
    uint256 public index;
    bool first_trx;

    constructor(uint256 _historicalBlocks) {
        historicalBlocks = _historicalBlocks;
        priorityFees = new uint256[](_historicalBlocks);
        prices = new uint256[](_historicalBlocks);
        blockNumbers = new uint256[](_historicalBlocks);
        index = 0;
    }

    function recordData(uint256 priorityFee, uint256 price) public {
        if (block.number > blockNumbers[index]) {
            priorityFees[index] = priorityFee; 
            prices[index] = price;
            blockNumbers[index] = block.number;
            index = (index + 1) % historicalBlocks;
        }
    }

    function generateRandomPriorityFeesStandardizedToThousand() public {
        // Random value between 1 and 10_000
        for (uint256 i = 0; i < historicalBlocks; i++) {
            uint256 randomPriorityFee = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i))) % 10_000 + 1; 
            priorityFees[i] = randomPriorityFee;
            blockNumbers[i] = block.number + i;
        }
    }

    function generateRandomPricesStandardizedToThousand() public {
        // Random value between 1 and 10_000
        for (uint256 i = 0; i < historicalBlocks; i++) {
            uint256 randomPrice = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i))) % 10_000 + 1; 
            prices[i] = randomPrice;
            blockNumbers[i] = block.number + i;
        }
    }

    function calculateMean(
        uint256[] memory data) internal view returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < data.length; i++) {
            sum += data[i];
        }
        return sum / data.length;
    }

    function calculateStdDev(
        uint256[] memory data, uint256 mean) internal view returns (uint256) {
        uint256 variance = 0;

        for (uint256 i = 0; i < data.length; i++) {
            uint256 diff = data[i] > mean ? data[i] - mean : mean - data[i];
            variance += diff * diff;
        }

        variance /= data.length;
        return sqrt(variance);
    }

    function calculateVolatility(uint256[] memory data) internal view returns (uint256) {
        if (data.length == 0) {
           return 0;
        }
        uint256 mean = calculateMean(data);
        uint256 stdDev = calculateStdDev(data, mean);
        return  stdDev;
    }

    function getPriorityFeeVolatility() public view returns (uint256) {
        return calculateVolatility(priorityFees);
    }

    function getPriceVolatility() public view returns (uint256) {
        return calculateVolatility(prices);
    }

    function generateDataAndCalculateVolatilities() public returns (uint256, uint256) {
        generateRandomPriorityFeesStandardizedToThousand();
        generateRandomPricesStandardizedToThousand();
        
        uint256 priorityFeeVolatility = getPriorityFeeVolatility();
        uint256 priceVolatility = getPriceVolatility();
        
        return (priorityFeeVolatility, priceVolatility);
    }

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