// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Oracle.sol";

contract DynamicFeeReplicationChecker is Ownable {
    Oracle public oracle;
    uint256 public baseFee; // Static base fee
    uint256 public currentBlockId;
    mapping(uint256 => uint256) public dynamicFees;
    mapping(uint256 => uint256) public onChainPrices;
    mapping(uint256 => uint256) public replicationErrors;

    event DynamicFeeRecorded(uint256 blockId, uint256 dynamicFee);
    event OnChainPriceRecorded(uint256 blockId, uint256 onChainPrice);
    event ReplicationErrorCalculated(uint256 blockId, uint256 replicationError);

    constructor(address _oracle, uint256 _baseFee) {
        oracle = Oracle(_oracle);
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

    // Function to record an on-chain price
    function recordOnChainPrice(uint256 onChainPrice) external onlyOwner {
        onChainPrices[currentBlockId] = onChainPrice;
        emit OnChainPriceRecorded(currentBlockId, onChainPrice);
    }

    // Function to calculate the replication error
    function calculateReplicationError() external onlyOwner {
        int offChainPrice = oracle.getLatestPrice();
        uint256 onChainPrice = onChainPrices[currentBlockId];

        // Calculate the replication error as the absolute difference between on-chain and off-chain prices
        uint256 replicationError = abs(int(onChainPrice) - offChainPrice);
        replicationErrors[currentBlockId] = replicationError;

        emit ReplicationErrorCalculated(currentBlockId, replicationError);
    }

    // Function to check if the dynamic fee reduces the replication error
    function checkDynamicFeeEffectiveness() external view returns (bool) {
        uint256 previousBlockId = currentBlockId - 1;
        uint256 previousReplicationError = replicationErrors[previousBlockId];
        uint256 currentReplicationError = replicationErrors[currentBlockId];

        // Check if the replication error has reduced
        return currentReplicationError < previousReplicationError;
    }

    // Internal function to calculate the absolute value of an integer
    function abs(int x) internal pure returns (uint256) {
        return uint256(x >= 0 ? x : -x);
    }
}
