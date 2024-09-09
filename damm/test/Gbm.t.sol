// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../src/Gbm.sol";
import {console} from "forge-std/console.sol";

contract TestGeometricBrownianMotion {
    GeometricBrownianMotion public gbm;

    constructor() {
        // Initialize the GeometricBrownianMotion contract with example parameters
        gbm = new GeometricBrownianMotion(1000, 5, 2, 365, 10);
    }

    function testGenerateGBM() public {
        // Generate the GBM path
        gbm.generateGBM();

        // Retrieve and display the prices
        uint256[] memory prices = gbm.getPrices();
        for (uint256 k = 0; k < prices.length; k++) {
            console.log("Price at time %d: %d", k, prices[k]);
            if (k > 0) {
                assert(prices[k] != prices[k - 1]);
            }
        }
    }
}