// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/PriorityFeeAndPriceReturnVolatilitySimulator.sol";

contract PriorityFeeAndPriceReturnVolatilitySimulatorTest is Test {
    PriorityFeeAndPriceReturnVolatilitySimulator public simulator;

    function setUp() public {
        simulator = new PriorityFeeAndPriceReturnVolatilitySimulator();
    }

    function testClassifyMEVTransaction() public {
        // Record some data
        simulator.recordData(100, 1000);
        simulator.recordData(110, 1010);
        simulator.recordData(120, 1020);
        simulator.recordData(130, 1030);
        simulator.recordData(140, 1040);
        simulator.recordData(150, 1050);
        simulator.recordData(160, 1060);
        simulator.recordData(170, 1070);
        simulator.recordData(180, 1080);
        simulator.recordData(190, 1090);

        // Calculate sigma-priority fee
        uint256 sigmaPriorityFee = simulator.getPriorityFeeVolatility();

        // Calculate sigma of the price returns
        uint256 sigmaPriceReturn = simulator.getPriceVolatility();

        // Classify transactions
        for (uint256 i = 0; i < 10; i++) {
            uint256 priorityFee = simulator.priorityFees(i);
            if (priorityFee > sigmaPriorityFee) {
                console.log("Transaction %d is classified as MEV based on priority fee", i);
            } else if (sigmaPriorityFee > sigmaPriceReturn && priorityFee > sigmaPriceReturn) {
                console.log("Transaction %d is classified as MEV based on price return sigma", i);
            } else {
                console.log("Transaction %d is not classified as MEV", i);
            }
        }
    }
}