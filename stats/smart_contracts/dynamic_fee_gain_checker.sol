// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract DynamicFeeGainChecker is Ownable {
    uint256 public n; // Number of blocks to consider
    uint256 public baseFee; // Static base fee
    uint256 public currentBlockId;
    mapping(uint256 => uint256) public dynamicFees;
    mapping(uint256 => uint256) public rebalancingResults;
    mapping(address => uint256) public lpGains;

    event DynamicFeeRecorded(uint256 blockId, uint256 dynamicFee);
    event RebalancingResultRecorded(uint256 blockId, uint256 result);
    event GainCalculated(address indexed lp, uint256 gain);

    constructor(uint256 _n, uint256 _baseFee) {
        n = _n;
        baseFee = _baseFee;
        currentBlockId = block.number;
    }

    // Function to record a dynamic fee
    function recordDynamicFee(uint256 dynamicFee) external onlyOwner {
        // Update the current block ID if a new block has started
        if (block.number != currentBlockId) {
            currentBlockId = block.number;
        }

        dynamicFees[currentBlockId] = dynamicFee;
        emit DynamicFeeRecorded(currentBlockId, dynamicFee);
    }

    // Function to record a rebalancing result
    function recordRebalancingResult(uint256 result) external onlyOwner {
        rebalancingResults[currentBlockId] = result;
        emit RebalancingResultRecorded(currentBlockId, result);
    }

    // Function to calculate the gain for the calling LP address
    function calculateGain(address lp) external {
        uint256 gain = 0;

        for (uint256 i = 1; i <= n; i++) {
            uint256 blockId = currentBlockId - i;
            uint256 dynamicFee = dynamicFees[blockId];
            uint256 rebalancingResult = rebalancingResults[blockId];

            // Calculate the gain as the difference between the rebalancing result with dynamic fee and static base fee
            uint256 staticFeeResult = rebalancingResult - baseFee;
            uint256 dynamicFeeResult = rebalancingResult - dynamicFee;
            gain += (dynamicFeeResult - staticFeeResult);
        }

        lpGains[lp] = gain;
        emit GainCalculated(lp, gain);
    }

    // Function to get the gain for the calling LP address
    function getGain(address lp) external view returns (uint256) {
        return lpGains[lp];
    }
}
