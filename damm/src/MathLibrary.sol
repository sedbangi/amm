// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library MathLibrary {
    using SafeMath for uint256;
    using SafeMath for int256;
    
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function exp(int256 x) internal pure returns (uint256) {
        // Approximate exp function using Taylor series expansion
        uint256 sum = 1;
        uint256 term = 1;
        for (uint256 i = 1; i < 10; i++) {
            term = term.mul(uint256(x)).div(i);
            sum = sum.add(term);
        }
        return sum;
    }

    function randomNormal(int256 mean, uint256 stddev) internal view returns (int256) {
        // Simplified random normal distribution using Box-Muller transform
        uint256 u1 = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 1000000;
        uint256 u2 = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, u1))) % 1000000;
        int256 z0 = int256(sqrt(u1).mul(int256(stddev)).div(1000));
        return z0 + mean;
    }
}