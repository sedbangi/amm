// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract FeeQuantizer {
    function getquantizedFee(uint256 fee) external pure returns (uint256) {
        if (fee >= 2000) return 0;
        //require(fee <= 2000, "Fee must be between 0 and 20%");
        fee = (fee / 50) * 50;
        return fee;
    }
}