// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/FeeQuantizer.sol";

contract TestFeeQuantizer is Test {
    FeeQuantizer public feeQuantizer;

    function setUp() public {
        feeQuantizer = new FeeQuantizer();
    }

    function testSnapFee() public {
        // Test case 1: fee = 0
        feeQuantizer.snapFee(0);
        assertEq(feeQuantizer.getquantizedFee(), 0);

        // Test case 2: fee = 25
        feeQuantizer.snapFee(25);
        assertEq(feeQuantizer.getquantizedFee(), 0);

        // Test case 3: fee = 50
        feeQuantizer.snapFee(50);
        assertEq(feeQuantizer.getquantizedFee(), 50);

        // Test case 4: fee = 75
        feeQuantizer.snapFee(75);
        assertEq(feeQuantizer.getquantizedFee(), 100);

        // Test case 5: fee = 100
        feeQuantizer.snapFee(100);
        assertEq(feeQuantizer.getquantizedFee(), 100);

        // Test case 6: fee = 1025
        feeQuantizer.snapFee(1025);
        assertEq(feeQuantizer.getquantizedFee(), 1000);

        // Test case 7: fee = 1050
        feeQuantizer.snapFee(1050);
        assertEq(feeQuantizer.getquantizedFee(), 1050);

        // Test case 8: fee = 1075
        feeQuantizer.snapFee(1075);
        assertEq(feeQuantizer.getquantizedFee(), 1100);

        // Test case 9: fee = 2000
        feeQuantizer.snapFee(2000);
        assertEq(feeQuantizer.getquantizedFee(), 2000);

        // Test case 10: fee > 2000 (should revert)
        vm.expectRevert("Fee must be between 0 and 20%");
        feeQuantizer.snapFee(2001);
    }
}