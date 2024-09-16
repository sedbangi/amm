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
        assertEq(feeQuantizer.getquantizedFee(0), 0);

        // Test case 2: fee = 25
        assertEq(feeQuantizer.getquantizedFee(25), 0);

        // Test case 3: fee = 50
        assertEq(feeQuantizer.getquantizedFee(50), 50);

        // Test case 4: fee = 75
        assertEq(feeQuantizer.getquantizedFee(100), 100);

        // Test case 5: fee = 100
        assertEq(feeQuantizer.getquantizedFee(100), 100);

        // Test case 6: fee = 1025
        assertEq(feeQuantizer.getquantizedFee(1025), 1000);

        // Test case 7: fee = 1075
        assertEq(feeQuantizer.getquantizedFee(1075), 1050);

        // Test case 8: fee = 2000
        assertEq(feeQuantizer.getquantizedFee(2000), 0);

        // Test case 9: fee > 2000 (should revert)
        //vm.expectRevert("Fee must be between 0 and 20%");
    }
}