// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import "./MathLibrary.sol";

contract PriorityFeeAndPriceReturnVolatilitySimulator {
    using MathLibrary for uint256;
    uint256[200] public priorityFees;
    uint256[200] public prices;
    uint256[200] public blockNumbers;
    uint256 public index;

    constructor() {
        index = 0;
    }

    function recordData(uint256 priorityFee, uint256 price) public {
        if (block.number > blockNumbers[index]) {
            priorityFees[index] = priorityFee;
            prices[index] = price;
            blockNumbers[index] = block.number;
            index = (index + 1) % 200;
        }
    }

    function calculateVolatility(uint256[200] memory data) internal pure returns (uint256) {
        uint256 mean = 0;
        for (uint256 i = 0; i < 200; i++) {
            mean += data[i];
        }
        mean /= 200;

        uint256 variance = 0;
        for (uint256 i = 0; i < 200; i++) {
            variance += (data[i] - mean) ** 2;
        }
        variance /= 200;

        return sqrt(variance);
    }

    function getPriorityFeeVolatility() public view returns (uint256) {
        return calculateVolatility(priorityFees);
    }

    function getPriceVolatility() public view returns (uint256) {
        return calculateVolatility(prices);
    }
}