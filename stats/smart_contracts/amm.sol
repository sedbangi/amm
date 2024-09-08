// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v4-core/contracts/interfaces/IUniswapV4Pool.sol";
import "@uniswap/v4-core/contracts/interfaces/IUniswapV4Hook.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract AMM is IUniswapV4Hook, Ownable {
    using SafeMath for uint256;

    uint256 public sqrtPrice;
    uint256 public L;
    uint256 public baseFee;
    int256 public poolFee;
    uint256 public poolFeeInMarketDirection;
    uint256 public poolFeeInOppositeDirection;
    uint256 public orderBoolPressure;
    uint256 public m;
    uint256 public n;
    uint256 public alpha;
    uint256 public intentThreshold;
    uint256 public cutOffPercentile;
    bool public firstTransaction;
    uint256 public totalBlocks;
    uint256 public priceBeforePreviousBlock;
    uint256 public priceAfterPreviousBlock;
    uint256 public slippage;
    uint256 public currentBlockId;
    bool public firstTransaction;
    uint256[] public listSubmittedFees;
    mapping(address => bool) public setIntendToTradeNextBlock;
    mapping(address => bool) public setOfIntendToTradeSwapperSignalledInPreviousBlock;

    AggregatorV3Interface internal priceFeed;

    event BeforeSwap(address indexed pool, address indexed sender, uint256 amount0, uint256 amount1);
    event Trade(uint256 x, uint256 y, uint256 fee);

    constructor(
        uint256 _price,
        uint256 _L,
        uint256 _baseFee,
        uint256 _m,
        uint256 _n,
        uint256 _alpha,
        uint256 _intentThreshold,
        address _priceFeed
    ) {
        sqrtPrice = sqrt(_price);
        L = _L;
        baseFee = _baseFee;
        m = _m;
        n = _n;
        alpha = _alpha;
        intentThreshold = _intentThreshold;
        cutOffPercentile = 85;
        firstTransaction = true;
        totalBlocks = 0;
        priceBeforePreviousBlock = _price.mul(995).div(1000);
        priceAfterPreviousBlock = _price;
        slippage = 0;
        currentBlockId = 0;
        priceFeed = AggregatorV3Interface(_priceFeed);
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
        uint256 priceImpact = abs(priceAfterPreviousBlock.sub(priceBeforePreviousBlock)).mul(100).div(priceBeforePreviousBlock);
        uint256 dynamicFee = baseFee.add(priceImpact.mul(1).div(100));
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
        if (swapperIntent[swapperId]) {
            dynamicFee = meanFee.add(m.mul(sigmaFee));
        } else {
            dynamicFee = n.mul(sigmaFee);
        }
        return dynamicFee;
    }

    function calculateCombinedFee(uint256 blockId, address swapperId) public view returns (uint256) {
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
            combinedFee = combinedFee.mul(50).div(100);
        }
        return combinedFee;
    }
    function tradeToPriceWithGasFee(
        uint256 efficientOffChainPrice,
        uint256 submittedFee,
        address swapperId,
        uint256 blockId,
        uint256 gasCost,
        bool informed
    ) public returns (uint256, uint256, uint256) {
        if (currentBlockId == 0) {
            currentBlockId = blockId;
            beginBlock(blockId, efficientOffChainPrice);
        } else if (currentBlockId != blockId) {
            endBlock();
            currentBlockId = blockId;
            beginBlock(blockId, efficientOffChainPrice);
        }

        if (currentBlockId == 0) {
            poolFee = baseFee.add(1);
        } else {
            uint256 delta = calculateCombinedFee(blockId, swapperId).sub(baseFee);
            poolFeeInMarketDirection = poolFee.add(delta);
            poolFeeInOppositeDirection = poolFee.sub(delta);
        }

        uint256 currentAmmPrice = sqrtPrice.mul(sqrtPrice);
        (uint256 ammBidPrice, uint256 ammAskPrice) = getBidAndAskOfAmm(currentAmmPrice);

        if (submittedFee != 0) {
            require(submittedFee >= 0, "Submitted fee must be non-negative.");
            require(submittedFee < baseFee, "Submitted fee cannot exceed base fee.");
            listSubmittedFees.push(submittedFee);
            setIntendToTradeNextBlock[swapperId] = true;
        }

        if (informed) {
            if (ammAskPrice > efficientOffChainPrice && ammBidPrice < efficientOffChainPrice) {
                return (0, 0, 0);
            }
        }

        uint256 x;
        uint256 y;
        uint256 fee;
        uint256 newSqrtPrice;

        if (ammAskPrice < efficientOffChainPrice) {
            uint256 _fee = (orderBoolPressure > 0) ? poolFeeInMarketDirection.add(1) : (orderBoolPressure < 0) ? poolFeeInOppositeDirection.add(1) : baseFee.add(1);
            newSqrtPrice = sqrt(efficientOffChainPrice.div(_fee));
            (x, y, fee) = buyXTokensForYTokens(newSqrtPrice, _fee);
        } else if (ammBidPrice > efficientOffChainPrice) {
            uint256 _fee = (orderBoolPressure > 0) ? poolFeeInOppositeDirection.add(1) : (orderBoolPressure < 0) ? poolFeeInMarketDirection.add(1) : baseFee.add(1);
            newSqrtPrice = sqrt(efficientOffChainPrice.mul(2).sub(_fee));
            (x, y, fee) = sellXTokensForYTokens(newSqrtPrice, _fee);
        }

        if (gasCost > x.mul(efficientOffChainPrice).add(y)) {
            return (0, 0, 0);
        } else {
            sqrtPrice = newSqrtPrice;
        }

        emit Trade(x, y, fee);
        return (x, y, fee);
    }

    function beforeSwap(
        address sender,
        IUniswapV4Pool pool,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        emit BeforeSwap(address(pool), sender, amount0, amount1);
        // Custom logic before the swap
        (, int price, , , ) = priceFeed.latestRoundData();
        orderBoolPressure = uint256(price);
    }

    function afterSwap(
        address sender,
        IUniswapV4Pool pool,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        // No-op for after swap
    }

    function sort(uint256[] memory data) internal pure returns (uint256[] memory) {
        // Implement sorting logic
    }

    function mean(uint256[] memory data) internal pure returns (uint256) {
        // Implement mean calculation
    }

    function std(uint256[] memory data) internal pure returns (uint256) {
        // Implement standard deviation calculation
    }

    function abs(uint256 x) internal pure returns (uint256) {
        return x >= 0 ? x : -x;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }
}
