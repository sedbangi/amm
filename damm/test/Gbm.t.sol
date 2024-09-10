// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/Gbm.sol";

contract TestGeometricBrownianMotion is Test {
    GeometricBrownianMotion public gbm;

    function setUp() public {
        // Initialize the GeometricBrownianMotion contract with example parameters
        uint256 initialPrice = 1000;
        uint256 dailyStd = 5;
        uint256 blocksPerDay = 5760; // Assuming 15 seconds per block
        uint256 numberDays = 1;
        gbm = new GeometricBrownianMotion(initialPrice, dailyStd, blocksPerDay, numberDays);
    }

    function testGeneratePricePath() public {
        uint256[] memory prices = gbm.generatePricePath();

        // Log the prices for inspection
        for (uint256 k = 0; k < prices.length; k++) {
            console.log("Price at block %d: %d", k, prices[k]);
        }

        // Basic assertions to ensure the function works as expected
        assertEq(prices.length, gbm.numberDays() * gbm.blocksPerDay());
        assertGt(prices[0], 0);
        for (uint256 k = 1; k < prices.length; k++) {
            assertGt(prices[k], 0);
        }
    }
}