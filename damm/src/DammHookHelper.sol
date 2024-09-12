// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {DammOracle} from "../src/DammOracle.sol";

contract DammHookHelper {
    uint256 public baseFee;
    // NOTE: Sid gives from oracle
    uint256 public priceAfterPreviousBlock;
    // NOTE: Sid gives from oracle
    uint256 public priceBeforePreviousBlock;
    uint256[] public submittedFees;
    uint256 public cutOffPercentile;
    mapping(address => bool) public previousBlockSwappers;
    bool public firstTransaction;
    uint256 public alpha;
    uint256 public m;
    uint256 public n;

    DammOracle public dammOracle;

    constructor(address _dammOracle) {
        dammOracle = DammOracle(_dammOracle);
        baseFee = 3000;
        cutOffPercentile = 85;
        firstTransaction = true;
        alpha = 50;
        m = 1;
        n = 1;
    }

    function endogenousDynamicFee(uint256 blockId) internal view returns (uint256) {
        if (blockId == 0) {
            return baseFee;
        }
        uint256 priceImpact = (priceAfterPreviousBlock > priceBeforePreviousBlock) ?
            (priceAfterPreviousBlock - priceBeforePreviousBlock) * 1e18 / priceBeforePreviousBlock :
            (priceBeforePreviousBlock - priceAfterPreviousBlock) * 1e18 / priceBeforePreviousBlock;
        uint256 dynamicFee = baseFee + priceImpact * 1 / 100; // 1% of price impact
        return dynamicFee;
    }

    function exogenousDynamicFee(address swapperId) internal view returns (uint256) {
        if (submittedFees.length < 2) {
            return baseFee;
        }
        uint256[] memory sortedFees = submittedFees;
        // Sort the fees
        for (uint i = 0; i < sortedFees.length; i++) {
            for (uint j = i + 1; j < sortedFees.length; j++) {
                if (sortedFees[i] > sortedFees[j]) {
                    uint256 temp = sortedFees[i];
                    sortedFees[i] = sortedFees[j];
                    sortedFees[j] = temp;
                }
            }
        }
        uint256 cutoffIndex = sortedFees.length * cutOffPercentile / 100;
        uint256 sum = 0;
        for (uint i = 0; i < cutoffIndex; i++) {
            sum += sortedFees[i];
        }
        uint256 meanFee = sum / cutoffIndex;
        uint256 sigmaFee = 0;
        for (uint i = 0; i < cutoffIndex; i++) {
            sigmaFee += (sortedFees[i] - meanFee) ** 2;
        }
        sigmaFee = sqrt(sigmaFee / cutoffIndex);
        uint256 dynamicFee = previousBlockSwappers[swapperId] ? meanFee + m * sigmaFee : n * sigmaFee;
        return dynamicFee;
    }

    function calculateCombinedFee(uint256 blockId, address swapperId) internal returns (uint256) {
        uint256 combinedFee = alpha * endogenousDynamicFee(blockId) + (100 - alpha) * exogenousDynamicFee(swapperId) / 100;
        combinedFee = combinedFee > endogenousDynamicFee(blockId) ? combinedFee : endogenousDynamicFee(blockId);
        if (combinedFee <= baseFee * 125 / 100) {
            cutOffPercentile = cutOffPercentile + 5 > 100 ? 100 : cutOffPercentile + 5;
        }
        if (combinedFee > baseFee * 2) {
            cutOffPercentile = cutOffPercentile - 5 < 50 ? 50 : cutOffPercentile - 5;
        }
        if (firstTransaction) {
            combinedFee *= 5;
            firstTransaction = false;
        }
        return combinedFee;
    }

    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}