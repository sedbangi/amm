// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract FeeQuantizer {
    /*
    The fee quantizer function quantizes the fee to the nearest 50 basis points.
    The economic model is to allow submitted delta fees to be discretized to the nearest 50 basis points.
    Namely, multiple submissions of the same fee will be treated as the same fee.
    Furthermore, the fee is capped at 20%.
    Hence, LPs  who quote arbitrary fees above 20% will be treated as if they quoted 0%
    It is expected that LTs will not quote fees above 20% -> since it is not in their best interest to do so.
    Once pranking for multiple submissions is implemented, this function will be updated to reflect the new economic model.
    */
    function getquantizedFee(uint256 fee) external pure returns (uint256) {
        if (fee >= 2000) return 0;
        //require(fee <= 2000, "Fee must be between 0 and 20%");
        fee = (fee / 50) * 50;
        return fee;
    }
}