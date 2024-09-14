// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/DammHook.sol";
import "../src/FeeQuantizer.sol";
import {DammOracle} from "../src/DammOracle.sol";


contract DynamicFeeTest is Test {
    DammHook dammHook;
    DammOracle dammOracle;
    FeeQuantizer quantizeFee;
 
    uint256 public BASE_FEE = 100;
    uint256 public CUT_OFF_PERCENTILE = 50;
    uint256 public N = 2;

    address[] public senders;
    mapping(address => uint256) public submittedDeltaFees;

    function setUp() public {
        quantizeFee = new FeeQuantizer();
        dammOracle = new DammOracle();
        dammHook = new DammHook(address(dammOracle));

        // Initialize mock data
        senders.push(address(0x1));
        senders.push(address(0x2));
        senders.push(address(0x3));

        submittedDeltaFees[address(0x1)] = 150;
        submittedDeltaFees[address(0x2)] = 200;
        submittedDeltaFees[address(0x3)] = 250;

        // Set the state variables in the DammHook contract
        dammHook.setSenders(senders);
        dammHook.setSubmittedDeltaFees(submittedDeltaFees);
        dammHook.setBaseFee(BASE_FEE);
        dammHook.setCutOffPercentile(CUT_OFF_PERCENTILE);
        dammHook.setN(N);
    }

    function testGetSubmittedDeltaFeeForBlock() public {
        uint256 deltaFee = dammHook.getSubmittedDeltaFeeForBlock();
        console.log("Calculated Delta Fee for Block: %d", deltaFee);

        // Add assertions to verify the behavior
        assertGt(deltaFee, 0);
    }

    function testBaseFeeForLessThanTwoSwappers() public {
        // Clear senders and add only one sender
        delete senders;
        senders.push(address(0x1));

        dammHook.setSenders(senders);

        uint256 deltaFee = dammHook.getSubmittedDeltaFeeForBlock();
        assertEq(deltaFee, BASE_FEE);
    }

    function testDynamicFeeLessThanTwoTimesBaseFee() public {
        uint256 deltaFee = dammHook.getSubmittedDeltaFeeForBlock();
        assertLt(deltaFee, 2 * BASE_FEE);
    }

    function testOnlyQuantizedFeesAccepted() public {
        uint256 fee = 150;
        uint256 quantizedFee = quantizeFee.quantize(fee);

        // Simulate submitting a quantized fee
        dammHook.submitFee(address(0x1), quantizedFee);

        uint256 deltaFee = dammHook.getSubmittedDeltaFeeForBlock();
        assertEq(deltaFee, quantizedFee);
    }
}