// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./PriorityFeeSimulation.sol";

contract MevClassifier {
    PriorityFeeSimulation public feeSimulator;
    uint256 public K;
    uint256 public mSigma;
    uint256 public nSigma;
    uint256[] public tokenPrices;
    uint256 public totalReturns;
    uint256 public totalSquaredReturns;

    constructor(address _feeSimulator, uint256 _K, uint256 _mSigma, uint256 _nSigma) {
        feeSimulator = PriorityFeeSimulation(_feeSimulator);
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

    function classifyTransaction(uint256 fee) public view returns (string memory) {
        uint256 nSigmaFee = feeSimulator.getNSigmaFee();
        if (fee > nSigmaFee) {
            return "MEV";
        }

        uint256 meanReturn = totalReturns / tokenPrices.length;
        uint256 varianceReturn = (totalSquaredReturns / tokenPrices.length) - (meanReturn * meanReturn);
        uint256 stddevReturn = sqrt(varianceReturn);

        uint256 mSigmaReturn = meanReturn + (mSigma * stddevReturn);
        uint256 nSigmaReturn = meanReturn + (nSigma * stddevReturn);

        if (mSigmaReturn > nSigmaReturn) {
            return "MEV";
        }

        return "Non-MEV";
    }

    function removeFirstElement(uint256[] memory array) internal pure returns (uint256[] memory) {
        uint256[] memory newArray = new uint256[](array.length - 1);
        for (uint256 i = 1; i < array.length; i++) {
            newArray[i - 1] = array[i];
        }
        return newArray;
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}