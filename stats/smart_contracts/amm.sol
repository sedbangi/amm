// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract AMM is Ownable {
    using SafeMath for uint256;

    uint256 public baseFee;
    uint256 public m;
    uint256 public n;
    uint256 public alpha;
    uint256 public cutOffPercentile;
    uint256 public L;
    uint256 public sqrtPrice;
    uint256 public priceBeforePreviousBlock;
    uint256 public priceAfterPreviousBlock;
    bool public firstTransaction;
    uint256 public totalBlocks;
    uint256 public currentBlockId;
    uint256[] public listSubmittedFees;
    mapping(address => bool) public previousBlockSwappers;
    mapping(address => bool) public setOfIntendToTradeSwapperSignalledInPreviousBlock;

    event TokensSwapped(address indexed swapper, uint256 amountX, uint256 amountY, uint256 fee);

    constructor(uint256 _baseFee, uint256 _m, uint256 _n, uint256 _alpha, uint256 _cutOffPercentile, uint256 _L, uint256 _initialPrice) {
        baseFee = _baseFee;
        m = _m;
        n = _n;
        alpha = _alpha;
        cutOffPercentile = _cutOffPercentile;
        L = _L;
        sqrtPrice = sqrt(_initialPrice);
        priceBeforePreviousBlock = _initialPrice;
        priceAfterPreviousBlock = _initialPrice;
        firstTransaction = true;
        totalBlocks = 0;
        currentBlockId = 0;
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        return uint256(sqrt(int256(x)));
    }

    function sqrt(int256 x) internal pure returns (int256) {
        int256 z = (x + 1) / 2;
        int256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    function endogenousDynamicFee(uint256 blockId) public view returns (uint256) {
        if (blockId == 0) {
            return baseFee;
        }
        uint256 priceImpact = abs(priceAfterPreviousBlock - priceBeforePreviousBlock).div(priceBeforePreviousBlock);
        uint256 dynamicFee = baseFee.add(priceImpact.mul(1).div(100)); // Example: 1% of price impact
        return dynamicFee;
    }

    function exogenousDynamicFee(address swapperId) public view returns (uint256) {
        if (listSubmittedFees.length < 2) {
            return baseFee;
        }
        uint256[] memory sortedFees = sort(listSubmittedFees);
        uint256 cutoffIndex = sortedFees.length.mul(cutOffPercentile).div(100);
        uint256[] memory filteredFees = new uint256[](cutoffIndex);
        for (uint256 i = 0; i < cutoffIndex; i++) {
            filteredFees[i] = sortedFees[i];
        }
        uint256 meanFee = mean(filteredFees);
        uint256 sigmaFee = std(filteredFees);
        uint256 dynamicFee;
        if (previousBlockSwappers[swapperId]) {
            dynamicFee = meanFee.add(m.mul(sigmaFee));
        } else {
            dynamicFee = n.mul(sigmaFee);
        }
        return dynamicFee;
    }

    function calculateCombinedFee(uint256 blockId, address swapperId) public returns (uint256) {
        uint256 combinedFee = alpha.mul(endogenousDynamicFee(blockId)).add((1 - alpha).mul(exogenousDynamicFee(swapperId)));
        combinedFee = max(combinedFee, endogenousDynamicFee(blockId));
        if (combinedFee <= baseFee.mul(125).div(100)) {
            cutOffPercentile = min(cutOffPercentile.add(5), 100);
        }
        if (combinedFee > baseFee.mul(2)) {
            cutOffPercentile = max(cutOffPercentile.sub(5), 50);
        }
        if (firstTransaction) {
            combinedFee = combinedFee.mul(5);
            firstTransaction = false;
        }
        if (setOfIntendToTradeSwapperSignalledInPreviousBlock[swapperId]) {
            combinedFee = combinedFee.div(2);
        }
        return combinedFee;
    }

    function buyXTokensForYTokens(uint256 newSqrtPrice, uint256 poolFeePlusOne) public returns (uint256, uint256, uint256) {
        uint256 x = calculateAmountXTokensInvolvedInSwap(newSqrtPrice);
        uint256 y = calculateAmountOfYTokensInvolvedInSwap(newSqrtPrice);
        return (x, y.mul(poolFeePlusOne), y.mul(poolFeePlusOne.sub(1)));
    }

    function sellXTokensForYTokens(uint256 newSqrtPrice, uint256 poolFeePlusOne) public returns (uint256, uint256, uint256) {
        uint256 x = calculateAmountXTokensInvolvedInSwap(newSqrtPrice);
        uint256 y = calculateAmountOfYTokensInvolvedInSwap(newSqrtPrice);
        return (x, y.mul(2).sub(poolFeePlusOne), y.sub(y.mul(2).sub(poolFeePlusOne)));
    }

    function calculateAmountXTokensInvolvedInSwap(uint256 newSqrtPrice) public view returns (uint256) {
        uint256 priceXBeforeSwap = sqrtPrice.mul(sqrtPrice);
        uint256 priceXAfterSwap = newSqrtPrice.mul(newSqrtPrice);
        return (newSqrtPrice.sub(sqrtPrice)).mul(L).div(sqrtPrice.mul(newSqrtPrice));
    }

    function calculateAmountOfYTokensInvolvedInSwap(uint256 newSqrtPrice) public view returns (uint256) {
        return (newSqrtPrice.sub(sqrtPrice)).mul(L);
    }

    function getBidAndAskOfAMM(uint256 currentAMMPrice) public view returns (uint256, uint256) {
        uint256 bidPrice = currentAMMPrice.mul(2).sub(1).sub(baseFee);
        uint256 askPrice = currentAMMPrice.mul(1).add(baseFee);
        return (bidPrice, askPrice);
    }

    function tradeToPriceWithGasFee(uint256 efficientOffChainPrice, uint256 submittedFee, address swapperId, uint256 blockId, uint256 gas, bool informed) public returns (uint256, uint256, uint256) {
        if (currentBlockId == 0) {
            currentBlockId = blockId;
            beginBlock(blockId, efficientOffChainPrice);
        } else if (currentBlockId != blockId) {
            endBlock();
            currentBlockId = blockId;
            beginBlock(blockId, efficientOffChainPrice);
        }

        uint256 poolFee;
        if (currentBlockId == 0) {
            poolFee = 1 + baseFee;
        } else {
            uint256 delta = calculateCombinedFee(blockId, swapperId).sub(baseFee);
            poolFee = poolFee.add(delta);
        }

        uint256 currentAMMPrice = sqrtPrice.mul(sqrtPrice);
        (uint256 ammBidPrice, uint256 ammAskPrice) = getBidAndAskOfAMM(currentAMMPrice);

        if (submittedFee < 0) {
            revert("Submitted fee must be non-negative.");
        } else if (submittedFee >= baseFee) {
            revert("Submitted fee cannot exceed base fee.");
        } else {
            listSubmittedFees.push(submittedFee);
            previousBlockSwappers[swapperId] = true;
            setOfIntendToTradeSwapperSignalledInPreviousBlock[swapperId] = true;
        }

        if (informed) {
            if (ammAskPrice > efficientOffChainPrice && ammBidPrice < efficientOffChainPrice) {
                return (0, 0, 0);
            }
        }

        uint256 x;
        uint256 y;
        uint256 fee;
        if (ammAskPrice < efficientOffChainPrice) {
            uint256 _fee = 1 + poolFee;
            uint256 newSqrtPrice = sqrt(efficientOffChainPrice.div(_fee));
            (x, y, fee) = buyXTokensForYTokens(newSqrtPrice, _fee);
        } else if (ammBidPrice > efficientOffChainPrice) {
            uint256 _fee = 1 + poolFee;
            uint256 newSqrtPrice = sqrt(efficientOffChainPrice.mul(2).sub(_fee));
            (x, y, fee) = sellXTokensForYTokens(newSqrtPrice, _fee);
        }

        if (gas > x.mul(efficientOffChainPrice).add(y)) {
            revert("Gas cost cannot exceed the total value of the trade.");
        } else {
            sqrtPrice = sqrt(efficientOffChainPrice);
        }

        emit TokensSwapped(swapperId, x, y, fee);
        return (x, y, fee);
    }

    function beginBlock(uint256 blockId, uint256 efficientOffChainPrice) public {
        // Mocking chain_link price feed from CEX
        // Implement your logic here
    }

    function endBlock() public {
        listSubmittedFees = new uint256[](0);
        for (uint256 i = 0; i < previousBlockSwappers.length; i++) {
            delete previousBlockSwappers[i];
        }
        totalBlocks = totalBlocks.add(1);
        firstTransaction = true;
        for (uint256 i = 0; i < setOfIntendToTradeSwapperSignalledInPreviousBlock.length; i++) {
            delete setOfIntendToTradeSwapperSignalledInPreviousBlock[i];
        }
    }

    function abs(uint256 x) internal pure returns (uint256) {
        return x >= 0 ? x : -x;
    }

    function sort(uint256[] memory data) internal pure returns (uint256[] memory) {
        uint256[] memory sortedData = data;
        for (uint256 i = 0; i < sortedData.length; i++) {
            for (uint256 j = i + 1; j < sortedData.length; j++) {
                if (sortedData[i] > sortedData[j]) {
                    uint256 temp = sortedData[i];
                    sortedData[i] = sortedData[j];
                    sortedData[j] = temp;
                }
            }
        }
        return sortedData;
    }

    function mean(uint256[] memory data) internal pure returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < data.length; i++) {
            sum = sum.add(data[i]);
        }
        return sum.div(data.length);
    }

    function std(uint256[] memory data) internal pure returns (uint256) {
        uint256 meanValue = mean(data);
        uint256 variance = 0;
        for (uint256 i = 0; i < data.length; i++) {
            variance = variance.add((data[i].sub(meanValue)).mul(data[i].sub(meanValue)));
        }
        return sqrt(variance.div(data.length));
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }
}
