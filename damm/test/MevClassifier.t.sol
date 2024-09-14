// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/MevClassifier.sol";
import "../src/PriorityFeeSimulation.sol";

contract TestMevClassifier is Test {
    PriorityFeeSimulation public feeSimulator;
    MevClassifier public mevClassifier;

    function setUp() public {
        feeSimulator = new PriorityFeeSimulation(5, 2);
        mevClassifier = new MevClassifier(5, 1, 2);
    }

    function testClassifyTransaction() public {
        // Submit fees
        feeSimulator.submitFee(100);
        feeSimulator.submitFee(200);
        feeSimulator.submitFee(300);
        feeSimulator.submitFee(400);
        feeSimulator.submitFee(500);

        // Submit token prices
        mevClassifier.submitTokenPrice(1000);
        mevClassifier.submitTokenPrice(1050);
        mevClassifier.submitTokenPrice(1100);
        mevClassifier.submitTokenPrice(1150);
        mevClassifier.submitTokenPrice(1200);

        // Classify transaction
        bool classification = mevClassifier.classifyTransaction(600);
        console.log("Transaction classification: %s", classification);

        // assertEq(keccak256(bytes(classification)), keccak256(bytes("MEV")));
    }
}