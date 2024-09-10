// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/PriorityFeeSimulation.sol";

contract TestPriorityFeeSimulation is Test {
    PriorityFeeSimulation public simulation;

    function setUp() public {
        uint256 N = 5;
        uint256 nSigma = 2;
        simulation = new PriorityFeeSimulation(N, nSigma);
    }

    function testSubmitFee() public {
        simulation.submitFee(100);
        simulation.submitFee(200);
        simulation.submitFee(300);
        simulation.submitFee(400);
        simulation.submitFee(500);

        uint256 nSigmaFee = simulation.getNSigmaFee();
        console.log("n-sigma fee: %d", nSigmaFee);

        assertGt(nSigmaFee, 0);
    }

    function testSubmitFeeWithOverflow() public {
        simulation.submitFee(100);
        simulation.submitFee(200);
        simulation.submitFee(300);
        simulation.submitFee(400);
        simulation.submitFee(500);
        simulation.submitFee(600);

        uint256 nSigmaFee = simulation.getNSigmaFee();
        console.log("n-sigma fee: %d", nSigmaFee);

        assertGt(nSigmaFee, 0);
    }
}