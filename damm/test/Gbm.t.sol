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
        uint256 days = 10;
        gbm = new GeometricBrownianMotion(initialPrice, dailyStd, blocksPerDay, days);
    }

    function testGeneratePricePath() public {
        uint256[] memory prices = gbm.generatePricePath();

        // Log the prices for inspection
        for (uint256 i = 0; i < prices.length; i++) {
            console.log("Price at block %d: %d", i, prices[i]);
        }

        // Basic assertions to ensure the function works as expected
        assertEq(prices.length, gbm.days() * gbm.blocksPerDay());
        assertGt(prices[0], 0);
        for (uint256 i = 1; i < prices.length; i++) {
            assertGt(prices[i], 0);
        }
    }
}