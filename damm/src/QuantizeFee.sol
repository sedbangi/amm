// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract FeeQuantizer {
    uint256 public quantizedFee;

    function snapFee(uint256 fee) public {
        require(fee <= 2000, "Fee must be between 0 and 20%");
        
        // Snap the fee to the nearest 0.5%
        uint256 remainder = fee % 50;
        if (remainder >= 25) {
            quantizedFee = fee + (50 - remainder);
        } else {
            quantizedFee = fee - remainder;
        }
    }

    function getquantizedFee() public view returns (uint256) {
        return quantizedFee;
    }
}