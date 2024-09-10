// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {MathLibrary} from "../src/MathLibrary.sol";
import {console} from "forge-std/console.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/Math.sol";

contract GeometricBrownianMotion {
    using SafeMath for uint256;
    using SafeMath for int256;
    using MathLibrary for uint256;

    uint256 public initialPrice;
    uint256 public dailyStd;
    uint256 public blocksPerDay;
    uint256 public days;
    uint256[] public prices;
    
    constructor(uint256 _initialPrice, uint256 _dailyStd, uint256 _blocksPerDay, uint256 _days) {
        initialPrice = _initialPrice;
        dailyStd = _dailyStd;
        blocksPerDay = _blocksPerDay;
        days = _days;
    }

    function generatePricePath() public view returns (uint256[] memory) {
        uint256 p0 = initialPrice;
        uint256 sigma = dailyStd.div(sqrt(blocksPerDay));
        uint256 totalNumberOfBlocks = days.mul(blocksPerDay);
        int256[] memory z = new int256[](totalNumberOfBlocks);
        uint256[] memory prices = new uint256[](totalNumberOfBlocks);

        // Generate random normal values (simplified)
        for (uint256 k = 0; k < totalNumberOfBlocks; k++) {
            z[k] = int256(randomNormal(0, sigma));
        }

        // Cumulative sum
        for (uint256 k = 1; k < totalNumberOfBlocks; k++) {
            z[k] = z[k - 1] + z[k];
        }

        // Calculate prices
        for (uint256 k = 0; k < totalNumberOfBlocks; k++) {
            int256 drift = int256(k.mul(sigma).mul(sigma).div(2));
            prices[k] = uint256(exp(z[k] - drift)).mul(p0).div(exp(z[0]));
            console.log("Price at time %d: %d", k, prices[k]);
        }
        return prices;
    }
}