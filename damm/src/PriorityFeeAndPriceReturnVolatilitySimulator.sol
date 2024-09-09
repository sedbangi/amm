// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import "./MathLibrary.sol";

contract PriorityFeeAndPriceReturnVolatilitySimulator {
    using MathLibrary for uint256;
    uint constant historicalBlocks = 200;
    uint256[historicalBlocks] public priorityFees;
    uint256[historicalBlocks] public prices;
    uint256[historicalBlocks] public blockNumbers;
    uint256 public index;

    constructor() {
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

    function calculateVolatility(uint256[historicalBlocks] memory data) internal pure returns (uint256) {
        uint256 mean = 0;
        for (uint256 i = 0; i < historicalBlocks; i++) {
            mean += data[i];
        }
        mean /= 200;

        uint256 variance = 0;
        for (uint256 i = 0; i < historicalBlocks; i++) {
            variance += (data[i] - mean) ** 2;
        }
        variance /= 200;

        return variance.sqrt();
    }

    function getPriorityFeeVolatility() public view returns (uint256) {
        return calculateVolatility(priorityFees);
    }

    function getPriceVolatility() public view returns (uint256) {
        return calculateVolatility(prices);
    }
}