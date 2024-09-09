// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/DammHook.sol";
import {MathLibrary} from "../src/MathLibrary.sol";

contract TestDammHook is Test {
    DammHook public dammHook;

    address[] public senders;
    mapping(address => uint256) public submittedDeltaFees;

    uint256 public constant BASE_FEE = 100;
    uint256 public constant CUT_OFF_PERCENTILE = 50;
    uint256 public constant N = 2;

    using MathLibrary for uint256;

    function setUp() public {
        dammHook = new DammHook();
    }

    function testGetSubmittedDeltaFeeForBlock() public {
        // Test case 1: numberSenders < 2
        assertEq(dammHook.getSubmittedDeltaFeeForBlock(), BASE_FEE);

        // Test case 2: numberSenders >= 2
        address sender1 = address(0x1);
        address sender2 = address(0x2);
        address sender3 = address(0x3);

        dammHook.addSender(sender1, 100);
        dammHook.addSender(sender2, 200);
        dammHook.addSender(sender3, 300);

        uint256 expectedFee = calculateExpectedFee([100, 200, 300]);
        assertEq(dammHook.getSubmittedDeltaFeeForBlock(), expectedFee);
    }

    function calculateExpectedFee(uint256[] memory fees) internal pure returns (uint256) {
        uint256 numberSenders = fees.length;
        uint256[] memory sortedFees = sort(fees);

        uint256 cutoffIndex = (numberSenders * CUT_OFF_PERCENTILE) / 100;
        uint256[] memory filteredFees = new uint256[](cutoffIndex);
        for (uint256 i = 0; i < cutoffIndex; i++) {
            filteredFees[i] = sortedFees[i];
        }

        uint256 sigmaFee = std(filteredFees);
        return N * sigmaFee;
    }

    function sort(uint256[] memory data) internal pure returns (uint256[] memory) {
        uint256 n = data.length;
        for (uint256 i = 0; i < n; i++) {
            for (uint256 j = i + 1; j < n; j++) {
                if (data[i] > data[j]) {
                    uint256 temp = data[i];
                    data[i] = data[j];
                    data[j] = temp;
                }
            }
        }
        return data;
    }

    function std(uint256[] memory data) internal pure returns (uint256) {
        uint256 sum = 0;
        uint256 n = data.length;
        for (uint256 i = 0; i < n; i++) {
            sum += data[i];
        }
        uint256 mean = sum / n;

        uint256 varianceSum = 0;
        for (uint256 i = 0; i < n; i++) {
            varianceSum += (data[i] - mean) ** 2;
        }
        uint256 variance = varianceSum / n;
        return variance.sqrt();
    }
}