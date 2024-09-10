// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {MathLibrary} from "../src/MathLibrary.sol";
import {console} from "forge-std/console.sol";

contract PriorityFeeSimulation {
    uint256 public N;
    uint256 public nSigma;
    uint256[] public fees;
    uint256 public totalFees;
    uint256 public totalSquaredFees;

    constructor(uint256 _N, uint256 _nSigma) {
        N = _N;
        nSigma = _nSigma;
    }

    function submitFee(uint256 fee) public {
        if (fees.length == N) {
            uint256 oldestFee = fees[0];
            totalFees = totalFees - oldestFee;
            totalSquaredFees = totalSquaredFees - (oldestFee * oldestFee);
            fees = removeFirstElement(fees);
        }

        fees.push(fee);
        totalFees = totalFees + fee;
        totalSquaredFees = totalSquaredFees + (fee * fee);
    }

    function getNSigmaFee() public view returns (uint256) {
        require(fees.length > 0, "No fees submitted yet");

        uint256 mean = totalFees / fees.length;
        uint256 variance = (totalSquaredFees / fees.length) - (mean * mean);
        uint256 stddev = sqrt(variance);

        return mean + (nSigma * stddev);
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