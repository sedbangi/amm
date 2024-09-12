// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./DammOracle.sol";

contract MevClassifier {
    DammOracle public dammOracle;
    uint256 public K;
    uint256 public mSigma;
    uint256 public nSigma;
    uint256[] public tokenPrices;
    uint256 public totalReturns;
    uint256 public totalSquaredReturns;

    constructor(address _dammOracle, uint256 _K, uint256 _mSigma, uint256 _nSigma) {
        dammOracle = DammOracle(_dammOracle);
        K = _K;
        mSigma = _mSigma;
        nSigma = _nSigma;
    }

    function submitTokenPrice(uint256 price) public {
        if (tokenPrices.length == K) {
            uint256 oldestPrice = tokenPrices[0];
            uint256 oldestReturn = (oldestPrice * 100) / tokenPrices[1] - 100;
            totalReturns -= oldestReturn;
            totalSquaredReturns -= oldestReturn * oldestReturn;
            tokenPrices = removeFirstElement(tokenPrices);
        }

        if (tokenPrices.length > 0) {
            uint256 lastPrice = tokenPrices[tokenPrices.length - 1];
            uint256 priceReturn = (price * 100) / lastPrice - 100;
            totalReturns += priceReturn;
            totalSquaredReturns += priceReturn * priceReturn;
        }

        tokenPrices.push(price);
    }

    function classifyTransaction(uint256 priorityFee) external view returns (bool) {
        uint256 priceVolatility = dammOracle.getPriceVolatility();
        uint256 feeVolatility = dammOracle.getFeeVolatility();

        // Implement the MEV classification logic based on volatilities
        return (priorityFee > feeVolatility) && (priceVolatility > mSigma);
    }

    function removeFirstElement(uint256[] storage array) internal returns (uint256[] storage) {
        if (array.length == 0) return array;
        for (uint256 i = 0; i < array.length - 1; i++) {
            array[i] = array[i + 1];
        }
        array.pop();
        return array;
    }
}