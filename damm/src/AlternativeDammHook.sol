// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../src/FeeQuantizer.sol";

contract DammHook {
    address[] public senders;
    mapping(address => uint256) public submittedDeltaFees;
    uint256 public BASE_FEE = 100;
    uint256 public CUT_OFF_PERCENTILE = 50;
    uint256 public N = 2;
    FeeQuantizer public feeQuantizer;

    constructor(address _feeQuantizer) {
        feeQuantizer = FeeQuantizer(_feeQuantizer);
    }

    function setSenders(address[] memory _senders) public {
        senders = _senders;
    }

    function setSubmittedDeltaFees(mapping(address => uint256) memory _submittedDeltaFees) public {
        submittedDeltaFees = _submittedDeltaFees;
    }

    function setBaseFee(uint256 _baseFee) public {
        BASE_FEE = _baseFee;
    }

    function setCutOffPercentile(uint256 _cutOffPercentile) public {
        CUT_OFF_PERCENTILE = _cutOffPercentile;
    }

    function setN(uint256 _N) public {
        N = _N;
    }

    function submitFee(address sender, uint256 fee) public {
        feeQuantizer.snapFee(fee);
        uint256 quantizedFee = feeQuantizer.getQuantizedFee();
        submittedDeltaFees[sender] = quantizedFee;
    }

    function getSubmittedDeltaFeeForBlock() public view returns (uint256) {
        uint256 numberSenders = senders.length;
        if (numberSenders < 2) {
            return BASE_FEE;
        }

        uint[] memory sortedDeltaFees = new uint[](numberSenders);

        for (uint256 i = 0; i < senders.length; i++) {
            sortedDeltaFees[i] = submittedDeltaFees[senders[i]];
        }

        sort(sortedDeltaFees);

        uint256 cutoffIndex = (numberSenders * CUT_OFF_PERCENTILE) / 100;
        uint256[] memory filteredFees = new uint256[](cutoffIndex);
        for (uint256 i = 0; i < cutoffIndex; i++) {
            filteredFees[i] = sortedDeltaFees[i];
        }
        
        uint256 sigmaFee = std(filteredFees);
        uint256 calculatedDeltaFeeForBlock = N * sigmaFee;

        return calculatedDeltaFeeForBlock;
    }

    function sort(uint[] memory data) internal pure {
        uint256 length = data.length;
        for (uint256 i = 0; i < length; i++) {
            for (uint256 j = i + 1; j < length; j++) {
                if (data[i] > data[j]) {
                    uint256 temp = data[i];
                    data[i] = data[j];
                    data[j] = temp;
                }
            }
        }
    }

    function std(uint256[] memory data) internal pure returns (uint256) {
        uint256 length = data.length;
        uint256 mean = 0;
        for (uint256 i = 0; i < length; i++) {
            mean += data[i];
        }
        mean = mean / length;

        uint256 variance = 0;
        for (uint256 i = 0; i < length; i++) {
            variance += (data[i] - mean) * (data[i] - mean);
        }
        variance = variance / length;

        return sqrt(variance);
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